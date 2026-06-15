#!/usr/bin/env bash
#
# session_start_check.sh — fires on SessionStart hook (lead or teammate session)
#
# Purpose: detect if we're under a team lead workstation with active_teammates
# recorded in TEAMMATE_INFO.json, and if so, remind the user/agent to run
# /reactivate-team via additionalContext. Eliminates the "lead thinks teammates
# are still alive" hallucination — Claude Code does NOT auto-respawn them.
#
# Input (stdin JSON): session_id / hook_event_name / cwd / source (startup/resume/compact)
# Output:
#   - not a team lead workstation, or active_teammates empty → stdout empty
#   - team lead workstation with active teammates → stdout emits hookSpecificOutput
#     The message branches on source (KEY):
#       compact (same-process context compaction) → "teammates likely still alive, ping before declaring dead"
#       startup/resume/unknown (a real restart)   → "all dead, run /reactivate-team"
#     — on compact it must NOT shout "Session restarted = ALL DEAD" (teammates didn't die)
# Return: exit 0

set -uo pipefail

payload=$(cat)

# Extract cwd
cwd=""
if command -v jq >/dev/null 2>&1; then
    cwd=$(echo "$payload" | jq -r '.cwd // empty' 2>/dev/null)
fi
[ -z "$cwd" ] && cwd="$PWD"

# Find project root (walk up until _agent_team_work_zone/ seen)
project_root="${CLAUDE_PROJECT_DIR:-}"
if [ -z "$project_root" ] || [ ! -d "$project_root/_agent_team_work_zone" ]; then
    project_root="$cwd"
    while [ "$project_root" != "/" ] && [ ! -d "$project_root/_agent_team_work_zone" ]; do
        project_root=$(dirname "$project_root")
    done
fi

[ -d "$project_root/_agent_team_work_zone" ] || exit 0

# --- Sweep stale checkpoint scratch files ---
# A genuine session restart (source=startup/resume) ⇒ all teammates are dead ⇒ any
# leftover checkpoint scratch file is moot. Dead teammates never clean up after
# themselves, so leftovers pile up into landmines. Clear them once at the restart
# entry point:
#   - .checkpoint_pending      — the pre-v0.2.3 flag (mechanism retired; swept here
#                                for upgrading users)
#   - .checkpoint_nudge_count  — teammate_idle_checkpoint.sh's consecutive-nudge safety
#                                cap counter (session-scoped, meaningless after restart)
# compact (in-process context compaction, where teammates may still be alive) is
# excluded — conservatively sweep only on a real restart.
source=""
if command -v jq >/dev/null 2>&1; then
    source=$(echo "$payload" | jq -r '.source // empty' 2>/dev/null)
fi
if [ "$source" = "startup" ] || [ "$source" = "resume" ] || [ -z "$source" ]; then
    rm -f "$project_root"/_agent_team_work_zone/*_team/teammates/*/.checkpoint_pending 2>/dev/null || true
    rm -f "$project_root"/_agent_team_work_zone/*_team/teammates/*/.checkpoint_nudge_count 2>/dev/null || true
fi

# Scan all *_team workstations for non-empty active_teammates in TEAMMATE_INFO.json
reminders=""
for team_dir in "$project_root"/_agent_team_work_zone/*_team/; do
    [ -d "$team_dir" ] || continue
    info_file="$team_dir/TEAMMATE_INFO.json"
    [ -f "$info_file" ] || continue

    team_name=$(basename "$team_dir")

    # Count active_teammates
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
        # Context compaction: same process, teammates are very likely still alive — never report "dead" because of this
        ADDL="[Teammate persistence] CONTEXT COMPACTED (same process — NOT a session restart). Detected: ${reminders}A compaction does NOT kill teammates: ones spawned earlier in THIS still-running session are very likely STILL ALIVE. Before treating ANY teammate as dead — or running /reactivate-team — you MUST SendMessage-ping it and wait for a receipt in THIS session: a receipt = alive; no receipt within a reasonable window = dead/unknown. Do NOT declare a teammate dead from static signals alone (TEAMMATE_INFO.json status:active, inbox messages, config.json entries) — they are evidence of neither life nor death. Only a real restart (source=startup/resume) is guaranteed to kill all teammates."
        SYSMSG="ℹ️ Context compacted (NOT a restart) — teammates spawned this session are likely STILL ALIVE. Verify with a SendMessage ping before assuming any is dead; do NOT auto-run /reactivate-team."
    else
        # Genuine restart (startup/resume/unknown): all teammates are dead
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
