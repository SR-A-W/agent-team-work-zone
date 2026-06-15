#!/usr/bin/env bash
#
# session_end_final_checkpoint.sh — fires on SessionEnd hook
#
# Purpose: log the state of the exiting session (lead or teammate) for diagnostics.
# Note: at SessionEnd the skill cannot actually run — context is already winding
# down. This script only logs and records pending flags. Real checkpoints must
# happen via the TeammateIdle trigger chain while the session is still active.
#
# Input (stdin JSON): session_id / hook_event_name / cwd
# Output: stdout empty (cannot inject context post-exit)
# Return: exit 0

set -uo pipefail

payload=$(cat)

# Infer session type and workstation from cwd
cwd=""
if command -v jq >/dev/null 2>&1; then
    cwd=$(echo "$payload" | jq -r '.cwd // empty' 2>/dev/null)
fi
[ -z "$cwd" ] && cwd="$PWD"

# Find project root
project_root="${CLAUDE_PROJECT_DIR:-}"
if [ -z "$project_root" ] || [ ! -d "$project_root/_agent_team_work_zone" ]; then
    project_root="$cwd"
    while [ "$project_root" != "/" ] && [ ! -d "$project_root/_agent_team_work_zone" ]; do
        project_root=$(dirname "$project_root")
    done
fi

[ -d "$project_root/_agent_team_work_zone" ] || exit 0

# Record session end timestamp to log (optional diagnostic)
log_dir="$project_root/_agent_team_work_zone/.hook_logs"
mkdir -p "$log_dir" 2>/dev/null || true

timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
echo "$timestamp SessionEnd cwd=$cwd" >> "$log_dir/session_end.log" 2>/dev/null || true

# Note: as of v0.2.3 automatic checkpointing is handled by teammate_idle_checkpoint.sh
# (TeammateIdle + exit 2 gate) while the session is still active; at SessionEnd the
# context is already winding down and skills cannot run, so we no longer scan for the
# old .checkpoint_pending flag (that mechanism is retired) — just keep the timestamp log.

exit 0
