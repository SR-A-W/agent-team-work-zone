---
name: handoff
description: >
  Task handoff: a single skill supporting both the giver (generate handoff document) and the
  receiver (read handoff document and absorb tasks) modes. Ask the user at the start which
  they are, then enter the corresponding flow. Handoff documents follow the top-level
  meeting_room frontmatter conventions, adding a new kind: HANDOFF type. Used in scenarios
  involving agent responsibility change or task migration after refactoring. Treat the task as
  a black box: this skill does not care how the receiver will complete the task.
argument-hint: "[--give | --take]"
disable-model-invocation: true
allowed-tools: Read Write Edit Glob Grep Bash
---

# Task Handoff (bidirectional single-file skill)

Transfer one or more outstanding tasks from agent A to agent B. **A single `/handoff` command supports both giver and receiver**—ask the user at the start which they are, then branch accordingly.

Typical scenarios:
- **Responsibility change**: an agent's scope of responsibility changed, and tasks in hand need to pass to another agent
- **Post-refactor migration**: in-flight tasks in the old workflow need to go to the agent corresponding to the new architecture
- **Temporary absence**: the giver will be offline for a while and entrusts tasks to someone else

> **Black box principle (applies throughout this skill)**: this skill treats each agent as an opaque black box. It **does not care** how the receiver will complete the task—directly doing it, handing off again, assembling a collaboration group, calling some tool—all are decisions the receiver makes in their own session, and are not this skill's concern. This skill's sole responsibility is to **transfer the full information of the task from A to B completely**.

---

## Step 0: Mode selection

`$ARGUMENTS` may contain `--give` or `--take` as a shortcut.

- If `--give` → enter [Mode A: Giver] directly
- If `--take` → enter [Mode B: Receiver] directly
- If neither → ask the user:

```
Are you:
  (1) The giver — you are transferring one or more tasks to another agent
  (2) The receiver — you are reading a handoff document someone else wrote earlier
      and taking over the tasks
```

Enter the corresponding mode after the user answers clearly. **Do not guess**—per rule #11, when ambiguous, ask.

---

# Mode A: Giver (generate handoff document)

## A1. Identity confirmation (two-tier check)

**First try to infer from conversation context**: your English role name (e.g. `Secretary`, `SkillSmith`, `Architect`). If you're clear about who you are, use it and skip to A2.

**Only when context cannot determine** do on-disk check:
1. Glob `_agent_team_work_zone/*/README.md` to find all workstations
2. Read each README's "Identity" section and compare against conversation history to find the matching workstation
3. If still unable to determine, **stop immediately and ask the user**

Record as `<SELF>`.

## A2. Collect tasks via natural-language dialogue

Ask the user (or extract from conversation context what's already known):

```
Which tasks are we handing off? Please tell me:

1. How many tasks in total?
2. For each task:
   - What is the goal? (what to do)
   - Why does it exist? (why — the most easily lost part; must be made explicit)
   - Current progress? (done / stuck at / not started)
   - Which files, paths, intermediate artifacts are involved?
   - Are there related OPEN/IN_PROGRESS files in meeting_room?
3. Who is the receiver? (their English role name; if not decided, write TBD and update later)
4. Overall handoff reason?
   - responsibility_change
   - post_refactor_migration
   - other (free-form)
5. Overall priority? (HIGH / MEDIUM / LOW)
```

**Key principles when collecting**:
- **Why is mandatory**: for every task, elicit the motivation. The "what to do" is easy to write; the "why" is the easiest part to lose in handoff
- **Do not over-templatize**: for complex task details use natural-language dialogue; don't force a table
- **Do not assume receiver's flow**: don't ask "how will the receiver do this"—that's the receiver's business
- **Empty task list friendly handling**: if the user says "actually nothing to hand off", tell them "then no handoff needed, ending"

## A3. Organize the handoff document

Organize a markdown document with the following 7 sections:

```markdown
# Task Handoff: <SELF> → <receiver or TBD>

## 1. Handoff metadata
- Giver: <SELF>
- Receiver: <receiver or TBD>
- Date: <YYYY-MM-DD HH:MM>
- Reason: <responsibility_change / post_refactor_migration / other>
- Task count: <N>
- Overall priority: <HIGH/MEDIUM/LOW>

## 2. Task list

### Task 1: <short title>
- **Goal**: <what to do>
- **Why**: <why this task exists — initial motivation>
- **Current progress**: <done X, stuck at Y, not started Z>
- **Status**: <not started / in progress / partial / stuck>
- **Related files**:
  - `path/to/file1`
  - `path/to/file2`
- **Decisions already made**: <if any, write here; if none, write "none">
- **Open questions**: <things awaiting receiver's decision>

### Task 2: ...
(same structure)

## 3. Context snapshot
(environmental info the receiver needs beyond the tasks themselves)
- Key paths: <...>
- Common commands: <...>
- Dependencies and environment conventions: <...>
- External resource links: <...>

## 4. Decisions already made
(to avoid the receiver re-discussing settled matters)
- Decision 1: <content> — reason <...>
- Decision 2: <...>

## 5. Open questions
(suspended questions awaiting receiver or user decision)
- Question 1: <...>
- Question 2: <...>

## 6. Suggested next steps (non-mandatory; receiver can judge)
- <step 1>
- <step 2>

> **This section is reference, not command**. The receiver can fully adopt a different path.

## 7. Related file references
(paths to related OPEN / IN_PROGRESS files in meeting_room, so the receiver can follow the trail)
- `_agent_team_work_zone/meeting_room/<file_a>.md` — <one-sentence note>
- `_agent_team_work_zone/meeting_room/<file_b>.md` — <one-sentence note>
```

If some sections have no content (e.g. no "decisions already made"), keep the section heading and write "none"; **do not omit sections**—keeping document structure stable lets the receiver know where to look.

## A4. Write to meeting_room

**File path**: `_agent_team_work_zone/meeting_room/<SELF>_HANDOFF_<YYYYMMDD>_<HHMM>_<slug>.md`

`<slug>` is a short description (connected by underscores, e.g. `auth_module_rewrite` or `failed_eval_followup`).

**Get precise timestamp**: use Bash `date '+%Y%m%d %H%M %Y-%m-%d %H:%M'` to get both the filename part and frontmatter part in one call.

**Required frontmatter**:

```yaml
---
kind: HANDOFF
status: OPEN
from: <SELF>
to: <receiver English name or TBD>
date: YYYY-MM-DD HH:MM
priority: HIGH | MEDIUM | LOW
handoff_reason: responsibility_change | post_refactor_migration | other
task_count: <N>
---
```

`kind: HANDOFF` is a new type prefix. Other types (`TASK`, `ERR`, `STATUS`, `DONE`, `PROJECT_STATUS`) are still handled by existing skills.

## A5. Sync update the giver's workstation files

**`TODO.md`**: for each task handed off, **do not delete the original entry**—append a marker at the end of the entry:
```markdown
- [ ] Original task description [HANDED OFF → <receiver or TBD> at YYYY-MM-DD HH:MM, see meeting_room/<filename>]
```

**`ACTIVE_JOBS.md`**: similarly keep the original entry and add `[HANDED OFF → ...]` marker. For long-running tasks (e.g. cron triggers), also note in comments whether the receiver needs to inherit the run authority.

> **Why not delete**: keeping the handoff record is an audit trail. In the future one can trace "this task was given to Y at time X".

## A6. Report to user

```
✅ Handoff document generated:
- File: _agent_team_work_zone/meeting_room/<filename>
- Handed off N tasks to <receiver>
- Reason: <reason>
- Priority: <priority>

Workstation files synced:
- TODO.md: N items marked [HANDED OFF]
- ACTIVE_JOBS.md: M items marked [HANDED OFF]

Next:
- Wait for the receiver to run /handoff --take in their session to absorb the tasks
- If the `to` field is TBD, please designate the receiver ASAP (edit the frontmatter's `to` field)
```

If `to` is TBD, **additionally remind the user**: "The handoff document is generated but no receiver is specified. Once you decide on the receiver, tell me and I'll update the file's `to` field."

---

# Mode B: Receiver (read handoff document)

## B1. Identity confirmation (two-tier check)

Same as Mode A's A1—context inference first, on-disk check as fallback; if unable to determine, ask immediately. Record as `<SELF>`.

## B2. Scan HANDOFF files

```
Glob: _agent_team_work_zone/meeting_room/*_HANDOFF_*.md
```

For each matching file, read frontmatter and filter:
- `kind: HANDOFF`
- `status: OPEN`
- `to: <SELF>` (**single recipient or list containing `<SELF>`**)

> If `to: TBD`, skip—TBD is not yet assigned and should not be absorbed by anyone.

Sort **ascending by `date`** (earliest handoff first).

**If none**:
```
No handoff documents waiting for you.
(Search scope: *_HANDOFF_* files in _agent_team_work_zone/meeting_room/ with to: <SELF> and status: OPEN)
```
Then end the skill.

## B3. Display list for user to choose

```
Found N handoff documents waiting for you (ascending by date):

1. <filename1>  from: X, date: YYYY-MM-DD HH:MM, task_count: 3, priority: HIGH
   Reason: responsibility_change
2. <filename2>  from: Y, date: YYYY-MM-DD HH:MM, task_count: 1, priority: MEDIUM
   Reason: post_refactor_migration

Process all at once, or only some? Please tell me.
```

Decide which files to process based on user's choice.

## B4. Read and absorb one by one

For each selected handoff document (in chronological order), execute B5 ~ B7.

## B5. Fully read the handoff document

Use Read to read the whole markdown, **not just the frontmatter**. Understand:
- Task list (each task's why, progress, related files)
- Context snapshot (paths, commands, conventions)
- Decisions already made (don't re-discuss)
- Open questions (which ones await your decision)
- Suggested next steps (reference, not mandatory)
- Related file references (entry points for following the trail)

## B6. Confirm receipt with user

```
I'm about to absorb N tasks from handoff document <filename> (from <predecessor>, original
handoff time <date>):

Task summary:
1. <Task 1 title> — why: <one-sentence motivation>
2. <Task 2 title> — why: <...>
3. ...

Confirm taking over? After taking over I will:
- Append tasks to my TODO.md (noting source is HANDOFF)
- Add running tasks to ACTIVE_JOBS.md
- Change handoff document status to IN_PROGRESS
```

Wait for explicit user confirmation.

## B7. Update own workstation files + change handoff document status

**`TODO.md`**: append one entry per absorbed task:
```markdown
- [ ] [from HANDOFF, from <predecessor>, date: YYYY-MM-DD] <task title> — why: <motivation> — see meeting_room/<filename>
```

**`ACTIVE_JOBS.md`**: if the handoff includes running tasks (SLURM job, cron trigger, etc.), append relevant metadata.

**`notes.md`**: append only if the handoff document contains **long-term reusable** info (e.g. key paths, command conventions). One-off info doesn't go into notes (rule #10).

**Modify the handoff document**: change `status` from `OPEN` to `IN_PROGRESS`. Per rule #8, the `to` field is you (or contains you), so you have modification authority.

## B8. Report to user

```
✅ Absorbed handoff document <filename>:
- Took over N tasks, appended to TODO.md
- ACTIVE_JOBS.md added K in-progress tasks
- notes.md appended M long-term references
- Handoff document status: OPEN → IN_PROGRESS

What I plan to do next (based on the handoff's "suggested next steps" + my own judgment):
- ...
- ...

If you have questions or want to adjust priorities, let me know.
```

## B9. (Optional) Close the handoff document after full digestion

When you feel all handoff document content is fully absorbed (TODOs underway, related files in place, key decisions understood), you may:
- Append a "receipt complete note" at the end of the handoff document (time + receiver + summary)
- Change `status` to `RESOLVED`

**This skill does not auto-archive**. After the receiver finishes absorbing the handoff, they simply set `status` to `RESOLVED`; archiving is done by the issuer (`from`) on their next `/check-inbox` step 9.

---

## Boundaries (relationship with other skills)

- **vs `/check-inbox`**: check-inbox passively scans all messages addressed to you (TASK / ERR / STATUS etc. all kinds). handoff is a **proactive** dedicated scenario for "a complete handoff list needs to be absorbed". For routine handling of new tasks, check-inbox suffices; HANDOFF files will also be caught by check-inbox, but absorbing handoff lists item by item is smoother with `/handoff --take`.
- **vs `/sync`**: sync restores workspace state and identity awareness (member changes, message scanning, task review). handoff transfers **concrete outstanding tasks**. The two functions are orthogonal.

---

## Notes

- **Black box principle**: this skill does not assume how the receiver will complete tasks, nor embed implementation details in the handoff document. "The receiver should do it this way" is out of scope
- **Why is mandatory**: each task's "why it exists" must be collected explicitly—this is the most easily lost part in handoff
- **No auto-archive**: this skill does not archive completed handoff files; receiver sets `status: RESOLVED` only, archiving is done by the issuer on their next `/check-inbox`
- **TBD support**: the giver can first generate a `to: TBD` document and update the `to` field after the user later designates the receiver. TBD files won't be accidentally absorbed by any receiver
- **Conservative about impersonation**: if the giver claims to be X but identity check fails → refuse to write file and ask per rule #11
- **Empty list**: no tasks to hand off → friendly "no handoff needed" message; do not create empty files
- **Do not over-templatize complex tasks**: most of this skill's logic should be "agent collects information via natural-language dialogue"—don't force every case into the same table
- **Preserve audit trail**: original entries in the giver's TODO/ACTIVE_JOBS are **never deleted**; only append `[HANDED OFF → ...]` markers
