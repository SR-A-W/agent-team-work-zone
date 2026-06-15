---
name: archive-resolved
description: >
  Scan the top-level meeting_room (all agents) + your team's roundtable (team leads only) for
  completed (RESOLVED) files; by permission rules archive only files the current agent has
  authority to handle, moving them to the corresponding layer's archive. Strictly follow work
  rule #8 (including cc field).
  (From v0.3.0, prefer /check-inbox instead — see DEPRECATED NOTICE)
disable-model-invocation: true
allowed-tools: Read Glob Grep Bash
---

> **Notice (from v0.3.0)**: The authoritative archival logic has been merged into `/check-inbox` (step 9: issuer archiving).
> Prefer `/check-inbox` over this skill. This file is retained for backward-compatible reference;
> if you need to trigger an archival scan independently, the logic here remains valid, but `/check-inbox` rules take precedence.

# Archive completed tasks (permission-filtered, two-layer support)

Scan `_agent_team_work_zone/meeting_room/` (all agents) + `_agent_team_work_zone/<your_team>/roundtable/` (team lead only), and move files the current agent has authority to archive with `status: RESOLVED` to the corresponding archive.

> **Important — Work rule #8**:
> - Only files whose `to` field **explicitly addresses you** may have their `status` modified or be archived by you
> - `to: ALL` status reports belong to the publisher; other agents **read only, do not modify, do not archive**
> - Reports you submitted yourself (`from` is you) can be self-managed
> - **`cc` field**: if you are in `cc` (not in `to`), the file is read-only; **never** archive
> - **Violating this rule may cause loss of other agents' work state**

## Execution steps

### 1. Identity check (two-tier)

**First infer from conversation context**: if you know your role and workstation mode, use it directly. Record as `<SELF>`, and note `<mode>` (flat / team_lead).

**Only on failure** do the on-disk check:
1. Glob `_agent_team_work_zone/*/README.md` and `_agent_team_work_zone/*_team/README.md`
2. Compare conversation history and find matching workstation
3. Determine mode (ends with `_team` + contains `roundtable/`)
4. If unable to determine, stop immediately and ask

### 2. Scan two-layer inbox

#### All agents: scan top-level
Glob `_agent_team_work_zone/meeting_room/*.md` (excluding `README.md`).

#### Team lead only: additionally scan own roundtable
Glob `_agent_team_work_zone/<SELF>_team/roundtable/*.md` (excluding `README.md`).

For each file, read frontmatter and extract `status`, `from`, `to`, `cc` (if any).

### 3. Filter by permission rules

| status | from | to | cc | Can `<SELF>` archive? |
|---|---|---|---|---|
| RESOLVED | `<SELF>` | any | any | ✅ Archivable (self-published) |
| RESOLVED | other | `<SELF>` (single) | any | ❌ **Do not archive** — archiving is done by the issuer |
| RESOLVED | other | list containing `<SELF>` + others | any | ⚠️ **Do not archive** — wait for last recipient |
| RESOLVED | other | `ALL` | any | ❌ **Never archive** (belongs to publisher) |
| RESOLVED | other | other agent (not containing `<SELF>`) | `<SELF>` | ❌ **Never archive** (cc is read-only) |
| RESOLVED | other | other agent | not containing `<SELF>` | ❌ Do not archive (unrelated to you) |
| not RESOLVED | any | any | any | ❌ Do not archive |

Divide files into:
- **Archivable**
- **Skip (no authority — ALL / cc / multi-recipient / unrelated)**
- **Skip (not completed)**

### 4. Confirm with user

```
Current agent: <SELF> (mode: flat/team_lead)

✅ Archivable (you have authority):
[TOP]
- file1.md  (from: <SELF>, to: X)
[TEAM] <SELF>_team/roundtable/
- file3.md  (from: teammate_Z, to: <SELF>_team/lead)

⏭️ Skip — no authority:
- file2.md  (from: Y, to: <SELF>)        ← archived by issuer
- file4.md  (from: A, to: ALL)          ← belongs to publisher A
- file5.md  (from: B, to: C, cc: <SELF>) ← cc read-only
- file6.md  (from: D, to: <SELF>, E)     ← multiple recipients

⏳ Skip — not completed:
- file7.md  (status: OPEN)

Confirm archiving the N files in the "Archivable" list?
```

### 5. Execute move

After user confirms, **archive classified by the file's original location**:

- Top-level files → `_agent_team_work_zone/archive/`
- Department files → `_agent_team_work_zone/<SELF>_team/archive/`

```bash
mv _agent_team_work_zone/meeting_room/<filename> _agent_team_work_zone/archive/
mv _agent_team_work_zone/<SELF>_team/roundtable/<filename> _agent_team_work_zone/<SELF>_team/archive/
```

> Never move any file in the "Skip" list.

### 6. Report results

```
Archive complete (executor: <SELF>):
- ✅ Top-level archived: N → _agent_team_work_zone/archive/
- ✅ Department archived: M → _agent_team_work_zone/<SELF>_team/archive/
- ⏭️ Skipped K RESOLVED (no authority: ALL / cc / multi-recipient / unrelated)
- ⏳ Active remaining in meeting room: X (OPEN/IN_PROGRESS)
- ⏳ Active remaining in department roundtable: Y
```

## Notes

- Do not move `README.md`
- Do not move subdirectories
- When `to` is a list with other recipients remaining, **be conservative**—do not archive
- When `to: ALL`, **only archive if `from` is `<SELF>`**
- **cc field** is absolute read-only authority; **never archive**
- If in any doubt about ownership, prefer skipping over wrong archiving
- Team leads: do not archive top-level files into the department archive, nor vice versa—**original location determines archive location**
- New rule (from v0.3.0): recipients (`to` is you) no longer have archival authority, even for single-recipient files. Archival authority belongs to the issuer (`from`).
