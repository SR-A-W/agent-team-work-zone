#!/usr/bin/env bash
#
# atwz_checkpoint_git.sh — optional git save of a teammate's workstation after /checkpoint.
#
# Usage:
#   atwz_checkpoint_git.sh save    <ws>                       # last action of /checkpoint
#   atwz_checkpoint_git.sh enable  [snapshot|commit] [--zone <abs path>]
#   atwz_checkpoint_git.sh disable [--zone <abs path>]
#   atwz_checkpoint_git.sh status  [--zone <abs path>]
#   atwz_checkpoint_git.sh list    <ws>
#   atwz_checkpoint_git.sh restore <ws> [<file>…] [--from <rev>]
#
#   <ws> = ABSOLUTE workstation directory …/_agent_team_work_zone/<team>/teammates/<name>
#
# The setting lives in <zone>/settings.conf (`checkpoint_git = off | snapshot | commit`).
# A missing file or key means off. The file is parsed with sed, never sourced.
#
#   off       nothing runs, not even detection; no output.
#   snapshot  the workstation's files are written to the private ref
#             refs/atwz/checkpoints/<team>/<name> through a temporary index. HEAD, the
#             branch and the shared index are untouched, so no lock is needed.
#   commit    the workstation's files are committed on the current branch with a pathspec
#             commit, inside the project-wide git lock (atwz_git_lock.sh).
#
# Detection runs on every save: not inside a git work tree / working-context.md ignored /
# no files → one "skipped: <reason>" line. save, enable, disable and status always exit 0;
# list and restore exit non-zero only on a usage error. The framework never pushes
# refs/atwz/*: a normal `git push` sends only branches.
#
# Portable: bash 3.2 (macOS) and Linux; no GNU-only flags.

set -u

SELF="$0"
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd -P)
P="checkpoint git:"

say() { echo "$P $*"; }

usage() {
    echo "usage: atwz_checkpoint_git.sh save <ws> | enable [snapshot|commit] [--zone <dir>] | disable [--zone <dir>] | status [--zone <dir>] | list <ws> | restore <ws> [file…] [--from <rev>]" >&2
    exit 2
}

# ---- settings.conf ----
read_mode() { # read_mode <conf>  → off | snapshot | commit
    local v=""
    if [ -f "$1" ]; then
        v=$(sed -n 's/#.*//; s/^[[:space:]]*checkpoint_git[[:space:]]*=[[:space:]]*\([A-Za-z]*\).*/\1/p' "$1" | tail -n 1)
    fi
    case "$v" in snapshot|commit) echo "$v" ;; *) echo off ;; esac
}

write_mode() { # write_mode <conf> <mode>  — keeps other lines and comments
    local conf="$1" mode="$2" tmp
    if [ ! -f "$conf" ]; then
        printf '%s\n%s\n' \
            "# Agent Team Work Zone — project settings (written by atwz_checkpoint_git.sh enable/disable; safe to edit by hand)" \
            "checkpoint_git = $mode        # off | snapshot | commit" > "$conf"
        return
    fi
    tmp=$(mktemp "$conf.XXXXXX") || return 1
    # keep the file mode: seed the temp file with a copy of the original, then overwrite its content
    cp -p "$conf" "$tmp" || { rm -f "$tmp"; return 1; }
    if grep -q '^[[:space:]]*checkpoint_git[[:space:]]*=' "$conf"; then
        sed "s/^\([[:space:]]*checkpoint_git[[:space:]]*=[[:space:]]*\)[A-Za-z]*/\1$mode/" "$conf" > "$tmp"
    else
        cat "$conf" > "$tmp"
        echo "checkpoint_git = $mode        # off | snapshot | commit" >> "$tmp"
    fi
    mv "$tmp" "$conf" || { rm -f "$tmp"; return 1; }
}

# ---- workstation path → zone/team/name/ref ----
parse_ws() { # sets WS ZONE TEAM NAME REF CONF MODE; returns 1 (after printing) if unusable
    WS="${1:-}"
    case "$WS" in
        /*) ;;
        *) say "skipped: workstation path must be absolute"; return 1 ;;
    esac
    WS="${WS%/}"
    case "$WS" in
        */_agent_team_work_zone/*/teammates/*) ;;
        *) say "skipped: not a teammate workstation path"; return 1 ;;
    esac
    if [ ! -d "$WS" ]; then say "skipped: workstation directory not found: $WS"; return 1; fi
    ZONE=$(cd "$WS/../../.." && pwd -P)
    TEAM=$(basename "$(cd "$WS/../.." && pwd -P)")
    NAME=$(basename "$WS")
    REF="refs/atwz/checkpoints/$TEAM/$NAME"
    CONF="$ZONE/settings.conf"
    MODE=$(read_mode "$CONF")
    return 0
}

first_line() { printf '%s\n' "$1" | sed -n '/./{p;q;}'; }

# ---- which files to save (prints "skipped" and returns 1 when nothing to do) ----
FILES=()
collect_files() {
    local f out
    FILES=()
    if [ "$(git -C "$WS" rev-parse --is-inside-work-tree 2>/dev/null)" != true ]; then
        say "skipped: not inside a git work tree"; return 1
    fi
    if git -C "$WS" check-ignore -q -- working-context.md 2>/dev/null; then
        out=$(git -C "$WS" check-ignore -v -- working-context.md 2>/dev/null | head -n 1)
        say "skipped: working-context.md is ignored by git ($out)"; return 1
    fi
    while IFS= read -r -d '' f; do
        f="${f#./}"
        case "$(basename "$f")" in .started|.checkpoint_nudge_count|*.before-restore.*) continue ;; esac
        git -C "$WS" check-ignore -q -- "$f" 2>/dev/null && continue
        FILES[${#FILES[@]}]="$f"
    done < <(cd "$WS" && find . -name .git -prune -o -type f -print0)
    if [ ${#FILES[@]} -eq 0 ]; then say "skipped: no files to save"; return 1; fi
    return 0
}

# ---- save: snapshot ----
TMPIDX=""
save_snapshot() {
    local tmpidx err tree parent commit short ts zero
    tmpidx=$(mktemp "${TMPDIR:-/tmp}/atwz_idx.XXXXXX") || { say "skipped: mktemp failed"; return; }
    TMPIDX="$tmpidx"; trap 'rm -f "${TMPIDX:-}"' EXIT
    rm -f "$tmpidx"     # git wants a non-existent or a valid index file
    # -f: the list is already filtered by check-ignore; a TRACKED file that matches an ignore
    # rule is not ignored by git, but is "untracked" for this fresh index, so plain add refuses it.
    if ! err=$(GIT_INDEX_FILE="$tmpidx" git -C "$WS" add -f -- "${FILES[@]}" 2>&1); then
        say "skipped: git add failed: $(first_line "$err")"; return
    fi
    if ! tree=$(GIT_INDEX_FILE="$tmpidx" git -C "$WS" write-tree 2>&1); then
        say "skipped: git write-tree failed: $(first_line "$tree")"; return
    fi
    parent=$(git -C "$WS" rev-parse -q --verify "$REF^{commit}" 2>/dev/null)
    if [ -n "$parent" ] && [ "$(git -C "$WS" rev-parse "$parent^{tree}")" = "$tree" ]; then
        say "skipped: unchanged since last snapshot $(git -C "$WS" rev-parse --short "$parent")"; return
    fi
    ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    if [ -z "$(git -C "$WS" config user.name)" ] || [ -z "$(git -C "$WS" config user.email)" ]; then
        export GIT_AUTHOR_NAME=atwz-checkpoint GIT_AUTHOR_EMAIL=atwz-checkpoint@localhost
        export GIT_COMMITTER_NAME=atwz-checkpoint GIT_COMMITTER_EMAIL=atwz-checkpoint@localhost
    fi
    if [ -n "$parent" ]; then
        commit=$(git -C "$WS" commit-tree --no-gpg-sign "$tree" -p "$parent" -m "atwz checkpoint snapshot: $TEAM/$NAME $ts" 2>&1)
    else
        commit=$(git -C "$WS" commit-tree --no-gpg-sign "$tree" -m "atwz checkpoint snapshot: $TEAM/$NAME $ts" 2>&1)
    fi
    if [ $? -ne 0 ]; then say "skipped: git commit-tree failed: $(first_line "$commit")"; return; fi
    if [ -n "$parent" ]; then
        err=$(git -C "$WS" update-ref -m "atwz checkpoint" "$REF" "$commit" "$parent" 2>&1)
    else
        # first snapshot: the all-zero old value makes the create a compare-and-swap too
        zero=$(git -C "$WS" hash-object --stdin </dev/null | tr '0-9a-f' '0')
        err=$(git -C "$WS" update-ref -m "atwz checkpoint" "$REF" "$commit" "$zero" 2>&1)
    fi
    if [ $? -ne 0 ]; then say "skipped: git update-ref failed: $(first_line "$err")"; return; fi
    short=$(git -C "$WS" rev-parse --short "$commit")
    say "saved snapshot $short to $REF (${#FILES[@]} files)"
}

# ---- save: commit (runs inside the lock via the internal _commit subcommand) ----
commit_locked() {
    local gd f err untracked=() deleted=() short branch extra=""
    gd=$(git -C "$WS" rev-parse --git-dir 2>/dev/null)
    case "$gd" in /*) ;; *) gd="$WS/$gd" ;; esac
    if git -C "$WS" rev-parse -q --verify MERGE_HEAD >/dev/null 2>&1 \
       || git -C "$WS" rev-parse -q --verify REBASE_HEAD >/dev/null 2>&1 \
       || git -C "$WS" rev-parse -q --verify CHERRY_PICK_HEAD >/dev/null 2>&1 \
       || [ -d "$gd/rebase-merge" ] || [ -d "$gd/rebase-apply" ]; then
        say "skipped: repository is mid-merge/rebase"; return
    fi
    for f in "${FILES[@]}"; do
        git -C "$WS" ls-files --error-unmatch -- "$f" >/dev/null 2>&1 || untracked[${#untracked[@]}]="$f"
    done
    # tracked files that no longer exist under the workstation: the pathspec commit records their removal
    while IFS= read -r -d '' f; do
        [ -e "$WS/$f" ] || deleted[${#deleted[@]}]="$f"
    done < <(git -C "$WS" ls-files -z -- .)
    if [ ${#deleted[@]} -gt 0 ]; then
        FILES=("${FILES[@]}" "${deleted[@]}"); extra=", ${#deleted[@]} removed"
    fi
    if [ ${#untracked[@]} -eq 0 ] && git -C "$WS" rev-parse -q --verify HEAD >/dev/null 2>&1 \
       && git -C "$WS" diff --quiet HEAD -- "${FILES[@]}" 2>/dev/null; then
        say "skipped: nothing to commit"; return
    fi
    if [ ${#untracked[@]} -gt 0 ]; then
        if ! err=$(git -C "$WS" add -- "${untracked[@]}" 2>&1); then
            say "skipped: git add failed: $(first_line "$err")"; return
        fi
    fi
    if ! err=$(git -C "$WS" commit -q -m "atwz checkpoint: $TEAM/$NAME" -- "${FILES[@]}" 2>&1); then
        # leave the shared index as we found it: unstage the untracked files we just added
        [ ${#untracked[@]} -gt 0 ] && git -C "$WS" rm -q --cached -- "${untracked[@]}" >/dev/null 2>&1
        err=$(first_line "$err"); [ -n "$err" ] || err="(no message — a commit hook may have refused it)"
        say "skipped: git commit failed: $err"; return
    fi
    short=$(git -C "$WS" rev-parse --short HEAD)
    branch=$(git -C "$WS" symbolic-ref -q --short HEAD 2>/dev/null || echo "detached HEAD")
    say "committed $short on $branch ($((${#FILES[@]} - ${#deleted[@]})) files$extra)"
}

save_commit() {
    local out rc
    out=$(cd "$WS" && bash "$SCRIPT_DIR/atwz_git_lock.sh" run --label "checkpoint $TEAM/$NAME" -- bash "$SELF" _commit "$WS" 2>&1)
    rc=$?
    if [ $rc -eq 75 ]; then
        say "skipped: git lock busy ($(printf '%s\n' "$out" | sed -n 's/.*held by //p' | tail -n 1))"
    elif [ -n "$out" ]; then
        printf '%s\n' "$out" | grep "^$P" | tail -n 1
    else
        say "skipped: git lock failed (exit $rc)"
    fi
}

cmd_save() {
    parse_ws "${1:-}" || exit 0
    [ "$MODE" = off ] && exit 0
    collect_files || exit 0
    case "$MODE" in
        snapshot) save_snapshot ;;
        commit) save_commit ;;
    esac
    exit 0
}

cmd_commit_internal() {
    parse_ws "${1:-}" || exit 0
    collect_files || exit 0
    commit_locked
    exit 0
}

# ---- enable / disable / status ----
zone_arg() { # zone_arg [--zone <dir>] → ZONE
    ZONE=$(cd "$SCRIPT_DIR/../.." && pwd -P)
    if [ "${1:-}" = "--zone" ]; then
        [ -n "${2:-}" ] || usage
        ZONE=$(cd "$2" 2>/dev/null && pwd -P) || { say "zone directory not found: $2"; exit 0; }
    fi
    CONF="$ZONE/settings.conf"
}

detect_zone() { # prints the one-line verdict for $ZONE; $1 = prefix for the line
    local v top ws wtop note=""
    if [ "$(git -C "$ZONE" rev-parse --is-inside-work-tree 2>/dev/null)" != true ]; then
        say "$1, but it will have no effect here: _agent_team_work_zone/ is not inside a git work tree"; return
    fi
    if git -C "$ZONE" check-ignore -q -- "$ZONE/README.md" 2>/dev/null; then
        v=$(git -C "$ZONE" check-ignore -v -- "$ZONE/README.md" 2>/dev/null | head -n 1)
        say "$1, but it will have no effect here: _agent_team_work_zone/ is ignored by git ($v)"; return
    fi
    say "$2"
    top=$(git -C "$ZONE" rev-parse --show-toplevel 2>/dev/null)
    for ws in "$ZONE"/*/teammates/*/; do
        [ -d "$ws" ] || continue
        wtop=$(git -C "$ws" rev-parse --show-toplevel 2>/dev/null)
        [ -n "$wtop" ] && [ "$wtop" != "$top" ] && note=1
    done
    [ -n "$note" ] && echo "note: checked at the work-zone level; each checkpoint re-checks its own workstation"
    return 0
}

cmd_enable() {
    local mode=snapshot
    case "${1:-}" in snapshot|commit) mode="$1"; shift ;; esac
    zone_arg "$@"
    write_mode "$CONF" "$mode" || { say "could not write $CONF"; exit 0; }
    detect_zone "enabled ($mode)" "enabled ($mode); every /checkpoint will now save the teammate's workstation files"
    exit 0
}

cmd_disable() {
    zone_arg "$@"
    write_mode "$CONF" off || { say "could not write $CONF"; exit 0; }
    say "disabled"
    exit 0
}

cmd_status() {
    zone_arg "$@"
    local mode; mode=$(read_mode "$CONF")
    if [ "$mode" = off ]; then
        say "off ($CONF)"
    else
        detect_zone "$mode" "$mode; every /checkpoint saves the teammate's workstation files"
    fi
    exit 0
}

# ---- list / restore ----
cmd_list() {
    [ $# -eq 1 ] || usage
    parse_ws "$1" || exit 1
    [ "$(git -C "$WS" rev-parse --is-inside-work-tree 2>/dev/null)" = true ] || { say "not inside a git work tree"; exit 0; }
    if [ "$MODE" = commit ]; then
        git -C "$WS" log --format='%h %ci %s' -- .
    elif git -C "$WS" rev-parse -q --verify "$REF" >/dev/null 2>&1; then
        git -C "$WS" log --format='%h %ci %s' "$REF"
    else
        say "no snapshots yet ($REF)"
    fi
    exit 0
}

cmd_restore() {
    local ws="${1:-}" rev="" files=() prefix f path cur tmp ts
    [ -n "$ws" ] || usage
    shift
    while [ $# -gt 0 ]; do
        case "$1" in
            --from) [ -n "${2:-}" ] || usage; rev="$2"; shift 2 ;;
            *) files[${#files[@]}]="$1"; shift ;;
        esac
    done
    parse_ws "$ws" || exit 1
    [ "$(git -C "$WS" rev-parse --is-inside-work-tree 2>/dev/null)" = true ] || { say "not inside a git work tree"; exit 0; }
    if [ -z "$rev" ]; then
        if [ "$MODE" = commit ]; then rev=HEAD; else rev="$REF"; fi
    fi
    git -C "$WS" rev-parse -q --verify "$rev^{commit}" >/dev/null 2>&1 || { say "no such revision: $rev"; exit 0; }
    prefix=$(git -C "$WS" rev-parse --show-prefix)     # repo-relative path of the workstation, with trailing /
    if [ ${#files[@]} -eq 0 ]; then
        while IFS= read -r path; do
            files[${#files[@]}]="${path#"$prefix"}"
        done < <(git -C "$WS" ls-tree -r --name-only --full-name "$rev" -- .)
        [ ${#files[@]} -gt 0 ] || { say "nothing under this workstation in $rev"; exit 0; }
    fi
    ts=$(date -u +%Y%m%dT%H%M%SZ)
    for f in "${files[@]}"; do
        path="$prefix$f"
        tmp=$(mktemp "${TMPDIR:-/tmp}/atwz_restore.XXXXXX") || exit 0
        if ! git -C "$WS" show "$rev:$path" > "$tmp" 2>/dev/null; then
            rm -f "$tmp"; echo "not in $rev: $f"; continue
        fi
        cur="$WS/$f"
        if [ -f "$cur" ] && cmp -s "$tmp" "$cur"; then
            rm -f "$tmp"; echo "unchanged $f"; continue
        fi
        if [ -f "$cur" ]; then
            cp -p "$cur" "$cur.before-restore.$ts"
            cat "$tmp" > "$cur"; rm -f "$tmp"
            echo "restored $f from $rev (previous kept as $f.before-restore.$ts)"
        else
            mkdir -p "$(dirname "$cur")"
            cat "$tmp" > "$cur"; rm -f "$tmp"
            echo "restored $f from $rev"
        fi
    done
    exit 0
}

case "${1:-}" in
    save) shift; cmd_save "$@" ;;
    _commit) shift; cmd_commit_internal "$@" ;;
    enable) shift; cmd_enable "$@" ;;
    disable) shift; cmd_disable "$@" ;;
    status) shift; cmd_status "$@" ;;
    list) shift; cmd_list "$@" ;;
    restore) shift; cmd_restore "$@" ;;
    *) usage ;;
esac
