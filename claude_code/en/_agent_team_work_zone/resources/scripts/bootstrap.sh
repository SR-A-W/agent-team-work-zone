#!/usr/bin/env bash
#
# bootstrap.sh — one-click setup for _agent_team_work_zone
#
# This script:
#   1. Checks Claude Code version (>= 2.1.32, required for agent-teams feature)
#   2. Checks tmux:
#        - not inside tmux  -> soft notice (in-process mode needs no tmux)
#        - inside tmux ($TMUX set) -> hard check, fail-fast:
#            · tmux < 3.0 -> exit (spawn would fail with "size invalid")
#            · PATH tmux vs $TMUX socket server mismatch -> exit
#              (spawn would fail with "Could not determine current tmux pane/window")
#   3. Checks jq (optional, used for settings.json merge; falls back if missing)
#   4. Calls install_skills.sh to sync skills and agents into .claude/
#   5. Creates or merges .claude/settings.json to enable the agent-teams env flag
#   6. (interactive, optional) offers to write "teammateMode":"in-process" to hide
#      the extra pane — purely a personal display preference, default = no
#      (keeps Claude Code's default "auto")
#
# Usage:
#   cd /path/to/your/project
#   bash _agent_team_work_zone/resources/scripts/bootstrap.sh
#
# Development environment (dogfooding inside the agent-work-zone repo):
#   cd /path/to/agent-work-zone
#   bash claude_code/en/_agent_team_work_zone/resources/scripts/bootstrap.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"

echo "=================================================="
echo "  _agent_team_work_zone bootstrap"
echo "=================================================="
echo "Template: $TEMPLATE_ROOT"
echo "Project:  $PROJECT_ROOT"
echo ""

# --- 1. Claude Code version check ---
REQUIRED_VERSION="2.1.32"

version_ge() {
    # return 0 if $1 >= $2 (using sort -V)
    [ "$(printf '%s\n' "$2" "$1" | sort -V | head -n1)" = "$2" ]
}

if ! command -v claude >/dev/null 2>&1; then
    echo "✗ claude not found on PATH."
    echo "  Install Claude Code first: https://docs.claude.com/claude-code"
    exit 1
fi

CC_VERSION="$(claude --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "0.0.0")"

if version_ge "$CC_VERSION" "$REQUIRED_VERSION"; then
    echo "✓ Claude Code v$CC_VERSION (>= $REQUIRED_VERSION required for Agent Teams)"
else
    echo "✗ Claude Code v$CC_VERSION < $REQUIRED_VERSION required"
    echo "  The Agent Teams feature (used by /spawn-team etc.) requires v$REQUIRED_VERSION or later."
    echo "  Upgrade: https://docs.claude.com/claude-code"
    exit 1
fi

# --- 2. tmux check ---
# Boundary decision (Architect, 2026-05-17, agent-team quirks task): the HARD fail-fast
# check lives HERE (bootstrap is executable code that can reliably detect+block).
# The /spawn-team and /reactivate-team skills only DECODE these errors in prose
# (a markdown prompt cannot reliably run+parse `tmux -V` every spawn). The two
# layers do not overlap.
#
# Fail-fast fires ONLY when the broken condition is actually present in THIS
# environment — i.e. Claude Code is running INSIDE tmux ($TMUX is set) AND the
# tmux is too old or PATH/socket-inconsistent. If NOT inside tmux, an old or
# missing tmux is only a latent prerequisite -> soft notice (in-process teammate
# mode works fine without tmux).
TMUX_MIN="3.0"

if command -v tmux >/dev/null 2>&1; then
    TMUX_VERSION="$(tmux -V 2>&1 | grep -oE '[0-9]+\.[0-9]+[a-z]?' | head -1 || echo "0.0")"
    # strip trailing letter (e.g. 3.6a -> 3.6) for numeric >= compare
    TMUX_VERSION_NUM="$(printf '%s' "$TMUX_VERSION" | grep -oE '[0-9]+\.[0-9]+' | head -1)"

    if [ -n "${TMUX:-}" ]; then
        # Claude Code is running INSIDE a tmux session -> teammate panes split
        # HERE -> an old/mismatched tmux WILL fail at spawn time. Hard-stop now
        # with a friendly diagnostic instead of a cryptic spawn-time error.

        # 2a. version floor
        if ! version_ge "$TMUX_VERSION_NUM" "$TMUX_MIN"; then
            echo "✗ tmux $TMUX_VERSION is too old (need >= $TMUX_MIN) and you are"
            echo "  running INSIDE a tmux session (\$TMUX is set)."
            echo ""
            echo "  Why fatal: Agent Teams split a pane in your current tmux."
            echo "  tmux <= 2.7 lacks pane-size protocol fields Claude Code needs,"
            echo "  so /spawn-team and /reactivate-team fail with the cryptic error:"
            echo "    'Failed to create teammate pane: size invalid'"
            echo "  (no window size fixes it — it's a protocol incompatibility)."
            echo ""
            echo "  Fix: upgrade tmux to >= $TMUX_MIN (3.6a verified), OR start"
            echo "  Claude Code OUTSIDE tmux and use in-process teammate mode."
            exit 1
        fi

        # 2b. PATH-binary vs running-server socket consistency
        TMUX_SOCKET="${TMUX%%,*}"
        if ! tmux -S "$TMUX_SOCKET" display-message -p '#{pane_id}' >/dev/null 2>&1; then
            SERVER_PID="$(printf '%s' "$TMUX" | cut -d, -f2)"
            SERVER_BIN="(could not resolve)"
            if [ -n "$SERVER_PID" ] && [ -r "/proc/$SERVER_PID/exe" ]; then
                SERVER_BIN="$(readlink -f "/proc/$SERVER_PID/exe" 2>/dev/null || echo '(unknown)')"
            fi
            echo "✗ tmux PATH/socket mismatch."
            echo ""
            echo "  PATH tmux:            $(command -v tmux)  (v$TMUX_VERSION)"
            echo "  This session's server: $SERVER_BIN"
            echo "  Socket:               $TMUX_SOCKET"
            echo ""
            echo "  The tmux on your PATH cannot talk to the server that owns this"
            echo "  session (different build/protocol — common with multiple tmux"
            echo "  installs). At spawn time this surfaces as:"
            echo "    'Could not determine current tmux pane/window'"
            echo ""
            echo "  Fix: point PATH at the SAME tmux that started this session"
            echo "  (fix PATH then 'hash -r', or re-attach under the right tmux),"
            echo "  then re-run bootstrap."
            exit 1
        fi

        echo "✓ tmux $TMUX_VERSION inside session, PATH/socket consistent (>= $TMUX_MIN)"
    else
        # Not inside tmux: tmux is only a latent prereq for split-pane view.
        if version_ge "$TMUX_VERSION_NUM" "$TMUX_MIN"; then
            echo "✓ tmux $TMUX_VERSION (>= $TMUX_MIN; split-panes mode available)"
        else
            echo "⚠ tmux $TMUX_VERSION is < $TMUX_MIN."
            echo "  in-process teammate mode works fine without tmux. But if you"
            echo "  later run Claude Code INSIDE tmux for split-pane team view,"
            echo "  upgrade to >= $TMUX_MIN first (older → 'size invalid' at spawn)."
        fi
    fi
else
    echo "⚠ tmux not found — STRONGLY RECOMMENDED (but not required)."
    echo "  Teams run in in-process mode by default (full functionality, no tmux)."
    echo "  Running Claude Code INSIDE tmux gives two wins:"
    echo "    (1) survives terminal close / SSH disconnect → far fewer /reactivate-team"
    echo "    (2) optional split-pane view of every teammate's output"
    echo "  Install tmux >= $TMUX_MIN and launch Claude Code inside a tmux session."
    echo "  (To keep persistence without extra panes: tmux + \"teammateMode\":\"in-process\".)"
fi

# --- 3. jq check (optional) ---
HAS_JQ=0
if command -v jq >/dev/null 2>&1; then
    JQ_VERSION="$(jq --version | sed 's/jq-//')"
    echo "✓ jq $JQ_VERSION (used for settings.json merge)"
    HAS_JQ=1
else
    echo "⚠ jq not found — settings.json merge will use heredoc fallback if file exists"
fi

echo ""

# --- 4. Install skills and agents ---
echo "--- Installing skills and agents ---"
PROJECT_ROOT="$PROJECT_ROOT" bash "$SCRIPT_DIR/install_skills.sh"
echo ""

# --- 5. Create or merge .claude/settings.json ---
SETTINGS_JSON="$PROJECT_ROOT/.claude/settings.json"
mkdir -p "$(dirname "$SETTINGS_JSON")"

echo "--- .claude/settings.json ---"
HOOKS_TEMPLATE="$TEMPLATE_ROOT/resources/settings_hooks_template.json"

if [ ! -f "$SETTINGS_JSON" ]; then
    # First-time create: start with env flag, then merge hooks template if jq available
    cat >"$SETTINGS_JSON" <<'EOF'
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
EOF
    echo "  ✓ created $SETTINGS_JSON with agent-teams env flag"

    if [ "$HAS_JQ" -eq 1 ] && [ -f "$HOOKS_TEMPLATE" ]; then
        # Substitute {{TEMPLATE_REL}} placeholder with actual template relative path
        RESOLVED="$(mktemp)"
        sed "s|{{TEMPLATE_REL}}|${TEMPLATE_ROOT#$PROJECT_ROOT/}|g" "$HOOKS_TEMPLATE" > "$RESOLVED"
        TMP="$(mktemp)"
        jq -s '.[0] * .[1]' "$SETTINGS_JSON" "$RESOLVED" >"$TMP"
        mv "$TMP" "$SETTINGS_JSON"
        rm -f "$RESOLVED"
        echo "  ✓ merged teammate-persistence hooks into $SETTINGS_JSON"
    elif [ ! "$HAS_JQ" -eq 1 ]; then
        echo "  ⚠ jq unavailable — hooks NOT merged. Manually copy contents of"
        echo "    $HOOKS_TEMPLATE into $SETTINGS_JSON (merge the \"hooks\" key),"
        echo "    replacing {{TEMPLATE_REL}} with ${TEMPLATE_ROOT#$PROJECT_ROOT/}"
        exit 1
    fi
else
    # Existing settings: merge env flag AND hooks
    if [ "$HAS_JQ" -eq 1 ]; then
        TMP="$(mktemp)"
        jq '.env = (.env // {}) | .env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1"' "$SETTINGS_JSON" >"$TMP"
        mv "$TMP" "$SETTINGS_JSON"
        echo "  ↻ merged CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 into existing $SETTINGS_JSON"

        # Also merge hooks (template wins for our 4 event keys)
        if [ -f "$HOOKS_TEMPLATE" ]; then
            RESOLVED="$(mktemp)"
            sed "s|{{TEMPLATE_REL}}|${TEMPLATE_ROOT#$PROJECT_ROOT/}|g" "$HOOKS_TEMPLATE" > "$RESOLVED"
            TMP="$(mktemp)"
            jq -s '.[0] * .[1]' "$SETTINGS_JSON" "$RESOLVED" >"$TMP"
            mv "$TMP" "$SETTINGS_JSON"
            rm -f "$RESOLVED"
            echo "  ↻ merged teammate-persistence hooks into $SETTINGS_JSON"
            echo "    (if you had customized SessionStart / TeammateIdle / UserPromptSubmit / SessionEnd"
            echo "    hooks manually, they have been overwritten; re-merge your customizations)"
        fi
    else
        echo "  ⚠ $SETTINGS_JSON already exists and jq is not available."
        echo "    Neither the env flag nor hooks could be merged automatically."
        echo "    Manually ensure:"
        echo "      1. { \"env\": { \"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS\": \"1\" } }"
        echo "      2. copy the \"hooks\" block from $HOOKS_TEMPLATE,"
        echo "         replacing {{TEMPLATE_REL}} with ${TEMPLATE_ROOT#$PROJECT_ROOT/}"
        exit 1
    fi
fi

# --- 6. (optional, interactive) hide the extra teammate pane ---
# Personal display preference only. Default = NO change (keep Claude Code's
# default "auto"). Choosing yes writes "teammateMode":"in-process" so spawning
# teammates does not split an extra tmux pane.
echo "--- Teammate pane display preference (optional) ---"
echo ""
echo "Inside tmux, Claude Code's default (\"teammateMode\":\"auto\") splits an"
echo "extra pane per teammate. Some users prefer \"in-process\" — teammates run"
echo "without splitting panes; switch to one with Shift+Down."
echo ""
echo "This is a PERSONAL DISPLAY PREFERENCE ONLY:"
echo "  • Does NOT change agent-team behaviour or capability."
echo "  • Default keeps Claude Code's default (\"auto\") untouched."
echo ""

if [ -t 0 ]; then
    printf 'Modify settings to hide the extra pane ("teammateMode":"in-process")? [y/N] '
    read -r HIDE_ANS || HIDE_ANS=""
    case "$HIDE_ANS" in
        [Yy]|[Yy][Ee][Ss])
            printf 'Scope — [P]roject-local .claude/settings.json (recommended) or [g]lobal ~/.claude/settings.json? [P/g] '
            read -r SCOPE_ANS || SCOPE_ANS=""
            case "$SCOPE_ANS" in
                [Gg]|[Gg][Ll][Oo][Bb][Aa][Ll])
                    TARGET_SETTINGS="$HOME/.claude/settings.json"
                    SCOPE_LABEL="global (~/.claude/settings.json)"
                    ;;
                *)
                    TARGET_SETTINGS="$SETTINGS_JSON"
                    SCOPE_LABEL="project-local (.claude/settings.json)"
                    ;;
            esac
            mkdir -p "$(dirname "$TARGET_SETTINGS")"
            if [ "$HAS_JQ" -eq 1 ]; then
                if [ -f "$TARGET_SETTINGS" ]; then
                    TMP="$(mktemp)"
                    jq '.teammateMode = "in-process"' "$TARGET_SETTINGS" >"$TMP" && mv "$TMP" "$TARGET_SETTINGS"
                else
                    printf '{\n  "teammateMode": "in-process"\n}\n' >"$TARGET_SETTINGS"
                fi
                echo "  ✓ set \"teammateMode\":\"in-process\" in $SCOPE_LABEL"
                echo "    revert anytime: delete that key, or re-run bootstrap and answer N"
            else
                echo "  ⚠ jq unavailable — cannot safely merge JSON."
                echo "    To hide panes manually, add  \"teammateMode\":\"in-process\""
                echo "    to $TARGET_SETTINGS"
            fi
            ;;
        *)
            echo "  ↳ keeping Claude Code default (\"auto\"). No settings changed."
            ;;
    esac
else
    echo "  (non-interactive shell — skipped; keeping default \"auto\")"
fi
echo ""

echo "=================================================="
echo "  Bootstrap complete"
echo "=================================================="
echo ""
echo "Next steps:"
echo "  1. Start a new Claude Code session:"
echo "       claude -n \"Architect\""
echo "  2. Run /onboard to create your workstation (agent will ask if you want"
echo "     a flat workstation or a team lead)"
echo "  3. For existing sessions, run /sync to pick up new skills"
echo ""
echo "Teammate display mode:"
echo "  • Default \"auto\" splits a pane per teammate inside tmux."
echo "  • To hide panes, re-run bootstrap and answer Y at the pane prompt"
echo "    above (writes \"teammateMode\":\"in-process\"). Personal preference;"
echo "    does not affect team behaviour. Shift+Down still switches teammate."
echo ""
echo "⚠ Do not directly edit .claude/skills/ or .claude/agents/ —"
echo "  those are installed copies. Edit the sources in"
echo "  $TEMPLATE_ROOT/resources/ instead and re-run bootstrap."
echo ""
