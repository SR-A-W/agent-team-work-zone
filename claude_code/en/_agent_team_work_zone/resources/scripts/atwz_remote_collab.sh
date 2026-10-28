#!/usr/bin/env bash
#
# atwz_remote_collab.sh — git operations for /remote-collab: two teams on two machines working through
# the same remote repository.
#
# Usage (from any directory; the script changes to the project root, the directory that contains
# _agent_team_work_zone/):
#   atwz_remote_collab.sh check  --config <team dir>/remote_collab.json --seen <watcher workstation>/remote_seen
#                                [--journal <watcher workstation>/working-context.md]
#                                [--loop-job <watcher workstation>/loop_job] [--respawn-after <rounds, default 12>]
#   atwz_remote_collab.sh pull   --config <team dir>/remote_collab.json
#   atwz_remote_collab.sh push   --config <team dir>/remote_collab.json [--message <commit message>] [--dry-run]
#   atwz_remote_collab.sh status --config <team dir>/remote_collab.json
#   atwz_remote_collab.sh watch  --config <team dir>/remote_collab.json [--interval <10m | 90s | 1h | seconds>]
#                                [--max-hours <hours, default 24>]
#   atwz_remote_collab.sh watch-stop --config <team dir>/remote_collab.json
#
# check  Fetches only; never touches the working tree, the index or the current branch. Lists the
#        meeting_room documents in the new remote commits that are addressed to this team, status changes
#        of this team's documents, and the number of other changed files. The watcher runs it on each check.
#        --journal: on every check, write one line "<UTC> remote-collab check: <result>" to that file; when its
#        last line is already such a line, replace it, so the file does not grow. The file is never created.
#        --loop-job: add 1 to the rounds= line of that file on every check (failed checks count too) and
#        print rounds=<n>; when n reaches --respawn-after, or reaches half of it (rounded up) in a check that
#        has doc lines, also print respawn_due rounds=<n>. A missing file
#        is created with an empty job_id=, the current created_at= / created_epoch= and rounds=1; the other
#        lines of an existing file are kept as they are.
# pull   Fetches and merges: fast-forward when possible; when both sides have new commits, `git merge
#        --no-edit` (the one exception to rule 10, used only here). On a conflict, `git merge --abort` and
#        list the conflicting files; when uncommitted local changes block the merge, list those files and
#        change nothing. Never stashes, never resolves conflicts.
# push   Commits only this team's team files, by explicit path, merges the remote the same way as pull,
#        then pushes; if the push is rejected, tries once more. --dry-run only lists the files it would
#        commit and the commits it would push, and changes nothing.
# status Shows the configuration, the watcher's last check time and result, the age of its scheduled task,
#        the last pull / push results, and how many commits are not pushed or not merged. Takes no lock.
#        Also shows the watch mode, and in the background-script mode whether a watch is running.
# watch  For the background-script mode: runs its own check (with <team dir>/.remote_seen) every interval
#        (default: script_interval in the configuration, else 3000 seconds (50 minutes); at least 60 seconds), and exits
#        only when there is something to report: any output other than "no updates" is printed as it is
#        (exit 0); 3 failed checks in a row print the failed lines and watch_failed (exit 1); after
#        --max-hours it prints watch_expired (exit 0). Takes no lock itself (each check does). Keeps the pid
#        file <team dir>/.remote_collab_watch.pid; if another watch is already running, prints
#        watch_already_running pid=<n> (exit 6). On TERM / INT / HUP it prints watch_stopped (exit 143).
# watch-stop  Sends TERM to the watch in the pid file, only after checking that the process really is this
#        script's watch; waits up to 5 seconds. Prints watch_stopped_by_request pid=<n>, watch_not_running,
#        or watch_stop_failed pid=<n> (exit 5).
#
# check / pull / push run inside the atwz_git_lock.sh lock. That lock only keeps agents on this machine
# from running git at the same time; it cannot stop another machine. Between machines, git merging does.
#
# Output: one item per line, starting with a fixed English keyword, for the skill and the watcher to parse:
#   no updates | updates <start>..<new> commits=<n> | doc | <type> | <from> -> <to> | <status> | <path>
#   mine_status | <path> | <old> -> <new> | changes | partner_team_files=<n> | other_files=<n>
#   same_team_name | <team dir> | partner_teams | <dirs…> | nothing to merge | merged <before>..<after> <how>
#   conflict | <files…> | blocked_by_local_changes | <files…> | commit | <files…> | nothing to push
#   pushed <n> | failed: <reason> | rounds=<n> | respawn_due rounds=<n> | journal_failed: <path> | loop_job_failed: <path>
#   watch_expired | watch_failed | watch_already_running pid=<n> | watch_stopped
#   watch_stopped_by_request pid=<n> | watch_not_running | watch_stop_failed pid=<n>
#   watch_mode | teammate | watch_mode | script interval=<i> | watch | running pid=<n> since=<UTC>
#   watch | not running | watch | stale pid file | job_age_hours=<n | unknown> rounds=<n> (status only)
# Exit codes: 0 success (including no updates); 1 watch: 3 failed checks in a row; 2 usage error; 3 conflict;
# 4 blocked by local changes; 5 other failure; 6 a watch is already running; 75 timed out waiting for the
# lock; 143 watch ended by a signal. check always exits 0 except on a usage error.
#
# Reads only the names in the configuration, never credentials. Needs git and jq. Portable: bash 3.2
# (macOS) and Linux.

set -u

usage() {
    echo "usage: atwz_remote_collab.sh check|pull|push|status|watch|watch-stop --config <remote_collab.json> [--seen <file>] [--journal <file>] [--loop-job <file>] [--respawn-after <rounds>] [--message <text>] [--dry-run] [--interval <i>] [--max-hours <hours>]" >&2
    exit 2
}

cmd="${1:-}"
case "$cmd" in check|pull|push|status|watch|watch-stop) ;; *) usage ;; esac
shift
config=""; seen=""; journal=""; loop_job=""; respawn_after=12; message=""; dry=no; interval=""; max_hours=24
while [ $# -gt 0 ]; do
    case "$1" in
        --config) [ $# -ge 2 ] || usage; config="$2"; shift 2 ;;
        --seen) [ $# -ge 2 ] || usage; seen="$2"; shift 2 ;;
        --journal) [ $# -ge 2 ] || usage; journal="$2"; shift 2 ;;
        --loop-job) [ $# -ge 2 ] || usage; loop_job="$2"; shift 2 ;;
        --respawn-after) [ $# -ge 2 ] || usage; respawn_after="$2"; shift 2 ;;
        --message) [ $# -ge 2 ] || usage; message="$2"; shift 2 ;;
        --dry-run) dry=yes; shift ;;
        --interval) [ $# -ge 2 ] || usage; interval="$2"; shift 2 ;;
        --max-hours) [ $# -ge 2 ] || usage; max_hours="$2"; shift 2 ;;
        *) usage ;;
    esac
done

fail() { echo "failed: $*"; exit 5; }
# Make a path absolute when its directory exists (the file itself may be missing)
abs_path() { if [ -d "$(dirname "$1")" ]; then printf '%s/%s' "$(cd "$(dirname "$1")" && pwd -P)" "$(basename "$1")"; else printf '%s' "$1"; fi; }

script_dir=$(cd "$(dirname "$0")" && pwd -P)
proj_root=$(cd "$script_dir/../../.." && pwd -P)
lock="$script_dir/atwz_git_lock.sh"
zone="_agent_team_work_zone"

command -v git >/dev/null 2>&1 || fail "git is not installed"
command -v jq >/dev/null 2>&1 || fail "jq is not installed"
[ -n "$config" ] && [ -f "$config" ] || fail "config not found: $config"
config="$(cd "$(dirname "$config")" && pwd -P)/$(basename "$config")"
team_dir=$(dirname "$config")
[ "$cmd" != check ] || [ -n "$seen" ] || fail "check needs --seen <file>"
if [ -n "$seen" ]; then
    mkdir -p "$(dirname "$seen")" 2>/dev/null
    seen="$(cd "$(dirname "$seen")" && pwd -P)/$(basename "$seen")" || fail "cannot use --seen $seen"
fi
printf '%s' "$respawn_after" | grep -Eq '^[0-9]+$' || usage
printf '%s' "$max_hours" | grep -Eq '^[0-9]+([.][0-9]+)?$' || usage
[ -z "$journal" ] || journal=$(abs_path "$journal")
[ -z "$loop_job" ] || loop_job=$(abs_path "$loop_job")
self_script="$script_dir/$(basename "$0")"
cd "$proj_root" || fail "cannot enter project root $proj_root"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "not inside a git work tree"

# When not yet inside the lock, run this script again while holding it (paths made absolute)
if { [ "$cmd" = check ] || [ "$cmd" = pull ] || [ "$cmd" = push ]; } && [ -z "${ATWZ_RC_LOCKED:-}" ]; then
    inner=("$cmd" --config "$config")
    [ -n "$seen" ] && inner+=(--seen "$seen")
    [ -n "$journal" ] && inner+=(--journal "$journal")
    [ -n "$loop_job" ] && inner+=(--loop-job "$loop_job")
    inner+=(--respawn-after "$respawn_after")
    [ -n "$message" ] && inner+=(--message "$message")
    [ "$dry" = yes ] && inner+=(--dry-run)
    ATWZ_RC_LOCKED=1 bash "$lock" run --label "remote-collab $cmd" -- bash "$self_script" "${inner[@]}"
    rc=$?
    [ "$rc" -eq 75 ] && echo "failed: timed out waiting for the local git lock"
    exit "$rc"
fi

remote=$(jq -r '.remote // empty' "$config" 2>/dev/null)
branch=$(jq -r '.branch // empty' "$config" 2>/dev/null)
self_team=$(jq -r '.self_team // empty' "$config" 2>/dev/null)
partner_team=$(jq -r '.partner_team // empty' "$config" 2>/dev/null)
watcher=$(jq -r '.watcher // empty' "$config" 2>/dev/null)
[ -n "$remote" ] && [ -n "$branch" ] && [ -n "$self_team" ] || fail "config lacks remote, branch or self_team"
rref="refs/remotes/$remote/$branch"
prefix=$(git rev-parse --show-prefix 2>/dev/null)
state="$team_dir/.remote_collab_state"
team_rel="$zone/$self_team"
ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# This team's names: <team dir>, <team dir>/lead, <team dir>/<teammate>, and lead_name from the registry
ours="$self_team
$self_team/lead"
if [ -f "$team_dir/TEAMMATE_INFO.json" ]; then
    ours="$ours
$(jq -r --arg t "$self_team" '.active_teammates[]?.name | "\($t)/\(.)"' "$team_dir/TEAMMATE_INFO.json" 2>/dev/null)
$(jq -r '.lead_name // empty' "$team_dir/TEAMMATE_INFO.json" 2>/dev/null)"
fi
is_ours() { [ -n "$1" ] && printf '%s\n' "$ours" | grep -Fxq -- "$1"; }

# Value of one frontmatter field (the file content is on standard input)
fm_get() {
    awk -v k="$1" 'NR == 1 { if ($0 != "---") exit; next }
        $0 == "---" { exit }
        index($0, k ":") == 1 { v = substr($0, length(k) + 2); gsub(/^[ \t]+|[ \t\r]+$/, "", v); print v; exit }'
}
# Does the value name this team or ALL (a single name or an [a, b] list)
names_hit() {
    printf '%s\n' "$1" | tr '[]' '  ' | tr ',' '\n' | sed -e "s/^[[:space:]\"']*//" -e "s/[[:space:]\"']*\$//" |
    { while IFS= read -r t; do
          [ -n "$t" ] || continue
          [ "$t" = ALL ] && exit 0
          is_ours "$t" && exit 0
      done
      exit 1; }
}
doc_type() {
    if [ -n "$2" ]; then printf '%s' "$2"; return; fi
    t=$(basename "$1" | sed -nE 's/.*_(PROJECT_STATUS|TASK|ERR|DONE|STATUS|REPORT|REVIEW|HANDOFF|RFC|DESIGN|PLAN|DRAFT)_.*/\1/p')
    printf '%s' "${t:-DOC}"
}

# List meeting_room documents changed between <start>..<end>; $3 = version to compare status with (HEAD for check, the pre-merge commit for pull)
list_docs() {
    start="$1"; end="$2"; base="$3"
    git -c core.quotePath=false diff --relative --name-status -M "$start" "$end" -- "$zone/meeting_room/" 2>/dev/null |
    while IFS="$(printf '\t')" read -r st p1 p2; do
        case "$st" in A|M) p="$p1" ;; R*) p="$p2" ;; *) continue ;; esac
        case "$p" in */README.md) continue ;; esac
        if [ "$base" = HEAD ] && [ "$(git rev-parse -q --verify "$end:./$p" 2>/dev/null)" = "$(git rev-parse -q --verify "HEAD:./$p" 2>/dev/null)" ]; then
            continue  # this machine already has the same content (for example, it pushed it)
        fi
        content=$(git show "$end:./$p" 2>/dev/null) || continue
        from=$(printf '%s\n' "$content" | fm_get from)
        to=$(printf '%s\n' "$content" | fm_get to)
        cc=$(printf '%s\n' "$content" | fm_get cc)
        status=$(printf '%s\n' "$content" | fm_get status)
        kind=$(printf '%s\n' "$content" | fm_get kind)
        if names_hit "$from" && [ "$from" != ALL ]; then
            old=$(git show "$base:./$p" 2>/dev/null | fm_get status)
            [ -n "$old" ] && [ "$old" != "$status" ] && echo "mine_status | $p | $old -> $status"
        elif names_hit "$to" || names_hit "$cc"; then
            echo "doc | $(doc_type "$p" "$kind") | $from -> $to | $status | $p"
        fi
    done
}

write_state() {  # $1 = pull|push  $2 = result
    tmp="$state.tmp.$$"
    { [ -f "$state" ] && grep -v "^last_$1_" "$state"; printf 'last_%s_at=%s\nlast_%s_result=%s\n' "$1" "$(ts)" "$1" "$2"; } > "$tmp" && mv "$tmp" "$state" || rm -f "$tmp"
}

# Age in seconds of the scheduled task recorded in loop_job file $1 (created_epoch= line); empty when unknown
job_age_s() {
    ce=$(sed -n 's/^created_epoch=\([0-9][0-9]*\)$/\1/p' "$1" 2>/dev/null | head -n 1)
    [ -n "$ce" ] || return 0
    age=$(( $(date +%s) - ce ))
    [ "$age" -ge 0 ] || age=0
    printf '%s' "$age"
}

# End of every check: the journal line and the task age (both only when asked for)
check_tail() {  # $1 = result for the journal line
    if [ -n "$journal" ]; then
        if [ -f "$journal" ]; then
            jt="$journal.tmp.$$"
            line="$(ts) remote-collab check: $1"
            last=$(tail -n 1 "$journal")
            if cp -p "$journal" "$jt" 2>/dev/null && case "$last" in
                    *" remote-collab check: "*) { sed '$d' "$journal"; printf '%s\n' "$line"; } > "$jt" ;;
                    *) { cat "$journal"; [ -z "$(tail -c 1 "$journal")" ] || echo; printf '%s\n' "$line"; } > "$jt" ;;
                esac && mv "$jt" "$journal"; then :; else rm -f "$jt"; echo "journal_failed: $journal"; fi
        else
            echo "journal_failed: $journal"
        fi
    fi
    if [ -n "$loop_job" ]; then
        lt="$loop_job.tmp.$$"
        if [ -f "$loop_job" ]; then
            r=$(sed -n 's/^rounds=\([0-9][0-9]*\)$/\1/p' "$loop_job" 2>/dev/null | head -n 1)
            r=$(( ${r:-0} + 1 ))
            { grep -v '^rounds=' "$loop_job"; echo "rounds=$r"; } > "$lt"
        else
            r=1
            printf 'job_id=\ncreated_at=%s\ncreated_epoch=%s\nrounds=1\n' "$(ts)" "$(date +%s)" > "$lt"
        fi
        if [ -s "$lt" ] && mv "$lt" "$loop_job"; then
            echo "rounds=$r"
            # Respawn at the threshold, or already at half of it when this round brings documents (a digest
            # is about to add 8,000-15,000 tokens)
            if [ "$r" -ge "$respawn_after" ] || { [ "$has_doc" = yes ] && [ "$r" -ge $(( (respawn_after + 1) / 2 )) ]; }; then
                echo "respawn_due rounds=$r"
            fi
        else
            rm -f "$lt"; echo "loop_job_failed: $loop_job"
        fi
    fi
    return 0
}

# Background-script mode: the pid file, and whether a pid is this script's watch
pidf="$team_dir/.remote_collab_watch.pid"
pid_in_file() { sed -n 's/^pid=\([0-9][0-9]*\)$/\1/p' "$pidf" 2>/dev/null | head -n 1; }
pid_is_watch() {
    [ -n "$1" ] && kill -0 "$1" 2>/dev/null || return 1
    ps -p "$1" -o command= 2>/dev/null | grep -Eq 'atwz_remote_collab\.sh watch( |$)'
}
# 10m / 90s / 1h / plain seconds -> seconds; fails on anything else
to_secs() {
    n="${1%[smh]}"
    case "$n" in ''|*[!0-9]*) return 1 ;; esac
    case "$1" in *h) echo $((n * 3600)) ;; *m) echo $((n * 60)) ;; *) echo "$n" ;; esac
}

do_fetch() {
    err=$(git fetch --quiet "$remote" "$branch" 2>&1) || { echo "failed: fetch $(printf '%s' "$err" | head -n 1)"; return 5; }
    git rev-parse -q --verify "$rref" >/dev/null 2>&1 || { echo "failed: no remote-tracking branch $remote/$branch"; return 5; }
    return 0
}

# Merge $1 into the current branch; sets how
do_merge() {
    out=$(git merge --ff-only --quiet "$1" 2>&1) && { how=fast-forward; return 0; }
    case "$out" in *"would be overwritten"*)
        echo "blocked_by_local_changes | $(printf '%s\n' "$out" | awk '/^\t/ { sub(/^\t/, ""); printf "%s ", $0 }')"
        return 4 ;;
    esac
    out=$(git merge --no-edit --quiet "$1" 2>&1) && { how=merge; return 0; }
    case "$out" in *"would be overwritten"*)
        echo "blocked_by_local_changes | $(printf '%s\n' "$out" | awk '/^\t/ { sub(/^\t/, ""); printf "%s ", $0 }')"
        return 4 ;;
    esac
    conflicts=$(git -c core.quotePath=false diff --name-only --diff-filter=U 2>/dev/null | tr '\n' ' ')
    if [ -n "$conflicts" ] || git rev-parse -q --verify MERGE_HEAD >/dev/null 2>&1; then
        git merge --abort >/dev/null 2>&1
        echo "conflict | $conflicts"
        return 3
    fi
    echo "failed: merge $(printf '%s' "$out" | head -n 1)"
    return 5
}

case "$cmd" in
check)
    prev=""; [ -f "$seen" ] && prev=$(head -n 1 "$seen"); has_doc=no
    record() { mkdir -p "$(dirname "$seen")" && printf '%s\nchecked_at=%s result=%s\n' "$1" "$(ts)" "$2" > "$seen"; }
    if ! out=$(do_fetch); then record "$prev" failed; echo "$out"; check_tail "$out"; exit 0; fi
    new=$(git rev-parse "$rref")
    mb=$(git merge-base HEAD "$new" 2>/dev/null) || { record "$prev" failed; echo "failed: no common history with $remote/$branch"; check_tail "failed: no common history with $remote/$branch"; exit 0; }
    n=$(git rev-list --count "HEAD..$new")
    if [ "$new" = "$prev" ] || [ "$n" -eq 0 ]; then record "$new" "no updates"; echo "no updates"; check_tail "no updates"; exit 0; fi
    start="$mb"
    if [ -n "$prev" ] && git merge-base --is-ancestor "$prev" "$new" 2>/dev/null && git merge-base --is-ancestor "$mb" "$prev" 2>/dev/null; then
        start="$prev"
    fi
    echo "updates $(printf '%s' "$start" | cut -c1-7)..$(printf '%s' "$new" | cut -c1-7) commits=$n"
    docs=$(list_docs "$start" "$new" HEAD)
    [ -n "$docs" ] && printf '%s\n' "$docs"
    printf '%s\n' "$docs" | grep -q '^doc | ' && has_doc=yes
    files=$(git diff --name-only "$mb" "$new" 2>/dev/null)
    pf=0
    [ -n "$partner_team" ] && pf=$(printf '%s\n' "$files" | grep -c "^$prefix$zone/$partner_team/")
    of=$(printf '%s\n' "$files" | grep -v '^$' | grep -v "^$prefix$zone/meeting_room/" | grep -v "^$prefix$zone/archive/" \
         | grep -v "^$prefix$team_rel/" | { if [ -n "$partner_team" ]; then grep -v "^$prefix$zone/$partner_team/"; else cat; fi; } | grep -c .)
    echo "changes | partner_team_files=$pf | other_files=$of"
    printf '%s\n' "$files" | grep -q "^$prefix$team_rel/" && echo "same_team_name | $self_team"
    if [ -z "$partner_team" ]; then
        cand=$(git ls-tree -d --name-only "$new" -- "$zone/" 2>/dev/null | sed "s|^$zone/||" | grep '_team$' | grep -vx "$self_team" | tr '\n' ' ')
        [ -n "$cand" ] && echo "partner_teams | $cand"
    fi
    record "$new" updates
    check_tail "updates $(printf '%s' "$start" | cut -c1-7)..$(printf '%s' "$new" | cut -c1-7)"
    exit 0
    ;;
pull)
    before=$(git rev-parse HEAD)
    do_fetch || { write_state pull failed; exit 5; }
    new=$(git rev-parse "$rref")
    if git merge-base --is-ancestor "$new" HEAD; then write_state pull "nothing to merge"; echo "nothing to merge"; exit 0; fi
    do_merge "$remote/$branch"; rc=$?
    if [ "$rc" -ne 0 ]; then write_state pull "failed ($rc)"; exit "$rc"; fi
    after=$(git rev-parse HEAD)
    echo "merged $(printf '%s' "$before" | cut -c1-7)..$(printf '%s' "$after" | cut -c1-7) $how"
    list_docs "$before" "$after" "$before"
    write_state pull "merged $how"
    exit 0
    ;;
push)
    # This team's team files: changes under the team directory; meeting_room / archive files sent by or to this team
    collect() {
        { git -c core.quotePath=false ls-files -m -d -o --exclude-standard -- "$zone/meeting_room" "$zone/archive" "$team_rel"
          git -c core.quotePath=false diff --cached --name-only --no-renames --relative -- "$zone/meeting_room" "$zone/archive" "$team_rel"
        } 2>/dev/null | sort -u | while IFS= read -r p; do
            [ -n "$p" ] || continue
            case "$p" in "$team_rel"/*) echo "$p"; continue ;; esac
            case "$p" in */README.md) continue ;; esac
            if [ -f "$p" ]; then c=$(cat "$p"); else c=$(git show "HEAD:./$p" 2>/dev/null); fi
            from=$(printf '%s\n' "$c" | fm_get from); to=$(printf '%s\n' "$c" | fm_get to); cc=$(printf '%s\n' "$c" | fm_get cc)
            if { names_hit "$from" && [ "$from" != ALL ]; } || names_hit "$to" || names_hit "$cc"; then echo "$p"; fi
        done
    }
    paths=$(collect)
    if [ "$dry" = yes ]; then
        [ -n "$paths" ] && printf '%s\n' "$paths" | sed 's/^/would_commit | /'
        git rev-parse -q --verify "$rref" >/dev/null 2>&1 && git log --oneline "$rref..HEAD" 2>/dev/null | sed 's/^/would_push | /'
        echo "dry run: nothing changed"
        exit 0
    fi
    if [ -n "$paths" ]; then
        pa=(); while IFS= read -r p; do [ -n "$p" ] && pa+=("$p"); done <<EOF
$paths
EOF
        add=()
        for p in "${pa[@]}"; do
            if [ -e "$p" ] || git ls-files --error-unmatch -- "$p" >/dev/null 2>&1; then add+=("$p"); fi
        done
        if [ "${#add[@]}" -gt 0 ]; then
            err=$(git add -A -- "${add[@]}" 2>&1) || fail "git add: $(printf '%s' "$err" | tail -n 3 | tr '\n' ' ')"
        fi
        if ! git diff --cached --quiet -- "${pa[@]}"; then
            err=$(git commit --quiet -m "${message:-remote-collab: $self_team team files}" -- "${pa[@]}" 2>&1) \
                || fail "commit: $(printf '%s' "$err" | tail -n 3 | tr '\n' ' ')"
            echo "commit | $(printf '%s ' "${pa[@]}")"
        fi
    fi
    tries=0
    while :; do
        do_fetch || { write_state push failed; exit 5; }
        new=$(git rev-parse "$rref")
        if ! git merge-base --is-ancestor "$new" HEAD; then
            do_merge "$remote/$branch"; rc=$?
            if [ "$rc" -ne 0 ]; then write_state push "failed ($rc)"; exit "$rc"; fi
            echo "merged $(printf '%s' "$new" | cut -c1-7) $how"
        fi
        ahead=$(git rev-list --count "$new..HEAD")
        if [ "$ahead" -eq 0 ]; then write_state push "nothing to push"; echo "nothing to push"; exit 0; fi
        if perr=$(git push --quiet "$remote" "HEAD:$branch" 2>&1); then
            write_state push "pushed $ahead"; echo "pushed $ahead"; exit 0
        fi
        tries=$((tries + 1))
        [ "$tries" -le 1 ] || { write_state push "failed"; fail "push: $(printf '%s' "$perr" | tail -n 3 | tr '\n' ' ')"; }
    done
    ;;
watch)
    [ -n "$interval" ] || interval=$(jq -r '.script_interval // empty' "$config" 2>/dev/null)
    [ -n "$interval" ] || interval=3000
    secs=$(to_secs "$interval") || usage
    [ "$secs" -ge 60 ] || usage
    old=$(pid_in_file)
    if [ -n "$old" ] && [ "$old" != "$$" ] && pid_is_watch "$old"; then
        echo "watch_already_running pid=$old"
        exit 6
    fi
    pt="$pidf.tmp.$$"
    printf 'pid=%s\nstarted_at=%s\n' "$$" "$(ts)" > "$pt" && mv "$pt" "$pidf" || { rm -f "$pt"; fail "cannot write $pidf"; }
    child=""
    drop_pid() { [ "$(pid_in_file)" = "$$" ] && rm -f "$pidf"; return 0; }
    on_signal() { [ -n "$child" ] && kill "$child" 2>/dev/null; drop_pid; trap - EXIT; echo "watch_stopped"; exit 143; }
    trap on_signal TERM INT HUP
    trap drop_pid EXIT
    started=$(date +%s); fails=0; flines=""
    while :; do
        if awk -v e="$(( $(date +%s) - started ))" -v h="$max_hours" 'BEGIN { exit !(e >= h * 3600) }'; then
            echo "watch_expired"
            exit 0
        fi
        out=$(bash "$self_script" check --config "$config" --seen "$team_dir/.remote_seen")
        [ -n "$out" ] || out="failed: check printed nothing"
        if [ "$out" = "no updates" ]; then
            fails=0; flines=""
        elif printf '%s\n' "$out" | grep -v '^$' | grep -qv '^failed: '; then
            printf '%s\n' "$out"
            exit 0
        else
            fails=$((fails + 1)); flines="$flines$out
"
            if [ "$fails" -ge 3 ]; then printf '%s' "$flines"; echo "watch_failed"; exit 1; fi
        fi
        sleep "$secs" &
        child=$!
        wait "$child"
        child=""
    done
    ;;
watch-stop)
    p=$(pid_in_file)
    if [ -z "$p" ] || ! pid_is_watch "$p"; then
        rm -f "$pidf"
        echo "watch_not_running"
        exit 0
    fi
    kill -TERM "$p" 2>/dev/null
    i=0
    while [ "$i" -lt 5 ] && kill -0 "$p" 2>/dev/null; do sleep 1; i=$((i + 1)); done
    if kill -0 "$p" 2>/dev/null; then echo "watch_stop_failed pid=$p"; exit 5; fi
    echo "watch_stopped_by_request pid=$p"
    exit 0
    ;;
status)
    echo "config | remote=$remote branch=$branch self_team=$self_team partner_team=${partner_team:-unknown} watcher=${watcher:-none} interval=$(jq -r '.interval // "-"' "$config") push_permission=$(jq -r '.push_permission // "-"' "$config") stopped_at=$(jq -r '.stopped_at // "-"' "$config")"
    wmode=$(jq -r '.watch_mode // "teammate"' "$config" 2>/dev/null)
    if [ "$wmode" = script ]; then
        echo "watch_mode | script interval=$(jq -r '.script_interval // "50m"' "$config" 2>/dev/null)"
        p=$(pid_in_file)
        if [ -z "$p" ] && [ ! -f "$pidf" ]; then echo "watch | not running"
        elif pid_is_watch "$p"; then echo "watch | running pid=$p since=$(sed -n 's/^started_at=//p' "$pidf")"
        else echo "watch | stale pid file"; fi
    else
        echo "watch_mode | teammate"
    fi
    if [ "$wmode" = script ] && [ -f "$team_dir/.remote_seen" ]; then
        echo "last_check | $(sed -n 2p "$team_dir/.remote_seen")"
    elif [ "$wmode" != script ] && [ -n "$watcher" ] && [ -f "$team_dir/teammates/$watcher/remote_seen" ]; then
        echo "last_check | $(sed -n 2p "$team_dir/teammates/$watcher/remote_seen")"
    else
        echo "last_check | never"
    fi
    if [ -n "$watcher" ] && [ -f "$team_dir/teammates/$watcher/loop_job" ]; then
        age=$(job_age_s "$team_dir/teammates/$watcher/loop_job")
        r=$(sed -n 's/^rounds=\([0-9][0-9]*\)$/\1/p' "$team_dir/teammates/$watcher/loop_job" | head -n 1)
        if [ -n "$age" ]; then a="$((age / 3600))"; else a=unknown; fi
        echo "job_age_hours=$a rounds=${r:-0}"
    fi
    [ -f "$state" ] && sed 's/^/state | /' "$state"
    if git rev-parse -q --verify "$rref" >/dev/null 2>&1; then
        echo "outgoing | $(git rev-list --count "$rref..HEAD") commits not pushed (as of the last fetch)"
        echo "incoming | $(git rev-list --count "HEAD..$rref") commits not merged (as of the last fetch)"
    fi
    exit 0
    ;;
esac
