# Meeting Room — top-level cross-workstation meeting room

> This is the hub for **cross-workstation / cross-team** asynchronous communication among all agents.
>
> **Note**: for intra-department communication, use each team workstation's `roundtable/`; do not put it in the top-level meeting_room. The top level only handles cross-workstation, cross-team global matters.

## Top Level vs Intra-Department Roundtable

| Scenario | Where it should go |
|---|---|
| Communication between flat workstations (Secretary <-> GitKeeper) | Top-level meeting_room |
| Task handoff between a flat workstation and a team lead | Top-level meeting_room |
| Communication between team leads | Top-level meeting_room |
| Global announcement (project owner broadcast) | Top-level meeting_room, `to: ALL` |
| Inside a team: lead <-> teammate dispatch | **The corresponding team's `<team>/roundtable/`** |
| Inside a team: tracker periodic report | **The corresponding team's `<team>/roundtable/`** |
| Inside a team: teammate-to-teammate collaboration | **The corresponding team's `<team>/roundtable/`** |

---

## Submitting Reports

Place information that other workstations need to know as markdown files in this directory.

**File naming convention** (must include the agent name + timestamp to the minute):
```
<AgentEnglishName>_<Type>_<YYYYMMDD>_<HHMM>_<brief_description>.md
```

Type prefixes:
- `ERR` — error report (problem found, needs another agent to fix)
- `PROJECT_STATUS` — project progress snapshot
- `TASK` — task handoff (needs a specific agent to take over execution)
- `DONE` — completion notice (some work is done; relevant agent may proceed with follow-up)
- `STATUS` — other status updates

Examples:
- `Architect_ERR_20260411_1530_vllm_compat_issue.md`
- `Planner_DONE_20260411_0930_refactor_plan_ready.md`
- `Secretary_PROJECT_STATUS_20260411_1800_weekly_update.md`

**The file header must contain frontmatter**:
```yaml
---
status: OPEN | IN_PROGRESS | RESOLVED
from: <sender Agent English name>   # capitalized
to: <target Agent English name> or ALL   # capitalized
date: YYYY-MM-DD HH:MM               # must include time
priority: HIGH | MEDIUM | LOW
cc: [Agent1, Agent2]                 # optional, carbon copy; cc'd parties are read-only
---
```

---

## Reading Reports

- Before starting work, check this directory for files whose `to` field points at you or at `to: ALL`
- If you are a **team lead**, also check your team's `roundtable/` (`/check-inbox` scans both locations)
- Pay special attention to reports with `status: OPEN` and relevant to your responsibilities
- After taking over a task, update status to `IN_PROGRESS`
- Once complete, update status to `RESOLVED`, briefly note the outcome (archiving is done by the issuer on their next `/check-inbox`)

## Archival Rules

- Files with RESOLVED status must be moved from this directory to `../archive/`
- **Archival authority belongs exclusively to the issuer (`from`)**: only the file's publisher may execute the move
- Recipients (`to`): once your work is done, set status to RESOLVED — **do not move the file to archive**
- `/check-inbox` step 9 automatically scans the issuer's completed docs and prompts for archiving
- This directory stays clean, containing only pending and in-progress tasks
- `../archive/` is a historical record, kept and not deleted
- **Work rule #8**: files with `to: ALL` or where you are in `cc` are read-only — do not modify or archive

## Multi-Recipient File Template

When a task requires multiple agents to complete jointly, add a **Completion Checklist** at the end of the file for each recipient to check off:

```yaml
---
status: OPEN
from: Issuer
to: [A, B, C]
date: 2026-06-11 09:00
priority: HIGH
---

...task body...

## Completion Checklist
- [ ] A: (pending)
- [ ] B: (pending)
- [ ] C: (pending)
```

Once a recipient takes on the task, they set `status` to `IN_PROGRESS` (or add a "started: YYYY-MM-DD HH:MM" note to their checklist row) to signal they have claimed it. Once their part is done, they check off their row and append a timestamp + summary. The last one to finish sets `status` to `RESOLVED`. On the issuer's next `/check-inbox`, step 9 detects `status: RESOLVED` or a fully-checked checklist and archives the file.

## Notes

- Reports must be self-contained: the reader should not have to dig through logs or other files to understand
- If specific files are involved, give full paths
- If errors are involved, paste the key error messages
- The `cc` field is for notification only, and cannot be used to bypass `to` permissions
