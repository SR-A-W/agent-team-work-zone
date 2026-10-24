#!/usr/bin/env bash
#
# migrations/v1.1.0_to_v1.2.0.sh
#
# Migrates a _agent_team_work_zone/ from v1.1.0 to v1.2.0.
#   $1 UPGRADE_DIR  $2 TARGET_DIR   (invoked by upgrade.sh; do not run directly)
#
# MINOR: a new skill, a short command name and rule/skill text changes.
#   - New skill /quickstart (resources/skills/quickstart/, installed into .claude/skills/ by
#     bootstrap's install_skills like every other skill); quick modes in /onboard and /spawn-team.
#   - New: `config` as a short name for `reconfigure` in the npm command (`reconfigure` still works).
#   - The optional "Plain vocabulary" CLAUDE.md section ships with a starter list of rejected
#     words (CLAUDE.md itself is not touched by an upgrade).
#   - Rules and skills: read workstation files to the end; commitments get open/done/void;
#     the idle notification may carry a summary but is not acted on.
#   - meeting_room/README.md: conventions for a team from another repository.
# Behaviour: the usual framework-owned overwrite and block refreshes. The rules and
# teammate-rules texts changed, so each workstation README whose block differs gets a
# .bak of its old block. Also refreshes meeting_room/README.md (changed in this version;
# earlier upgrades had stopped copying it) and the root entry upgrade.sh.
# settings.conf, RULES_LEDGER.md and TEAMMATE_INFO.json are never created,
# changed or deleted. No schema change, no user-data migration.

set -euo pipefail
[ $# -ge 2 ] || { echo "Usage: $0 <UPGRADE_DIR> <TARGET_DIR>" >&2; exit 2; }
UPGRADE_DIR="$1"; TARGET_DIR="$2"
MIG_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./common.sh
. "$MIG_DIR/common.sh"

print_step "migration v1.1.0 → v1.2.0"
cp_framework_files "$UPGRADE_DIR" "$TARGET_DIR" "resources" "docs"
[ -f "$UPGRADE_DIR/CHANGELOG.md" ] && { cp "$UPGRADE_DIR/CHANGELOG.md" "$TARGET_DIR/CHANGELOG.md"; print_step "CHANGELOG.md"; }
# meeting_room/README.md is framework-owned (the rest of meeting_room/ is user data).
[ -f "$UPGRADE_DIR/meeting_room/README.md" ] && { mkdir -p "$TARGET_DIR/meeting_room"; cp "$UPGRADE_DIR/meeting_room/README.md" "$TARGET_DIR/meeting_room/README.md"; print_step "meeting_room/README.md"; }
# Root entry upgrade.sh (framework-owned). It may be the very script that started
# this upgrade and bash reads scripts as it runs, so never rewrite it in place:
# write a temp file beside it (keeping its mode) and rename it over the old one —
# the running copy keeps its old inode.
if [ -f "$UPGRADE_DIR/upgrade.sh" ]; then
    if _t="$(mktemp_beside "$TARGET_DIR/upgrade.sh")" && cat "$UPGRADE_DIR/upgrade.sh" > "$_t" && mv "$_t" "$TARGET_DIR/upgrade.sh"; then
        print_step "upgrade.sh"
    else
        rm -f "${_t:-}"
        print_warn "Could not update $TARGET_DIR/upgrade.sh — the old one still works; copy it from the new template later."
    fi
fi
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
    # Lead / flat workstation: full rules block — diff, back up, replace only if it differs.
    [ -f "$d/README.md" ] && refresh_rules_section "$UPGRADE_DIR/README.md" "$d/README.md"
    if [ -d "$d/teammates" ]; then
        for td in "$d/teammates"/*/; do
            [ -d "$td" ] || continue
            # Teammate workstation: TEAMMATE_RULES block, same diff + backup; no block → left alone.
            [ -f "${td}README.md" ] && refresh_teammate_rules_section "$UPGRADE_DIR/resources/teammate_rules.md" "${td}README.md"
        done
    fi
done

write_version "$TARGET_DIR/VERSION" "v1.2.0"

# --- What's new in v1.2.0 ---
print_step "v1.2.0 —— 新技能 /quickstart：第一次使用时，在项目根目录启动 Claude Code，输入 /quickstart，它不提问就建好第一支团队。想自己定角色，仍用 /onboard。"
print_step "v1.2.0 —— 新的短命令：npx agent-team-work-zone config（或 atwz config），与 reconfigure 相同；reconfigure 仍然可用。看到 Unknown command: config 时，说明你的 atwz 或 npx 缓存的版本较旧：用 npx agent-team-work-zone@latest config，或照旧用 reconfigure。"
print_step "v1.2.0 —— 可选的「平实用语」CLAUDE.md 段落现在带一份起始的禁用词名单。升级不改动你的 CLAUDE.md；想要这些条目，对照 resources/claude_md_optional/plain_vocabulary.md 自己抄进去。"
print_step "v1.2.0 —— 守则和 skill：工位文件要读到末尾（没读完的在回执里写 Unread: <文件>）；承诺分为进行中、已完成、作废三种状态，作废由 lead 裁定；idle 通知可能带摘要，但 lead 不据此行动，问题要写进 SendMessage 汇报。"
print_step "v1.2.0 —— meeting_room/README.md：新增来自其他仓库的团队使用本会议室的约定。"
print_step "无需手动迁移。升级后请重启 Claude Code 会话，并对每个运行中的团队执行 /reactivate-team。"

print_success "v1.2.0 applied"
