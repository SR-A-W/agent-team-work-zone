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

# -------- mktemp_beside: temp file next to a target, carrying its mode --------
#
# Usage:
#   tmp="$(mktemp_beside <target>)" || <handle failure>
#
# Creates the temp file in the target's own directory (so the final mv is an
# atomic same-filesystem rename, not a cross-filesystem copy+unlink from /tmp)
# and, if the target exists, copies it there with `cp -p` so the mode is
# preserved — a bare mktemp file is 0600, and mv-ing it over a README would
# silently turn 644 into 600. If the target does not exist yet (e.g. a missing
# VERSION), the temp file gets the umask default mode instead. Callers then overwrite the temp file's CONTENT
# (`> "$tmp"` truncates but keeps the mode). Portable (no GNU-only
# chmod --reference). On failure prints nothing, removes any partial temp file
# and returns 1 — the caller warns and skips.
mktemp_beside() {
    local target="$1" t
    t="$(mktemp "$(dirname "$target")/.$(basename "$target").XXXXXX")" || return 1
    if [ -e "$target" ]; then
        cp -p "$target" "$t" || { rm -f "$t"; return 1; }
    else
        # New file: give it the mode a plain `> file` would get (umask), not 0600.
        chmod "$(printf '%o' $(( 0666 & ~0$(umask) )))" "$t" || { rm -f "$t"; return 1; }
    fi
    printf '%s\n' "$t"
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
    # tmp_section is scratch (read back by awk only) and may live in /tmp;
    # tmp_out replaces the target, so it is created beside it with its mode.
    # This function is often called where set -e is suspended (if/||), so
    # every failure is checked: warn + skip, target untouched.
    if ! tmp_section="$(mktemp)"; then
        print_warn "Could not create a temp file — skipped: $tgt"
        return 0
    fi
    if ! tmp_out="$(mktemp_beside "$tgt")"; then
        rm -f "$tmp_section"
        print_warn "Could not create a temp file next to the target (directory not writable?) — skipped: $tgt"
        return 0
    fi

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

    rm -f "$tmp_section"
    if ! mv "$tmp_out" "$tgt"; then
        rm -f "$tmp_out"
        print_warn "Could not write $tgt — skipped, file untouched"
        return 0
    fi
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

# -------- inject_markers_anchored: content-anchored START/END self-heal --------
#
# Usage:
#   inject_markers_anchored <file> <src> <NAME> <heading_ere> <region>
#
# Shared engine behind ensure_rules_markers / ensure_reference_markers. Wraps
# an unmarked framework section of <file> in <!-- NAME:START --> / <!-- NAME:END -->.
#   - START goes immediately before the first line matching <heading_ere>.
#   - The candidate region runs from that heading to the next "## " heading
#     (<region> = h2, RULES) or to end-of-file (<region> = eof, REFERENCE).
#   - Anchor: END first goes right after the LAST line in that region that also
#     appears in <src>'s own NAME block — NOT at the region's end — so a user's
#     own notes, a USER:* segment or a divider after the framework text stay
#     outside the block and a later refresh never moves or overwrites them.
#     Only "substantive" lines count as anchors: after trimming, not blank, not
#     a code fence, and >= 6 bytes once all punctuation/whitespace is stripped.
#     Blank lines, "---", "| --- |", "```" and other short structural lines
#     never match, so a divider in the user's notes cannot equal a template
#     line and drag END past the user's content. Matching is on trimmed text
#     (CR ignored); awk runs under LC_ALL=C (byte-based, locale-independent).
#   - Numbered-rule extension (h2 / RULES only): hand-copied rules are often
#     reworded by the agent that copied them, so exact matching alone would
#     leave reworded tail rules behind next to the fresh copy. If the region
#     has numbered rule headings ("### N."), END extends to the end of the LAST
#     one — up to the next "### " heading, a "---" / "***" / "___" divider, an
#     HTML comment, or the region end. Unrecognised lines taken in this way are
#     counted and reported with a visible ⚠ (they land in the backup on
#     refresh). Not applied to REFERENCE: its refresh takes no backup, so a
#     heuristic extension there could lose data.
#   - Trailing structure: END then extends over a contiguous run of blank /
#     template-identical lines (so an older template's own closing "---" goes
#     inside instead of being left behind as a duplicate); that walk stops at
#     the first line not in the template, so it never crosses user text.
# Tradeoffs (deliberate): notes separated from the rules by a divider or a
# heading stay outside, untouched; notes glued straight onto the last rule are
# taken in (recoverable from the backup, and reported). Content inserted
# BETWEEN framework lines is inside the block. Non-blank lines still left
# outside are reported as "old framework wording or your own content — please
# check", never lost.
# Return: 0 = markers injected; 1 = heading found but no line under it matches
# the template (looks user-authored, e.g. "## Work Rules for my team"), or the
# rewrite failed — warn + skip, file untouched. Callers have already checked
# the heading exists and that <src> has both NAME markers.
inject_markers_anchored() {
    local file="$1" src="$2" name="$3" heading="$4" region="$5"
    local tmp cnt rc kept
    # Called only from `if ! ensure_*` contexts, where set -e is suspended —
    # every failure must be checked explicitly so no false "Injected" is printed.
    if ! tmp="$(mktemp_beside "$file")" || ! cnt="$(mktemp)"; then
        rm -f "${tmp:-}"
        print_warn "Could not create temp files for $name markers — skipped, file untouched: $file"
        return 1
    fi

    rc=0
    LC_ALL=C awk -v s="<!-- $name:START -->" -v e="<!-- $name:END -->" \
        -v hre="$heading" -v region="$region" -v cntfile="$cnt" '
        function norm(x) { sub(/\r$/, "", x); gsub(/^[ \t]+|[ \t]+$/, "", x); return x }
        function substantive(x,   y) {
            if (x == "" || x ~ /^(```|~~~)/) return 0
            y = x; gsub(/[[:punct:][:space:]]/, "", y)
            return length(y) >= 6
        }
        FNR == NR {
            if (index($0, e)) { insrc = 0 }
            if (insrc) { t = norm($0); any[t] = 1; if (substantive(t)) tpl[t] = 1 }
            if (index($0, s)) { insrc = 1 }
            next
        }
        { n++; line[n] = $0 }
        END {
            for (i = 1; i <= n; i++) if (line[i] ~ hre) { h = i; break }
            r = n + 1
            if (region == "h2") for (i = h + 1; i <= n; i++) if (line[i] ~ /^## /) { r = i; break }
            last = 0
            for (i = h + 1; i < r; i++) { t = norm(line[i]); if (substantive(t) && (t in tpl)) last = i }
            if (last == 0) exit 3
            # Numbered-rule extension (RULES / h2 only) — see header comment.
            swallowed = 0
            if (region == "h2") {
                # The search for the last numbered rule stops at the first
                # separator after the anchors (divider, un-numbered "### "
                # heading, HTML comment): a "### N." the user put after a
                # divider is their own and must not become "the last rule".
                stop = r
                for (i = last + 1; i < r; i++) {
                    t = norm(line[i])
                    if ((t ~ /^### / && t !~ /^### [0-9]+\./) || t ~ /^(---+|\*\*\*+|___+)$/ || t ~ /^<!--/) { stop = i; break }
                }
                sh = 0
                for (i = h + 1; i < stop; i++) if (norm(line[i]) ~ /^### [0-9]+\./) sh = i
                if (sh > 0) {
                    for (i = sh + 1; i < r; i++) {
                        t = norm(line[i])
                        if (t ~ /^### / || t ~ /^(---+|\*\*\*+|___+)$/ || t ~ /^<!--/) break
                    }
                    j = i - 1
                    while (j > last && norm(line[j]) == "") j--
                    if (j > last) {
                        for (k = last + 1; k <= j; k++) if (norm(line[k]) != "" && !(norm(line[k]) in any)) swallowed++
                        last = j
                    }
                }
            }
            # Absorb trailing template structure (e.g. a closing
            # "---"): walk forward over blank lines and lines identical to some
            # template line, and stop at the first line that is neither. This
            # can never cross user text — any non-template line ends the walk.
            for (j = last + 1; j < r; j++) {
                t = norm(line[j])
                if (t == "") continue
                if (t in any) { last = j; continue }
                break
            }
            kept = 0
            for (i = last + 1; i < r; i++) if (norm(line[i]) != "") kept++
            print kept " " swallowed > cntfile
            for (i = 1; i <= n; i++) {
                if (i == h) print s
                print line[i]
                if (i == last) print e
            }
        }
    ' "$src" "$file" > "$tmp" || rc=$?

    if [ "$rc" -eq 3 ]; then
        rm -f "$tmp" "$cnt"
        print_warn "Section under the $name heading matches no framework text (looks user-authored) — skipped, not touched: $file"
        return 1
    elif [ "$rc" -ne 0 ]; then
        rm -f "$tmp" "$cnt"
        print_warn "Could not inject $name markers (awk exit $rc) — skipped: $file"
        return 1
    fi

    local swallowed=0
    read -r kept swallowed < "$cnt" 2>/dev/null || true
    rm -f "$cnt"
    case "$kept" in ''|*[!0-9]*) kept=0 ;; esac
    case "$swallowed" in ''|*[!0-9]*) swallowed=0 ;; esac
    if ! mv "$tmp" "$file"; then
        rm -f "$tmp"
        print_warn "Could not write $name markers into $file — skipped, file untouched"
        return 1
    fi
    print_success "Injected $name:START/END markers: $file"
    if [ "$swallowed" -gt 0 ]; then
        print_warn "$swallowed non-blank line(s) not recognised as framework text were taken into the managed block as part of the last numbered rule (they go into the backup on refresh) — to keep notes outside, separate them from the rules with --- or a heading: $file"
    fi
    if [ "$kept" -gt 0 ]; then
        print_warn "$kept non-blank line(s) after the recognised $name text were kept outside the managed block, untouched — they may be old framework wording or your own content; please check: $file"
    fi
    return 0
}

# -------- refresh_block_with_backup: diff + backup + replace one marked block --------
#
# Usage:
#   refresh_block_with_backup <src> <tgt> <NAME> <bak_tag> <label> <success_msg>
#
# Compares <tgt>'s <!-- NAME:START --> … <!-- NAME:END --> block against
# <src>'s. Identical → no-op (no backup noise, file not rewritten). Different
# → back up the OLD block itself (not the whole file) to
# "<tgt>.<bak_tag>.bak.<YYYYmmddHHMMSS>", print a visible ⚠ naming the
# backup, then replace via replace_marked_section. Missing/malformed markers
# on either side → warn + skip. Fail-soft: always returns 0.
refresh_block_with_backup() {
    local src="$1" tgt="$2" name="$3" bak_tag="$4" label="$5" success_msg="$6"
    local s="<!-- $name:START -->" e="<!-- $name:END -->"

    if ! grep -qF "$s" "$src" || ! grep -qF "$e" "$src"; then
        print_warn "SOURCE missing $name:START/END markers — skipped: $tgt"
        return 0
    fi
    if ! grep -qF "$s" "$tgt" || ! grep -qF "$e" "$tgt"; then
        print_warn "TARGET missing $name:START/END markers — skipped: $tgt"
        return 0
    fi

    local tgt_block src_block
    tgt_block="$(awk -v s="$s" -v e="$e" 'index($0,s){c=1} c{print} index($0,e){c=0}' "$tgt")"
    src_block="$(awk -v s="$s" -v e="$e" 'index($0,s){c=1} c{print} index($0,e){c=0}' "$src")"

    if [ "$tgt_block" = "$src_block" ]; then
        return 0
    fi

    local backup
    backup="${tgt}.${bak_tag}.bak.$(date -u +%Y%m%d%H%M%S)"
    # Backup first, replace only if the backup landed: no backup → no replace
    # (fail-soft — the old block stays where it is, the migration continues).
    if ! { printf '%s\n' "$tgt_block" > "$backup"; } 2>/dev/null; then
        rm -f "$backup" 2>/dev/null || true
        print_warn "$label differs but its backup could not be written ($backup) — NOT refreshed, left as is: $tgt"
        return 0
    fi
    print_warn "$label differs — old block backed up to $backup"

    replace_marked_section "$src" "$tgt" "$s" "$e" "$success_msg"
}

# -------- ensure_rules_markers: self-heal missing RULES:START/END markers --------
#
# Usage:
#   ensure_rules_markers <file> <src_readme>
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
# byte-identical. Once the heading is found, START goes immediately before
# it and END is placed by content anchoring against <src_readme>'s RULES
# block (see inject_markers_anchored): right after the last framework rules
# line found before the next "## " heading — NOT at that heading, which used
# to pull a user's own notes written after the rules into the block (and, on
# refresh, out of the README into the .rules.bak). A heading whose section
# matches no template rules text at all (e.g. a user's own "## Work Rules for
# my team") is skipped untouched (return 1). If no matching heading is found
# at all, warn + skip (return 1) — this function never fabricates a rules
# section for a file that doesn't have one (e.g. today's teammate workstation
# README, which has no rules section; that gap is closed on the
# spawn/reactivate side, not here).
ensure_rules_markers() {
    local file="$1"
    local src="$2"

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

    inject_markers_anchored "$file" "$src" RULES '^## (工作守则|Work Rules)' h2
}

# -------- refresh_rules_section: orchestrate rules-block refresh + backup --------
#
# Usage:
#   refresh_rules_section <src_readme> <tgt_readme>
#
# 1. ensure_rules_markers on the target (anchored against the source's RULES
#    block); if it fails (malformed, no rules section, or a section that
#    matches no template rules text), skip entirely — target is left untouched.
# 2. Compare the target's current RULES block against the source's. If
#    identical, no-op (no backup noise). If different, back up the OLD block
#    itself (not the whole file) to "<tgt>.rules.bak.<YYYYmmddHHMMSS>" — this
#    is the precise diff that's about to be overwritten, kept small and next
#    to the file it came from — then replace (refresh_block_with_backup).
# Fail-soft throughout: every failure path warns and returns 0, never aborts
# the caller.
refresh_rules_section() {
    local src="$1"
    local tgt="$2"

    if [ ! -f "$tgt" ]; then
        print_warn "TARGET file not found — skipped: $tgt"
        return 0
    fi

    if ! grep -q '<!-- RULES:START -->' "$src" || ! grep -q '<!-- RULES:END -->' "$src"; then
        print_warn "SOURCE missing RULES:START/END markers — skipped: $tgt"
        return 0
    fi

    if ! ensure_rules_markers "$tgt" "$src"; then
        return 0
    fi

    refresh_block_with_backup "$src" "$tgt" RULES rules "Rules section" \
        "$(basename "$tgt") rules section refreshed"
}

# -------- refresh_teammate_rules_section: teammate-block refresh + backup --------
#
# Usage:
#   refresh_teammate_rules_section <src_teammate_rules_md> <tgt_teammate_readme>
#
# Teammate workstation READMEs carry a condensed <!-- TEAMMATE_RULES:START/END -->
# block (source: resources/teammate_rules.md), written there by
# /spawn-team or /reactivate-team. Once delivered it sits in a user-visible,
# user-editable README, so a refresh gets the same diff + backup treatment as
# the lead/flat RULES block: identical → no-op; different → old block backed
# up to "<tgt>.teammate_rules.bak.<YYYYmmddHHMMSS>" with a visible ⚠, then
# replaced. No block at all → not fabricated here (a migration does not
# invent content in another agent's workstation); it is delivered on the
# teammate's next spawn/reactivate. Exactly one marker → malformed, warn +
# skip. Fail-soft: always returns 0.
refresh_teammate_rules_section() {
    local src="$1"
    local tgt="$2"
    local who
    who="teammates/$(basename "$(dirname "$tgt")")"

    if [ ! -f "$tgt" ]; then
        print_warn "TARGET file not found — skipped: $tgt"
        return 0
    fi

    if ! grep -q '<!-- TEAMMATE_RULES:START -->' "$tgt" && ! grep -q '<!-- TEAMMATE_RULES:END -->' "$tgt"; then
        print_step "$who: no TEAMMATE_RULES block yet — will be delivered on next spawn/reactivate (no action needed)"
        return 0
    fi

    if ! grep -q '<!-- TEAMMATE_RULES:START -->' "$tgt" || ! grep -q '<!-- TEAMMATE_RULES:END -->' "$tgt"; then
        print_warn "Malformed TEAMMATE_RULES markers (only one of START/END present) — skipped: $tgt"
        return 0
    fi

    refresh_block_with_backup "$src" "$tgt" TEAMMATE_RULES teammate_rules "Teammate rules block" \
        "$who/README.md teammate-rules block refreshed"
}

# -------- ensure_reference_markers: self-heal missing REFERENCE:START/END markers --------
#
# Usage:
#   ensure_reference_markers <file> <src_readme>
#
# Covers the five-section reference block (Pre-installed Skills / General-
# purpose Custom Subagents / Role Archetype Quick Reference / Team-Created
# Role Definition Storage / Troubleshooting) — five separate "## " headings
# that together make up ONE reference block. Unlike RULES (one "## " heading
# with "### " subsections), the candidate region therefore does NOT stop at
# the next "## " heading — stopping at the first one encountered would only
# wrap "Pre-installed Skills" and silently duplicate the other four sections
# outside (then inside, on next run) the marker pair; this was caught by
# self-test before shipping. The region runs to end-of-file, and END is
# placed by content anchoring against <src_readme>'s REFERENCE block (see
# inject_markers_anchored): right after the last framework reference line.
# Placing END blindly at end-of-file used to swallow anything a user had
# appended after Troubleshooting (e.g. a <!-- USER:* --> segment) — and since
# the reference refresh takes no backup, that content was lost outright.
# Idempotent. If both markers are already present, no-op (return 0). If exactly
# one is present, the file is in a malformed state — warn + skip (return 1)
# rather than risk inserting a duplicate/misplaced marker. If neither is
# present, locate the section by its first heading (dual-language literal,
# same rationale as ensure_rules_markers: mixed-language installs are real,
# and this keeps the zh/en copies of this file byte-identical). If no
# matching heading is found at all (or nothing under it matches the
# template), warn + skip (return 1) — this function never fabricates the
# reference section for a file that doesn't have one (e.g. a workstation
# README, which never carries these five sections at all).
ensure_reference_markers() {
    local file="$1"
    local src="$2"

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

    inject_markers_anchored "$file" "$src" REFERENCE '^## (预置 Skills|Pre-installed Skills)' eof
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

    if ! grep -q '<!-- REFERENCE:START -->' "$src" || ! grep -q '<!-- REFERENCE:END -->' "$src"; then
        print_warn "SOURCE missing REFERENCE:START/END markers — skipped: $tgt"
        return 0
    fi

    if ! ensure_reference_markers "$tgt" "$src"; then
        return 0
    fi

    replace_marked_section "$src" "$tgt" '<!-- REFERENCE:START -->' '<!-- REFERENCE:END -->' \
        "$(basename "$tgt") reference section refreshed"
}

# -------- append_missing_lines: add missing lines to a user file, append-only --------
#
# Usage:
#   append_missing_lines <file> <header_comment> <line>...
#
# For files the user owns and may have edited (e.g. the install's .gitignore).
# Each <line> is compared with the file's lines after stripping trailing
# whitespace / CR; only lines not already present are appended, at the end, in
# the order given, under one <header_comment> line. Nothing is rewritten,
# reordered or deleted; the file keeps its mode (plain >> append). Already
# complete → no-op, file untouched. Missing file → not created, nothing
# printed, return 1 (the caller checks for the file first and tells the user).
# A write error prints a warning and returns 1. Sets APPEND_MISSING_COUNT to
# the number of lines appended (0 when the file was already complete).
append_missing_lines() {
    local file="$1" header="$2"; shift 2
    local missing=() l
    APPEND_MISSING_COUNT=0
    if [ ! -f "$file" ]; then
        return 1
    fi
    for l in "$@"; do
        if ! awk -v want="$l" '{ sub(/[ \t\r]+$/, "") } $0 == want { found = 1; exit } END { exit !found }' "$file"; then
            missing+=("$l")
        fi
    done
    [ "${#missing[@]}" -eq 0 ] && return 0
    {
        # make sure we start on a fresh line
        if [ -s "$file" ] && [ -n "$(tail -c 1 "$file")" ]; then printf '\n'; fi
        printf '\n%s\n' "$header"
        printf '%s\n' "${missing[@]}"
    } >> "$file" 2>/dev/null || { print_warn "Could not append to $file — left as is"; return 1; }
    APPEND_MISSING_COUNT=${#missing[@]}
    print_success "$(basename "$file"): appended ${#missing[@]} missing line(s): $file"
    return 0
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
    local tmp; tmp="$(mktemp_beside "$path")"
    printf '%s\n' "$ver" > "$tmp"
    mv "$tmp" "$path"
}
