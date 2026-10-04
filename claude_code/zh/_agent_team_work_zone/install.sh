#!/usr/bin/env bash
#
# install.sh — first-time setup for _agent_team_work_zone.
#
# Run after copying _agent_team_work_zone/ into your project root:
#
#   bash _agent_team_work_zone/install.sh
#
# No arguments. Paths are derived from $0:
#   SCRIPT_DIR   = the _agent_team_work_zone/ directory this file lives in
#   TARGET_DIR   = SCRIPT_DIR
#   PROJECT_ROOT = parent of SCRIPT_DIR  (your project root)
#
# What it does:
#   1. Verifies it is run from within a recognizable project layout.
#   2. If .claude/ already has content, asks before merging into it; declined or no
#      terminal → exit code 3 and the bootstrap command to run later.
#   3. Invokes resources/scripts/bootstrap.sh to create .claude/skills/, .claude/agents/,
#      and .claude/settings.json with the agent-teams env flag + hooks.
#   4. Prints next steps.
#
# Run upgrade.sh (same directory) for subsequent updates.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="$SCRIPT_DIR"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# -------- Minimal inline print helpers --------
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    _R=$'\033[0m'; _B=$'\033[1m'; _RED=$'\033[31m'; _GRN=$'\033[32m'; _YLW=$'\033[33m'; _CYN=$'\033[36m'
else
    _R=""; _B=""; _RED=""; _GRN=""; _YLW=""; _CYN=""
fi
_header() { printf '%s==================================================%s\n%s  %s%s\n%s==================================================%s\n' "$_B" "$_R" "$_B$_CYN" "$1" "$_R" "$_B" "$_R"; }
_ok()     { printf '%s✓%s %s\n' "$_GRN" "$_R" "$1"; }
_warn()   { printf '%s⚠%s %s\n' "$_YLW" "$_R" "$1"; }
_err()    { printf '%s✗%s %s\n' "$_RED" "$_R" "$1"; }
_step()   { printf '  → %s\n' "$1"; }

_header "_agent_team_work_zone install"
printf 'Framework: %s\n' "$TARGET_DIR"
printf 'Project:   %s\n' "$PROJECT_ROOT"
echo ""

# -------- Step 1: Verify layout --------
BOOTSTRAP="$TARGET_DIR/resources/scripts/bootstrap.sh"
if [ ! -f "$BOOTSTRAP" ]; then
    _err "bootstrap.sh not found at expected path:"
    _err "  $BOOTSTRAP"
    _err "Make sure _agent_team_work_zone/ is fully copied into your project root."
    exit 1
fi
_ok "Framework layout looks correct"
echo ""

# -------- Step 2: Check .claude/ does not already exist --------
CLAUDE_DIR="$PROJECT_ROOT/.claude"
if [ -d "$CLAUDE_DIR" ] && [ -n "$(ls -A "$CLAUDE_DIR" 2>/dev/null)" ]; then
    _warn ".claude/ already exists and is non-empty at: $CLAUDE_DIR"
    _warn "Installing merges into it: .claude/settings.json is merged, and the framework's skills"
    _warn "and agents are added or updated by name — your own skills and agents are left alone."
    _warn "But the framework's SessionStart, TeammateIdle and SessionEnd hooks replace any hooks"
    _warn "you have on those three events (settings.json is backed up first if you do)."
    _warn "(To refresh an existing framework install, run _agent_team_work_zone/upgrade.sh instead.)"
    echo ""
    printf 'Install into the existing .claude/? [y/N] '
    if [ -t 0 ]; then
        read -r _ans || _ans=""
    else
        _ans=""
        echo ""
    fi
    case "$_ans" in
        [yY]|[yY][eE][sS]) _ok "Proceeding — merging into the existing .claude/." ;;
        *)
            echo "Install cancelled (nothing was changed in .claude/)."
            echo "To finish the install later, run in the project directory:"
            echo "  bash _agent_team_work_zone/resources/scripts/bootstrap.sh"
            exit 3 ;;
    esac
    echo ""
fi

# -------- Step 3: Run bootstrap --------
_header "Running bootstrap"
_step "bash $BOOTSTRAP"
echo ""

if ! PROJECT_ROOT="$PROJECT_ROOT" bash "$BOOTSTRAP"; then
    echo ""
    _err "bootstrap.sh failed — see errors above."
    _err "Fix the issue and re-run install.sh."
    exit 1
fi
echo ""

# -------- Step 4: Next steps --------
_header "Install complete"
echo ""
echo "Next steps:"
echo "  1. Start a Claude Code session in your project:"
echo "       cd $(printf '%q' "$PROJECT_ROOT")"
echo "       claude"
echo "  2. Onboard your first agent:"
echo "       /onboard <role> <responsibilities>"
echo "     Example:"
echo "       /onboard Architect \"Design system architecture and review code\""
echo "  3. To upgrade the framework in the future:"
echo "       npx agent-team-work-zone@latest upgrade     (installed with npm)"
echo "       bash _agent_team_work_zone/upgrade.sh        (installed from source)"
echo ""
