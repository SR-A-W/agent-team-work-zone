#!/usr/bin/env bash
#
# migrations/v0.3.1_to_v0.3.2.sh
#
# Migrates a _agent_team_work_zone/ from v0.3.1 to v0.3.2.
#   $1 UPGRADE_DIR  $2 TARGET_DIR   (invoked by upgrade.sh; do not run directly)
#
# Behaviour: full framework-owned overwrite, PLUS a new rules-refresh pass:
#   - Work Rules text now lives inside <!-- RULES:START --> / <!-- RULES:END -->
#     markers in README.md (independent of the existing FRAMEWORK markers), so
#     it can be kept in sync across upgrades instead of only living outside the
#     FRAMEWORK block where nothing ever touched it.
#   - Lead workstations and flat workstations are swept: if a README already
#     has a rules section, the RULES markers are self-healed in if missing,
#     then the block is diffed against source and refreshed (with a backup of
#     the old block) only if it actually differs.
#   - Teammate workstations get a SEPARATE, deliberately asymmetric mechanism:
#     a condensed 7-rule <!-- TEAMMATE_RULES:START/END --> block sourced from
#     resources/teammate_rules.md (new in this version — see the inline
#     comments below for why the two mechanisms differ).
#   - Files with no rules section / no TEAMMATE_RULES block at all are left
#     untouched — that gap is closed on the spawn/reactivate side, not by this
#     migration.
#
# NO breaking change. NO TEAMMATE_INFO.json schema change. Fail-soft: any
# individual README's rules refresh can warn+skip without aborting the rest.

set -euo pipefail
[ $# -ge 2 ] || { echo "Usage: $0 <UPGRADE_DIR> <TARGET_DIR>" >&2; exit 2; }
UPGRADE_DIR="$1"; TARGET_DIR="$2"
MIG_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./common.sh
. "$MIG_DIR/common.sh"

print_step "migration v0.3.1 → v0.3.2"
cp_framework_files "$UPGRADE_DIR" "$TARGET_DIR" "resources" "docs"
[ -f "$UPGRADE_DIR/CHANGELOG.md" ] && { cp "$UPGRADE_DIR/CHANGELOG.md" "$TARGET_DIR/CHANGELOG.md"; print_step "CHANGELOG.md"; }
[ -f "$UPGRADE_DIR/README.md" ] && { print_step "README.md (FRAMEWORK section)"; replace_framework_section "$UPGRADE_DIR/README.md" "$TARGET_DIR/README.md"; }
[ -f "$UPGRADE_DIR/README.md" ] && { print_step "README.md (RULES section)"; refresh_rules_section "$UPGRADE_DIR/README.md" "$TARGET_DIR/README.md"; }
[ -f "$UPGRADE_DIR/README.md" ] && { print_step "README.md (REFERENCE section)"; refresh_reference_section "$UPGRADE_DIR/README.md" "$TARGET_DIR/README.md"; }

print_step "扫描工位 README 的守则区（跳过 docs/resources/meeting_room/archive/.upgrade）"
for d in "$TARGET_DIR"/*/; do
    d="${d%/}"
    base="$(basename "$d")"
    case "$base" in
        docs|resources|meeting_room|archive|.upgrade) continue ;;
    esac
    # Lead / flat workstation: the 13-rule block is hand-copied by the agent per
    # /onboard, so it may carry user customization (already observed 4 diverged
    # copies in practice) — diff against source, back up the old block, and
    # replace ONLY if it actually differs.
    [ -f "$d/README.md" ] && refresh_rules_section "$UPGRADE_DIR/README.md" "$d/README.md"
    if [ -d "$d/teammates" ]; then
        for td in "$d/teammates"/*/; do
            [ -d "$td" ] || continue
            tgt_readme="${td}README.md"
            if [ -f "$tgt_readme" ]; then
                # Teammate workstation: the TEAMMATE_RULES block is a framework-owned
                # literal excerpt, deliberately asymmetric to the lead/flat path above
                # (no diff-backup mechanism — see refresh_rules_section's docstring for
                # why the two are allowed to differ). But this migration does NOT
                # fabricate a TEAMMATE_RULES block where none exists: per Rule #1, a
                # migration script does not reach into another agent's workstation to
                # invent content it never had. Pre-existing teammate workstations spawned
                # before this version simply have no block yet — that gets delivered the
                # next time the teammate is spawned/reactivated (spawn-team/reactivate-team
                # already append it), not by this migration.
                if grep -q '<!-- TEAMMATE_RULES:START -->' "$tgt_readme"; then
                    # Block already present (created by a spawn/reactivate on or after
                    # this version) — refresh it, but only rewrite the file if the
                    # content actually changed, so a repeat upgrade doesn't needlessly
                    # touch every teammate README's mtime.
                    do_replace=1
                    if grep -q '<!-- TEAMMATE_RULES:END -->' "$tgt_readme"; then
                        tgt_block="$(awk '/<!-- TEAMMATE_RULES:START -->/{c=1} c{print} /<!-- TEAMMATE_RULES:END -->/{c=0}' "$tgt_readme")"
                        src_block="$(awk '/<!-- TEAMMATE_RULES:START -->/{c=1} c{print} /<!-- TEAMMATE_RULES:END -->/{c=0}' "$UPGRADE_DIR/resources/teammate_rules.md")"
                        [ "$tgt_block" = "$src_block" ] && do_replace=0
                    fi
                    if [ "$do_replace" -eq 1 ]; then
                        replace_marked_section "$UPGRADE_DIR/resources/teammate_rules.md" "$tgt_readme" \
                            '<!-- TEAMMATE_RULES:START -->' '<!-- TEAMMATE_RULES:END -->' \
                            "$(basename "$td")/README.md teammate-rules block refreshed"
                    fi
                else
                    print_step "teammates/$(basename "$td"): no TEAMMATE_RULES block yet — will be delivered on next spawn/reactivate (no action needed)"
                fi
            fi
        done
    fi
done

write_version "$TARGET_DIR/VERSION" "v0.3.2"

# --- What's new in v0.3.2 ---
print_step "v0.3.2 引入 RULES:START/END 标记，独立于 FRAMEWORK 标记之外，覆盖工作守则区。"
print_step "此前守则区在 FRAMEWORK 标记之外，升级从不刷新；工位 README 也无守则章节。"
print_step "本次升级会扫描顶层 README + lead / 扁平工位 README，按需自愈标记并刷新 13 条守则区（有实质变化才备份）。"
print_step "teammate 工位改用独立的 TEAMMATE_RULES 精简 7 条（resources/teammate_rules.md）：已有该块的，内容变了才刷新（不产生备份）；还没有该块的（本版之前 spawn 的存量），本次迁移不动它——留给下次 spawn/reactivate 时 teammate 自己补（守则 #1：别人不改 teammate 工位文件）。"
print_step "守则区若有实质变化，旧块会备份为 <文件>.rules.bak.<时间戳>，供核对/回滚。"
print_step "顶层 README 新增 REFERENCE:START/END 标记，覆盖预置 Skills/Custom Subagents/角色原型/角色定义存储/Troubleshooting 五节：这些此前也在标记外、升级永不刷新；现在每次升级直接覆盖（纯框架内容，无用户定制，不产生备份）。"
print_step "向后兼容，无需手动迁移。"

print_success "v0.3.2 applied"
