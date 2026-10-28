# /remote-collab: the watcher's check rules

This file is for the watcher `<slug>-remotewatch`; the /remote-collab spawn prompt and start message point to it. Other teammates need not read it. If this file is already in your context, there is no need to read it again.

## 1. Values

- `<project root>`: the path before `/.claude/skills/` in the sentence that told you to read this file.
- `<team dir name>`: the team directory your workstation is in; your workstation `<ws>` = `<project root>/_agent_team_work_zone/<team dir name>/teammates/<slug>-remotewatch/`.
- `<interval>`: the interval given in that sentence.

## 2. Limits

- You only fetch (the check script does it); you do not pull, merge, change meeting-room documents, assign work, or change any file outside your own workstation.
- Pulling and assigning work are the lead's; "Suggested assignee" and "Urgent" are always marked as suggestions, and the lead may ignore them.
- Run only these commands: the check in watch_targets, `git show <commit>:./<path>`, the `git diff --stat` in section 6, and `date -u +%Y-%m-%dT%H:%M:%SZ` (for the time), `rm -f <ws>/loop_job`. Create scheduled tasks with `/loop` and delete them with CronDelete.
- Read only: this team's `TEAMMATE_INFO.json` and this team's teammate READMEs. Write only: your own workstation (`digests/`, `loop_job`, `working-context.md` and so on).
- Do not read the meeting-room documents in the working tree (they are the old versions from before the merge); send messages to no one but the lead.

## 3. What to watch

```
watch_targets: cd "<project root>" && bash _agent_team_work_zone/resources/scripts/atwz_remote_collab.sh check --config _agent_team_work_zone/<team dir name>/remote_collab.json --seen _agent_team_work_zone/<team dir name>/teammates/<slug>-remotewatch/remote_seen --journal _agent_team_work_zone/<team dir name>/teammates/<slug>-remotewatch/working-context.md --loop-job _agent_team_work_zone/<team dir name>/teammates/<slug>-remotewatch/loop_job
stop_when: the lead says stop; 3 failed lines in a row with the same reason (stop and tell the lead why).
```

On every check the script writes one record line to working-context.md and adds 1 to the round count in `loop_job`; you do not write these yourself.

## 4. Starting (after being spawned, or on a start message)

1. When spawned, first finish step 0 and send your receipt.
2. On the first start after being spawned or brought back (no scheduled task created yet in this session), first `rm -f <ws>/loop_job`, so that the script counts rounds from 1 again; on another start message in the same session, do not delete it. Then check once right away by section 5. With no updates, send the lead one line `[remote-collab] first check: no updates`; with updates, send them as section 5 says.
3. Run (this sentence is the "check prompt"):
   `/loop <interval> do one remote check by <project root>/.claude/skills/remote-collab/watcher_rules.md: run the watch_targets command; only the no updates and rounds lines → send nothing and end the turn; doc lines → write the digest file, then send a message of at most 5 lines; only mine_status or changes lines → send one line; same_team_name, partner_teams, failed, journal_failed or loop_job_failed lines → add one line for each; a respawn_due line → after handling the above, send the "please spawn me again" line as a separate message. Do not write the work record yourself; the script already did.`
4. Take the scheduled task's ID from the tool result and replace the `job_id=` line of `<ws>/loop_job` with `job_id=<ID>`; the other lines (`created_at`, `created_epoch`, `rounds`) are written by the script; leave them. If that line already held a different ID (another start message in the same session) → after replacing it, `CronDelete <old ID>`.

## 5. Handling the output of each check

- Only `no updates` and `rounds=…` → send nothing; end the turn.
- `doc` lines → first write the digest file (section 6), then send a message of at most 5 lines (section 7).
- Only `mine_status` (no `doc`) → send one line for each: `Status of our document changed: <file name> <old> → <new> (can be archived after the merge)`, the first line starting with `[remote-collab] `, and the last line `To handle it, first run /remote-collab pull`.
- Only `changes` (no documents) → one line `[remote-collab] <n> new commits on the remote, no documents for us; the changes are in <their team directory / code>, <sum of the two numbers> files in total.`
- `same_team_name | <dir>` → one line `[remote-collab] Someone on the remote changed a team directory with our name, <dir>; the two sides' team names collide; the lead needs to handle it. Keep checking.`
- `partner_teams | <dirs…>` → one line `[remote-collab] Team directories <dirs…> appeared on the remote; the configuration does not record the other side yet.`
- `failed: …` → on the first failure, one line `[remote-collab] Check failed: <reason>`; after 3 in a row with the same reason → stop as stop_when says.
- `journal_failed: <path>` → one line `[remote-collab] Could not write the work record: <path>`.
- `loop_job_failed: <path>` → one line `[remote-collab] Could not write the round count: <path>`.
- `respawn_due rounds=<n>` (the threshold is reached; or this check has documents and half the threshold is reached) → after handling all of the above (with documents: write the digest and send the digest message first), send this as a **separate** message:
  `[remote-collab] I have done <n> checks; please spawn me again` (only this sentence, no name and no commands)
- When several appear at once, send them as one message; `same_team_name`, `partner_teams`, `failed`, `journal_failed` and `loop_job_failed` lines that come with documents go at the end, one line each (the 5-line limit covers only the document part).

## 6. The digest file

- Location: `<ws>/digests/<UTC time>_<start short hash>-<new short hash>.md`, for example `digests/20261028T0330Z_a1b2c3d-e4f5a6b.md`. One per batch, never overwritten. The start and new commits come from the `updates <start>..<new>` line.
- Read each document: `cd "<project root>" && git show <new short hash>:./<path in the doc line>`.
- Our teammates' responsibilities: for each teammate whose `status` is active in this team's `TEAMMATE_INFO.json`, read the Scope and Deliverables in its README. Once per batch.
- Code and other changes (this batch):
  `cd "<project root>" && git diff --stat --relative <start> <new> -- . ':(exclude)_agent_team_work_zone/meeting_room' ':(exclude)_agent_team_work_zone/archive' ':(exclude)_agent_team_work_zone/*_team/*'`
- Urgent or not: "urgent" only in three cases: the deadline in the document is within 7 days (counted from the UTC date of the check), its frontmatter `priority` is HIGH or urgent, or its text says in so many words that it is urgent; in every other case write "cannot tell". A deadline more than 7 days away is still written in the "Deadline" line, but does not count as urgent.

Template (fill it in):

```markdown
# Remote update digest <start short hash>..<new short hash>

- Checked at: <UTC>; commits: <commits=n>
- State: not merged yet. To handle it, the lead first runs /remote-collab pull.
- Note: this file was put together automatically by /remote-collab (the watcher or a one-off subagent). "Suggested assignee" and "Urgent" are only suggestions; the lead decides.

## 1. <file name>

- Path: <path in the doc line>
- From → to: <from> → <to> (cc: <cc>, or "none")
- Type / status / priority: <type> / <status> / <priority, or "not given">
- What they ask for: <two or three sentences, only restating what the document says, no inference>
- Deadline: <the date or time limit in the document; or "none">
- Files and paths mentioned: <list each one; or "none">
- Which of our teammates' responsibilities it touches: <teammate name — basis: which sentence of its README; or "cannot tell">
- Suggested assignee (suggestion): <teammate name or the lead; or "the lead decides">
- Urgent (suggestion): <urgent / cannot tell> — basis: <deadline / priority / the document's words; or "not stated in the document">

## Status changes of our documents

- <file name>: <old> → <new> (can be archived after the merge) (write "none" when there are no mine_status lines)

## Code and other changes in this batch (excluding team directories, meeting_room, archive)

<paste the git diff --stat output as it is; or "none">
```

## 7. The message to the lead (when there are documents; at most 5 lines)

```
[remote-collab] <k> documents for us on the remote (<start>..<new>, <n> commits), not merged yet
Most urgent (suggestion): <file name> — <one sentence, with the deadline>
Also: status changes of our documents <a>; code and other changes <b> files
Digest: <path of the digest file, relative to the project root>
To handle them, first run /remote-collab pull
```

- When no document is marked urgent, write `Most urgent (suggestion): none stated as urgent`.
- The "Also" line: leave it out when both numbers are 0. `<b>` is the number of files in the digest's list of code and other changes.

## 8. Stopping and the rest

- stop_when met → `CronDelete <the ID in loop_job>`, `rm -f <ws>/loop_job`, send one line `[remote-collab] stopped: <reason>`, and go idle.
- The lead says "stop" → `CronDelete <the ID in loop_job>`, `rm -f <ws>/loop_job`, reply one line `[remote-collab] stopped`, and go idle.
- Delete only by the ID in `loop_job`, never by CronList (the same process may hold other agents' scheduled tasks).
- On a final checkpoint request or a shutdown request (being benched by /bench-teammate) → first `CronDelete <the ID in loop_job>`, then `rm -f <ws>/loop_job` (so that a respawned watcher starts again from round 1), then do as asked. The final checkpoint writes Part A only, no Part B entry.
- Never wait inside your turn (no `until … sleep`, no chain of checks); end the turn after each check.
- A checkpoint reminder while idle → minimal checkpoint: write only Part A (what you watch, the last commit seen in remote_seen, the task ID and round count in loop_job, the stop condition).

## 9. One-off digest (background-script mode)

This section is for the one-off digest subagent the lead starts in background-script mode; the watcher can ignore it.

- You are not the watcher: do not run the check script, create no scheduled task, send no SendMessage.
- Limits as in section 2: run only `git show` and the `git diff --stat` in section 6; read only this team's `TEAMMATE_INFO.json` and the teammate READMEs.
- Take the start and new commits and the documents from the check output the lead pasted for you. Write the digest file to `<team dir>/digests/` (not a watcher workstation), with the name and format of section 6.
- A single-person workstation has no teammates: "Suggested assignee" is always the lead.
- When done, reply with the path of the digest file and the lines in the format of section 7 as your final answer, then end.
