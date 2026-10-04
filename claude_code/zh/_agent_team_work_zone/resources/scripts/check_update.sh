#!/usr/bin/env bash
#
# check_update.sh — tell the user when a newer agent-team-work-zone release exists.
#
# Run by the SessionStart hook (settings_hooks_template.json). Read-only: it only
# prints a notice; it never upgrades anything. It must never slow down or break
# session start, so:
#   - it compares the installed VERSION with a cached "latest version" (instant);
#   - the cache (_agent_team_work_zone/.upgrade/update_check) is refreshed at most
#     once every 24 hours, in a fully detached background process — the session
#     does not wait for it;
#   - every failure (no network, no curl, unexpected reply, unwritable cache) is
#     silent, and the script always exits 0.
# The latest version comes from the npm registry:
#   https://registry.npmjs.org/agent-team-work-zone/latest  ("version" field)
#
# Usage:
#   check_update.sh                  hook mode (above)
#   check_update.sh --now            refresh the cache now (3 s timeout), then check
#   check_update.sh --refresh-cache  internal: the background refresh
#
# Turn it off: environment variable ATWZ_UPDATE_CHECK=0, or create the file
# _agent_team_work_zone/.no_update_check (commit it to turn it off for everyone).
#
# Deliberately no `set -e`.

LATEST_URL="https://registry.npmjs.org/agent-team-work-zone/latest"
CHECK_INTERVAL=86400   # seconds between registry lookups

SCRIPT_PATH="$0"
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)" || exit 0
FW="$(cd "$SCRIPT_DIR/../.." 2>/dev/null && pwd)" || exit 0    # resources/scripts → _agent_team_work_zone
CACHE_DIR="$FW/.upgrade"
CACHE_FILE="$CACHE_DIR/update_check"

[ "${ATWZ_UPDATE_CHECK:-1}" = "0" ] && exit 0
[ -e "$FW/.no_update_check" ] && exit 0
[ -f "$FW/VERSION" ] || exit 0
LOCAL="$(tr -d '[:space:]' < "$FW/VERSION" 2>/dev/null)"
[ -n "$LOCAL" ] || exit 0

now() { date +%s 2>/dev/null || echo 0; }

# "1.2.3" / "v1.2.3" → "1 2 3"; anything else → empty
nums() {
    local v="${1#v}"; v="${v%%[-+]*}"
    case "$v" in
        *[!0-9.]*|.*|*.|*..*) return 0 ;;
    esac
    local a b c
    IFS=. read -r a b c <<< "$v"
    [ -n "$a" ] && [ -n "$b" ] && [ -n "$c" ] || return 0
    echo "$a $b $c"
}
# is_newer <latest> <local>: true when latest > local (major.minor.patch, numeric)
is_newer() {
    local l c
    l="$(nums "$1")"; c="$(nums "$2")"
    [ -n "$l" ] && [ -n "$c" ] || return 1
    set -- $l $c
    [ "$1" -gt "$4" ] && return 0; [ "$1" -lt "$4" ] && return 1
    [ "$2" -gt "$5" ] && return 0; [ "$2" -lt "$5" ] && return 1
    [ "$3" -gt "$6" ]
}

fetch_latest() {
    command -v curl >/dev/null 2>&1 || return 0
    curl -fsS --max-time 3 "$LATEST_URL" 2>/dev/null \
        | grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' | head -n 1 \
        | sed 's/.*"\([^"]*\)"$/\1/'
}

save_cache() {   # $1 = latest version (may be empty: "looked, nothing usable")
    mkdir -p "$CACHE_DIR" 2>/dev/null || return 0
    local t="$CACHE_FILE.$$"
    { { now; printf '%s\n' "$1"; } > "$t"; } 2>/dev/null && mv -f "$t" "$CACHE_FILE" 2>/dev/null
    rm -f "$t" 2>/dev/null
    return 0
}

refresh_cache() {   # keep the previous value if the lookup fails
    local prev="$1" got
    got="$(fetch_latest)"
    if [ -n "$(nums "$got")" ]; then save_cache "$got"; else save_cache "$prev"; fi
}

AT=0; LATEST=""
if [ -f "$CACHE_FILE" ]; then
    { { read -r AT; read -r LATEST; } < "$CACHE_FILE"; } 2>/dev/null
fi
case "$AT" in ''|*[!0-9]*) AT=0 ;; esac

case "${1:-}" in
    --refresh-cache)
        # One lookup at a time: a lock directory; one older than a minute is stale.
        LOCK="$CACHE_DIR/update_check.lock"
        if [ -d "$LOCK" ] && [ -n "$(find "$LOCK" -maxdepth 0 -mmin +1 2>/dev/null)" ]; then
            rmdir "$LOCK" 2>/dev/null
        fi
        mkdir "$LOCK" 2>/dev/null || exit 0
        refresh_cache "$LATEST"
        rmdir "$LOCK" 2>/dev/null
        exit 0 ;;
    --now)
        refresh_cache "$LATEST"
        { { read -r AT; read -r LATEST; } < "$CACHE_FILE"; } 2>/dev/null ;;
    *)
        if [ $(( $(now) - AT )) -ge "$CHECK_INTERVAL" ]; then
            # Stamp the attempt first (keeps the old value), so sessions starting at the
            # same time don't all go to the network; then look it up in the background,
            # fully detached (no inherited file descriptors, own session if possible).
            save_cache "$LATEST"
            if command -v setsid >/dev/null 2>&1; then
                setsid bash "$SCRIPT_PATH" --refresh-cache </dev/null >/dev/null 2>&1 &
            else
                nohup bash "$SCRIPT_PATH" --refresh-cache </dev/null >/dev/null 2>&1 &
            fi
        fi ;;
esac

[ -n "$LATEST" ] || exit 0
is_newer "$LATEST" "$LOCAL" || exit 0

cat <<EOF
[agent-team-work-zone] 有新版本 ${LATEST#v}（当前安装：$LOCAL）。
  升级：npx agent-team-work-zone@latest upgrade
       （全局安装的：npm i -g agent-team-work-zone@latest，然后 atwz upgrade；
        源码安装的：bash _agent_team_work_zone/upgrade.sh）
  升级后请重启 Claude Code 会话，并对正在运行的团队执行 /reactivate-team。
  不想再看到这条提示：设置 ATWZ_UPDATE_CHECK=0，或创建文件 _agent_team_work_zone/.no_update_check
EOF
exit 0
