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

# -------- replace_marked_section: generic <!-- X:START --> ~ <!-- X:END --> swap --------
#
# Usage:
#   replace_marked_section <src> <tgt> <start_marker> <end_marker> [success_msg]
#
# The source file's start_marker … end_marker block (markers included) replaces
# the same block in the target. Everything outside the markers in the target is
# preserved verbatim. Uses awk state machine for unambiguous parsing. Markers are
# matched as literal substrings (via awk index()/grep -F), not regexes, so marker
# text containing regex metacharacters (e.g. "<!-- ... -->") is safe.
#
# Edge cases:
#   - target missing        → copy source as-is
#   - target missing marker → warn + skip (do not touch target)
#   - source missing marker → warn + skip
#
# No EXIT trap: this function may be called many times per script run (once per
# workstation README) and each call runs to completion in a single shell — an
# EXIT trap here would clobber whatever trap the calling script already set
# (e.g. upgrade.sh's own `trap ... EXIT` for its own temp files), and a repeated
# `trap ... EXIT` across many calls would leak all but the last call's temp
# files. Every return path below does its own explicit `rm -f` instead.
replace_marked_section() {
    local src="$1"
    local tgt="$2"
    local start_marker="$3"
    local end_marker="$4"
    local success_msg="${5:-}"

    if [ ! -f "$tgt" ]; then
        print_warn "TARGET file not found, copying source as-is: $tgt"
        cp "$src" "$tgt"
        return 0
    fi

    if ! grep -qF "$start_marker" "$tgt" || ! grep -qF "$end_marker" "$tgt"; then
        print_warn "TARGET missing $start_marker/$end_marker markers — skipped: $tgt"
        print_warn "(File will not be updated. Fix the markers and re-run if needed.)"
        return 0
    fi

    local tmp_section tmp_out
    tmp_section="$(mktemp)"
    tmp_out="$(mktemp)"

    awk -v start="$start_marker" -v end="$end_marker" '
        index($0, start) { capture = 1 }
        capture { print }
        index($0, end)   { capture = 0 }
    ' "$src" > "$tmp_section"

    if [ ! -s "$tmp_section" ]; then
        print_warn "SOURCE has no $start_marker/$end_marker section — skipped: $src"
        rm -f "$tmp_section" "$tmp_out"
        return 0
    fi

    awk -v section_file="$tmp_section" -v start="$start_marker" -v end="$end_marker" '
        BEGIN { state = 0 }

        index($0, start) {
            if (state == 0) {
                state = 1
                while ((getline line < section_file) > 0) print line
                close(section_file)
                next
            }
        }

        index($0, end) {
            if (state == 1) {
                state = 2
                next
            }
        }

        { if (state != 1) print }
    ' "$tgt" > "$tmp_out"

    mv "$tmp_out" "$tgt"
    rm -f "$tmp_section"
    if [ -n "$success_msg" ]; then
        print_success "$success_msg"
    fi
}

# -------- replace_framework_section: README FRAMEWORK:START~END swap --------
#
# Usage:
#   replace_framework_section <src_readme> <tgt_readme>
#
# Thin backward-compatible wrapper around replace_marked_section. All 22+
# existing per-version migration scripts call this directly — signature and
# behaviour (including edge cases and the success message) are unchanged.
replace_framework_section() {
    replace_marked_section "$1" "$2" '<!-- FRAMEWORK:START -->' '<!-- FRAMEWORK:END -->' \
        "README.md FRAMEWORK section updated"
}

# -------- ensure_rules_markers: self-heal missing RULES:START/END markers --------
#
# Usage:
#   ensure_rules_markers <file>
#
# Idempotent. If both markers are already present, no-op (return 0). If exactly
# one is present, the file is in a malformed state — warn + skip (return 1)
# rather than risk inserting a duplicate/misplaced marker. If neither is
# present, locate the rules section by its heading (count-insensitive: matches
# "## 工作守则" OR "## Work Rules", regardless of how many rules are listed —
# existing installs have both 12-rule and 13-rule copies). BOTH heading
# spellings are always checked, in both the zh and en copies of this file,
# regardless of which language tree ships it — mixed-language installs are
# real (e.g. a zh-deployed teammate workstation whose README carries an
# English "## Work Rules" heading); narrowing this to one language per tree
# was tried once and produced a false negative (an English-headed rules
# section silently treated as "no rules section at all" under a zh install).
# This dual check is also what keeps the zh and en copies of this file
# byte-identical. Once the heading is found, wrap it: START goes immediately
# before the heading line; END goes immediately before the next "## " heading,
# or at end-of-file if there is none. If no matching heading is found at all,
# warn + skip (return 1) — this function never fabricates a rules section for
# a file that doesn't have one (e.g. today's teammate workstation README,
# which has no rules section; that gap is closed on the spawn/reactivate
# side, not here).
ensure_rules_markers() {
    local file="$1"

    if grep -q '<!-- RULES:START -->' "$file" && grep -q '<!-- RULES:END -->' "$file"; then
        return 0
    fi

    if grep -q '<!-- RULES:START -->' "$file" || grep -q '<!-- RULES:END -->' "$file"; then
        print_warn "Malformed RULES markers (only one of START/END present) — skipped: $file"
        return 1
    fi

    if ! grep -qE '^## (工作守则|Work Rules)' "$file"; then
        print_warn "No rules section heading found — skipped (not auto-created): $file"
        return 1
    fi

    local tmp
    tmp="$(mktemp)"

    awk '
        BEGIN { state = 0 }
        state == 0 && /^## (工作守则|Work Rules)/ {
            print "<!-- RULES:START -->"
            print
            state = 1
            next
        }
        state == 1 && /^## / {
            print "<!-- RULES:END -->"
            print
            state = 2
            next
        }
        { print }
        END { if (state == 1) print "<!-- RULES:END -->" }
    ' "$file" > "$tmp"

    mv "$tmp" "$file"
    print_success "Injected RULES:START/END markers: $file"
    return 0
}

# -------- refresh_rules_section: orchestrate rules-block refresh + backup --------
#
# Usage:
#   refresh_rules_section <src_readme> <tgt_readme>
#
# 1. ensure_rules_markers on the target; if it fails (malformed, or no rules
#    section at all), skip entirely — target is left untouched.
# 2. Compare the target's current RULES block against the source's. If
#    identical, no-op (no backup noise). If different, back up the OLD block
#    itself (not the whole file) to "<tgt>.rules.bak.<YYYYmmddHHMMSS>" — this
#    is the precise diff that's about to be overwritten, kept small and next
#    to the file it came from — then replace via replace_marked_section.
# Fail-soft throughout: every failure path warns and returns 0, never aborts
# the caller.
refresh_rules_section() {
    local src="$1"
    local tgt="$2"

    if [ ! -f "$tgt" ]; then
        print_warn "TARGET file not found — skipped: $tgt"
        return 0
    fi

    if ! ensure_rules_markers "$tgt"; then
        return 0
    fi

    if ! grep -q '<!-- RULES:START -->' "$src" || ! grep -q '<!-- RULES:END -->' "$src"; then
        print_warn "SOURCE missing RULES:START/END markers — skipped: $tgt"
        return 0
    fi

    local tgt_block src_block
    tgt_block="$(awk '/<!-- RULES:START -->/{c=1} c{print} /<!-- RULES:END -->/{c=0}' "$tgt")"
    src_block="$(awk '/<!-- RULES:START -->/{c=1} c{print} /<!-- RULES:END -->/{c=0}' "$src")"

    if [ "$tgt_block" = "$src_block" ]; then
        return 0
    fi

    local backup
    backup="${tgt}.rules.bak.$(date -u +%Y%m%d%H%M%S)"
    printf '%s\n' "$tgt_block" > "$backup"
    print_warn "Rules section differs — old block backed up to $backup"

    replace_marked_section "$src" "$tgt" '<!-- RULES:START -->' '<!-- RULES:END -->' \
        "$(basename "$tgt") rules section refreshed"
}

# -------- ensure_reference_markers: self-heal missing REFERENCE:START/END markers --------
#
# Usage:
#   ensure_reference_markers <file>
#
# Covers the five-section reference block (Pre-installed Skills / General-
# purpose Custom Subagents / Role Archetype Quick Reference / Team-Created
# Role Definition Storage / Troubleshooting) — five separate "## " headings
# that together make up ONE reference block running to end-of-file. This is
# NOT a mirror of ensure_rules_markers's "stop at the next ## heading" logic:
# RULES has exactly one "## " heading with "### " subsections, so the next
# "## " heading correctly signals its end; REFERENCE spans five "## " headings
# by design, so stopping at the first one encountered would only wrap
# "Pre-installed Skills" and silently duplicate the other four sections
# outside (then inside, on next run) the marker pair — this was caught by
# self-test before shipping. END therefore always goes at end-of-file (per the
# confirmed template layout: nothing follows Troubleshooting).
# Idempotent. If both markers are already present, no-op (return 0). If exactly
# one is present, the file is in a malformed state — warn + skip (return 1)
# rather than risk inserting a duplicate/misplaced marker. If neither is
# present, locate the section by its first heading (dual-language literal,
# same rationale as ensure_rules_markers: mixed-language installs are real,
# and this keeps the zh/en copies of this file byte-identical): START goes
# immediately before that heading line, END goes at end-of-file. If no
# matching heading is found at all, warn + skip (return 1) — this function
# never fabricates the reference section for a file that doesn't have one
# (e.g. a workstation README, which never carries these five sections at all).
ensure_reference_markers() {
    local file="$1"

    if grep -q '<!-- REFERENCE:START -->' "$file" && grep -q '<!-- REFERENCE:END -->' "$file"; then
        return 0
    fi

    if grep -q '<!-- REFERENCE:START -->' "$file" || grep -q '<!-- REFERENCE:END -->' "$file"; then
        print_warn "Malformed REFERENCE markers (only one of START/END present) — skipped: $file"
        return 1
    fi

    if ! grep -qE '^## (预置 Skills|Pre-installed Skills)' "$file"; then
        print_warn "No reference section heading found — skipped (not auto-created): $file"
        return 1
    fi

    local tmp
    tmp="$(mktemp)"

    awk '
        BEGIN { state = 0 }
        state == 0 && /^## (预置 Skills|Pre-installed Skills)/ {
            print "<!-- REFERENCE:START -->"
            print
            state = 1
            next
        }
        { print }
        END { if (state == 1) print "<!-- REFERENCE:END -->" }
    ' "$file" > "$tmp"

    mv "$tmp" "$file"
    print_success "Injected REFERENCE:START/END markers: $file"
    return 0
}

# -------- refresh_reference_section: orchestrate reference-block refresh --------
#
# Usage:
#   refresh_reference_section <src_readme> <tgt_readme>
#
# Unlike refresh_rules_section, this section is 100% framework-owned content
# (skill/subagent/archetype reference tables, Troubleshooting) with no user
# customization to preserve — so after self-healing markers, it is replaced
# UNCONDITIONALLY via replace_marked_section, same as replace_framework_section:
# no diff against source, no backup. If ensure_reference_markers fails
# (malformed, or no reference section at all — e.g. a workstation README),
# skip entirely; target is left untouched.
refresh_reference_section() {
    local src="$1"
    local tgt="$2"

    if [ ! -f "$tgt" ]; then
        print_warn "TARGET file not found — skipped: $tgt"
        return 0
    fi

    if ! ensure_reference_markers "$tgt"; then
        return 0
    fi

    replace_marked_section "$src" "$tgt" '<!-- REFERENCE:START -->' '<!-- REFERENCE:END -->' \
        "$(basename "$tgt") reference section refreshed"
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
