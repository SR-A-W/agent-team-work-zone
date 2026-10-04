#!/usr/bin/env bash
#
# atwz_git_lock.sh —— 持有项目级 git 锁运行一条 git 命令。
#
# 用法：
#   atwz_git_lock.sh run [--label <说明>] -- <命令…>
#
# 所有 agent 共用一个 git checkout（同一个工作目录、同一个 index）。两次提交、合并或拉取
# 同时发生，可能把对方的文件带进自己的提交，或把它们回退。这个包装脚本让项目里所有 agent
# 的这类命令排队执行：
#
#   1. 只要 <git-dir>/index.lock 存在（别的 git 操作正在进行）就等；
#   2. 用原子的 `mkdir <git-common-dir>/atwz-git.lock/` 取锁；
#   3. 运行命令、释放锁，返回命令的退出码。
#
# 整个等待只有一个 180 秒的预算，每 10 秒重试一次。超时则往 stderr 输出一行并以 75 退出。
# 只有同时满足以下条件，锁才视为失效并被删除：超过 600 秒、在本机取得、其 pid 已不存在；
# 别的主机持有的锁绝不打破。本脚本从不删除 .git/index.lock。
#
# 锁目录放在 git 目录里，所以不会出现在 `git status` 中，并且仓库的所有 worktree 共用它。
#
# 可移植：bash 3.2（macOS）与 Linux；不用 GNU 专有参数。

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
field() { # field <字段名> <owner 行>
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
            # 用原子的改名来打破：只有一个等待者能把目录移走；再确认移走的正是刚才判定失效的那把锁。
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
