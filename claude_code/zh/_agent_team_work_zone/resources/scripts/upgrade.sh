#!/usr/bin/env bash
#
# upgrade.sh — migration-chain dispatcher for _agent_team_work_zone upgrades.
#
# This script is shipped inside the template. At runtime, the user copies the
# new-version template into their project's .upgrade/ staging directory and
# invokes THIS script from there:
#
#   bash _agent_team_work_zone/.upgrade/resources/scripts/upgrade.sh
#
# No arguments. All paths are derived from $0 so the user can't point it at the
# wrong project.
#
# Layout assumed at runtime:
#
#   <project>/
#   └── _agent_team_work_zone/         ← TARGET_DIR  (the install being upgraded)
#       ├── VERSION                    ← target's current version (or missing = v0.0.0)
#       ├── .upgrade/                  ← UPGRADE_DIR (staged new template)
#       │   ├── VERSION                ← source version we're upgrading TO
#       │   └── resources/scripts/
#       │       ├── upgrade.sh         ← THIS FILE
#       │       └── migrations/
#       │           ├── common.sh
#       │           └── vX.Y.Z_to_vA.B.C.sh …
#       └── (rest of the framework + user workstations)
#
# Dispatcher logic:
#   1. Read UPGRADE_DIR/VERSION       → SRC_VER     (must exist)
#   2. Read TARGET_DIR/VERSION        → TGT_VER     (missing → v0.0.0 with WARN)
#   3. Enumerate migrations/vX_to_vY.sh, sort by "from" version
#   4. Pick the chain whose "from" ≥ TGT_VER and "to" ≤ SRC_VER
#   5. Execute each migration in order; after each, target VERSION is bumped
#      (the migration itself does this so partial-success state is recoverable)
#   6. Verify final VERSION matches SRC_VER
#   7. Re-run bootstrap.sh to refresh skills / hooks
#
# Safety properties:
#   - set -euo pipefail throughout
#   - any migration failing stops the chain; target is left in whatever state
#     the last successful migration bumped it to, so re-running resumes cleanly
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
UPGRADE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"     # .../.upgrade/
TARGET_DIR="$(cd "$UPGRADE_DIR/.." && pwd)"        # .../_agent_team_work_zone/
MIGRATIONS_DIR="$SCRIPT_DIR/migrations"

# shellcheck source=./migrations/common.sh
. "$MIGRATIONS_DIR/common.sh"

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

print_header "_agent_team_work_zone upgrade"
printf 'Upgrade staging: %s\n' "$UPGRADE_DIR"
printf 'Target install:  %s\n' "$TARGET_DIR"
echo ""

# --- Sanity: we must actually be running out of a staged .upgrade/ ---
if [ "$(basename "$UPGRADE_DIR")" != ".upgrade" ]; then
    print_error "Expected to be invoked from <target>/.upgrade/resources/scripts/upgrade.sh"
    print_error "Derived UPGRADE_DIR: $UPGRADE_DIR"
    print_error "Copy the new template into <project>/_agent_team_work_zone/.upgrade/ first."
    exit 1
fi

if [ ! -d "$TARGET_DIR" ] || [ "$(basename "$TARGET_DIR")" != "_agent_team_work_zone" ]; then
    print_error "TARGET_DIR does not look like an _agent_team_work_zone install: $TARGET_DIR"
    exit 1
fi

# --- 1. Resolve source version ---
SRC_VERSION_FILE="$UPGRADE_DIR/VERSION"
if [ ! -f "$SRC_VERSION_FILE" ]; then
    print_error "Staged .upgrade/ has no VERSION file: $SRC_VERSION_FILE"
    print_error "Copy the new-version template (from agent-team-work-zone repo) into .upgrade/ first."
    print_error "See: $UPGRADE_DIR/README.md"
    exit 1
fi
SRC_VER="$(tr -d '[:space:]' < "$SRC_VERSION_FILE")"

# --- 2. Resolve target version (tolerant of missing VERSION) ---
TGT_VERSION_FILE="$TARGET_DIR/VERSION"
if [ -f "$TGT_VERSION_FILE" ]; then
    TGT_VER="$(tr -d '[:space:]' < "$TGT_VERSION_FILE")"
else
    print_warn "TARGET has no VERSION file — treating as v0.0.0 and proceeding."
    TGT_VER="v0.0.0"
fi

printf 'Source version: %s\n' "$SRC_VER"
printf 'Target version: %s\n' "$TGT_VER"
echo ""

# --- 3. Enumerate available migrations ---
if [ ! -d "$MIGRATIONS_DIR" ]; then
    print_error "Migrations directory missing: $MIGRATIONS_DIR"
    exit 1
fi

# Collect vX.Y.Z_to_vA.B.C.sh filenames, parse from/to versions, sort by FROM.
#
# Implementation note: we sort by replacing dots with spaces and piping to
# sort -k1n -k2n -k3n, which avoids depending on sort -V's lexicographic
# ordering of embedded strings.
shopt -s nullglob
MIGRATION_FILES=("$MIGRATIONS_DIR"/v*_to_v*.sh)
shopt -u nullglob

if [ "${#MIGRATION_FILES[@]}" -eq 0 ]; then
    print_error "No migration scripts found under $MIGRATIONS_DIR"
    exit 1
fi

# Build "from\tto\tpath" lines, then sort by from-version.
MIG_INDEX="$(mktemp)"
trap 'rm -f "$MIG_INDEX"' EXIT

for f in "${MIGRATION_FILES[@]}"; do
    base="$(basename "$f" .sh)"
    # base = vX.Y.Z_to_vA.B.C
    from="${base%%_to_*}"
    to="${base##*_to_}"
    if ! [[ "$from" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || ! [[ "$to" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        print_warn "Skipping malformed migration filename: $base"
        continue
    fi
    # Emit sort key (from version, dot-separated numbers) then from/to/path.
    fromkey="${from#v}"; fromkey="${fromkey//./ }"
    printf '%s\t%s\t%s\t%s\n' "$fromkey" "$from" "$to" "$f"
done | sort -k1,1n -k2,2n -k3,3n > "$MIG_INDEX"

# --- 4. Walk the chain: start at TGT_VER, apply migrations whose from==current. ---

CURRENT="$TGT_VER"

if ! version_lt "$CURRENT" "$SRC_VER"; then
    print_success "Already up-to-date ($CURRENT ≥ $SRC_VER). Nothing to do."
    exit 0
fi

# --- MAJOR version bump: warn and require confirmation before proceeding. ---
# Skip when TGT_VER is v0.0.0 (fresh install — no user state to worry about).
if [ "$TGT_VER" != "v0.0.0" ]; then
    parse_version "$TGT_VER"; old_major=$MAJOR
    parse_version "$SRC_VER"; new_major=$MAJOR
    if [ "$new_major" -gt "$old_major" ]; then
        print_warn "=================================================="
        print_warn "  MAJOR VERSION UPGRADE: $TGT_VER → $SRC_VER"
        print_warn "=================================================="
        print_warn "This may include breaking changes."
        print_warn "Review $TARGET_DIR/CHANGELOG.md before proceeding."
        if [ -t 0 ]; then
            _MAJOR_IDX=$(choose_option 1 \
                "主版本升级确认 (↑↓ 切换，回车确认，数字键快选):" \
                "Yes — 继续升级" \
                "No  — 取消")
        else
            _MAJOR_IDX=1
        fi
        case "$_MAJOR_IDX" in
            0) ;;
            *) echo "升级已取消。"; exit 0 ;;
        esac
    fi
fi

# Build chain plan for display.
print_header "Planning upgrade chain"
printf 'Current: %s → target: %s\n\n' "$CURRENT" "$SRC_VER"

PLAN=()
CURSOR="$CURRENT"
while version_lt "$CURSOR" "$SRC_VER"; do
    # Find the migration whose from == CURSOR.
    line="$(awk -F'\t' -v cur="$CURSOR" '$2 == cur { print; exit }' "$MIG_INDEX")"
    if [ -z "$line" ]; then
        print_error "No migration path from $CURSOR to reach $SRC_VER."
        print_error "Missing migrations/${CURSOR}_to_*.sh — cannot proceed."
        exit 1
    fi
    # Parse the line: fromkey \t from \t to \t path
    IFS=$'\t' read -r _ mfrom mto mpath <<< "$line"

    # Guard against a runaway chain that skips past SRC_VER.
    if version_lt "$SRC_VER" "$mto"; then
        print_error "Migration $mfrom → $mto overshoots target $SRC_VER."
        print_error "The migration chain in $MIGRATIONS_DIR must land exactly on $SRC_VER."
        exit 1
    fi

    PLAN+=("$mfrom|$mto|$mpath")
    printf '  %s → %s   (%s)\n' "$mfrom" "$mto" "$(basename "$mpath")"
    CURSOR="$mto"
done
echo ""

# --- 5. Execute chain ---
print_header "Executing migrations"
for step in "${PLAN[@]}"; do
    IFS='|' read -r mfrom mto mpath <<< "$step"
    printf '\n%s---%s Running %s → %s\n' "$__C_BOLD" "$__C_RESET" "$mfrom" "$mto"
    if ! bash "$mpath" "$UPGRADE_DIR" "$TARGET_DIR"; then
        print_error "Migration $mfrom → $mto FAILED"
        print_error "Target VERSION left at the last successfully-applied step."
        print_error "Inspect the error above, fix, then re-run upgrade.sh to resume."
        exit 1
    fi
done

# --- 6. Verify final version ---
FINAL_VER="$(tr -d '[:space:]' < "$TGT_VERSION_FILE" 2>/dev/null || echo "")"
if [ "$FINAL_VER" != "$SRC_VER" ]; then
    print_error "Chain completed but target VERSION is '$FINAL_VER', expected '$SRC_VER'."
    print_error "One of the migrations did not bump VERSION correctly. Please investigate."
    exit 1
fi
echo ""
print_success "Files upgraded: $TGT_VER → $SRC_VER"
echo ""

# --- 7. Re-run bootstrap.sh (new one, already copied to TARGET_DIR by migrations). ---
BOOTSTRAP="$TARGET_DIR/resources/scripts/bootstrap.sh"
PROJECT_ROOT_DIR="$(cd "$TARGET_DIR/.." && pwd)"
print_header "Re-running bootstrap.sh"
if [ ! -f "$BOOTSTRAP" ]; then
    print_error "bootstrap.sh not found at $BOOTSTRAP"
    print_error "Cannot complete upgrade — skills and hooks not refreshed."
    print_error "Locate bootstrap.sh in the new resources/scripts/ directory and run:"
    printf '  PROJECT_ROOT="%s" bash "<path-to-bootstrap.sh>"\n' "$PROJECT_ROOT_DIR"
    print_error "Staging area preserved for debugging."
    exit 1
fi

if ! PROJECT_ROOT="$PROJECT_ROOT_DIR" bash "$BOOTSTRAP"; then
    echo ""
    print_error "bootstrap.sh exited non-zero — skills / hooks may not be fully refreshed."
    print_error "Framework files are already upgraded. Fix the error above, then run:"
    printf '  PROJECT_ROOT="%s" bash "%s"\n' "$PROJECT_ROOT_DIR" "$BOOTSTRAP"
    print_error "Staging area preserved for debugging."
    exit 1
fi
echo ""
print_success "bootstrap.sh completed"

echo ""

# Auto-cleanup: remove staging contents except README.md.
# Only reached when bootstrap.sh succeeds; staging is no longer needed.
print_header "Cleaning up staging area"
if [ -d "$UPGRADE_DIR" ]; then
    find "$UPGRADE_DIR" -mindepth 1 ! -name README.md -exec rm -rf {} + 2>/dev/null || true
    print_success "Staging area cleaned (README.md preserved)"
fi

echo ""
print_header "Upgrade complete: $TGT_VER → $SRC_VER"
echo ""
echo "Next steps:"
echo "  1. Review the CHANGELOG:   $TARGET_DIR/CHANGELOG.md"
echo "  2. In active Claude Code sessions, run /sync to pick up new skills."
echo "  3. If any teammate was mid-task, ask the team lead to /reactivate-team."
echo ""
