#!/usr/bin/env bash
#
# migrations/v0.5.0_to_v1.0.0.sh
#
# Migrates a _agent_team_work_zone/ from v0.5.0 to v1.0.0.
#   $1 UPGRADE_DIR  $2 TARGET_DIR   (invoked by upgrade.sh; do not run directly)
#
# MAJOR-NOTICE: v1.0.0 没有改变团队的工作方式。新增的是：
# MAJOR-NOTICE:   - 用 npm 安装与升级：npx agent-team-work-zone init / upgrade
# MAJOR-NOTICE:     （或 npm i -g agent-team-work-zone 全局安装后，用短命令 atwz）；
# MAJOR-NOTICE:   - 会话开始时的新版本提示（可以关闭）；
# MAJOR-NOTICE:   - 首次安装时的 git 检查。
# MAJOR-NOTICE: 大版本号标记的是新的发行方式，不是破坏性变更；
# MAJOR-NOTICE: `bash _agent_team_work_zone/upgrade.sh` 照常可用。
#
# Behaviour: the usual framework-owned overwrite and block refreshes, plus the
# root entry upgrade.sh (new: UPGRADE_SOURCE_DIR). The rules and teammate-rules
# texts did not change in this release, so no .bak files are expected. Nothing else: no .gitignore change, no schema change, no user-data
# migration. settings.conf, RULES_LEDGER.md and TEAMMATE_INFO.json are never
# created, changed or deleted. Fail-soft per README, as in earlier migrations.
#
# The "# MAJOR-NOTICE:" lines above are printed by the dispatcher before it asks
# for confirmation of this major-version upgrade.

set -euo pipefail
[ $# -ge 2 ] || { echo "Usage: $0 <UPGRADE_DIR> <TARGET_DIR>" >&2; exit 2; }
UPGRADE_DIR="$1"; TARGET_DIR="$2"
MIG_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./common.sh
. "$MIG_DIR/common.sh"

print_step "migration v0.5.0 → v1.0.0"
cp_framework_files "$UPGRADE_DIR" "$TARGET_DIR" "resources" "docs"
[ -f "$UPGRADE_DIR/CHANGELOG.md" ] && { cp "$UPGRADE_DIR/CHANGELOG.md" "$TARGET_DIR/CHANGELOG.md"; print_step "CHANGELOG.md"; }
# Root entry upgrade.sh (framework-owned): v1.0.0 adds UPGRADE_SOURCE_DIR to it.
# It may be the very script that started this upgrade and bash reads scripts as
# it runs, so never rewrite it in place: write a temp file beside it (keeping its
# mode) and rename it over the old one — the running copy keeps its old inode.
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

write_version "$TARGET_DIR/VERSION" "v1.0.0"

# --- What's new in v1.0.0 ---
print_step "v1.0.0 —— 团队的工作方式没有变化。新增：用 npm 包安装与升级："
print_step "  • 新项目：  npx agent-team-work-zone init [项目目录] [--lang zh|en]"
print_step "  • 已有安装：npx agent-team-work-zone upgrade [项目目录] [--yes]（使用包内自带的模板，不联网下载）"
print_step "  • 全局安装后（npm i -g agent-team-work-zone）可用短名：atwz init / atwz upgrade。"
print_step "  • bash _agent_team_work_zone/upgrade.sh 照旧可用；也可以指定本地模板目录：UPGRADE_SOURCE_DIR=<目录> bash _agent_team_work_zone/upgrade.sh"
print_step "  • 主版本升级现在会先打印本版改了什么；没有终端时可用 ATWZ_ASSUME_YES=1（npm 方式：--yes）确认。"
print_step "  • 新增：有新版本发布时，会话开始时打印一段简短提示（最多一天查一次、在后台进行；从不自动升级）。关闭：ATWZ_UPDATE_CHECK=0，或创建文件 _agent_team_work_zone/.no_update_check。"
print_step "  • 新安装：bootstrap.sh 会检查一次 git（不在仓库里或不在仓库根目录时提醒；在仓库根目录时询问是否把 _agent_team_work_zone/ 纳入 git）。升级时不询问。"
print_step "向后兼容，无需手动迁移。"

print_success "v1.0.0 applied"
