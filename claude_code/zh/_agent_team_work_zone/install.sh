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
    # warning colour: mirrors __C_WARN in resources/scripts/migrations/common.sh — keep in sync
    if [ "$(tput colors 2>/dev/null || echo 0)" -ge 256 ] 2>/dev/null; then _WRN=$'\033[1;38;5;202m'; else _WRN=$'\033[1;31m'; fi
else
    _R=""; _B=""; _RED=""; _GRN=""; _YLW=""; _CYN=""; _WRN=""
fi
_header() { printf '%s==================================================%s\n%s  %s%s\n%s==================================================%s\n' "$_B" "$_R" "$_B$_CYN" "$1" "$_R" "$_B" "$_R"; }
_ok()     { printf '%s✓%s %s\n' "$_GRN" "$_R" "$1"; }
_warn()   { printf '%s⚠ %s%s\n' "$_WRN" "$1" "$_R"; }
_err()    { printf '%s✗%s %s\n' "$_RED" "$_R" "$1"; }
_step()   { printf '  → %s\n' "$1"; }

# mirrors choose_option in resources/scripts/bootstrap.sh — keep in sync
# choose_option — arrow-key selection menu
# Usage: idx=$(choose_option <default_idx> "<title>" "<opt0>" "<opt1>" ...)
# All rendering goes to /dev/tty; only the selected 0-based index is printed to stdout.
choose_option() {
    local default_idx="$1"; shift
    local title="$1"; shift
    local -a opts=("$@")
    local count="${#opts[@]}"
    local cur="$default_idx"
    local key seq1 seq2 num

    _co_render() {
        local i=0
        printf '%s\n' "$title" >/dev/tty
        while [ "$i" -lt "$count" ]; do
            if [ "$i" -eq "$cur" ]; then
                printf '  \033[7m\033[1m❯ %s\033[0m\n' "${opts[$i]}" >/dev/tty
            else
                printf '    %s\n' "${opts[$i]}" >/dev/tty
            fi
            i=$((i+1))
        done
    }

    _co_render
    while true; do
        key=""
        IFS= read -rsn1 key </dev/tty || { echo "$default_idx"; return 0; }
        case "$key" in
            $'\033')
                seq1=""; seq2=""
                IFS= read -rsn1 -t 0.1 seq1 </dev/tty || true
                IFS= read -rsn1 -t 0.1 seq2 </dev/tty || true
                case "${seq1}${seq2}" in
                    '[A') if [ "$cur" -gt 0 ]; then cur=$((cur-1)); fi ;;
                    '[B') if [ "$cur" -lt $((count-1)) ]; then cur=$((cur+1)); fi ;;
                esac
                ;;
            'k') if [ "$cur" -gt 0 ]; then cur=$((cur-1)); fi ;;
            'j') if [ "$cur" -lt $((count-1)) ]; then cur=$((cur+1)); fi ;;
            [1-9])
                num=$((key-1))
                if [ "$num" -lt "$count" ]; then cur=$num; fi
                ;;
            ''|$'\n'|$'\r')
                echo "$cur"
                return 0
                ;;
        esac
        printf '\033[%dA\033[J' "$((count+1))" >/dev/tty
        _co_render
    done
}

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
    _warn "and agents are added or updated by name — yours with other names are left alone (one with the same name as a framework skill or agent is replaced)."
    _warn "But the framework's SessionStart, TeammateIdle and SessionEnd hooks replace any hooks"
    _warn "you have on those three events (settings.json is backed up first if you do)."
    _warn "(To refresh an existing framework install, run _agent_team_work_zone/upgrade.sh instead.)"
    echo ""
    if [ -t 0 ]; then
        _ans=$(choose_option 1 \
            "Install into the existing .claude/? (↑↓ to navigate, Enter to confirm, 1-9 to quick-select):" \
            "Yes — merge into the existing .claude/" \
            "No  — cancel")
    else
        _ans=1
        echo "Install into the existing .claude/? No terminal to confirm — not installing (default No)."
    fi
    case "$_ans" in
        0) _ok "Proceeding — merging into the existing .claude/." ;;
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
