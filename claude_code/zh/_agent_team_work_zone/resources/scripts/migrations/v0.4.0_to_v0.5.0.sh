#!/usr/bin/env bash
#
# migrations/v0.4.0_to_v0.5.0.sh
#
# Migrates a _agent_team_work_zone/ from v0.4.0 to v0.5.0.
#   $1 UPGRADE_DIR  $2 TARGET_DIR   (invoked by upgrade.sh; do not run directly)
#
# Behaviour: full framework-owned overwrite + the usual block refreshes, plus one
# new step for a user-owned file:
#   - resources/ + docs/ overwrite (new scripts, the /broadcast-rule skill and the
#     optional CLAUDE.md sections arrive here; bootstrap.sh, which upgrade.sh
#     re-runs, installs the skill).
#   - Top-level README: FRAMEWORK / RULES / REFERENCE refreshed (the new
#     "Before you start" section is inside FRAMEWORK).
#   - Lead / flat workstation READMEs: RULES refreshed (diff + backup).
#   - Teammate workstation READMEs: TEAMMATE_RULES refreshed (diff + backup);
#     no block yet → left alone. Text above the block is never touched.
#   - _agent_team_work_zone/.gitignore (user-owned): only the patterns that are
#     new in this version are appended, and only those missing. Nothing is
#     rewritten, reordered or removed. No .gitignore → not created (notice only).
#
# Never created, overwritten or deleted here: _agent_team_work_zone/settings.conf,
# <team>_team/RULES_LEDGER.md, TEAMMATE_INFO.json. (CLAUDE.md is bootstrap.sh's: append-only.)
# No schema change.
# Fail-soft: any single file's step can warn + skip without aborting the rest.

set -euo pipefail
[ $# -ge 2 ] || { echo "Usage: $0 <UPGRADE_DIR> <TARGET_DIR>" >&2; exit 2; }
UPGRADE_DIR="$1"; TARGET_DIR="$2"
MIG_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./common.sh
. "$MIG_DIR/common.sh"

print_step "migration v0.4.0 → v0.5.0"
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

# .gitignore: append only the patterns new in v0.5.0 that the install lacks.
NEW_GITIGNORE_LINES=(
    '*_team/teammates/*/.started'
    '.hook_logs/'
    '*_team/teammates/*/.checkpoint_nudge_count'
    '*_team/TEAMMATE_INFO.json.bak'
    '*_team/.info.??????'
    '**/.README.md.??????'
    '/.VERSION.??????'
    '/settings.conf.??????'
)
GITIGNORE_RESULT=""
print_step ".gitignore（只追加 v0.5.0 新增且缺少的规则）"
if [ -f "$TARGET_DIR/.gitignore" ]; then
    if append_missing_lines "$TARGET_DIR/.gitignore" \
        "# v0.5.0 升级追加：只在运行时产生的文件，以及写入中断时可能留下的临时文件（守则备份仍纳入管理）。" \
        "${NEW_GITIGNORE_LINES[@]}"; then
        if [ "$APPEND_MISSING_COUNT" -gt 0 ]; then
            GITIGNORE_RESULT="在 _agent_team_work_zone/.gitignore 里追加了 $APPEND_MISSING_COUNT 条缺少的规则；你自己的行没有改动"
        else
            GITIGNORE_RESULT="_agent_team_work_zone/.gitignore 已含全部新规则，未改动"
        fi
    else
        GITIGNORE_RESULT="无法追加到 _agent_team_work_zone/.gitignore（见上方警告），文件保持原样"
    fi
else
    GITIGNORE_RESULT="这个安装里没有 _agent_team_work_zone/.gitignore，已跳过，没有新建（见上方）"
    print_warn "这个安装里没有 _agent_team_work_zone/.gitignore —— 不新建（你可能在别处统一管理忽略规则）。"
    print_step "  模板版在 https://github.com/SR-A-W/agent-team-work-zone 的 claude_code/zh/_agent_team_work_zone/.gitignore。"
    print_step "  把它拷进 _agent_team_work_zone/ 后，git 会忽略：升级暂存区（.upgrade/，其 README 除外）、teammate 启动标记（.started）、"
    print_step "  hook 日志（.hook_logs/）、idle hook 计数器（.checkpoint_nudge_count）、注册表备份（TEAMMATE_INFO.json.bak），"
    print_step "  以及写入中断时留下的临时文件（.info.??????、.README.md.??????、.VERSION.??????、settings.conf.??????）。守则备份（*.rules.bak.*）仍纳入管理。"
fi

write_version "$TARGET_DIR/VERSION" "v0.5.0"

# --- What's new in v0.5.0 ---
print_step "v0.5.0 —— 对你有影响的变化："
print_step "  • README「开始之前」：_agent_team_work_zone/ 要放在项目目录里，并且总在这个目录下启动 Claude Code；强烈推荐把它纳入 git。"
print_step "  • 可选的 checkpoint git 保存（默认关闭）：bash _agent_team_work_zone/resources/scripts/atwz_checkpoint_git.sh enable。设置存在 _agent_team_work_zone/settings.conf，只有这条命令会创建它。"
print_step "  • 共享 checkout 的 git 锁：bash _agent_team_work_zone/resources/scripts/atwz_git_lock.sh run -- git … 让各 agent 的 git 命令一次只跑一个。git 锁需要 git 2.5 或更高。"
print_step "  • 新增 /broadcast-rule（team lead 用）：把规则变更发给每个 teammate，并维护 <team>_team/RULES_LEDGER.md，只有这个 skill 会创建它。"
print_step "  • 可选的 CLAUDE.md 段落（消息格式、平实用语）在 resources/claude_md_optional/。只在首次安装时询问，升级时不询问；要加的话：cat _agent_team_work_zone/resources/claude_md_optional/<文件>.md >> CLAUDE.md"
print_step "  • .gitignore：$GITIGNORE_RESULT。"
print_step "  • 本次升级没有创建、修改或删除 settings.conf、任何 RULES_LEDGER.md 或 TEAMMATE_INFO.json。"
print_step "向后兼容，无需手动迁移。"

print_success "v0.5.0 applied"
