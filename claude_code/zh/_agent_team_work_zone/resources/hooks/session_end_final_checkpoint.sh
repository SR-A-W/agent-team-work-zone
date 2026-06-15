#!/usr/bin/env bash
#
# session_end_final_checkpoint.sh — 在 SessionEnd hook 触发时执行
#
# 作用：提醒正在退出的 session（lead 或 teammate）关于 checkpoint 状态。
# 注意：SessionEnd 时 skill 无法真的执行——context 已收尾。本脚本只做日志和
# 留下退出标记。真正的 checkpoint 应该靠 TeammateIdle 触发链路在 session 活跃时完成。
#
# 输入（stdin JSON）：session_id / hook_event_name / cwd
# 输出：stdout 空（exit 后无法注入 context 了）
# 返回：exit 0

set -uo pipefail

payload=$(cat)

# 从 cwd 推断 session 类型和工位
cwd=""
if command -v jq >/dev/null 2>&1; then
    cwd=$(echo "$payload" | jq -r '.cwd // empty' 2>/dev/null)
fi
[ -z "$cwd" ] && cwd="$PWD"

# 找项目根
project_root="${CLAUDE_PROJECT_DIR:-}"
if [ -z "$project_root" ] || [ ! -d "$project_root/_agent_team_work_zone" ]; then
    project_root="$cwd"
    while [ "$project_root" != "/" ] && [ ! -d "$project_root/_agent_team_work_zone" ]; do
        project_root=$(dirname "$project_root")
    done
fi

[ -d "$project_root/_agent_team_work_zone" ] || exit 0

# 记录 session 结束的时间戳到 log（可选诊断用）
log_dir="$project_root/_agent_team_work_zone/.hook_logs"
mkdir -p "$log_dir" 2>/dev/null || true

timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
echo "$timestamp SessionEnd cwd=$cwd" >> "$log_dir/session_end.log" 2>/dev/null || true

# 注：v0.2.3 起自动 checkpoint 由 teammate_idle_checkpoint.sh（TeammateIdle + exit 2 闸门）
# 在 session 活跃时完成；SessionEnd 阶段 context 已收尾、跑不了 skill，故这里不再扫描旧的
# .checkpoint_pending flag（该机制已退役），仅留时间戳日志供诊断。

exit 0
