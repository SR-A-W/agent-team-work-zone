#!/usr/bin/env bash
#
# atwz_git_lock.sh — run one git command while holding the project-wide git lock.
#
# Usage:
#   atwz_git_lock.sh run [--label <text>] -- <command…>
#
# All agents share one git checkout (one working tree, one index). Two commits, merges or
# pulls at the same moment can sweep each other's files or revert them. This wrapper
# serialises such commands across every agent of the project:
#
#   1. wait while <git-dir>/index.lock exists (another git operation is running);
#   2. take the lock with an atomic `mkdir <git-common-dir>/atwz-git.lock/`;
#   3. run the command, release the lock, return the command's exit code.
#
# The whole wait has ONE budget of 180 s, retrying every 10 s. On timeout it prints one
# line to stderr and exits 75. A lock is treated as stale (and removed) only if it is
# older than 600 s AND was taken on this host AND its pid is no longer alive; a lock
# held by another host is never broken. This script never deletes .git/index.lock.
#
# The lock directory lives inside the git directory, so it adds nothing to `git status`
# and is shared by all worktrees of the repository.
#
# Portable: bash 3.2 (macOS) and Linux; no GNU-only flags.

set -u

BUDGET_SEC=180
RETRY_SEC=10
STALE_SEC=600

usage() {
    echo "usage: atwz_git_lock.sh run [--label <text>] -- <command…>" >&2
    exit 2
}

[ "${1:-}" = "run" ] || usage
shift
label=""
while [ $# -gt 0 ]; do
    case "$1" in
        --label) [ $# -ge 2 ] || usage; label="$2"; shift 2 ;;
        --) shift; break ;;
        *) usage ;;
    esac
done
[ $# -gt 0 ] || usage

git_dir=$(git rev-parse --git-dir 2>/dev/null) || { echo "atwz-git-lock: not inside a git repository" >&2; exit 2; }
common_dir=$(git rev-parse --git-common-dir 2>/dev/null) || common_dir="$git_dir"
git_dir=$(cd "$git_dir" && pwd -P)
common_dir=$(cd "$common_dir" && pwd -P)
lockdir="$common_dir/atwz-git.lock"
host=$(uname -n)
start=$(date +%s)

owner_of() { cat "$lockdir/owner" 2>/dev/null || echo "(owner unknown)"; }
field() { # field <name> <owner line>
    printf '%s\n' "$2" | tr ' ' '\n' | sed -n "s/^$1=//p" | head -n 1
}

while :; do
    now=$(date +%s)
    if [ ! -e "$git_dir/index.lock" ] && mkdir "$lockdir" 2>/dev/null; then
        trap 'rm -rf "$lockdir"' EXIT
        trap 'exit 130' INT
        trap 'exit 143' TERM
        printf 'pid=%s host=%s started=%s label=%s\n' "$$" "$host" "$now" "$label" > "$lockdir/owner"
        "$@"
        exit $?
    fi

    if [ -d "$lockdir" ]; then
        owner=$(owner_of)
        o_pid=$(field pid "$owner"); o_host=$(field host "$owner"); o_started=$(field started "$owner")
        case "$o_started" in (''|*[!0-9]*) o_started=$now ;; esac
        if [ $((now - o_started)) -gt "$STALE_SEC" ] && [ "$o_host" = "$host" ] \
           && [ -n "$o_pid" ] && ! kill -0 "$o_pid" 2>/dev/null; then
            # Break it by an atomic rename: only one waiter can move the directory away; then check
            # that what we moved is the lock we judged stale.
            moved="$lockdir.stale.$$"
            if mv "$lockdir" "$moved" 2>/dev/null; then
                if [ "$(cat "$moved/owner" 2>/dev/null)" = "$owner" ]; then
                    rm -rf "$moved"
                    echo "atwz-git-lock: removed stale lock held by $owner" >&2
                elif [ ! -e "$lockdir" ]; then
                    mv "$moved" "$lockdir" 2>/dev/null || rm -rf "$moved"
                else
                    rm -rf "$moved"
                fi
            fi
            continue
        fi
    fi

    if [ $((now - start + RETRY_SEC)) -gt "$BUDGET_SEC" ]; then
        if [ -d "$lockdir" ]; then held="held by $(owner_of)"; else held="waiting for $git_dir/index.lock"; fi
        echo "atwz-git-lock: timed out after $BUDGET_SEC s; $held" >&2
        exit 75
    fi
    sleep "$RETRY_SEC"
done
