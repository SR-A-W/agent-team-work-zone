---
name: remove-teammate
description: >
  Offboard a teammate: gracefully complete handoff, archive their output, remove from team.
  Team lead can invoke autonomously (after natural-language user consent). Valid only in team
  lead context.
disable-model-invocation: false
allowed-tools: Read Write Edit Glob Grep Bash
---

# `/remove-teammate` — Offboard a Teammate

## Identity precheck

**First infer from conversation context**: you should already know you're a team lead. **When unable to infer**, follow `/evaluate-team`'s check logic. If not a team lead → stop immediately and warn.

## Phase 1: Determine the teammate to remove

From the user's description or `/evaluate-team` results, determine the nickname of the teammate to remove.

Confirm with user:

```
Do you want to offboard <Teammate nickname>?

Its recent output:
- <list files in roundtable with from that teammate>

Its tasks on hand:
- <list IN_PROGRESS or OPEN tasks with to that teammate>

Before removal, I need to:
1. **Require it to perform a final checkpoint** (it calls /checkpoint itself to persist working-context.md and completed.md)
2. Hand off its on-hand tasks to other teammates or put them back in the pool
3. Wrap up and archive its output (DONE reports, code, etc.)
4. Formally remove it from the Claude Code agent-team
5. Update TEAMMATE_INFO.json: move it from active_teammates to offboarded_teammates
6. Update team_recipes/'s latest recipe, appending an Amendment recording this offboard

Confirm removal?
```

Wait for explicit user consent.

## Phase 1.5: Enforce final checkpoint (Rule 1 + Rule 13)

**Key: the final checkpoint must be done by the teammate itself** (rule #1 low coupling; the lead cannot write workstation files on its behalf).

> **If the teammate is currently `status=benched`** (already temporarily offline, not online): skip the SendMessage below — it already wrote a final checkpoint when benched; just reuse its workstation's working-context.md and proceed to Phase 2. (benched → offboarded is a valid transition.)

Send via SendMessage to that teammate:

```
Before shutdown, run /checkpoint to persist your final state. This is your final
checkpoint — after it, I will remove you from the team. Your workstation files
(working-context.md, completed.md, commitments.md) will be preserved at
_agent_team_work_zone/<SELF>_team/teammates/<nickname>/ for audit and potential future
reactivation under a different task.
```

Wait for teammate's "Checkpoint written." confirmation before proceeding to Phase 2.

If the teammate cannot perform a final checkpoint for any reason (stuck / session already dead / unresponsive):
- Tell the user: "<nickname> cannot self-checkpoint (reason: ...). Its working-context.md retains the previous state; explicit consent required to force offboard and give up the latest work state."
- Wait for user decision: continue vs. address the stuck teammate first

## Phase 2: Hand off on-hand tasks

### 2a. Identify unfinished work
Scan `_agent_team_work_zone/<SELF>_team/roundtable/` for:
- Files with `from: <SELF>_team/<teammate>` and `status: IN_PROGRESS` (submitted by it but not completed)
- Files with `to: <SELF>_team/<teammate>` and `status: OPEN` or `IN_PROGRESS` (assigned to it but not done)

### 2b. Decide destination
For each unfinished item ask user:

```
Unfinished task handoff:

1. <file1.md> (IN_PROGRESS, from: <teammate>)
   Progress: <summary>
   Options:
     (a) Let it wrap up before offboard
     (b) Forced takeover — continued by lead or another teammate
     (c) Abandon this work

2. <file2.md> (OPEN, to: <teammate>)
   Options:
     (a) Reassign to another teammate (specify who)
     (b) Return to pool; record in <SELF>_team/TODO.md
     (c) Cancel

Your decision?
```

### 2c. Execute handoff
Per user decision:
- **Reassign**: modify target file's `to` field
- **Return to pool**: append an item to `<SELF>_team/TODO.md` and archive the original file or mark as WITHDRAWN
- **Wrap up before offboard**: suggest the user wait for the teammate to finish before running `/remove-teammate`

## Phase 3: Archive the teammate's completed output

Move RESOLVED files from that teammate (with `from: <teammate>` and `to` addressing lead or other departed teammates) from roundtable to `<SELF>_team/archive/`:

```bash
mv _agent_team_work_zone/<SELF>_team/roundtable/<file>.md _agent_team_work_zone/<SELF>_team/archive/
```

Rule #8 still applies:
- Files with `from: <SELF>_team/<teammate>` can be archived by the lead (since teammate is about to offboard, lead effectively inherits its posting authority)
- Files with `to: ALL` not archived
- Files with `cc` not archived

## Phase 4: Formally remove from agent-team

Produce a natural-language remove instruction (Claude Code's built-in mechanism recognizes):

```
Remove teammate <nickname> from the current <SELF> team. Its unfinished tasks have been handed
off (see roundtable); its output has been archived to archive/. Please formally remove it.
```

## Phase 5: Update TEAMMATE_INFO.json

Path: `_agent_team_work_zone/<SELF>_team/TEAMMATE_INFO.json`

**Remove** the offboarded teammate from `active_teammates` and **append** to `offboarded_teammates`:

```json
{
  "name": "<offboarded nickname>",
  "offboarded_at": "<ISO8601 current time>",
  "reason": "<one-line reason: task completed / redundant role / stuck / user decision>"
}
```

Also update the top-level `updated_at`.

jq example (if available):
```bash
name="<nickname>"
reason="<reason>"
ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
jq --arg n "$name" --arg r "$reason" --arg ts "$ts" '
  .offboarded_teammates += [{name: $n, offboarded_at: $ts, reason: $r}] |
  .active_teammates |= map(select(.name != $n)) |
  .updated_at = $ts
' _agent_team_work_zone/<SELF>_team/TEAMMATE_INFO.json > /tmp/info.json && \
mv /tmp/info.json _agent_team_work_zone/<SELF>_team/TEAMMATE_INFO.json
```

**Do not delete** the teammate's workstation directory `_agent_team_work_zone/<SELF>_team/teammates/<nickname>/` — preserve it as historical audit (Rule 1 low coupling + useful reference if a similar task resumes and old working-context.md needs review).

## Phase 6: Update the latest team_recipes recipe

Find the newest recipe under `<SELF>_team/team_recipes/` and append at the end:

```markdown
---

## Amendment — YYYY-MM-DD HH:MM — remove-teammate

### Offboard
- **Nickname**: <teammate>
- **Reason**: <from user or /evaluate-team judgment>

### Handoff handling
- Unfinished task handoffs: <summary>
- Output archive: N RESOLVED moved to archive/

### Current team size: <remaining members>
```

## Phase 7: Report completion

```
✅ <Teammate nickname> offboarded

Handoff:
- <file1.md> → reassigned to <new teammate>
- <file2.md> → returned to TODO
- ...

Archive:
- <N files> → <SELF>_team/archive/

Team update:
- Size: <before> → <after>
- TEAMMATE_INFO.json: active_teammates -1, offboarded_teammates +1
- team_recipes/<latest>.md amended
- Claude Code agent-team formally removed
- Workstation directory preserved at teammates/<nickname>/ (audit; not deleted)

Remaining team members:
- <list>
```

## Notes

- **Do not drop tasks**: unfinished work must have a clear destination (reassign / return / cancel); it cannot just vanish
- **Final checkpoint is the teammate's own action** (Rule #1 low coupling): the lead cannot write workstation files on its behalf. If the teammate is stuck and cannot respond, accept losing the latest state — do not have the lead overstep
- **Do not delete workstation directory**: preserve `teammates/<nickname>/` as historical audit + potential reactivation reference
- **Rule #8 applies**: filter by permission when archiving roundtable files; never archive `to: ALL` or `cc` files
- **Amendment preserves history**: team_recipes should reflect the team's evolution trajectory (add, remove)
- **Formal remove must go through Claude Code mechanism**: cannot "pretend"; use a natural-language prompt so Claude Code's built-in mechanism actually closes the teammate's session
- **Offboard is not a fire**: teammates are inherently one-off collaborators; "offboard" is a neutral workflow step with no punitive connotation
