#!/usr/bin/env bash
#
# start_hpc_session.sh — one-shot tmux + claude bootstrap on HPC
#
# Provides "survive SSH disconnect" session foundation for agent-teams on
# HPC / Linux servers. The tmux session must exist BEFORE the lead's claude
# CLI is launched, otherwise teammateMode: "tmux" silently falls back to
# in-process, and teammates such as tracker cannot survive SSH drop.
#
# Order: tmux install check → $TMUX env check → conditional new-session
#        → attach hint
#
# Usage:
#   bash _agent_team_work_zone/resources/scripts/start_hpc_session.sh
#
#   # Custom session name:
#   SESSION_NAME=my_session bash _agent_team_work_zone/resources/scripts/start_hpc_session.sh
#
# Dev environment (dogfood inside the agent-work-zone repo):
#   bash claude_code/en/_agent_team_work_zone/resources/scripts/start_hpc_session.sh
#

set -euo pipefail

SESSION_NAME="${SESSION_NAME:-claude_hpc}"

echo "=================================================="
echo "  start_hpc_session — tmux + claude bootstrap"
echo "=================================================="
echo "Target tmux session: $SESSION_NAME"
echo ""

# --- 1. tmux install check ---
if ! command -v tmux >/dev/null 2>&1; then
    echo "✗ tmux not found on PATH."
    echo ""
    echo "  Install tmux (≥ 3.2 recommended):"
    echo "    Ubuntu / Debian:  sudo apt install tmux"
    echo "    RHEL / CentOS:    sudo yum install tmux"
    echo "    Fedora:           sudo dnf install tmux"
    echo "    macOS:            brew install tmux  (but on macOS, prefer Desktop Scheduled Tasks over this script)"
    echo ""
    echo "  HPC users without sudo: try conda: conda install -c conda-forge tmux"
    exit 1
fi

TMUX_VERSION="$(tmux -V | awk '{print $2}')"
echo "✓ tmux $TMUX_VERSION"

# --- 2. Already inside tmux → just launch claude ---
if [ -n "${TMUX:-}" ]; then
    echo "✓ already inside a tmux session (\$TMUX is set)"
    echo "  → launching claude in the current pane"
    echo ""
    exec claude
fi

# --- 3. Not inside tmux → create detached session and start claude inside ---

if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo "ℹ tmux session '$SESSION_NAME' already exists"
    echo "  Attach with:   tmux attach -t $SESSION_NAME"
    echo ""
    echo "  For a fresh session, kill the old one first:  tmux kill-session -t $SESSION_NAME"
    exit 0
fi

tmux new-session -d -s "$SESSION_NAME"
tmux send-keys -t "$SESSION_NAME" 'claude' Enter

echo "✓ Created tmux session '$SESSION_NAME' and started claude inside"
echo ""
echo "Next steps:"
echo "  1. Attach to the session:                  tmux attach -t $SESSION_NAME"
echo "  2. Inside claude, run /onboard etc."
echo "  3. Detach but keep running:                Ctrl-b d"
echo "  4. After SSH drop, reattach:               tmux attach -t $SESSION_NAME"
echo ""
echo "Reminder: make sure ~/.claude/settings.json has \"teammateMode\": \"tmux\" (or \"auto\")."
echo "          See docs/user_manual.md \"HPC deployment guide\" for details."
