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
#   6. (interactive, optional) select teammate display mode (auto / in-process / no change)
#      — always writes to global ~/.claude/settings.json; CC v2.1.179+ default is in-process
#   7. (interactive, recommended) enable auto permission mode (always writes to global
#      ~/.claude/settings.json) — project/local level is explicitly ignored by CC
#
# Usage:
#   cd /path/to/your/project
#   bash _agent_team_work_zone/resources/scripts/bootstrap.sh
#   bash _agent_team_work_zone/resources/scripts/bootstrap.sh --reconfigure
#       (on an existing install: ask the install-time questions again; nothing under
#        _agent_team_work_zone/ is changed — this is what `npx agent-team-work-zone reconfigure` runs)
#
# Development environment (dogfooding inside the agent-team-work-zone repo):
#   cd /path/to/agent-team-work-zone
#   bash claude_code/en/_agent_team_work_zone/resources/scripts/bootstrap.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# Shared output helpers (print_warn, recommended, ...).
# shellcheck source=./migrations/common.sh
. "$SCRIPT_DIR/migrations/common.sh"
PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"

# --reconfigure: re-run the install-time questions on an existing install (see Usage).
ATWZ_RECONFIGURE=0
case "${1:-}" in
    "") ;;
    --reconfigure) ATWZ_RECONFIGURE=1 ;;
    *) echo "Unknown option: $1 (the only option is --reconfigure)" >&2; exit 2 ;;
esac
# How to ask the install-time questions again later (printed where a question is skipped).
RESETUP_CMD="npx agent-team-work-zone reconfigure (source install: bash _agent_team_work_zone/resources/scripts/bootstrap.sh --reconfigure)"

echo "=================================================="
echo "  _agent_team_work_zone bootstrap"
echo "=================================================="
echo "Template: $TEMPLATE_ROOT"
echo "Project:  $PROJECT_ROOT"
echo ""

# --- 1. Claude Code version check ---
# This is the NEW-version template (claude_code/), adapted to the 2.1.178 agent-teams
# API (auto session-level team, TeamCreate/TeamDelete removed, Agent team_name ignored).
# It REQUIRES CC >= 2.1.178. Users on CC <= 2.1.177 must use public release v0.1.0 instead:
#   https://github.com/SR-A-W/agent-team-work-zone/releases/tag/v0.1.0
REQUIRED_VERSION="2.1.178"

version_ge() {
    # return 0 if $1 >= $2 (using sort -V)
    [ "$(printf '%s\n' "$2" "$1" | sort -V | head -n1)" = "$2" ]
}

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

if ! command -v claude >/dev/null 2>&1; then
    echo "✗ claude not found on PATH."
    echo "  Install Claude Code first: https://docs.claude.com/claude-code"
    exit 1
fi

CC_VERSION="$(claude --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "0.0.0")"

if version_ge "$CC_VERSION" "$REQUIRED_VERSION"; then
    echo "✓ Claude Code v$CC_VERSION (>= $REQUIRED_VERSION required for the 2.1.178 agent-teams API)"
else
    echo "✗ Claude Code v$CC_VERSION < $REQUIRED_VERSION required by THIS (new) template."
    echo ""
    echo "  This template is adapted to the Claude Code 2.1.178 agent-teams API."
    echo "  Your Claude Code is older. You have two options:"
    echo "    1. Upgrade Claude Code to >= $REQUIRED_VERSION:  https://docs.claude.com/claude-code"
    echo "    2. Use public release v0.1.0 for older Claude Code:"
    echo "         https://github.com/SR-A-W/agent-team-work-zone/releases/tag/v0.1.0"
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
        echo "  → tmux split-pane mode is available. On first install, choose 'auto' in the"
        echo "    display-mode menu below to get one pane per teammate (idle/stuck ones stay"
        echo "    visible); to change it later, run: $RESETUP_CMD"
        echo "    CC v2.1.179+ default is in-process (single terminal)."
    else
        # Not inside tmux: tmux is only a latent prereq for split-pane view.
        if version_ge "$TMUX_VERSION_NUM" "$TMUX_MIN"; then
            echo "✓ tmux $TMUX_VERSION (>= $TMUX_MIN; split-panes mode available)"
        else
            print_warn "tmux $TMUX_VERSION is < $TMUX_MIN."
            echo "  in-process teammate mode works fine without tmux. But if you"
            echo "  later run Claude Code INSIDE tmux for split-pane team view,"
            echo "  upgrade to >= $TMUX_MIN first (older → 'size invalid' at spawn)."
        fi
    fi
else
    print_warn "tmux not found — STRONGLY RECOMMENDED (but not required)."
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
    print_warn "jq not found — settings.json merge will use heredoc fallback if file exists"
fi

# --- 3b. git check (optional, warning only) ---
# The optional git lock (resources/scripts/atwz_git_lock.sh) needs git >= 2.5
# (git rev-parse --git-common-dir). Nothing else in the framework needs git.
if command -v git >/dev/null 2>&1; then
    GIT_RAW="$(git --version 2>/dev/null)"
    GIT_VERSION="$(printf '%s\n' "$GIT_RAW" | awk '{print $3}')"
    GIT_MAJOR="${GIT_VERSION%%.*}"; GIT_REST="${GIT_VERSION#*.}"; GIT_MINOR="${GIT_REST%%.*}"
    case "$GIT_MAJOR$GIT_MINOR" in
        *[!0-9]*|"")
            echo "· git version not recognised ($GIT_RAW); the optional git lock needs git 2.5 or later" ;;
        *)
            if [ "$GIT_MAJOR" -lt 2 ] || { [ "$GIT_MAJOR" -eq 2 ] && [ "$GIT_MINOR" -lt 5 ]; }; then
                print_warn "git $GIT_VERSION found — the optional git lock (atwz_git_lock.sh, also used by checkpoint commit mode) needs git 2.5 or later; everything else works"
            else
                echo "✓ git $GIT_VERSION"
            fi ;;
    esac
else
    echo "· git not found — only the optional checkpoint git saving and git lock need it"
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
        print_warn "jq unavailable — hooks NOT merged. Manually copy contents of" "  "
        echo "    $HOOKS_TEMPLATE into $SETTINGS_JSON (merge the \"hooks\" key),"
        echo "    replacing {{TEMPLATE_REL}} with ${TEMPLATE_ROOT#$PROJECT_ROOT/}"
        exit 1
    fi
else
    # Existing settings: merge env flag AND hooks
    if [ "$HAS_JQ" -eq 1 ]; then
        # The template's three hook events (SessionStart, TeammateIdle, SessionEnd) will
        # REPLACE whatever is on them (jq '*' replaces arrays); other events, e.g. a user's
        # own PreToolUse, are kept. If the user has hooks of their own on those three
        # events — commands that are not framework hooks; framework hooks of any version
        # run scripts under <TEMPLATE_REL>/resources/ — back the ORIGINAL settings.json up
        # before anything is rewritten (cp -p keeps its mode). A re-run finds only
        # framework hooks there, so it makes no new backup.
        TEMPLATE_REL="${TEMPLATE_ROOT#$PROJECT_ROOT/}"
        SETTINGS_BAK=""
        USER_HOOKS=0
        if [ -f "$HOOKS_TEMPLATE" ]; then
            USER_HOOKS="$(jq -r --arg rel "$TEMPLATE_REL/resources/" '
                [ (.hooks // {}) as $h
                  | ("SessionStart", "TeammateIdle", "SessionEnd") as $e
                  | ($h[$e] // [])[] | (.hooks // [])[] | (.command // "")
                  | select(contains($rel) | not) ] | length' "$SETTINGS_JSON" 2>/dev/null || echo 0)"
            if [ "${USER_HOOKS:-0}" != "0" ]; then
                SETTINGS_BAK="$SETTINGS_JSON.bak.$(date -u +%Y%m%d%H%M%S)"
                cp -p "$SETTINGS_JSON" "$SETTINGS_BAK"
            fi
        fi

        # Write merged results back with cat > (not mv): settings.json keeps its mode.
        TMP="$(mktemp)"
        jq '.env = (.env // {}) | .env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1"' "$SETTINGS_JSON" >"$TMP"
        cat "$TMP" > "$SETTINGS_JSON"; rm -f "$TMP"
        echo "  ↻ merged CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 into existing $SETTINGS_JSON"

        # Also merge hooks (see above: the template's three events replace the user's).
        if [ -f "$HOOKS_TEMPLATE" ]; then
            RESOLVED="$(mktemp)"
            sed "s|{{TEMPLATE_REL}}|$TEMPLATE_REL|g" "$HOOKS_TEMPLATE" > "$RESOLVED"
            TMP="$(mktemp)"
            jq -s '.[0] * .[1]' "$SETTINGS_JSON" "$RESOLVED" >"$TMP"
            cat "$TMP" > "$SETTINGS_JSON"; rm -f "$TMP"
            rm -f "$RESOLVED"
            echo "  ↻ merged teammate-persistence hooks into $SETTINGS_JSON"
            if [ -n "$SETTINGS_BAK" ]; then
                print_warn "You had $USER_HOOKS hook(s) of your own on SessionStart / TeammateIdle / SessionEnd;" "  "
                echo "    on those three events the framework's hooks have replaced them. Your previous"
                echo "    settings are saved in:"
                echo "      $SETTINGS_BAK"
                echo "    Re-add your hooks from there if you still need them (other events were kept)."
            fi
        fi
    else
        print_warn "$SETTINGS_JSON already exists and jq is not available." "  "
        echo "    Neither the env flag nor hooks could be merged automatically."
        echo "    Manually ensure:"
        echo "      1. { \"env\": { \"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS\": \"1\" } }"
        echo "      2. copy the \"hooks\" block from $HOOKS_TEMPLATE,"
        echo "         replacing {{TEMPLATE_REL}} with ${TEMPLATE_ROOT#$PROJECT_ROOT/}"
        exit 1
    fi
fi

# --- 5a. Install CLAUDE.md ---
echo "--- CLAUDE.md ---"
CLAUDE_MD_FIRST_INSTALL=0   # 1 = this run put the framework sections into CLAUDE.md (first install)
CLAUDE_TEMPLATE="$TEMPLATE_ROOT/resources/CLAUDE.md.template"
CLAUDE_MD="$PROJECT_ROOT/CLAUDE.md"

if [ ! -f "$CLAUDE_TEMPLATE" ]; then
    print_warn "$CLAUDE_TEMPLATE not found — skipping CLAUDE.md install" "  "
else
    # Extract the language-specific first ## header for idempotency (no hardcoding)
    CLAUDE_FIRST_HEADER="$(awk '/^## /{print; exit}' "$CLAUDE_TEMPLATE")"

    if [ ! -f "$CLAUDE_MD" ]; then
        cp "$CLAUDE_TEMPLATE" "$CLAUDE_MD"
        CLAUDE_MD_FIRST_INSTALL=1
        echo "  ✓ installed CLAUDE.md"
    elif grep -qF "$CLAUDE_FIRST_HEADER" "$CLAUDE_MD" && \
         grep -qF "## Coding Engineering Principles" "$CLAUDE_MD"; then
        echo "  ↻ CLAUDE.md already has the agent-team-work-zone sections — skipping"
    else
        printf '\n' >> "$CLAUDE_MD"
        awk '/^## /{found=1} found{print}' "$CLAUDE_TEMPLATE" >> "$CLAUDE_MD"
        CLAUDE_MD_FIRST_INSTALL=1
        print_warn "Appended agent-team-work-zone + Coding Engineering Principles sections to your existing CLAUDE.md — review them." "  "
    fi
fi
echo ""

# Which questions this run asks (5b optional sections, 5c git, 6 display mode, 7 auto permission):
#   upgrade      ATWZ_SKIP_OPTIONAL_SECTIONS=1 (set by the migration dispatcher) → none
#   reconfigure  --reconfigure                                                → all (with a terminal)
#   first        this run put the framework sections into CLAUDE.md          → all
#   rerun        any other run                                               → none
if [ "${ATWZ_SKIP_OPTIONAL_SECTIONS:-0}" = "1" ]; then RUN_KIND=upgrade
elif [ "$ATWZ_RECONFIGURE" = "1" ]; then RUN_KIND=reconfigure
elif [ "$CLAUDE_MD_FIRST_INSTALL" = "1" ]; then RUN_KIND=first
else RUN_KIND=rerun
fi

# --- 5b. Optional CLAUDE.md sections (strongly recommended, default Yes) ---
# One Yes/No menu (default Yes) per file in resources/claude_md_optional/.
#   first install: terminal → menu; no terminal → added, with a note on how to remove it
#   reconfigure:   terminal → menu; no terminal → not handled (nothing added)
#   upgrade / rerun: never added, never asked
# A section is APPENDED once: skipped if its "<!-- ATWZ-OPTIONAL:<id> -->" marker is already
# in CLAUDE.md. Existing CLAUDE.md content is never modified; a "no" is not recorded anywhere.
OPTIONAL_DIR="$TEMPLATE_ROOT/resources/claude_md_optional"
if [ -d "$OPTIONAL_DIR" ] && [ -f "$CLAUDE_MD" ]; then
    echo "--- Optional CLAUDE.md sections ---"
    if [ "$RUN_KIND" = upgrade ]; then
        echo "  ↻ Optional CLAUDE.md sections: not asked during an upgrade. To add them, run: $RESETUP_CMD"
    elif [ "$RUN_KIND" = rerun ]; then
        echo "  ↻ Optional CLAUDE.md sections: only offered on first install. To add them, run: $RESETUP_CMD"
    elif [ "$RUN_KIND" = reconfigure ] && [ ! -t 0 ]; then
        echo "  ↻ Optional CLAUDE.md sections: not handled (no terminal). To add them, run reconfigure in a terminal."
    else
        for id in user_message_format plain_vocabulary; do
            snippet="$OPTIONAL_DIR/$id.md"
            [ -f "$snippet" ] || continue
            title="$(awk '/^## /{sub(/^## /, ""); print; exit}' "$snippet")"
            if grep -qF "<!-- ATWZ-OPTIONAL:$id -->" "$CLAUDE_MD"; then
                printf '  ↻ optional "%s" section already in CLAUDE.md — skipping\n' "$title"
                continue
            fi
            if [ -t 0 ]; then
                OPT_IDX=$(choose_option 0 \
                    "$(printf 'Add the optional "%s" section to CLAUDE.md? (↑↓ to navigate, Enter to confirm, 1-9 to quick-select):' "$title")" \
                    "$(recommended "Yes — add it (strongly recommended)")" \
                    "No  — skip")
            else
                OPT_IDX=0   # first install without a terminal: added by default
            fi
            case "$OPT_IDX" in
                0)
                    printf '\n' >> "$CLAUDE_MD"
                    cat "$snippet" >> "$CLAUDE_MD"
                    printf '  ✓ appended the optional "%s" section to CLAUDE.md\n' "$title"
                    [ -t 0 ] || printf '    (no terminal: added by default; to remove it, delete the section marked <!-- ATWZ-OPTIONAL:%s --> from CLAUDE.md)\n' "$id" ;;
                *)
                    printf '  · not added: "%s"\n' "$title" ;;
            esac
        done
    fi
    echo ""
fi

# --- 5c. Git tracking of the work zone (first install and reconfigure; never on upgrade) ---
# Same run-kind test as 5b. Needs git (3b already reported if it is missing).
#   - project not inside a git repository  → warning + why tracking it helps
#   - inside a repository but not its root → warning: keep the work zone at the project root
#   - at the repository root               → menu: track _agent_team_work_zone/? (default Yes);
#     No → append "/_agent_team_work_zone/" to the PROJECT ROOT .gitignore (created if missing —
#     the user asked for it), append-only and idempotent; Yes never removes that line (it says how);
#     no terminal → first install: treated as Yes, nothing written; reconfigure: nothing changed.
if { [ "$RUN_KIND" = first ] || [ "$RUN_KIND" = reconfigure ]; } && command -v git >/dev/null 2>&1; then
    echo "--- git ---"
    GIT_TOP="$(git -C "$PROJECT_ROOT" rev-parse --show-toplevel 2>/dev/null || true)"
    PROJECT_REAL="$(cd "$PROJECT_ROOT" && pwd -P)"
    if [ -z "$GIT_TOP" ]; then
        print_warn "This project is not in a git repository."
        echo "  Tracking _agent_team_work_zone/ in git backs up your agents' project memory and lets you roll it back, bring the team up on another machine, and work with other people through git push / pull. To start: git init"
    elif [ "$(cd "$GIT_TOP" && pwd -P)" != "$PROJECT_REAL" ]; then
        print_warn "$(printf 'This project is inside the git repository %s but is not its root.' "$GIT_TOP")"
        echo "  Keep _agent_team_work_zone/ at the project root — the root of the repository — and start Claude Code there."
    else
        TRACK_ANSWER="y"
        if [ -t 0 ]; then
            TRACK_IDX=$(choose_option 0 \
                "Track _agent_team_work_zone/ in git? (strongly recommended) (↑↓ to navigate, Enter to confirm, 1-9 to quick-select):" \
                "$(recommended "Yes — track it in git (strongly recommended)")" \
                "No  — keep it out of git (add it to .gitignore)")
            [ "$TRACK_IDX" = 1 ] && TRACK_ANSWER="n"
        elif [ "$RUN_KIND" = reconfigure ]; then
            TRACK_ANSWER="keep"
            echo "· No terminal: git tracking of _agent_team_work_zone/ not changed."
        else
            echo "· No terminal: _agent_team_work_zone/ is left to be tracked in git (recommended). To keep it out of git instead: echo '/_agent_team_work_zone/' >> .gitignore"
        fi
        case "$TRACK_ANSWER" in
            n|N|no|NO|No)
                MIG_COMMON="$TEMPLATE_ROOT/resources/scripts/migrations/common.sh"
                ROOT_GI="$PROJECT_ROOT/.gitignore"
                if [ -f "$MIG_COMMON" ] && . "$MIG_COMMON" && { [ -f "$ROOT_GI" ] || : > "$ROOT_GI"; } \
                   && append_missing_lines "$ROOT_GI" "# agent-team-work-zone: the work zone is not tracked (chosen at install)" '/_agent_team_work_zone/' >/dev/null; then
                    echo "✓ Added /_agent_team_work_zone/ to .gitignore at the project root."
                    echo "  Your agents' project memory now has no git history: no backup or rollback through git, and the optional checkpoint saving in git will skip. To change your mind, remove that line from .gitignore."
                else
                    print_warn "Could not update the project's .gitignore; add the line /_agent_team_work_zone/ yourself if you want it untracked."
                fi ;;
            keep) ;;
            *)
                if [ -f "$PROJECT_ROOT/.gitignore" ] && grep -qxF '/_agent_team_work_zone/' "$PROJECT_ROOT/.gitignore"; then
                    echo "· /_agent_team_work_zone/ is listed in the project's .gitignore, so the work zone is still not tracked. To track it, remove that line (and the comment above it) from .gitignore, then: git add _agent_team_work_zone && git commit -m 'Track agent-team-work-zone'"
                else
                    echo "✓ Good. Commit it when ready: git add _agent_team_work_zone && git commit -m 'Add agent-team-work-zone'"
                fi ;;
        esac
    fi
    echo ""
fi

# --- 6 and 7 are asked on a first install and on reconfigure (same run-kind test as 5b/5c);
# never on an upgrade or a later re-run, so they do not overwrite settings chosen earlier. ---
if [ "$RUN_KIND" = upgrade ] || [ "$RUN_KIND" = rerun ]; then
    echo "--- Teammate display mode and auto permission mode ---"
    echo "  ↻ Display mode and auto permission mode keep their current settings. To change them, run: $RESETUP_CMD"
    echo ""
else
    # --- 6. Display mode selection (interactive, optional) ---
    # Since CC v2.1.179, the default changed from "auto" (tmux panes) to "in-process"
    # (single terminal). teammateMode is a user-level setting — only takes effect in
    # the global ~/.claude/settings.json (project/local level is ignored by CC).
    echo "--- Teammate display mode (optional) ---"
    echo ""
    echo "CC v2.1.179+ default is in-process (single terminal; Shift+Down to switch teammate)."
    echo "Inside tmux, choose 'auto' to get a split pane per teammate."
    print_warn "Writes to global ~/.claude/settings.json (affects all your projects)."
    echo ""

    if [ -t 0 ]; then
        DISPLAY_MODE_IDX=$(choose_option 2 \
            "Display mode (↑↓ to navigate, Enter to confirm, 1-9 to quick-select):" \
            "auto       — split pane per teammate in tmux/iTerm2, single terminal otherwise" \
            "in-process — always single terminal, Shift+Down to switch (works everywhere)" \
            "no change  — keep current setting")
        GLOBAL_SETTINGS="$HOME/.claude/settings.json"
        mkdir -p "$HOME/.claude"
        case "$DISPLAY_MODE_IDX" in
            0)
                if [ "$HAS_JQ" -eq 1 ]; then
                    if [ -f "$GLOBAL_SETTINGS" ]; then
                        TMP="$(mktemp)"
                        jq '.teammateMode = "auto"' "$GLOBAL_SETTINGS" >"$TMP" && mv "$TMP" "$GLOBAL_SETTINGS"
                    else
                        printf '{\n  "teammateMode": "auto"\n}\n' >"$GLOBAL_SETTINGS"
                    fi
                    echo "  ✓ set \"teammateMode\":\"auto\" → $GLOBAL_SETTINGS"
                else
                    print_warn "jq unavailable — cannot safely merge JSON." "  "
                    echo "    Manually add to $GLOBAL_SETTINGS:  \"teammateMode\": \"auto\""
                fi
                ;;
            1)
                if [ "$HAS_JQ" -eq 1 ]; then
                    if [ -f "$GLOBAL_SETTINGS" ]; then
                        TMP="$(mktemp)"
                        jq '.teammateMode = "in-process"' "$GLOBAL_SETTINGS" >"$TMP" && mv "$TMP" "$GLOBAL_SETTINGS"
                    else
                        printf '{\n  "teammateMode": "in-process"\n}\n' >"$GLOBAL_SETTINGS"
                    fi
                    echo "  ✓ set \"teammateMode\":\"in-process\" → $GLOBAL_SETTINGS"
                else
                    print_warn "jq unavailable — cannot safely merge JSON." "  "
                    echo "    Manually add to $GLOBAL_SETTINGS:  \"teammateMode\": \"in-process\""
                fi
                ;;
            *)
                echo "  ↻ no change to display mode."
                ;;
        esac
    else
        echo "  (non-interactive shell — skipped; display mode unchanged)"
    fi
    echo ""

    # --- 7. Enable auto permission mode (interactive, recommended) ---
    # Teammates INHERIT the lead's permission mode at spawn — per-teammate permission
    # modes cannot be set individually. permissions.defaultMode="auto" makes the lead
    # (and every teammate it spawns) start in auto mode, so teammates don't stall on
    # permission prompts in panes you aren't watching.
    # ⚠ CC explicitly ignores this setting at project/local level — it only takes
    #    effect in the global ~/.claude/settings.json. This step always writes global.
    echo "--- Auto permission mode (recommended) ---"
    echo ""
    echo "Teammates inherit the lead's permission mode at spawn — no per-teammate override."
    echo "\"permissions.defaultMode\":\"auto\" makes the lead and all teammates start in auto,"
    echo "preventing permission-prompt stalls in panes you aren't watching."
    print_warn "This setting only takes effect in the global ~/.claude/settings.json"
    echo "  (project/local level is explicitly ignored by CC)."
    echo ""

    if [ -t 0 ]; then
        AUTO_PERM_IDX=$(choose_option 0 \
            "Auto permission mode (↑↓ to navigate, Enter to confirm, 1-9 to quick-select):" \
            "$(recommended "enable auto permission mode (recommended — write to ~/.claude/settings.json)")" \
            "skip (leave permission mode as-is)")
        GLOBAL_SETTINGS="$HOME/.claude/settings.json"
        mkdir -p "$HOME/.claude"
        case "$AUTO_PERM_IDX" in
            0)
                if [ "$HAS_JQ" -eq 1 ]; then
                    if [ -f "$GLOBAL_SETTINGS" ]; then
                        TMP="$(mktemp)"
                        jq '.permissions.defaultMode = "auto"' "$GLOBAL_SETTINGS" >"$TMP" && mv "$TMP" "$GLOBAL_SETTINGS"
                    else
                        printf '{\n  "permissions": {\n    "defaultMode": "auto"\n  }\n}\n' >"$GLOBAL_SETTINGS"
                    fi
                    echo "  ✓ set \"permissions.defaultMode\":\"auto\" → $GLOBAL_SETTINGS"
                    echo "    revert anytime: delete that key, or use Shift+Tab per session."
                else
                    print_warn "jq unavailable — cannot safely merge JSON." "  "
                    echo "    Manually add to $GLOBAL_SETTINGS:"
                    echo "      \"permissions\": { \"defaultMode\": \"auto\" }"
                fi
                ;;
            *)
                echo "  ↻ skipped; permission mode unchanged."
                echo "    To use auto: switch the lead to auto with Shift+Tab before spawning."
                ;;
        esac
    else
        echo "  (non-interactive shell — skipped; permission mode unchanged)"
    fi
    echo ""
fi

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
echo "  • CC v2.1.179+ default is in-process (single terminal; Shift+Down to switch)."
echo "  • To change it later, run: $RESETUP_CMD"
echo ""
print_warn "Do not directly edit .claude/skills/ or .claude/agents/ —"
echo "  those are installed copies. Edit the sources in"
echo "  $TEMPLATE_ROOT/resources/ instead and re-run bootstrap."
echo ""
