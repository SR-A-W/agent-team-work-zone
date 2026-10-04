#!/usr/bin/env bash
#
# migrations/v0.3.2_to_v0.4.0.sh
#
# Migrates a _agent_team_work_zone/ from v0.3.2 to v0.4.0.
#   $1 UPGRADE_DIR  $2 TARGET_DIR   (invoked by upgrade.sh; do not run directly)
#
# Behaviour: full framework-owned overwrite, plus a rules-refresh sweep so the
# changed rules text actually reaches existing installs:
#   - The checkpoint-safety changes touch skills, hooks, docs and
#     resources/teammate_rules.md. Skills/hooks/docs arrive with the
#     resources/ + docs/ overwrite (and bootstrap.sh, which upgrade.sh re-runs);
#     the teammate rules excerpt only reaches teammate READMEs through the
#     TEAMMATE_RULES refresh below.
#   - The rules refresh itself is the fixed one: self-healed RULES
#     markers end at the last framework rule instead of the next "## " heading,
#     and teammate blocks are backed up before being replaced.
#   - Top-level README: FRAMEWORK / RULES / REFERENCE refreshed.
#   - Lead / flat workstation READMEs: RULES refreshed (diff + backup).
#   - Teammate workstation READMEs: TEAMMATE_RULES refreshed (diff + backup);
#     a README with no block yet is left alone (delivered on next
#     spawn/reactivate — Rule #1: a migration does not invent content in
#     another agent's workstation).
#
# NO breaking change. TEAMMATE_INFO.json schema_version 1 → 2 is zero-migration
# (the only change is that last_checkpoint_at is no longer written; an old
# registry that still carries it is tolerated and ignored), so this script does
# NOT touch any TEAMMATE_INFO.json. Fail-soft: any individual README's refresh
# can warn + skip without aborting the rest.

set -euo pipefail
[ $# -ge 2 ] || { echo "Usage: $0 <UPGRADE_DIR> <TARGET_DIR>" >&2; exit 2; }
UPGRADE_DIR="$1"; TARGET_DIR="$2"
MIG_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./common.sh
. "$MIG_DIR/common.sh"

print_step "migration v0.3.2 → v0.4.0"
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
    # Lead / flat workstation: full rules block, hand-copied per /onboard and
    # possibly customised — diff, back up the old block, replace only if it differs.
    [ -f "$d/README.md" ] && refresh_rules_section "$UPGRADE_DIR/README.md" "$d/README.md"
    if [ -d "$d/teammates" ]; then
        for td in "$d/teammates"/*/; do
            [ -d "$td" ] || continue
            # Teammate workstation: condensed TEAMMATE_RULES block, same diff +
            # backup treatment; no block yet → left alone (see header).
            [ -f "${td}README.md" ] && refresh_teammate_rules_section "$UPGRADE_DIR/resources/teammate_rules.md" "${td}README.md"
        done
    fi
done

write_version "$TARGET_DIR/VERSION" "v0.4.0"

# --- What's new in v0.4.0 ---
print_step "v0.4.0 —— checkpoint 安全："
print_step "  • teammate 跑 /checkpoint 时不再写 TEAMMATE_INFO.json，注册表只由 lead 维护，多个 teammate 同时 checkpoint 不会再互相覆盖注册表更新。"
print_step "  • TeammateIdle 的 checkpoint 提醒 hook 遇到 subagent 调用（payload 带 agent_id）时直接退出，不再提醒 subagent 做 checkpoint。"
print_step "  • /reactivate-team 遇到损坏的 TEAMMATE_INFO.json 会明确报错，并提示从 .bak 或 git 恢复；距上次 checkpoint 的时间改按各 teammate 的 working-context.md 修改时间计算。"
print_step "  • /checkpoint 先核对 teammate 身份，覆写 Part A 快照前先留存旧快照，完成后回一条带身份的回执。"
print_step "  • TEAMMATE_INFO.json 的 schema_version 1 → 2：去掉 last_checkpoint_at 字段。现有注册表无需改动，旧字段会被忽略；本次升级不碰你的注册表。"
print_step "v0.4.0 —— 守则刷新不再吞掉你的内容："
print_step "  • teammate README：TEAMMATE_RULES 块与新版不同时，先把旧块备份为 <README>.teammate_rules.bak.<时间戳>，再替换。"
print_step "  • 给还没有 RULES 标记的 README 补标记时，块的结尾改为最后一条框架守则之后，不再是下一个 \"## \" 标题之前。要让你的笔记留在块外，请用 ---（或 *** / ___）或一个不带编号的 ##/### 标题把它和守则隔开；紧贴在最后一条守则后面的文字会被并进块，随旧块进 <文件>.rules.bak.<时间戳>（会打 ⚠ 提示）。"
print_step "  • 补 REFERENCE 标记时，你追加在参考章节之后的内容（如 <!-- USER:* --> 段）不再被吞进块里。"
print_step "  • 上面每条 ⚠ 都写明了文件；有备份的会另起一行写出备份路径；.bak 文件不会自动删除，请核对后自行清理。"
print_step "向后兼容，无需手动迁移。"

print_success "v0.4.0 applied"
