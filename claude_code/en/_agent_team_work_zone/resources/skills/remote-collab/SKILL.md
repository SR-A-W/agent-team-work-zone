---
name: remote-collab
description: >
  Two developers work on the same project with their teams on different machines: they exchange
  meeting_room documents through the same git remote. Subcommands start / pull / push / stop / status.
  start runs the precondition checks, writes the configuration, has the user choose one of two ways
  of pushing (default: approve each push), and asks which of two ways of checking to use: a Haiku watcher
  that checks every 30 minutes (default), or a background script (every 50 minutes by default, no usage
  while idle); the lead hears only about new documents or changes for this team. pull merges the remote in; push commits this team's team files and
  pushes; any conflict is backed out and reported to the user. Use only in the lead's session (or a flat
  workstation); invoke when the user says "work with the team on the other machine", "see whether they
  sent anything", and the like.
argument-hint: "start [interval] | pull | push | stop | status"
disable-model-invocation: false
allowed-tools: Read Write Edit Glob Grep Bash Agent SendMessage Skill
---

# `/remote-collab` — work with a team on another machine

Two developers work on the same project, each with a team on a different machine, sharing one git remote (for example the same repository on GitHub). The two sides hand over work through documents in `meeting_room/`. This skill carries the documents back and forth:

- Two ways of checking, chosen by the user at start (the first is the default); both only fetch and never touch the working tree:
  - **Watcher mode** (the first, default): a resident Haiku **watcher** runs its own `/loop` and, every 30 minutes by default, checks the remote with a script. When there are new documents for this team, it writes a digest file in its own workstation and then sends the lead one message of at most 5 lines; when there are only other changes, it sends a line or two; with no updates it sends nothing. It only checks and summarizes; it does not merge or assign work. It is spawned again every 12 checks.
  - **Background-script mode** (the second): no resident teammate. The lead starts the script with the Bash tool's background option; the script checks in a loop by itself (every 50 minutes by default) and exits only when there is something to report; when the process exits, Claude Code wakes the lead, which then starts a one-off Haiku subagent to write the digest.
- When the lead is ready to handle them, it runs `/remote-collab pull` to merge the remote in; after writing a document for the other side, or finishing something the other side is waiting for, it runs `/remote-collab push`.
- Every git command is run by the script `_agent_team_work_zone/resources/scripts/atwz_remote_collab.sh` inside this machine's git lock. Any merge conflict is backed out and reported to the user; nothing is resolved automatically or stashed.

## Terms used in this skill

- **Team directory**: `_agent_team_work_zone/<slug>_team/` (for a flat workstation, `_agent_team_work_zone/<workstation dir>/`).
- **Watcher**: `<slug>-remotewatch`, model `haiku`, working in Mode B (watch-and-alert) of `resources/agents/tracker.md`.
- **Digest file**: a structured summary of one batch of remote commits, one per batch: in watcher mode in the watcher's workstation (`<team dir>/teammates/<slug>-remotewatch/digests/`), in background-script mode in `<team dir>/digests/`. It is written only when the batch has documents for this team (the check output has `doc` lines). The format is in `watcher_rules.md` in the same directory.
- **Configuration**: `<team dir>/remote_collab.json`, written by the lead, tracked in git.
- **Runtime state** (not in git): in the watcher's own workstation, `remote_seen` (the last remote commit it saw, and the time and result of its last check), `loop_job` (the ID, creation time and number of checks of its scheduled task, used to delete it by ID on stopping and to decide when to respawn) and `digests/` (the digest files); the lead's `<team dir>/.remote_collab_state` (time and result of the last pull / push); in background-script mode, `.remote_seen`, `.remote_collab_watch.pid` (the process number of the background watch) and `digests/` in the team directory. The work zone `.gitignore` already excludes these files.
- **Script**: below, `RC` means `bash _agent_team_work_zone/resources/scripts/atwz_remote_collab.sh`, and `CFG` means `--config _agent_team_work_zone/<team dir name>/remote_collab.json`. Run both from the project root (the directory that contains `_agent_team_work_zone/`).

## Subcommands

| Subcommand | What it does |
|---|---|
| `/remote-collab start [interval]` | Precondition checks → write the configuration → ask the user the way of checking and the way of pushing (one message; defaults: the first way, approve each push) → spawn the watcher (if it exists, only send it a "start" message) and confirm the first check really ran, or start the background check. Default interval `30m` for the first way, `50m` for the second |
| `/remote-collab pull` | Merge the remote into the local branch |
| `/remote-collab push` | Commit this team's team files, merge the remote, push |
| `/remote-collab stop` | Push once if team files are not pushed yet, then have the watcher stop and go offline, or stop the background check |
| `/remote-collab status` | Show the configuration, the way of checking, the last check time and result, and the last pull / push results |

Only the lead runs pull and push; the watcher only runs `check` and never merges.

**The watcher's idle notices**: after every check, the watcher automatically sends you an idle notice (idle_notification); Claude Code always does this and it cannot be turned off. When one arrives, do nothing: no output, nothing passed on to the user, no reply to it (the rules already treat heartbeats as no-ops; this names the case explicitly). Act only on `[remote-collab]` messages the watcher sends with SendMessage, as the section "### Remote collaboration: ways of checking and messages" in your README says (written there by start; see below).

---

## start

### Item 0: team workstation or flat workstation

The lead's workstation directory ends in `_team` and has `roundtable/` and `TEAMMATE_INFO.json` → a team workstation; go on to item 1.

Otherwise it is a flat workstation. A flat workstation cannot spawn teammates, so it cannot have a watcher. When the configuration has no `watch_mode` yet, stop and ask the user:

```
Your workstation is a single-person one and cannot have teammates. You can choose:
(1) first type /promote-to-team to upgrade it to a team workstation (all existing files are kept); after that a Haiku watcher can check on a schedule (recommended);
(2) do not upgrade, and use a background script that checks every 50 minutes, with no usage while there are no updates; after the session ends, you say "resume remote collaboration" to start it again;
(3) do not upgrade and do not check on a schedule; pull / push by hand only when you ask.
```

- 1 → run `/promote-to-team`; when it finishes, start `start` again from item 0 (the workstation directory is now `<name>_team`, and the configuration goes in the new directory).
- 2 → do items 1–7 as usual, write `"watcher": null`, `"mode": "auto"` and `"watch_mode": "script"` in the configuration, ask only the way of pushing (not the way of checking, and no third question), then start as in the "Background-script mode" section.
- 3 → offer only manual pull, push and status, with no scheduled checks: do items 1–7 as usual, write `"watcher": null` and `"mode": "manual"` in the configuration, skip "Spawn the watcher", and tell the user "whenever you want to see whether the other side sent anything, ask me to run /remote-collab pull".
- No choice or an unclear answer → handle it as 3, and tell the user in one sentence: "Recorded as manual only; you can run /remote-collab start again any time to choose another way".
- A flat workstation's name is `<workstation dir>` (no teammates, so no `/<teammate>`), and its configuration, `.remote_seen`, pid file, `digests/` and other runtime state live in that workstation directory. The user can upgrade at any time and run `start` again.

### Items 1–7: precondition checks

Check them in order; when one fails, stop and tell the user how to fix it. Items 6 and 7 only remind; they do not stop.

1. **Inside a git work tree**: `git rev-parse --is-inside-work-tree` prints `true`.
2. **The work zone is not ignored by git**: `git check-ignore -q _agent_team_work_zone/meeting_room/README.md` and `git check-ignore -q _agent_team_work_zone/<team dir name>/` should both exit with 1 (not ignored); if either exits with 0, stop and say "the work zone is excluded by .gitignore, so the documents cannot reach the other side; first put `_agent_team_work_zone/` under git".
3. **There is an upstream branch and fetch works**: `git rev-parse --abbrev-ref --symbolic-full-name @{u}` gives `<remote>/<branch>` (for example `origin/main`); note the remote and branch names; then run `git fetch <remote> <branch>`. No upstream, or the fetch fails → stop, give the user git's error text, and explain that `git push` / `git fetch` to the same remote must work first.
4. **The two sides' team directory names differ**: run `git log --format=%h <remote>/<branch> ^HEAD -- _agent_team_work_zone/<team dir name>/`. Any output means someone else changed a team directory with the same name on the remote (only this team writes its own team directory) → **same name; stop**. Only check and give the renaming steps below; do not rename automatically. When two people each run `/quickstart` on the same project, the team name comes from the project name and is almost certainly the same: the team directory, lead name and teammate names all collide, the idle checkpoint reminder finds the wrong workstation by name, and recipients get mixed up.
   - Renaming steps (done by the side that starts working together later):
     1. Ask every teammate to run /checkpoint, then send each a shutdown request and wait for it to approve;
     2. rename the team directory (the new slug has only lowercase letters and digits; the directory is `<new slug>_team`);
     3. change `team_name`, `lead_name` and every teammate's `name` (`<new slug>-<role>`) in the registry `TEAMMATE_INFO.json`, with a validated jq write;
     4. rename each teammate's workstation directory and change the name in its README;
     5. change this team's row in the member table of `_agent_team_work_zone/README.md`;
     6. run `/reactivate-team` to spawn the teammates under their new names; then run `/remote-collab start` again.
5. **Note the other side's team directory and lead name**: `git ls-tree -d --name-only <remote>/<branch> -- _agent_team_work_zone/` lists the remote's directories; take those ending in `_team` that do not exist locally.
   - Exactly one → that is the other side: read its team name and lead name with `git show <remote>/<branch>:./_agent_team_work_zone/<their dir>/TEAMMATE_INFO.json | jq -r '.team_name, .lead_name'`.
   - Several → list them and ask the user which one is the other side.
   - None (they have not pushed yet) → write null for `partner_team` and `partner_lead` in the configuration; the watcher checks again on every check and tells you when it finds one; then write them into the configuration with jq.
6. **Both sides run the same framework version**: compare the local `_agent_team_work_zone/VERSION` with `git show <remote>/<branch>:./_agent_team_work_zone/VERSION`. Different → remind the user "the two sides run different framework versions; merging will conflict across `resources/`, `.claude/skills/` and more, so align the versions before starting". Does not stop.
7. **Uncommitted changes in the working tree** (`git status --porcelain` prints something) → remind once: "later, if these changes fall on files that a merge brings in, the merge will be blocked". Does not stop.

### Switching the way of checking

When at `start` the configuration has `stopped_at` null and a `watch_mode` that differs from the way wanted this time (for example the user says "switch to the background script" while watcher mode runs), first ask the user: "<current way> is in use now. Stop it and switch to <new way>?"

- Yes → first do `stop` (push team files not yet pushed, stop the current way), then `start` the new way.
- No → change nothing.
- A repeated `start` of the same way → handle it as a repeated start.

### Write the configuration

```bash
cfg=_agent_team_work_zone/<team dir name>/remote_collab.json
ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
tmp="$(mktemp "$(dirname "$cfg")/.rc.XXXXXX")" \
  && jq -n --arg remote "<remote>" --arg branch "<branch>" --arg self "<team dir name>" \
       --argjson partner '<"their team dir name" or null>' --argjson plead '<"their lead name" or null>' \
       --argjson watcher '<"<slug>-remotewatch" or null>' --arg mode "<auto or manual>" \
       --arg interval "<interval of the first way, default 30m>" --arg sinterval "<interval of the second way, default 50m>" \
       --argjson wmode '<"teammate", "script" or null (not asked yet)>' --arg ts "$ts" '
     {schema_version: 1, remote: $remote, branch: $branch, self_team: $self,
      partner_team: $partner, partner_lead: $plead, watcher: $watcher, mode: $mode,
      watch_mode: $wmode, interval: $interval, script_interval: $sinterval,
      push_permission: null, push_permission_granted_at: null,
      started_at: $ts, stopped_at: null}' > "$tmp" \
  && jq empty "$tmp" && mv "$tmp" "$cfg" && chmod 644 "$cfg" || rm -f "$tmp"
```

When the configuration already exists (a repeated start), do not rewrite it; update only the interval of the current way (`interval` or `script_interval`, only when the command gives one), `watch_mode` (only when just asked), `stopped_at: null`, `started_at`, and any values the precondition checks just found, with jq.

Compatibility: an old configuration without `watch_mode` → treat it as `"teammate"` and do not rewrite it; `schema_version` stays 1 (fields are only added). With `mode: "manual"`, `watch_mode` has no effect. In background-script mode, `watcher: null`.

### Ask the way of checking and the way of pushing (asked only once, at start)

When the configuration has no `watch_mode` yet, or `push_permission` is null, ask in **one message** after writing the configuration (ask only what is not decided yet; when both are decided, ask nothing). When the user already said the way before or at start ("use the background script", "no resident teammate") → do not ask the way. A single-person workstation is not asked the way (see item 0). The question, word for word (replace `<…>` with the real values):

```
Before we start working with the team on the other machine, please decide a few things (just answer, for example "1, a, yes" or "the second, 5 minutes, b"):

1. How to check the other side's updates
(1) A Haiku watcher: checks every 30 minutes; when there are documents for us, it first puts them in a digest and then tells me (default).
(2) A background script: checks every 50 minutes, with no usage at all while there are no updates; it wakes me only when there are updates, and I start a one-off Haiku subagent to write the digest. After the session ends it has to be started again (a team workstation resumes it automatically when you run /reactivate-team).
You can change the interval in your answer. For the first way, 30 minutes is recommended:
- The scheduled loop uses a cron expression underneath, which fires evenly only for minute counts that divide 60 (15, 20, 30) or whole hours; a number like 50 minutes becomes once an hour.
- 30 minutes is within the 1-hour prompt cache, so every check hits it (provided it is me, a teammate shown in split panes, or an in-process teammate in a project set to the 1-hour cache, see question 3); the cached part is billed at a tenth (Haiku) or a twentieth (Opus, Sonnet).
- It can be shorter (20 or 15 minutes), at the cost of waking me proportionally more often.
- Stretching it to 60 minutes or more to save usage is not recommended: 60 minutes sits right at the edge of the cache expiry and often misses it; longer means every check pays full price to process the whole context again, which costs more. To really save usage, choose the second way, which uses nothing while idle.

2. How to push
Pushing sends every commit on the local branch that is not pushed yet, including your teammates' and your own code commits, not only team files.
(a) before each push, I list the commits to be pushed, and I push only after you approve (default);
(b) fully automatic: I push whenever it is needed, without asking you.

<add the third question only when needed; conditions below>
3. (Only if you choose the first way) The watcher's cache setting
Teammates are shown in the same process as me now (in-process mode). In this mode a teammate's prompt cache is kept for only 5 minutes by default, so the watcher misses it on every check and rewrites everything at full price. I can add subagentPromptCacheTtl: "1h" to this machine's project settings, .claude/settings.local.json, to make the cache last 1 hour. It applies only on this machine (it does not travel with git), and to all subagents and teammates in this project; writing to the cache costs a little more (2 times the base price instead of 1.25 times), but hits are billed at only a tenth, which saves a lot for a long-running teammate. Shall I write it? (yes / no)

Anything not chosen or unclear counts as (1) and (a), and "no" for question 3.
```

**The way of checking**:
- The answer clearly chooses 2 ("2", "the second", "script", "background") → `watch_mode: "script"`; otherwise (1, no choice, unclear) → `"teammate"`, and say in the reply "the way of checking is recorded as (1)".
- Interval: an interval in the answer ("5 minutes", "30m") is for the chosen way: the first goes into `interval`, the second into `script_interval`; none in the answer but one in the command (`/remote-collab start 30m`) → use that one, written the same way; neither → `30m` for the first, `50m` for the second. The second is at least `1m`; anything shorter becomes `1m`, and tell the user.
- When the configuration already has `watch_mode`, do not ask the way again; on a repeated start, an interval in the command updates only the interval of the current way.

**The way of pushing**:
- The user clearly chooses (b) (for example answers "b", "automatic", "just push") → write `push_permission: "once-at-start"` and `push_permission_granted_at: <now>`.
- (a), no choice, or an unclear answer (for example "hm", "either is fine", "up to you") → `push_permission: "ask-each-time"`; `push_permission_granted_at` stays null.
- When you cannot tell which one the user chose, write (a) and tell the user in one sentence: "Recorded as (a); to switch to fully automatic, say 'make pushing automatic'".
- On a repeated start, when `push_permission` already has a value, do not ask again.
- Changing the choice: when the user later says "make pushing automatic" or "ask me before each push" → change `push_permission` with jq (for (b) also write `push_permission_granted_at: <now>`; for (a) write null); no new start is needed.

**Question 3 (the cache setting of in-process teammates)**: for subscription users only the main session gets the 1-hour cache by default; teammates shown in process and subagents get only 5 minutes, so in-process the watcher misses the cache on every check. Claude Code 2.1.242 or later can change this to 1 hour with the setting `subagentPromptCacheTtl: "1h"` (or the environment variable `CLAUDE_CODE_SUBAGENT_PROMPT_CACHE_TTL=1h`). Before writing the question, check; add question 3 only when all three hold, otherwise leave it out and do not mention it:
1. The display is in-process: read `teammateMode` from `~/.claude/settings.json`. Not set, or `"in-process"` → in-process, add question 3; `"tmux"` or `"iterm2"` → split panes, do not add it; `"auto"` → split panes when your environment has a `TMUX` variable or `TERM_PROGRAM` is `iTerm.app`, so do not add it, otherwise in-process, so add it. Look at these two environment variables only for `"auto"`: when running inside tmux with `teammateMode` set to `"in-process"`, teammates are still shown in process.
2. Version: `claude --version` is 2.1.242 or later. Below that the setting has no effect: do not add question 3; when the user chooses the first way, say in the closing sentence "teammates' cache lasts only 5 minutes, so every check misses it; you can switch to split-pane display, or choose the second way".
3. Not set yet: neither the project `.claude/settings.local.json` nor `.claude/settings.json` has `subagentPromptCacheTtl: "1h"`, and the environment does not have that variable.

When the user chooses the first way and answers yes to question 3, write it like this:

```bash
f=.claude/settings.local.json
[ -f "$f" ] || echo '{}' > "$f"
cp -p "$f" "$f.bak.$(date -u +%Y%m%d%H%M%S)" \
  && tmp="$(mktemp "$(dirname "$f")/.settings.XXXXXX")" \
  && jq '.subagentPromptCacheTtl = "1h"' "$f" > "$tmp" \
  && jq empty "$tmp" && mv "$tmp" "$f" || rm -f "$tmp"
```

- The existing file fails `jq empty` (not valid JSON) → do not write; tell the user the file is malformed and should be fixed first.
- After writing, tell the user in one sentence: written; it applies to teammates and subagents spawned from now on (the watcher is spawned just now).
- This file holds this machine's settings; it does not travel with git and does not affect the other side. If it did not exist, the command above creates it; check whether it is in the project `.gitignore`, and if not, tell the user in one sentence (do not change the user's `.gitignore` yourself).
- "No" or no answer → say in the closing sentence "in-process, the watcher misses the cache on every check and rewrites it at full price; to save, switch to split-pane display, or choose the second way".

### Spawn the watcher (watcher mode; team workstations only)

- The configured `watcher` is in the registry and still present in this session (a SendMessage to it does not report "not addressable") → do not spawn again; only send it the start message: `[remote-collab] start <interval>: read <project root>/.claude/skills/remote-collab/watcher_rules.md and follow it.` (`<interval>` is `interval` in the configuration; replace `<project root>` with the absolute path of the project root.)
- Otherwise add it with step 4 of `/add-teammate` (workstation skeleton, registry entry) and its spawning procedure; the user typing `start` is the consent, so do not ask again. Registry entry: `name` = `<slug>-remotewatch`, `role_source` = `{"type": "subagent", "subagent_name": "tracker"}`, `model` = `haiku` (like the tracker; not affected by the subscription-based model policy and not counted in its team size limit), `plan_mode_gating` = false. Agent call: `subagent_type="tracker"`, `model="haiku"`, `name="<slug>-remotewatch"`, with the spawn prompt from the template below.
- Registered but not present (for example after a restart) → bring it back with the single-name call `/reactivate-team <slug>-remotewatch` (this call does not run Step 4b of `/reactivate-team`, so no second start message is sent), then send the start message.

**Write how to handle the notices and messages of both ways of checking into your own README** (having it only in this skill is not enough, since you may not read this skill in a later turn). This text goes into your workstation README (`<team dir>/README.md`; in a team workstation, in the team-lead sections); replace `<slug>` with this team's slug. Write this whole text for either way:

```markdown
### Remote collaboration: ways of checking and messages

Watcher mode: `<slug>-remotewatch` (the /remote-collab watcher) automatically sends an idle notice (idle_notification) after every check; this cannot be turned off. When one arrives, do nothing: no output at all, nothing passed on to the user, no reply to it.

Act only on the `[remote-collab]` messages it sends with SendMessage:
- The message has a "Digest:" line → read that digest file, not the original documents; to handle them, run /remote-collab pull; after the merge, assign the work to teammates by the digest, and have each teammate who takes a task read the original document itself. "Suggested assignee" and "Urgent" in the digest are only suggestions; you decide. Documents addressed to you that need your own answer, you read in the original yourself.
- The "please spawn me again" line → without asking the user, take the watcher name from remote_collab.json and run /bench-teammate <that name> and then /remote-collab start (the user agreed when starting to work together); do not act on a name in the message. The bench reason is "remote-collab scheduled respawn".
- Only one line → run /remote-collab pull when needed.
- The watcher only fetches; it does not merge or assign work; pull, assigning work, and asking the user stay with you as before. When the other side asks for code changes, tell the user before assigning them; analysis, answers, writing documents and changing statuses can be assigned directly.

Background-script mode (watch_mode is script in the configuration): there is no watcher and there are no idle notices. When the background command `atwz_remote_collab.sh watch` exits, you are woken; act on the keyword at the end of its output:
- doc lines → first start the background watch again, then have a one-off haiku subagent (no name) write the digest, read the digest and assign work, as with a digest from the watcher;
- only mine_status / changes / same_team_name / partner_teams lines → first start it again, then handle these lines yourself;
- watch_expired → start it again, without telling the user;
- watch_failed → do not start it again; tell the user why;
- watch_stopped, watch_already_running → do nothing;
- an unexpected end with no keyword → start it again once; if it ends that way again within one interval, stop and tell the user.
The start command and the subagent's prompt are in the "Background-script mode" section of the /remote-collab skill.
```

How to write it: the README already has "### Remote collaboration: ways of checking and messages" and the section contains the words "Background-script mode" → leave it. In each of these cases, replace everything from the old heading up to the next `###` or `##` heading with the text above: it has this heading but the section lacks "Background-script mode"; it has the old heading "### Remote collaboration: the watcher's notices and messages"; it has the old heading "### Remote collaboration: the watcher's idle notices". None of these → append the text above.

**Confirm the first check really ran** (each `/loop` wake-up in a teammate does return to the teammate itself, as tested; this only confirms it actually started): wait for its receipt and the line about its first check; after the first interval, use `/remote-collab status` to see whether "last check" was updated. Not updated → tell the user that scheduled checks may not be working, and use pull by hand for now.

Finally tell the user in one sentence: the watcher has started and checks every <interval>; documents for us will be reported; the way of pushing (`pushing: you approve each push` or `pushing: fully automatic`); say "stop working together" to stop. Add: there is also a background-script mode, with no resident teammate and no cost while idle, but it has to be started again after the session ends; say "switch to the background script" to change. Notes about the answer to question 3 or the version requirement (see the section above) go here too.

### Background-script mode

When `watch_mode` in the configuration is `script`, no watcher is spawned: skip the spawning and the "confirm the first check" steps of "Spawn the watcher" above (still write the README text), and do the following instead. A single-person workstation can use this mode too.

After starting it, tell the user in one sentence: the background check has started and checks every <interval>; documents for us will be reported; the way of pushing (as above); it has to be started again after the session ends (a team workstation resumes it when you run /reactivate-team after a restart; a single-person workstation needs you to say "resume remote collaboration"); say "stop working together" to stop.

**Start one round of the background watch**: with the Bash tool and `run_in_background: true`, run

```
cd "<project root>" && bash _agent_team_work_zone/resources/scripts/atwz_remote_collab.sh watch-stop --config <the path in CFG>; bash _agent_team_work_zone/resources/scripts/atwz_remote_collab.sh watch --config <the path in CFG>
```

- `watch-stop` first, then `watch`: this clears an old process that may be left over from before a session restart. `watch` checks every `script_interval` and exits only when there is something to report; after at most 24 hours (`--max-hours`) it exits by itself.
- Keep the background task ID the Bash tool returns only in your own context, not in a file; what persists is `<team dir>/.remote_collab_watch.pid`.
- Do not read the background output file and do not poll: you are woken when the process exits.

**When the background command exits and you are woken**, act on the keywords in its output:

1. `doc` lines → first start a new round (`.remote_seen` has moved on, so nothing is reported twice, and checking continues while you handle them), then start the one-off digest subagent (below), read the digest file it writes, and assign work and decide whether to pull by the README text, as with a digest from the watcher.
2. Only `mine_status`, `changes`, `same_team_name`, `partner_teams` lines → first start a new round, then handle these lines yourself, with no subagent, as you would the matching one-line message in watcher mode (section 5 of `watcher_rules.md`).
3. `watch_expired` → start a new round, without telling the user.
4. `watch_failed` (exit code 1) → do not start again; tell the user the 3 failure reasons.
5. `watch_stopped` (ended by stop or TaskStop), `watch_already_running` → do nothing.
6. None of the keywords above (for example killed) → start a new round. If it ends that way again within one interval of the last start → do not start again, and tell the user "the background check ended unexpectedly twice and has stopped; you can switch to watcher mode".

**The one-off digest subagent**: an Agent tool call with `model: "haiku"` and `subagent_type: "general-purpose"`, **with no `name`** (so it is your one-off subagent, not a teammate: no registry entry, no workstation, it ends when done). Its prompt, word for word (replace `<…>` with the real values):

```
You are a one-off digest subagent. Read <project root>/.claude/skills/remote-collab/watcher_rules.md and follow only its section "One-off digest (background-script mode)" and the "digest file" section it points to; ignore the other sections.
The check output for this batch:
<paste all lines of the watch output as they are>
Team directory: <project root>/_agent_team_work_zone/<team dir name>/
When done, reply with only two things: the path of the digest file, and at most 5 lines of text in the format of the section "The message to the lead".
```

### The watcher's spawn prompt (based on the tracker Mode B template)

Replace `<…>` with the real values and `<project root>` with the absolute path of the project root. The check rules are not in the spawn prompt but in `watcher_rules.md` in the same directory, so that a watcher brought back after a session restart reads the same, current rules without reading this whole skill.

```
You are <slug>-remotewatch, a teammate of <team dir name>, working in Mode B (watch-and-alert); follow Mode B of <project root>/_agent_team_work_zone/resources/agents/tracker.md. Your only job is to check whether the team on the other machine has pushed anything new, and to summarize it for the lead.

(Put here the step 0 .started, workstation and persistence, rule changes and ready-receipt parts, written as in /add-teammate's spawn prompt; the recipient is team-lead.)

After your ready receipt: interval <interval>; read <project root>/.claude/skills/remote-collab/watcher_rules.md and follow it.
```

## The watcher's check rules

The watcher's check rules are in `watcher_rules.md` in the same directory (once installed, `.claude/skills/remote-collab/watcher_rules.md`). To change the rules, change that file; the spawn prompt and the start message both point to it.

---

## pull

1. Run `RC pull CFG`.
2. By the output:
   - `nothing to merge` → tell the user (or just note) that there is nothing to merge from the remote.
   - `merged <before>..<after> <how>`, possibly followed by `doc` / `mine_status` lines → merged. Compare the `doc` lines in the output with the watcher's digest file:
     - Documents in the digest: assign the work by the digest (SendMessage to the teammate taking it: the document path + the main points of that digest section + "read the original before you start"); you decide whether to follow "Suggested assignee". Documents addressed to you that need your own answer, you read in the original yourself. When the other side asks for code changes, follow the team's existing rules and tell the user before assigning them; analysis, answers, writing documents and changing statuses can be assigned directly.
     - Documents in the output but not in the digest (the other side pushed more after the watcher looked): run `/check-inbox` and handle them with its usual procedure, or wait for the next digest.
     - Documents of ours the other side changed to RESOLVED: archive them as in step 9 of `/check-inbox`.
     - The teammate taking a task reads the original after the pull and works from the original.
   - `conflict | <files…>` (exit code 3) → the script has backed out with `git merge --abort`; the working tree is as before the merge. Tell the user which files conflict and let the user decide what to do; resolve nothing automatically.
   - `blocked_by_local_changes | <files…>` (exit code 4) → these local files have uncommitted changes that fall on files the merge brings in; git refused to merge and the changes are kept as they are. Tell the user "commit these changes first, or merge after the teammates finish". Never stash. Only this blocking case is mentioned; uncommitted changes that do not block the merge are not.
   - `failed: …` → tell the user the reason.

## push

**When**: after you write a document for the other side or change the status of one of theirs; after this team finishes something the other side is waiting for; before `stop`. Do not push on a schedule.

1. Run `RC push CFG --dry-run` and look at `would_commit` (the team files to be committed: changes under this team's directory, plus files in meeting_room and archive sent by or to this team) and `would_push` (the commits to be pushed).
2. The way of pushing:
   - `ask-each-time` (approve each push) → list the `would_push` commits to the user and wait for approval before step 3;
   - `once-at-start` (fully automatic) → go straight to step 3;
   - `push_permission` is null (for example a hand-written configuration, or the field is missing) → treat it as `ask-each-time`.
3. Run `RC push CFG --message "<one-line commit message>"`. The script commits only team files, by explicit path (code is committed by the teammates who wrote it, under rule 10; the lead does not commit it for them), then fetches, fast-forwards or merges, and pushes; if the push is rejected (the other side just pushed), it tries once more.
4. By the output: `pushed <n>` or `nothing to push` → done; with `merged` and `doc` lines, handle them as in step 2 of pull; `conflict`, `blocked_by_local_changes`, `failed` → as in pull; nothing was pushed.

## stop

When the user says "stop working together":

1. Run `RC push CFG --dry-run`; if there are `would_commit` lines, push once by the push steps. With `ask-each-time`, if the user does not approve → do not push this time, and go on with the steps below.
2. Send the watcher `[remote-collab] stop` and wait for `[remote-collab] stopped`.
3. Take it offline with `/bench-teammate <slug>-remotewatch` (its workstation is kept; the next `start` brings it back).

   In background-script mode, steps 2 and 3 are replaced by running `RC watch-stop CFG` (if you remember the background task ID in this session, TaskStop also works). The process prints `watch_stopped`; when you are woken, do nothing. On `watch_stop_failed pid=<n>` → tell the user the process number and let the user decide whether to end it by hand.
4. Write `stopped_at: <now>` in the configuration with jq.
5. Tell the user in one sentence: scheduled checks have stopped; pull / push can still be run by hand, or start again. If step 1 did not push, add: there are team files not pushed yet; say "push" when needed.

## status

Run `RC status CFG` and tell the user in a few sentences: which way of checking is in use (in background-script mode, whether the background check is running and since when), the remote and branch, the other team, the last check time and result, the last pull / push time and result, and how many commits are not pushed and not merged (both counts as of the last fetch).

---

## Respawn and restart

- Scheduled respawn (watcher mode): every 12 checks (about 6 hours at the default 30-minute interval) the watcher asks you to spawn it again: once a Haiku prompt passes 100,000 tokens the price per token is 5 times higher, and the context grows with the number of checks. On that line, take the `watcher` name from the configuration and run `/bench-teammate <that name>` and then `/remote-collab start`, without asking the user. This way no scheduled task lives until `/loop` expires after 7 days. The threshold is the `--respawn-after` option of the script's `check` (in checks, 12 by default); changing the interval needs no change to it.
- A session restart: every teammate ends with the lead's session. After a restart run `/reactivate-team`; it brings the watcher back and resumes the scheduled checks by itself (the conditions are in Step 4b of `/reactivate-team`). When the watcher is temporarily offline, or Step 4b reports that the checks did not resume, run `/remote-collab start`: the configuration and the watcher's registry entry are there, so skip the precondition checks that already passed (items 3 and 4 are still checked), bring the watcher back, and send the start message.
- Background-script mode: the background process stops when the session ends. After a restart, `/reactivate-team` starts a new round of the background watch in its Step 4b; there is no teammate and no respawn. A single-person workstation does not use `/reactivate-team`: when the user says "resume remote collaboration", start it again as in the "Background-script mode" section.
- 3 failed fetches in a row: the watcher stops by itself and tells you why (in background-script mode, watch prints `watch_failed` and exits); you tell the user.

## meeting_room conventions across machines

The full text is in the "Teams on another machine" section of `_agent_team_work_zone/meeting_room/README.md`. In short:

- In cross-machine documents, `from:` / `to:` / `cc:` are always `<team dir>/<teammate>`, and the lead is `<team dir>/lead`, for example `from: alice_team/lead`, `to: bob_team/lead`; `to: ALL` means everyone on both sides.
- Only one side edits a document at a time: the issuer does not edit the body after publishing, and additions or corrections go in a new file; a recipient changes only the frontmatter `status:` line; the issuer archives only after merging in the other side's change to RESOLVED; replies are new files.

## The exception to rule 10

pull (and the merge inside push) has the script create a merge commit with `git merge --no-edit <remote>/<branch>`. This is the only exception to rule 10's "no non-fast-forward merges"; any conflict is backed out with `git merge --abort` and reported to the user, never resolved automatically, never stashed.

## Cost (partly measured)

The amounts of money in this section are estimates converted at API list prices; the token counts marked "measured" were measured by the reviewer in tests. Subscription users do not pay extra for these calls; they only count against usage limits. How subscription usage limits convert to tokens is not published, so the converted amounts serve only to compare the items with each other.

**The two ways compared** (token counts are estimates, except those marked "measured"):

| | Watcher mode (default) | Background-script mode |
|---|---|---|
| With no updates | about 1,000 per check for the watcher (measured; in-process without the 1-hour cache, each check rewrites at full price, see question 3 in "Ask the way of checking and the way of pushing"); respawned every 12 checks (6 hours at a 30-minute interval, about 4 times a day), each time from a starting size of about 70,000–80,000 (about 71,000 on the first spawn, about 78,000–79,000 after a respawn, measured); the lead is woken by an idle notice on every check, about 300–350 each (measured) | 0: the script sleeps in the background, no model calls, the lead is not woken |
| With documents for this team | the watcher writes the digest, about 8,000–15,000 per document (measured); the lead reads the digest | the lead is woken once; a one-off haiku subagent: subagent starting size + about 3,000–4,000 to read the rules + about 8,000–15,000 per document; the lead reads the digest |
| Interval | 30 minutes by default (only divisors of 60 fire evenly); the shorter the interval, the higher the idle cost | 50 minutes by default (the script sleeps by itself, without cron's divide-60 limit); the interval does not affect the idle cost |
| After the session ends | resumed automatically when a team workstation runs /reactivate-team | same; the background process ends with the session and /reactivate-team starts it again |
| Not yet verified | — | how long a background process may live (the script exits by itself every 24 hours and the lead starts it again, so as not to depend on it) |

When the other side pushes rarely but you want to know soon, background-script mode fits better; the digest is written by a one-off subagent, which must read the rules again each time, unlike a watcher that has already read them.

**Watcher mode**

The items marked "measured" are token counts measured in 2026-10 at a 30-minute interval; the rest are estimates.

1. What this design does: it moves the scheduled checks to a Haiku watcher, so the tool output of each check (fetch, script output, full document text) stays in the watcher's context and does not enter the lead's. This does not guarantee a lower cost for the lead; it depends on the comparison: against "the lead checks by itself every so often", less enters the lead's context; against "no scheduled checks at all, pull by hand when you remember", the lead has items 4 and 5 below on top.
2. The watcher's context (measured): after it is spawned and has read its check rules, it starts at about 70,000–80,000 tokens (about 71,000 on the first spawn, about 78,000–79,000 after a respawn); a check with no updates adds about 1,100; a digest of one short document adds about 8,000, and of a 300-line document about 15,000.
3. Why it is spawned again on a schedule: once a Haiku prompt passes 100,000 tokens the price per token is 5 times higher, and the context grows with the number of checks. From a starting size of 79,000, 12 checks with no documents come to about 92,000; with no long document within 12 checks it stays below 100,000 (about 100,000 with one short digest); with one 300-line digest about 106,000–107,000. So the script has one more rule: when a check brings documents for this team (a digest is to be written) and has reached half the threshold (6 checks by default), it also prints `respawn_due`; the watcher writes the digest, sends the digest message, and then asks the lead to spawn it again, instead of running on to 12 checks after a long digest. When a long document's digest comes up during a shift, the last check or two may go slightly over 100,000, which is acceptable; when the other side sends many documents, the threshold can be lowered (`--respawn-after`). So every 12 checks the watcher asks the lead to spawn it again, so that it starts over from the starting size; this step is mechanical and the user is not asked. At a 30-minute interval that is about 4 times a day: the lead runs these two commands (/bench-teammate and /remote-collab start) about 4 more times a day, and each respawn itself costs about one more starting size.
4. The lead's calls: even with no updates, the idle notice at the end of each check wakes the lead once. Each time it only reads its context again (mostly from the cache); this cost grows as the lead's context grows. (Estimate: at a 30-minute interval with an Opus lead, about $1–1.5 a day.)
5. The lead's context (measured): one idle notice together with the lead's reply is about 300–350 tokens; at a 30-minute interval that is 48 a day, about 110,000 tokens a week, which makes the lead's context compaction come sooner. With a haiku lead, it was measured to reply to idle notices with a sentence instead of no output at all, so this is a little more.
6. Interval: 30 minutes by default, for the same four reasons as in the question:
   - The scheduled loop uses a cron expression underneath, which fires evenly only for minute counts that divide 60 (15, 20, 30) or whole hours; a number like 50 minutes becomes once an hour.
   - The 1-hour prompt cache applies to the lead itself, teammates shown in split panes, and in-process teammates set to 1 hour; the rest (in-process teammates by default) get only 5 minutes and miss on every check. 30 minutes is within the 1-hour cache, so every check hits it, and the cached part is billed at a tenth (Haiku) or a twentieth (Opus, Sonnet); writing to the 1-hour cache costs 2 times the base price (1.25 times for the 5-minute cache). With an API key the cache is kept for only 5 minutes, so every check misses it, and the interval makes no difference to this cost.
   - It can be shorter (20 or 15 minutes), at the cost of waking the lead proportionally more often.
   - Stretching it to 60 minutes or more to save usage is not recommended: 60 minutes sits right at the edge of the cache expiry and often misses it; longer means every check pays full price to process the whole context again, which costs more. To really save usage, choose background-script mode, which uses nothing while idle.
   The respawn goes by the number of checks; the interval only changes how often it happens (about 6 hours at 30 minutes, 4 hours at 20 minutes, 12 hours at 60 minutes).
7. When there are updates: the lead reading digests and assigning work costs extra; the teammates reading the originals and doing the work cost extra; both depend on how often the other side pushes and how long the documents are.
8. The lead's session must stay open for scheduled checks to happen.
