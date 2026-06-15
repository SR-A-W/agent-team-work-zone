---
name: sync
description: >
  Sync workspace changes and restore context. Scans project team member changes, new meeting
  room messages, and department structure updates; identifies content needing adjustment and
  generates an action list. Team leads additionally scan their department's roundtable. Also
  used for role recovery after context compaction.
argument-hint: "[--recover]"
disable-model-invocation: true
allowed-tools: Read Write Edit Glob Grep Bash
---

# Sync — Workspace Sync and Context Recovery

This skill helps you quickly sync all workspace changes and, when needed, restore your role awareness.

Applicable scenarios:
- New members joined the project team; reporting relationships or collaboration partners changed
- Returning after a break and needing to know what happened
- Context was compacted and you need to restore identity and work state
- Periodic sync to ensure your information is up to date

---

## Execution flow

### Phase 0: Identity check (two-tier)

**First try to infer from conversation context**: if you are already clear about your role, workstation, and responsibilities in the current conversation (e.g. just onboarded, noted in the system prompt, recently read your own README), use that information directly and **skip to Phase 1**.

**Only if identity cannot be determined from context** enter **recovery mode**:

1. Use `Glob` to scan `_agent_team_work_zone/*/README.md` and `_agent_team_work_zone/*_team/README.md` to find all workstations
2. Read each README's "Identity" section, compare with clues in the conversation history, and find the workstation belonging to the current conversation
3. Read that workstation's `README.md` — restore role definition, scope of responsibility, 13 work rules
4. Read that workstation's `notes.md` — restore accumulated work knowledge
5. Confirm with the user: "I am <role name>, workstation at `<directory>`, mode: <flat/team lead>, correct?"

### Phase 1: Identify your workstation mode

Based on Phase 0 results, clarify:
- `<SELF>` — your English role name
- `<workstation>` — workstation directory path
- `<mode>` — `flat` or `team_lead` (determine by whether the directory ends with `_team` + whether a `roundtable/` subdirectory exists)

Subsequent steps branch by mode.

### Phase 2: Scan project team changes

Read the **project team members table** in `_agent_team_work_zone/README.md`.

Compare with your known member list (from notes.md or memory) and identify:
- **Newly joined members**: who is new? Role, workstation mode (flat / team), responsibility?
- **Departed members**: existed before but no longer in the table
- **Role changes**: a member's responsibility or mode changed (e.g. a flat workstation was promoted via `/promote-to-team`)

Output the change summary.

### Phase 3: Scan department structure (team lead only)

If you are a **team lead**:
- **Read `TEAMMATE_INFO.json`** (the authoritative current roster source)
  - File does not exist → team has never spawned a teammate; ignore
  - `active_teammates` non-empty → record each teammate's `name` / `status` / `last_checkpoint_at`
- **Detect whether reactivate is needed**: Claude Code does NOT automatically respawn teammates across sessions. If any entry in `active_teammates` has `status=active` or `status=idle`, **those teammates are NOT present in this session** (unless `/reactivate-team` just ran). Entries with `status=benched` (temporarily offline) are **NOT counted** as needing reactivate — they are intentionally offline, woken individually by the lead via `/reactivate-team <name>` as needed
  - If the `SessionStart` hook already reminded you via `additionalContext` (check the system notice at session start), no need to judge again
  - Otherwise add a line to the Phase 6 action list: **run `/reactivate-team` to restore N teammate(s)**
- **Detect stale teammates**: if any teammate's `last_checkpoint_at` is > 24h ago, flag as "checkpoint stale"—spawn record present but may have been dysfunctional
- Check for recent team assembly records in `team_recipes/` (historical reference)
- Check for RESOLVED roundtable files pending issuer archival (`from: <SELF>` and status: RESOLVED — note in action list: archive via `/check-inbox` step 9)

If you are a **flat workstation**: skip this step.

### Phase 4: Scan meeting room and roundtable

**All agents scan**: read all files under `_agent_team_work_zone/meeting_room/` (excluding README.md).

**If you are a team lead, also scan**: all files under `_agent_team_work_zone/<your_team>/roundtable/`.

**Messages relevant to me**:
- `to` field contains my role name → tasks I need to handle
- `cc` field contains my role name → information I should be aware of (read-only, cannot modify status, cannot archive)
- `to: ALL` → global announcement

**Sort by priority**: HIGH → MEDIUM → LOW
**Group by status**: OPEN (needs action) → IN_PROGRESS (in progress)

For team leads, display `[TOP]` (top-level meeting_room) and `[TEAM]` (own roundtable) messages separately.

Output the pending message list.

### Phase 5: Check own task status

Read task tracking files under your workstation:
- `TODO.md` — what pending items? Any expired or needing updates?
- `ACTIVE_JOBS.md` — what tasks are running? Do statuses need updating? **Note**: if you are a team lead who previously started a tracker cron trigger, it will also be listed here
- `COMPLETED_JOBS.md` — what was completed recently?

Output task status summary.

### Phase 6: Generate action list

Based on all the scanning above, generate a **concrete action list**:

```markdown
## Actions to execute

### Immediate
- [ ] Reply to [filename] in meeting_room (status: OPEN, to: me)
- [ ] Process teammate progress reports in roundtable (team lead only)
- [ ] ...

### Suggested
- [ ] Update notes.md to record new member XXX's role
- [ ] Review new teammate definition (team lead only)
- [ ] ...

### Awareness only
- New member ZZZ joined the team, responsible for [duty] (no direct relation to me)
- [cc] Message X cc'd to me, read-only
```

### Phase 7: Execution confirmation

Display the action list to the user; **do not auto-execute**. Wait for user confirmation before executing item by item.

For "update my own files" type actions, tell the user exactly what will change.

---

## Output format

```markdown
# Sync Report — <role name> — YYYY-MM-DD HH:MM

## Identity status
✓ Role: <name> | Workstation: <directory> | Mode: <flat/team_lead> | Recovery: <context/file>

## Project team changes
- New members: N (list)
- Departed: N (list)
- Mode changes: N (e.g. Architect was promoted to team lead)

## Team status (team lead only)
- TEAMMATE_INFO.json: active_teammates=N, offboarded_teammates=M
- Reactivate needed: <yes/no> (reason: <teammates not auto-respawned after session start>)
- Stale checkpoint (>24h): <list teammates and timestamps> or "none"
- Recent team_recipes: <filename>, <filename>
- Roundtable RESOLVED files pending issuer archival (from: <SELF>): N

## Pending messages (N)
### [TOP] Top-level meeting_room
#### OPEN (needs action)
- <filename> from: X | priority: HIGH | summary
### [TEAM] <your_team>/roundtable/ (team lead only)
#### OPEN
- <filename> from: teammate_X | kind: TASK | summary
### Awareness only (CC / ALL)
- <filename> from: Y | summary

## Task status
- Pending: N items
- In progress: N (incl. N tracker cron triggers)
- Recently completed: N

## Action list
### Immediate
- [ ] ...
### Suggested
- [ ] ...
```

## Notes

- **Default zero file I/O**: Phase 0 tries context inference first; only read files on failure
- **cc field**: files where you appear in cc are read-only; do not attempt to modify status or archive (rule #8)
- **Team lead scans one more**: don't forget to scan your own roundtable
- **Do not auto-execute actions**: only display the list; wait for user confirmation
