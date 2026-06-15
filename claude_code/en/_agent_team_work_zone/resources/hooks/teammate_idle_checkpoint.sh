#!/usr/bin/env bash
#
# teammate_idle_checkpoint.sh — TeammateIdle hook (fires in the LEAD session)
#
# New mechanism (v0.2.3): working-context.md mtime gate + exit 2 to force a checkpoint.
#
#   When a teammate finishes a turn and is about to go idle, this hook fires in the
#   lead session with the teammate's name in the payload. It locates that teammate's
#   working-context.md and decides based on "how long since the last save":
#     - Last save < N minutes ago (default 15)  → exit 0, let it go idle.
#     - Last save >= N minutes ago              → write "run /checkpoint" to stderr + exit 2.
#         exit 2 BLOCKS that teammate's idle and feeds the stderr straight to it,
#         forcing one more turn before idle = it runs a real /checkpoint. The checkpoint
#         overwrites working-context.md → its mtime refreshes → next idle the gate sees
#         it as fresh → exit 0, and the loop brakes itself.
#
# Why this path ALSO works for in-process teammates (the old flag + UserPromptSubmit
# chain never did): this hook acts entirely on the WRITE side (TeammateIdle, whose
# payload carries the teammate identity). The exit-2 stderr is delivered by Claude Code
# directly to the idling teammate — it never touches the READ side (UserPromptSubmit,
# whose payload carries no identity, and where in-process cwd = project root so you
# cannot tell who is who). That sidesteps the old "read side can't identify the
# in-process teammate" dead end entirely. See developer_manual §5.
#
# Safety rules:
#   - NEVER emit invalid JSON: TeammateIdle does not support hookSpecificOutput/
#     additionalContext (emitting it errors with "Invalid input"). This hook uses
#     stderr + exit codes only.
#   - ANY uncertainty (no name / no workstation / stat failure / no jq / no mtime)
#     → exit 0 silently. Never block the teammate.
#   - Hard safety cap: a consecutive-nudge limit (so a teammate that keeps ignoring
#     the reminder — mtime stays old → endless exit 2 — does not get wedged).
#
# Input (stdin JSON): session_id / cwd / teammate_name / team_name / ...
#   (Verified 2026-06-13: the TeammateIdle payload does carry team_name, value like
#    "architect_team" — already with the _team suffix; use it to pin the exact workstation
#    and avoid a same-name teammate across teams being misresolved by the alphabetical glob.)
# Output: empty stdout; stderr only when nudging; exit 0 (pass) or exit 2 (force checkpoint).
# Wired in: hooks.TeammateIdle of .claude/settings.json
#
# See Rule 13

set -uo pipefail

# ---- Tunables ----
CHECKPOINT_INTERVAL_SEC=900   # N = 15 minutes (set by user 2026-06-11: 10 min fired too
                              #                  often / cost too many tokens; 15 min
                              #                  balances "max accidental loss" vs token cost)
MAX_CONSECUTIVE_NUDGES=3      # Hard safety cap on consecutive force-checkpoints (anti-loop)

payload=$(cat)

# No jq → cannot parse payload → pass (don't block on uncertainty)
command -v jq >/dev/null 2>&1 || exit 0

# Debug: dump payload to a temp log (uncomment when investigating hook schema)
# echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) $payload" >> /tmp/teammate_idle_hook.log

teammate_name=$(echo "$payload" | jq -r '.teammate_name // .teammate // .agent_name // .name // empty' 2>/dev/null)
cwd=$(echo "$payload" | jq -r '.cwd // empty' 2>/dev/null)
[ -z "$cwd" ] && cwd="$PWD"

# No teammate identity → pass
[ -n "$teammate_name" ] || exit 0

# Locate the project root (the dir containing _agent_team_work_zone/). Prefer CLAUDE_PROJECT_DIR
# — set by Claude Code, stable for the whole session, does NOT drift with cd (per the docs:
# cwd changes via cd commands, CLAUDE_PROJECT_DIR stays put). If it's unset or has no
# workstation root under it, fall back to walking up from cwd (cwd may be a subdirectory,
# e.g. claude_code/). If both fail → pass; never block.
project_root="${CLAUDE_PROJECT_DIR:-}"
if [ -z "$project_root" ] || [ ! -d "$project_root/_agent_team_work_zone" ]; then
    project_root="$cwd"
    while [ "$project_root" != "/" ] && [ ! -d "$project_root/_agent_team_work_zone" ]; do
        project_root=$(dirname "$project_root")
    done
fi
[ -d "$project_root/_agent_team_work_zone" ] || exit 0

# Locate the teammate's workstation.
# Prefer pinning it exactly via the payload's team_name (verified 2026-06-13: the payload
#   carries team_name, value already with the _team suffix like "architect_team") — this
#   eliminates the old bug where a same-name teammate across teams was misresolved by the
#   alphabetical glob (upgrader's reviewer idle reading architect's reviewer mtime → false nudge).
# If team_name is absent (older Claude Code without the field) → fall back to the original glob
#   (best-effort, with the same-name ambiguity).
team_name=$(echo "$payload" | jq -r '.team_name // empty' 2>/dev/null)
teammate_ws=""
if [ -n "$team_name" ] && [ -d "$project_root/_agent_team_work_zone/${team_name}/teammates/${teammate_name}" ]; then
    teammate_ws="$project_root/_agent_team_work_zone/${team_name}/teammates/${teammate_name}"
else
    for team_dir in "$project_root"/_agent_team_work_zone/*_team/; do
        [ -d "$team_dir" ] || continue
        if [ -d "${team_dir}teammates/${teammate_name}" ]; then
            teammate_ws="${team_dir}teammates/${teammate_name}"
            break
        fi
    done
fi
# No workstation found → pass
[ -n "$teammate_ws" ] || exit 0

wc_file="$teammate_ws/working-context.md"
nudge_file="$teammate_ws/.checkpoint_nudge_count"

# ---- Gate: working-context.md mtime (primary timestamp; every checkpoint overwrites it) ----
# Linux uses stat -c %Y; BSD/macOS fallback stat -f %m
wc_mtime=""
if [ -f "$wc_file" ]; then
    wc_mtime=$(stat -c %Y "$wc_file" 2>/dev/null || stat -f %m "$wc_file" 2>/dev/null || echo "")
fi
# No mtime (file missing / stat failed) → pass
[ -n "$wc_mtime" ] || exit 0

now_epoch=$(date -u +%s)
age=$((now_epoch - wc_mtime))

if [ "$age" -lt "$CHECKPOINT_INTERVAL_SEC" ]; then
    # fresh: last save < N minutes ago. Let it idle and clear the nudge counter
    # (the loop has braked).
    rm -f "$nudge_file" 2>/dev/null || true
    exit 0
fi

# ---- stale: last save >= N minutes ago, need to force a checkpoint ----

# Hard safety cap: if a teammate keeps ignoring the nudge (gets the reminder but does
# not run /checkpoint, so mtime stays old), don't wedge it with endless exit 2 — once
# the cap is reached, give up forcing, let it idle, reset the counter.
nudge_count=0
[ -f "$nudge_file" ] && nudge_count=$(cat "$nudge_file" 2>/dev/null || echo 0)
case "$nudge_count" in (''|*[!0-9]*) nudge_count=0 ;; esac

if [ "$nudge_count" -ge "$MAX_CONSECUTIVE_NUDGES" ]; then
    rm -f "$nudge_file" 2>/dev/null || true
    # echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) give up nudging $teammate_name after $nudge_count tries" >> /tmp/teammate_idle_hook.log
    exit 0
fi

echo $((nudge_count + 1)) > "$nudge_file" 2>/dev/null || true

# exit 2: block this teammate's idle, feed the stderr straight to it, forcing /checkpoint first
mins=$((age / 60))
threshold_min=$((CHECKPOINT_INTERVAL_SEC / 60))
echo "[checkpoint reminder] You (${teammate_name}) last saved to working-context.md ~${mins} minutes ago (threshold ${threshold_min} min). Before going idle, run /checkpoint NOW to persist your current working state, so an unexpected session loss (SSH drop / crash) doesn't lose your latest work. This is required by Rule 13. Once the checkpoint completes you may idle normally and will not be reminded again." >&2
exit 2
