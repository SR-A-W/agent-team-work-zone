#!/usr/bin/env bash
#
# migrations/common.sh — shared helpers for per-version migration scripts.
#
# Sourced by:
#   - upgrade.sh               (the dispatcher)
#   - migrations/vX_to_vY.sh   (each individual migration)
#
# Do not run directly. Expects `set -euo pipefail` already active in caller.
#

# -------- Colored output --------
#
# Honour NO_COLOR convention; disable escapes when stdout isn't a tty.
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    __C_RESET=$'\033[0m'
    __C_BOLD=$'\033[1m'
    __C_RED=$'\033[31m'
    __C_GREEN=$'\033[32m'
    __C_YELLOW=$'\033[33m'
    __C_CYAN=$'\033[36m'
else
    __C_RESET=""; __C_BOLD=""; __C_RED=""; __C_GREEN=""; __C_YELLOW=""; __C_CYAN=""
fi

print_header() {
    # $1 — title line
    printf '%s==================================================%s\n' "$__C_BOLD" "$__C_RESET"
    printf '%s  %s%s\n' "$__C_BOLD$__C_CYAN" "$1" "$__C_RESET"
    printf '%s==================================================%s\n' "$__C_BOLD" "$__C_RESET"
}

print_success() { printf '%s✓%s %s\n' "$__C_GREEN" "$__C_RESET" "$1"; }
print_warn()    { printf '%s⚠%s %s\n' "$__C_YELLOW" "$__C_RESET" "$1"; }
print_error()   { printf '%s✗%s %s\n' "$__C_RED"    "$__C_RESET" "$1"; }
print_step()    { printf '  → %s\n' "$1"; }

# -------- cp_framework_files: pre-flight-checked whole-dir overwrite --------
#
# Usage:
#   cp_framework_files <source_root> <target_root> <dir1> [<dir2> ...]
#
# Verifies every named subdirectory exists under $source_root BEFORE touching
# the target. Missing source → print_error + return 1 (no rm, no cp). This is
# the blocker fix: never leave the user with no resources/ because of a bad
# source tree.
cp_framework_files() {
    local src_root="$1"; shift
    local tgt_root="$1"; shift

    local d
    for d in "$@"; do
        if [ ! -d "$src_root/$d" ]; then
            print_error "Source directory missing: $src_root/$d"
            print_error "Refusing to proceed — this would delete the user's $d/ with no replacement."
            print_error "Your .upgrade/ staging appears incomplete. Re-copy the template and retry."
            return 1
        fi
    done

    for d in "$@"; do
        print_step "$d/"
        rm -rf "$tgt_root/$d"
        cp -r "$src_root/$d" "$tgt_root/$d"
    done
}

# -------- replace_framework_section: README FRAMEWORK:START~END swap --------
#
# Usage:
#   replace_framework_section <src_readme> <tgt_readme>
#
# The source README's FRAMEWORK:START … FRAMEWORK:END block (markers included)
# replaces the same block in the target. Everything outside the markers in the
# target is preserved verbatim. Uses awk state machine for unambiguous parsing.
#
# Edge cases:
#   - target missing             → copy source as-is
#   - target missing markers     → warn + skip (do not touch target)
#   - source missing FRAMEWORK   → warn + skip
#
# Temp files are cleaned by EXIT trap even if awk / mv aborts mid-way.
replace_framework_section() {
    local src_readme="$1"
    local tgt_readme="$2"

    if [ ! -f "$tgt_readme" ]; then
        print_warn "TARGET README.md not found, copying source README as-is."
        cp "$src_readme" "$tgt_readme"
        return 0
    fi

    if ! grep -q '<!-- FRAMEWORK:START -->' "$tgt_readme" \
       || ! grep -q '<!-- FRAMEWORK:END -->' "$tgt_readme"; then
        print_warn "TARGET README.md missing FRAMEWORK:START/END markers — skipped."
        print_warn "(Your README will not be updated. Fix the markers and re-run if needed.)"
        return 0
    fi

    local tmp_fw tmp_out
    tmp_fw="$(mktemp)"
    tmp_out="$(mktemp)"
    trap 'rm -f "'"$tmp_fw"'" "'"$tmp_out"'"' EXIT

    awk '
        /<!-- FRAMEWORK:START -->/ { capture = 1 }
        capture { print }
        /<!-- FRAMEWORK:END -->/   { capture = 0 }
    ' "$src_readme" > "$tmp_fw"

    if [ ! -s "$tmp_fw" ]; then
        print_warn "Source README.md has no FRAMEWORK section — skipped."
        return 0
    fi

    awk -v fw_file="$tmp_fw" '
        BEGIN { state = 0 }

        /<!-- FRAMEWORK:START -->/ {
            if (state == 0) {
                state = 1
                while ((getline line < fw_file) > 0) print line
                close(fw_file)
                next
            }
        }

        /<!-- FRAMEWORK:END -->/ {
            if (state == 1) {
                state = 2
                next
            }
        }

        { if (state != 1) print }
    ' "$tgt_readme" > "$tmp_out"

    mv "$tmp_out" "$tgt_readme"
    print_success "README.md FRAMEWORK section updated"
}

# -------- Version helpers --------
#
# parse_version <vX.Y.Z> → sets globals MAJOR / MINOR / PATCH
parse_version() {
    local ver="${1#v}"
    IFS='.' read -r MAJOR MINOR PATCH <<< "$ver"
    : "${MAJOR:=0}" "${MINOR:=0}" "${PATCH:=0}"
}

# version_lt <a> <b> — return 0 iff a < b (semver compare, no pre-release)
version_lt() {
    local am an ap bm bn bp
    parse_version "$1"; am=$MAJOR; an=$MINOR; ap=$PATCH
    parse_version "$2"; bm=$MAJOR; bn=$MINOR; bp=$PATCH
    if [ "$am" -lt "$bm" ]; then return 0; fi
    if [ "$am" -gt "$bm" ]; then return 1; fi
    if [ "$an" -lt "$bn" ]; then return 0; fi
    if [ "$an" -gt "$bn" ]; then return 1; fi
    if [ "$ap" -lt "$bp" ]; then return 0; fi
    return 1
}

# write_version <path> <vX.Y.Z> — atomically update VERSION file
write_version() {
    local path="$1" ver="$2"
    local tmp; tmp="$(mktemp)"
    printf '%s\n' "$ver" > "$tmp"
    mv "$tmp" "$path"
}
