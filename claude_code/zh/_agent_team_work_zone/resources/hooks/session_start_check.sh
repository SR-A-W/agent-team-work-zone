#!/usr/bin/env bash
#
# session_start_check.sh — 在 SessionStart hook 触发时执行（lead session 或 teammate session）
#
# 作用：检查是否在 team lead 工位下，如果是且 TEAMMATE_INFO.json 里有
# active_teammates，通过 additionalContext 提醒用户/agent 运行 /reactivate-team。
# 这消除"lead 以为 teammate 还在"的幻觉——Claude Code 不会自动 respawn。
#
# 输入（stdin JSON）：session_id / hook_event_name / cwd / source（startup/resume/compact）
# 输出：
#   - 非 team lead 工位 或 active_teammates 为空 → stdout 空
#   - 是 team lead 且有 active teammate → stdout { "additionalContext": ... }
#     文案随 source 分叉（关键）：
#       compact（同进程上下文压缩）→ "teammate 很可能仍活着，先 ping 再判死"
#       startup/resume/未知（真重启）→ "全部已死，跑 /reactivate-team"
#     —— compact 时绝不能喊 "Session restarted = ALL DEAD"（teammate 没死）
# 返回：exit 0

set -uo pipefail

payload=$(cat)

# 提取 cwd
cwd=""
if command -v jq >/dev/null 2>&1; then
    cwd=$(echo "$payload" | jq -r '.cwd // empty' 2>/dev/null)
fi
[ -z "$cwd" ] && cwd="$PWD"

# 找项目根（向上找直到看到 _agent_team_work_zone/）
project_root="${CLAUDE_PROJECT_DIR:-}"
if [ -z "$project_root" ] || [ ! -d "$project_root/_agent_team_work_zone" ]; then
    project_root="$cwd"
    while [ "$project_root" != "/" ] && [ ! -d "$project_root/_agent_team_work_zone" ]; do
        project_root=$(dirname "$project_root")
    done
fi

[ -d "$project_root/_agent_team_work_zone" ] || exit 0

# --- 清扫 stale checkpoint 临时文件 ---
# 真正的 session 重启（source=startup/resume）⇒ 所有 teammate 必死 ⇒ 任何遗留的 checkpoint
# 临时文件都已失效。死掉的 teammate 不会自己清，残留会累积成"地雷"。在重启入口一次清掉：
#   - .checkpoint_pending      —— v0.2.3 前的旧 flag（机制已退役；这里为升级用户清残留）
#   - .checkpoint_nudge_count  —— teammate_idle_checkpoint.sh 的连续-nudge 安全帽计数
#                                 （session-scoped，重启后无意义，清掉避免误判）
# compact（同一进程内上下文压缩，teammate 可能仍活着）不在此清扫，保守起见只在真重启时动手。
source=""
if command -v jq >/dev/null 2>&1; then
    source=$(echo "$payload" | jq -r '.source // empty' 2>/dev/null)
fi
if [ "$source" = "startup" ] || [ "$source" = "resume" ] || [ -z "$source" ]; then
    rm -f "$project_root"/_agent_team_work_zone/*_team/teammates/*/.checkpoint_pending 2>/dev/null || true
    rm -f "$project_root"/_agent_team_work_zone/*_team/teammates/*/.checkpoint_nudge_count 2>/dev/null || true
fi

# 扫所有 *_team 工位看哪些有非空 TEAMMATE_INFO.json 的 active_teammates
reminders=""
for team_dir in "$project_root"/_agent_team_work_zone/*_team/; do
    [ -d "$team_dir" ] || continue
    info_file="$team_dir/TEAMMATE_INFO.json"
    [ -f "$info_file" ] || continue

    team_name=$(basename "$team_dir")

    # 读 active_teammates 数量
    active_count=0
    if command -v jq >/dev/null 2>&1; then
        active_count=$(jq '.active_teammates | length' "$info_file" 2>/dev/null || echo 0)
    fi

    if [ "$active_count" -gt 0 ]; then
        if [ -z "$reminders" ]; then
            reminders="Team persistence check: "
        fi
        reminders="${reminders}${team_name} has ${active_count} active teammate(s). "
    fi
done

if [ -n "$reminders" ]; then
    if [ "$source" = "compact" ]; then
        # 上下文压缩：同进程，teammate 很可能仍活着——绝不能因此报"已死"
        ADDL="[Teammate persistence] CONTEXT COMPACTED (same process — NOT a session restart). Detected: ${reminders}A compaction does NOT kill teammates: ones spawned earlier in THIS still-running session are very likely STILL ALIVE. Before treating ANY teammate as dead — or running /reactivate-team — you MUST SendMessage-ping it and wait for a receipt in THIS session: a receipt = alive; no receipt within a reasonable window = dead/unknown. Do NOT declare a teammate dead from static signals alone (TEAMMATE_INFO.json status:active, inbox messages, config.json entries) — they are evidence of neither life nor death. Only a real restart (source=startup/resume) is guaranteed to kill all teammates."
        SYSMSG="ℹ️ Context compacted (NOT a restart) — teammates spawned this session are likely STILL ALIVE. Verify with a SendMessage ping before assuming any is dead; do NOT auto-run /reactivate-team."
    else
        # 真重启（startup/resume/未知）：所有 teammate 必死
        ADDL="[Teammate persistence] Session restarted. Detected: ${reminders}Their Claude Code sessions did NOT persist — they exist only as workstation files on disk. SESSION RESTART = ALL TEAMMATES DEAD. Do NOT infer teammate liveness from: config.json member entries (ghost residue, session-bound), inbox messages (disk artifacts, may be days old), TEAMMATE_INFO.json status:active (static file, no runtime connection), or plain text replies (not visible across agent boundaries). The ONLY reliable liveness signal is a SendMessage reply received in the current session after an explicit ping. Assume all teammates are dead until /reactivate-team is run and SendMessage receipts are received.\n\nClaude Code agents are turn-based: you cannot speak before the user sends the first message. Wait for it, then respond based on context:\n- If this IS your team's workstation: surface the situation and ask whether to /reactivate-team, proceed solo, or read TEAMMATE_INFO.json first.\n- If this is NOT your workstation: briefly mention it to the user and continue normally."
        SYSMSG="⚠️ Active teammates detected in ${reminders% } — session restart means ALL teammates are dead. Do NOT assume liveness from config.json / inbox messages / TEAMMATE_INFO status. Team lead must run /reactivate-team BEFORE continuing prior work"
    fi
    cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "$ADDL",
    "systemMessage": "$SYSMSG"
  }
}
EOF
fi

exit 0
