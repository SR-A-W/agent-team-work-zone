#!/usr/bin/env bash
#
# migrations/v1.0.0_to_v1.1.0.sh
#
# Migrates a _agent_team_work_zone/ from v1.0.0 to v1.1.0.
#   $1 UPGRADE_DIR  $2 TARGET_DIR   (invoked by upgrade.sh; do not run directly)
#
# MINOR: a new command and installer improvements.
#   - New: `npx agent-team-work-zone reconfigure` / `bash .../bootstrap.sh --reconfigure` asks the
#     install-time questions again on an existing install (nothing in the work zone changes).
#   - Every install-time question is an arrow-key menu; upgrades no longer ask about display
#     mode or auto permission; the optional CLAUDE.md sections are strongly recommended and
#     added by default on a first install (never on an upgrade).
#   - Warnings in bold orange-red, recommended options in green (terminal only, not with NO_COLOR).
#   - npm upgrade asks for the language when it cannot detect it.
#   - Docs: there is no separate "atwz" npm package.
# Behaviour: the usual framework-owned overwrite and block refreshes (the rules
# and teammate-rules texts did not change, so no .bak files are expected).
# settings.conf, RULES_LEDGER.md and TEAMMATE_INFO.json are never created,
# changed or deleted. No schema change, no user-data migration.

set -euo pipefail
[ $# -ge 2 ] || { echo "Usage: $0 <UPGRADE_DIR> <TARGET_DIR>" >&2; exit 2; }
UPGRADE_DIR="$1"; TARGET_DIR="$2"
MIG_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./common.sh
. "$MIG_DIR/common.sh"

print_step "migration v1.0.0 → v1.1.0"
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

write_version "$TARGET_DIR/VERSION" "v1.1.0"

# --- What's new in v1.1.0 ---
print_step "v1.1.0 —— 新命令：npx agent-team-work-zone reconfigure（源码安装：bash _agent_team_work_zone/resources/scripts/bootstrap.sh --reconfigure）。在现有安装上重新询问安装时的问题——可选 CLAUDE.md 段落、git 纳入、显示模式、auto 权限——不重装、不下载，也不改动 _agent_team_work_zone/ 里的任何内容。"
print_step "v1.1.0 —— 安装过程中的所有提问都改成了方向键菜单（↑↓ 切换，回车确认）。"
print_step "v1.1.0 —— 升级时不再询问 teammate 显示模式和 auto 权限模式，沿用现有设置（要修改请用 reconfigure）。"
print_step "v1.1.0 —— 两段可选 CLAUDE.md 段落改为强烈推荐，首次安装时默认加入。升级从不加入；要给本项目加入，请运行 reconfigure。"
print_step "v1.1.0 —— 警告（⚠）用加粗橙红色显示，菜单里的推荐项用绿色（仅在终端里、且未设置 NO_COLOR 时）。"
print_step "v1.1.0 —— npm upgrade 判断不出安装的语言时，会让你选择。"
print_step "v1.1.0 —— 文档更正：没有单独的 \"atwz\" npm 包。用 npx agent-team-work-zone <命令>；或用 npm i -g agent-team-work-zone 装一次，之后用短命令 atwz <命令>。"
print_step "无需手动迁移。"

print_success "v1.1.0 applied"
