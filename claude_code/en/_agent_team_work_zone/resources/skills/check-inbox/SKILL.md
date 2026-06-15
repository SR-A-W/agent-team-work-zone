---
name: check-inbox
description: >
  Check tasks addressed to you in the top-level meeting_room (all agents) + your team's
  roundtable (team leads only); process in chronological order: read content, update
  workstation files, execute tasks, update status. Also scan as issuer for your own
  completed docs and archive them (step 9). Strictly follow work rule #8 (including cc
  field semantics). Authoritative archival implementation; /archive-resolved is deprecated.
disable-model-invocation: true
allowed-tools: Read Glob Grep Bash Edit Write
---

# Check inbox and process tasks

Scan `_agent_team_work_zone/meeting_room/` (all agents) and `_agent_team_work_zone/<your_team>/roundtable/` (team lead only) to find **all tasks addressed to the current agent** and process them one by one in chronological order.

> **Important — Work rule #8 (Meeting room / Roundtable permissions)**:
> - **Archival authority belongs exclusively to the issuer (`from`)**: only files where `from` is you may be archived by you
> - Files whose `to` field **explicitly addresses you**: you may modify their `status`, but **may not archive them** (archiving is done by the issuer)
> - `to: ALL` status reports belong to the publisher; other agents **read only, do not modify, do not archive**
> - Reports you submitted yourself (`from` is you) can be self-managed (including archiving in step 9)
> - **`cc` field**: if you are in `cc` (not in `to`), the file is for your awareness only — **read-only, do not modify status, do not archive**
> - **Violating this rule may cause loss of other agents' work state**

## Execution steps

### 1. Identity check (two-tier)

**First try to infer from conversation context**: if you're clear about your role and workstation, skip to next step. Record as `<SELF>` (English name), and note whether you are **flat** or **team_lead** and your corresponding `<workstation>` path.

**Only when context cannot determine** execute the on-disk check:
1. Glob `_agent_team_work_zone/*/README.md` and `_agent_team_work_zone/*_team/README.md`
2. Read each README and find the workstation matching the current conversation
3. If the workstation directory ends with `_team` and contains `roundtable/` → `team_lead` mode
4. Otherwise → `flat` mode
5. If still unable to determine, **stop immediately and ask the user**; do not guess

### 2. Scan inbox (two layers, branch by mode)

#### All agents: scan top-level meeting_room
Use Glob to list `_agent_team_work_zone/meeting_room/*.md` (excluding `README.md`).

#### Team lead only: additionally scan own roundtable
Use Glob to list `_agent_team_work_zone/<SELF>_team/roundtable/*.md` (excluding `README.md`).

For each file, read frontmatter and extract `status`, `from`, `to`, `cc` (if any), `kind` (if any), `date`, `priority`.

### 3. Filter by permission rules

For each file, determine ownership:

| status | to field | cc field | ownership |
|---|---|---|---|
| OPEN or IN_PROGRESS | `<SELF>` or list contains `<SELF>` | - | ✅ inbox — I need to handle |
| OPEN or IN_PROGRESS | `ALL` | - | 📢 broadcast — informational, do not proactively execute |
| OPEN or IN_PROGRESS | other | `<SELF>` | 👁️ cc — **read-only**, do not change status, do not archive |
| any | other agent (not containing `<SELF>`) | not containing `<SELF>` | ❌ unrelated, skip |
| RESOLVED | from=`<SELF>` | any | ➡️ enter step 9 (issuer archival queue) |
| RESOLVED | from=other | any | 📋 done, awaiting issuer archival — read-only, do not archive |

**Team version special**: for roundtable files, `from` and `to` are `<team>/<role>` format (e.g. `architect_team/tracker`); `architect_team/lead` equals `<SELF>` when `<SELF>` is that team's lead.

### 4. Sort in chronological order

Sort "inbox" + "cc" files in **ascending order by `date`** (earliest first).

Chronological order matters: later tasks may depend on results of earlier ones.

### 5. Read full content item by item

In chronological order use Read to read **full content** of each file and understand task requirements:
- **New task (OPEN)**: task description, input files, expected output, deadline, priority
- **Old task (IN_PROGRESS)**: what was completed, blockers, whether other agents have replied with progress updates

For IN_PROGRESS old tasks, additionally search once in meeting_room, roundtable, and archive for related follow-up reports to judge whether the old task can advance.

### 6. Output pending list and request user confirmation

Before starting execution, output a "pending list" to the user for confirmation:

```
Current agent: <SELF> (mode: flat/team_lead)

📬 Inbox — chronological order (total N):

🆕 New tasks (OPEN):
1. [TOP][HIGH] file1.md (from: X, date: 2026-04-11 10:00) — title/purpose
2. [TEAM][MED] roundtable/file2.md (from: architect_team/tracker, kind: TRACKER_REPORT, date: 2026-04-11 14:30) — summary

⏳ Old tasks (IN_PROGRESS):
3. [TOP][HIGH] file3.md (from: Z, date: 2026-04-10 09:15) — completed X, pending Y

👁️ CC'd to me (read-only):
4. [TOP] file4.md (from: W, to: V, cc: <SELF>, date: 2026-04-11 08:00) — summary

📢 Broadcast (to: ALL):
5. [TOP][LOW] file5.md (from: Secretary, date: 2026-04-11 08:00) — team announcement

📁 My completed outgoing docs (to be archived in step 9):
- [TOP] fileA.md (to: X, status: RESOLVED) — will be archived
- [TOP] fileB.md (to: [A,B,C], Completion Checklist: all done) — will be archived

Process in this order? Let me know if adjustments are needed.
```

> Legend: `[TOP]` = top-level meeting_room; `[TEAM]` = own team's roundtable

### 7. Update workstation files

After user confirms, **before executing tasks** sync workstation tracking files:

- **`TODO.md`**: append new tasks as pending items (if not already present)
- **`ACTIVE_JOBS.md`**: register started long-running tasks
- **`notes.md`**: append if the task involves paths/commands/configs with long-term reuse value (rule #10)

### 8. Execute tasks in order

For each pending task (**skip cc items — read-only**):

1. **Before starting**: update the file's `status` from `OPEN` to `IN_PROGRESS` (only when `to` explicitly addresses `<SELF>`)
2. **Execute the task**
3. **If blocked**:
   - Investigate technical issues yourself
   - For requirements, priority, direction → proactively ask the user per rule #11
   - If depending on another agent → create an ERR/TASK file at the appropriate layer (top-level or team roundtable)
4. **After task completes**:
   - Check off in TODO.md
   - Move from ACTIVE_JOBS.md to COMPLETED_JOBS.md
   - Append a processing result note at the file's end (time + executor + result summary + artifact paths)
   - Update `status` to `RESOLVED`
   - **Do not archive** (archiving is done by the issuer in their next `/check-inbox` step 9)

### 9. As issuer: archive your own completed docs

Scan `_agent_team_work_zone/meeting_room/` (and `_agent_team_work_zone/<SELF>_team/roundtable/` if team lead) for files where `from: <SELF>`, filtering for **completed** ones:

**Completion criteria (either satisfies — archive is triggered)**:
- `status: RESOLVED`
- or all entries in the file's Completion Checklist are checked (`- [x]`; no remaining `- [ ]`)

**Roundtable archival coordination (team lead only)**: when the lead scans its own roundtable and finds a doc whose issuer (`from`) is a **currently-active teammate**, completed (`status: RESOLVED` or checklist fully checked), but not yet archived — the lead **does NOT archive it directly** (archival authority is the issuer's). Instead the lead **may immediately `SendMessage` that issuer teammate to archive it**, giving the **exact path**: "Your roundtable doc `<path>` is RESOLVED — please archive it (`mv` to `<SELF>_team/archive/`)". The teammate is the issuer (has the authority); the lead supplied the exact path, so it does not need to scan roundtable (a teammate's `/check-inbox` does **not** scan roundtable, so it can never discover these on its own — the lead must push them).
> **Why the lead initiates**: users normally talk only to the team lead and invoke `/check-inbox` in the lead's session, so the lead is the only party that scans roundtable and notices "done-but-unarchived" pile-up; but the archival **action** is still performed by the issuer — issuer-only authority is unchanged.
> **If the issuer has been disbanded**: if that issuer is actually offboarded (not in `active_teammates`) → fall through to the "Absent-issuer fallback" below: the lead **verifies the situation** and then either (a) archives it itself, or (b) **transfers the doc's responsibility/ownership** to an active agent who handles it.

**Absent-issuer fallback (team lead only)**: additionally list RESOLVED files whose `from` agent is no longer in `TEAMMATE_INFO.json`'s `active_teammates` (issuer has offboarded), marked "(absent fallback — confirm before archiving)". The team lead **verifies, then** archives them manually **or transfers ownership**. **Flat workstations have no `TEAMMATE_INFO.json`; the absent-issuer scan is silently skipped.**

**Archivable list example**:
```
📁 As issuer — archivable (N total):
[TOP]
- fileA.md (to: X, status: RESOLVED) — X completed
- fileB.md (to: [A,B,C], checklist: all done) — all recipients done
[TEAM] <SELF>_team/roundtable/
- fileC.md (from: <SELF>, status: RESOLVED) — issued by me, archive directly

📨 Notify issuer to archive (active teammates' completed roundtable docs — their authority):
- roundtable/fileE.md (from: drafter — active, RESOLVED) → SendMessage drafter to archive

[Absent fallback / transfer ownership]
- roundtable/fileD.md (from: OldAgent — not in registry) → lead verifies, then archives or transfers ownership

Confirm: archive N (mine) + notify M issuer(s) to archive?
```

After user confirms, execute moves (original location determines archive destination):
```bash
mv _agent_team_work_zone/meeting_room/<filename> _agent_team_work_zone/archive/
mv _agent_team_work_zone/<SELF>_team/roundtable/<filename> _agent_team_work_zone/<SELF>_team/archive/
```

If no archivable files this scan, skip silently (do not output an empty list).

### 10. Report results

```
Inbox processing complete (executor: <SELF>, time: YYYY-MM-DD HH:MM):

✅ Completed (status → RESOLVED):
- [TOP] file1.md — result summary (issuer will archive)
- [TEAM] roundtable/file2.md — result summary (issuer will archive)

📁 Archived (as issuer):
- [TOP] fileA.md — to: X, completed
- [TEAM] roundtable/fileC.md — from: <SELF>, completed

📨 Notified issuer to archive (active teammates' completed roundtable docs):
- roundtable/fileE.md → SendMessage'd drafter to archive

🔄 In progress (status: IN_PROGRESS):
- file3.md — advanced to X, next step Y

⏸️ Paused (blocked):
- file_stuck.md — block reason: ..., ERR submitted

👁️ Read (cc, not executed):
- file4.md

📢 Broadcast read:
- file5.md

Workstation files updated: TODO.md (+N), ACTIVE_JOBS.md (+K)
```

## Notes

- **Order-sensitive**: strictly process in ascending `date` order
- **Permission boundary**: `to: ALL` / files with `cc` containing `<SELF>` must never have status modified, never be archived (see rule #8)
- **Two-layer scan**: team leads must scan both the top layer and their own roundtable; don't miss either
- **Revisit old tasks**: for IN_PROGRESS old tasks, proactively check archive/ for follow-up progress
- **Avoid duplicate registration**: before appending to TODO.md, check if it already exists
