#!/usr/bin/env bash
#
# migrations/v1.2.1_to_v1.3.0.sh
#
# Migrates a _agent_team_work_zone/ from v1.2.1 to v1.3.0.
#   $1 UPGRADE_DIR  $2 TARGET_DIR   (invoked by upgrade.sh; do not run directly)
#
# MINOR: teammate models by subscription tier, and a new skill /remote-collab.
#   - New scripts resources/scripts/atwz_detect_tier.sh and atwz_remote_collab.sh,
#     new skill resources/skills/remote-collab/ (installed into .claude/skills/ by
#     bootstrap's install_skills like every other skill), new docs/model_policy_schema.md.
#   - Work rule 10 gains the /remote-collab merge exception (README RULES block and
#     resources/teammate_rules.md).
#   - meeting_room/README.md: a section for a team on another machine.
#   - .gitignore: patterns for the policy-file temp file and the /remote-collab runtime files
#     (state, last-seen, digests, the watcher's loop job, the watch pid file, temp files).
# Behaviour: the usual framework-owned overwrite and block refreshes. The rules and
# teammate-rules texts changed, so each workstation README whose block differs gets a
# .bak of its old block. Also refreshes meeting_room/README.md and appends the missing
# new patterns to the install's .gitignore (append-only; nothing created if it is absent).
# Existing teams get no model_policy.json (their teammates stay on sonnet).
# settings.conf, RULES_LEDGER.md and TEAMMATE_INFO.json are never created,
# changed or deleted. No schema change, no user-data migration.

set -euo pipefail
[ $# -ge 2 ] || { echo "Usage: $0 <UPGRADE_DIR> <TARGET_DIR>" >&2; exit 2; }
UPGRADE_DIR="$1"; TARGET_DIR="$2"
MIG_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./common.sh
. "$MIG_DIR/common.sh"

print_step "migration v1.2.1 → v1.3.0"
cp_framework_files "$UPGRADE_DIR" "$TARGET_DIR" "resources" "docs"
[ -f "$UPGRADE_DIR/CHANGELOG.md" ] && { cp "$UPGRADE_DIR/CHANGELOG.md" "$TARGET_DIR/CHANGELOG.md"; print_step "CHANGELOG.md"; }
# meeting_room/README.md is framework-owned (the rest of meeting_room/ is user data).
[ -f "$UPGRADE_DIR/meeting_room/README.md" ] && { mkdir -p "$TARGET_DIR/meeting_room"; cp "$UPGRADE_DIR/meeting_room/README.md" "$TARGET_DIR/meeting_room/README.md"; print_step "meeting_room/README.md"; }
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

# .gitignore: append only the patterns new in v1.3.0 that the install lacks.
NEW_GITIGNORE_LINES=(
    '*_team/.policy.??????'
    '*_team/.remote_collab_state'
    '*/.remote_collab_state'
    '*_team/teammates/*/remote_seen'
    '*_team/teammates/*/digests/'
    '*_team/teammates/*/loop_job'
    '*_team/.remote_seen'
    '*/.remote_seen'
    '*_team/.remote_collab_watch.pid'
    '*/.remote_collab_watch.pid'
    '*_team/digests/'
    '*/digests/'
    '*/.rc.??????'
)
print_step ".gitignore（只追加 v1.3.0 新增且缺少的规则）"
if [ -f "$TARGET_DIR/.gitignore" ]; then
    if append_missing_lines "$TARGET_DIR/.gitignore" \
        "# v1.3.0 升级追加：成员模型策略文件写入时的临时文件，以及 /remote-collab 的运行时文件（状态、摘要、查看任务、后台脚本的 pid；每次查看、合并、推送都会变）。" \
        "${NEW_GITIGNORE_LINES[@]}"; then
        [ "$APPEND_MISSING_COUNT" -gt 0 ] || print_step "  .gitignore 已含全部新规则，未改动"
    fi
else
    print_warn "这个安装里没有 _agent_team_work_zone/.gitignore —— 不新建（你可能在别处统一管理忽略规则）。"
    print_step "  如果工作区纳入 git 管理，请自行忽略这些运行时文件：${NEW_GITIGNORE_LINES[*]}"
fi

write_version "$TARGET_DIR/VERSION" "v1.3.0"

# --- What's new in v1.3.0 ---
print_step "v1.3.0 —— 成员模型按你的订阅来定：/quickstart 和 /onboard 判断订阅档位，写入 <团队目录>/model_policy.json（成员默认模型和人数上限）。已有团队没有这个文件，成员默认仍用 sonnet；想用按档位的默认值，可以让 lead 执行 /onboard 里\"选定成员模型\"一步。"
print_step "v1.3.0 —— 新技能 /remote-collab：两台机器上的两个团队通过 git 和会议室协作同一个仓库（start、pull、push、stop、status；由 haiku 查看成员或后台脚本定时查看）。工作守则第 10 条加了它的合并例外，所以守则块已刷新，旧块已备份。"
print_step "v1.3.0 —— meeting_room/README.md：新增一节，写另一台机器上的团队怎么用会议室。"
print_step "无需手动迁移。升级后请重启 Claude Code 会话，并对每个运行中的团队执行 /reactivate-team。"

print_success "v1.3.0 applied"
