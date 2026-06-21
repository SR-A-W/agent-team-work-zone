---
name: promote-to-team
description: >
  Promote a flat workstation to team lead: rename the directory to <name>_team/, add
  roundtable/archive/team_recipes/teammates/ subdirectories, modify README to add rule 12 and
  lead-specific sections. The agent can invoke autonomously—when a flat agent foresees the
  task will become complex, proactively suggest to the user.
disable-model-invocation: false
allowed-tools: Read Write Edit Glob Bash
---

# `/promote-to-team` — Promote Flat Workstation to Team Lead

## Identity precheck

**First infer from conversation context**: if you're already clear you're a **flat workstation** (directory has no `_team` suffix, no `roundtable/`), proceed to next step.

**Only when unable to infer** do on-disk check:
1. Glob `_agent_team_work_zone/*/README.md` and `_agent_team_work_zone/*_team/README.md`
2. Find the workstation corresponding to the current conversation
3. If it's `*_team/` with `roundtable/` → **already a team lead**; stop immediately and warn:

   ```
   ⚠️ You are already a team lead (workstation at <path>).
   /promote-to-team is only valid for flat workstations.
   If you need to manage an existing team, try /evaluate-team, /add-teammate, /remove-teammate.
   ```

4. If flat workstation → continue

## Phase 1: Confirm promotion with user

The agent explains in natural language why promotion is needed, asking the user to confirm:

```
I foresee the current task will become complex (<reasons, e.g.: need to investigate multiple
hypotheses in parallel / need multiple specialized skills / single-person completion will
significantly consume context>); I suggest promoting from flat workstation to team lead to
handle it.

After promotion:
- My workstation directory will be renamed from _agent_team_work_zone/<english_name>/ to
  _agent_team_work_zone/<english_name>_team/
- I'll gain the team-specific subdirectories: roundtable/, archive/, team_recipes/, teammates/
- My README will add rule 12 (team lead context preservation) and team management sections
- My notes.md / TODO.md / ACTIVE_JOBS.md / COMPLETED_JOBS.md are fully preserved; no work
  history lost
- After promotion, I'll use /spawn-team to assemble a team to handle the complex task at hand

Do you agree to promote?
```

**Wait for explicit user consent** before entering Phase 2. If the user declines, stay flat and push on, but record the user's decision in notes.md (for future retrospection).

## Phase 2: Rename workstation directory

> ⚠️ **`<english_name>` must be a single token (no hyphen, no underscore)** — it will become this team's **slug** (the workstation name minus `_team`). Teammates spawned later are named `<slug>-<role>`, and the idle hook derives the workstation back via `${name%%-*}_team`; if the slug contains a hyphen, the hook will split it wrong. If the current flat workstation name has a hyphen, take this rename as the chance to make it a single token.

Use `git mv` (if in a git repo) or `mv`:

```bash
git mv _agent_team_work_zone/<english_name> _agent_team_work_zone/<english_name>_team
# If not in git:
mv _agent_team_work_zone/<english_name> _agent_team_work_zone/<english_name>_team
```

At this point:
- `README.md`, `notes.md`, `TODO.md`, `ACTIVE_JOBS.md`, `COMPLETED_JOBS.md` are all retained, only the parent directory changes
- No files lost

## Phase 3: Add team-specific sub-structure

Under the new `_agent_team_work_zone/<english_name>_team/`, create:

```
roundtable/
  README.md       ← Department-internal communication rules (reference top-level meeting_room README template + describe department isolation)
archive/
  .gitkeep
team_recipes/
  README.md       ← Explains team_recipes are audit records from /spawn-team, reusable
teammates/
  README.md       ← Explains each teammate's workstation structure + Tier 2 archive usage
TEAMMATE_INFO.json ← Team registry (initialize with empty active_teammates, see below)
```

### TEAMMATE_INFO.json initialization

Create an empty registry at the team workstation root:

```json
{
  "schema_version": 1,
  "team_name": "<english_name>_team",
  "lead_name": "<English Name>",
  "updated_at": "<ISO8601 current time>",
  "active_teammates": [],
  "offboarded_teammates": []
}
```

This is the team registry mandated by Rule 13. Subsequent `/spawn-team` / `/add-teammate` / `/reactivate-team` will read/write it; `/checkpoint` updates only the teammate's own `last_checkpoint_at`. Schema details in `docs/teammate_info_schema.md`.

### roundtable/README.md content

```markdown
# <English Name> Team — Department Internal Meeting Room (Roundtable)

> This directory is the **<English Name> team internal** communication space. Only this team's
> lead and teammates may post here. Cross-team / cross-workstation communication goes to
> `../../meeting_room/`.

## Frontmatter convention

Department-internal files use the `<team>/<role>` lowercase-slash format:

\`\`\`yaml
---
kind: TRACKER_REPORT | TASK | DONE | ERR | STATUS
status: OPEN | IN_PROGRESS | RESOLVED
from: <english_name>_team/<role>   # e.g. architect_team/tracker
to: <english_name>_team/lead       # or other teammate
date: YYYY-MM-DD HH:MM
priority: HIGH | MEDIUM | LOW
---
\`\`\`

## Archive

Department-internal RESOLVED files archive to `../archive/` (not the top-level archive).
Follow work rule #8: **archival authority belongs exclusively to the issuer (`from`)**; files whose `to` addresses you may have their status changed, but may not be archived by you.
```

### team_recipes/README.md content

```markdown
# Team Recipes — Team Assembly Audit Records

This directory stores team assembly prompts and task contexts produced by `/spawn-team` as:
- Audit records (when, why, how this team was assembled)
- Reusable material (for similar future tasks, you can first check here for reference)

Each recipe is a markdown file named: `<YYYYMMDD_HHMM>_<slug>.md`.

See `/spawn-team` skill Phase 6b.
```

### teammates/README.md content

```markdown
# Teammates — Team Custom Role Archive (Tier 2)

This directory stores team custom teammate definitions **reused across tasks**.

Per the three-tier storage strategy:

| Tier | Location | Scenario |
|---|---|---|
| 1 (default) | inline in spawn prompt + team_recipes/ audit | One-off task |
| **2 (this dir)** | `teammates/<role>.md` | Reuse the same custom role multiple times within team |
| 3 (rare) | `.claude/agents/<team>_<role>.md` with team prefix | Want Claude Code to globally auto-load |

Default is Tier 1. Only when the lead finds themselves repeatedly using the same custom
teammate should it be promoted to Tier 2.
Tier 3 is rare—consider it only when global reference is needed, and **must** use team prefix
to prevent collisions.
```

## Phase 4: Update workstation README

Edit `_agent_team_work_zone/<english_name>_team/README.md`:

### 4a. Annotate mode in Identity section

Change the original
> ## Identity
> - Architect
> - Responsible for project architecture design and experimental changes...

to
> ## Identity
> - Architect (Team Lead)
> - Responsible for project architecture design and experimental changes...
> - Mode: **team lead** (workstation at `architect_team/`, has team-specific sub-structure like `roundtable/`)

### 4b. Add rule 12 to the Work Rules section

If the original README only has 11 rules, **must add rule 12** (copy from `_agent_team_work_zone/README.md`):

> ### 12. Team lead saves context window
> If you are a team lead, your context window is dedicated to coordination—assembling teams,
> reading teammate summaries, reporting to user, cross-team routing. You **do not** do
> concrete coding/configuration/testing or other hands-on work; those go to teammates produced
> by `/spawn-team`. When receiving hands-on tasks, first judge: can it be handled in a few
> messages without burning context, or does it need a team? Anything beyond 1-2 files or
> requiring parallel investigation leans toward assembling a team.
> **Principle**: assemble early rather than rescue late.

### 4c. Add "Team Management" section

After the work rules, add:

```markdown
## Team Management

As a team lead, I use the following skills to manage my team:

- `/spawn-team` — Assemble a 3–5 person team for a new complex task (I invoke autonomously after natural-language user consent)
- `/evaluate-team` — Periodically evaluate the existing team: who is busy, who idle, missing roles, redundancy
- `/add-teammate` — Add a teammate to the existing team
- `/remove-teammate` — Offboard a teammate (archive their outputs after handoff)

For continuously monitoring long-running tasks, I use Claude Code's built-in `/schedule` to
start a tracker (based on `resources/agents/tracker.md`):
- training tasks default to every 12 hours
- eval tasks default to every 4 hours
- Reports auto-written to my team's `roundtable/`

## Department-internal communication

My team's internal communication uses `architect_team/roundtable/` (see that directory's README).
Cross-team and cross-workstation communication uses the top-level `_agent_team_work_zone/meeting_room/`.
`/check-inbox` scans both.

## Context preservation principle (reiterating Rule 12)

- Task can be handled in a message or two → handle myself
- More than 1-2 files or parallel work needed → assemble team
- Already feeling context tight → immediately package remaining work for teammates; don't push on
```

### 4d. Replace the flat workstation's "When to promote" section

The flat workstation README's "When to promote to team lead" section no longer applies (you are now a team lead); delete or replace with a short note:

> ~~## When to promote to team lead~~
>
> **Promoted** — currently in team lead mode; see "Team Management" above.

## Phase 5: Update member table

Edit the member table in `_agent_team_work_zone/README.md`: change that row's `Workstation directory` column from `<name>/` to `<name>_team/`, and the `Mode` column from `flat` to `team`.

## Phase 6: Report completion

```
✅ Promotion complete

Workstation: _agent_team_work_zone/<english_name>/ → _agent_team_work_zone/<english_name>_team/

New subdirectories:
- roundtable/       (department-internal communication)
- archive/          (department-internal archive)
- team_recipes/     (team assembly audit)
- teammates/        (Tier 2 custom roles)

README updates:
- Identity section annotated "Team Lead" mode
- Added rule 12 (if previously missing)
- Added "Team Management" section
- Removed flat workstation's "When to promote" section

Retained as-is:
- notes.md
- TODO.md / ACTIVE_JOBS.md / COMPLETED_JOBS.md

Member table updated: <english_name>'s Mode column changed from flat to team

Next:
You can directly describe in natural language the task the team needs to handle; I'll
proactively invoke /spawn-team to assemble the team.
```

## Notes

- **Only triggered on flat workstation**: precheck blocks team-lead mis-invocation
- **Preserve work history**: notes / TODO / ACTIVE_JOBS / COMPLETED_JOBS fully retained
- **Prefer git mv**: if in a git repo, `git mv` preserves history
- **Execute only after explicit user consent**: don't promote unilaterally
- **13 work rules must be complete**: check whether rule 12 is indeed present in the README; if the original flat workstation README has only 11 (old version), must add it
