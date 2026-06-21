---
name: onboard
description: >
  Onboard a new agent: first ask whether it's a flat workstation or team lead, then create
  the corresponding directory structure, generate the role definition file and task tracking
  files, and register in the member table. Use at the start of a new agent conversation.
argument-hint: "<task/role description>"
disable-model-invocation: true
allowed-tools: Read Write Edit Glob Bash
---

# Agent Onboarding Flow (supports both flat workstation and team lead modes)

You are performing onboarding for a new agent. Follow the steps below to completion.

## Input

The user provides a role or task description through `$ARGUMENTS`. The description may already contain explicit naming, but **naming is primarily decided by you, the agent**. Only when the user proactively states a preference or rejects your naming should you adopt the user's instruction.

## Step 0: Confirm workstation mode (flat or team lead)

Before any operation, **first ask the user based on the task description**:

```
I understand the role responsibility you need is: <one-sentence summary from $ARGUMENTS>

Should this role be:
  (1) Flat workstation — a single-person workstation, suitable for simple tasks a single
      person can complete (e.g. secretary, git management, translation)
  (2) Team Lead — with a department office, suitable for complex tasks requiring multi-person
      collaboration, parallel workflows, and adversarial investigation
      (team leads do not do concrete coding/configuration/testing work; they use /spawn-team
      to assemble a team, and teammates do the hands-on work)

Which would you like?
```

Only enter the corresponding branch after the user answers clearly. **Do not guess**—if the description is ambiguous, proactively ask per work rule #11.

> **Promote**: If the flat workstation later can't handle the load, you can use `/promote-to-team` to upgrade. But **`/onboard` runs only once at the start of the conversation**, and the mode decided here is settled.

## Step 1: Read the project team charter

Read `_agent_team_work_zone/README.md` to understand:
- The team's workflow
- Existing member list
- The 13 work rules
- The currently used mode (flat / team / mixed)

## Step 2: Determine role name

**You need to determine the following three items yourself**:
- **Chinese role name** (optional) — short (2-4 Chinese characters); leave blank if your project is English-only
- **English role name** — short English (e.g. Secretary, Architect, Planner)
- **One-sentence responsibility description** — summarize the core responsibility

**Naming principles**:
- Derive appropriate names from the user's task description
- The English name is converted to lowercase underscore format for directory naming
- Flat workstation directory: `<english_name>/`
- Team lead workstation directory: `<english_name>_team/` (**must end in `_team`**)
- Names should be short, clear, and easy to distinguish

**Confirm naming with the user**:

```
I suggest this role be called:
  Chinese: <Chinese name>
  English: <English Name>
  Workstation directory: _agent_team_work_zone/<english_name>[_team]/
  One-sentence responsibility: <description>

Do you agree with this naming? If not, please tell me your preference.
```

If the user vetoes, rename per the user's preference and confirm again.

## Step 3: Create workstation directory and base files

### Flat workstation branch

Create the directory and 5 files:

```
_agent_team_work_zone/<english_name>/
├── README.md           ← Role definition + 13 work rules + flat workstation promote reminder
├── notes.md            ← Work notes
├── TODO.md             ← Pending items
├── ACTIVE_JOBS.md      ← Active jobs
└── COMPLETED_JOBS.md   ← Completed jobs
```

README.md must contain the following sections:

1. **Identity** — role name + one-sentence responsibility description
2. **Scope of responsibility** — what to do / what not to do
3. **Workflow** — typical work steps
4. **Key files** — frequently accessed file paths
5. **Work rules** — **fully copy** the 13 work rules from the project team charter (to prevent forgetting after context compaction)
6. **Work notes** — explain that this workstation has notes.md
7. **When to promote to team lead** — remind yourself: when foreseeing the task will become complex, proactively suggest `/promote-to-team` to the user (the following content must be written in):

   > **When to promote**: If newly assigned tasks require several different specialized skills
   > (e.g. both code changes and environment configuration and scripting), involve multiple
   > parallelizable work items, need adversarial review or multi-angle investigation, or would
   > significantly consume context window if a single person did them (> 50% used on execution
   > details rather than decisions), you should **proactively** suggest to the project owner
   > to run `/promote-to-team` to promote.
   > **Principle: promote early rather than rescue late**. Once context is already filled with
   > task details, assembling a team is too late—the lead cannot effectively coordinate.

8. **Context recovery** — how to recover after compaction (read README + notes + relevant meeting_room files)

### Team Lead workstation branch

Create the directory, 5 files **+ team-specific sub-structure**:

```
_agent_team_work_zone/<english_name>_team/
├── README.md                ← Contains team-lead-specific sections + rule 12/13 + 13 work rules
├── notes.md
├── TODO.md / ACTIVE_JOBS.md / COMPLETED_JOBS.md
├── TEAMMATE_INFO.json       ← Team registry (initialize with empty active_teammates)
├── roundtable/              ← Department-internal communication
│   └── README.md            ← Derived from project template or meeting_room README
├── archive/                 ← Department-internal archive
│   └── .gitkeep
├── team_recipes/            ← Audit records produced by /spawn-team
│   └── README.md            ← Explain the purpose of team_recipes
└── teammates/               ← Each teammate's workstation + Tier 2 archive
    └── README.md            ← Explain workstation structure + Tier 2 archive usage
```

**Initialize TEAMMATE_INFO.json** (must be created for every new team lead workstation, so subsequent `/spawn-team` / `/add-teammate` / `/reactivate-team` can read/write it):

> ⚠️ `<english_name>` must be a single token (no hyphen) — it is this team's **slug**, and later teammate names `<slug>-<role>` plus the idle hook's `${name%%-*}_team` workstation derivation both depend on it having no hyphen.

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

Schema details in `docs/teammate_info_schema.md`. Teammates must not modify the structure of this file; only allowed operation is a teammate updating **its own entry's** `last_checkpoint_at` during `/checkpoint`.

README.md must contain all flat-version sections **plus** the following team-lead-specific sections:

- **Team scope of responsibility** — what area this team covers / typical task types / boundaries
- **Team management** — guide to using `/spawn-team`, `/evaluate-team`, `/add-teammate`, `/remove-teammate`
- **Context preservation principle** (i.e. rule 12):

  > **Important — Rule 12**: As a team lead, your context window is dedicated to **coordination**;
  > you do not do hands-on coding/configuration/testing work. When receiving hands-on tasks, first
  > judge: can it be handled in a few messages without burning context, or does it need a team?
  > Anything beyond 1-2 files or requiring parallel investigation leans toward `/spawn-team`.
  > Teammates do hands-on work in their own sessions; you only see the summary + decisions.

- **Tracker management** — when you need to continuously monitor long tasks, how to use the built-in `/schedule` + `resources/agents/tracker.md` template to start a tracker, with output written to this team's `roundtable/`

### Work notes and task tracking common to both modes

`notes.md` initial content:
```markdown
# <English role name> Work Notes

(Important knowledge accumulated during work is recorded here)
```

Create `TODO.md` / `ACTIVE_JOBS.md` / `COMPLETED_JOBS.md` per the standard template (reference existing workstations).

## Step 4: Register in the member table

Edit `_agent_team_work_zone/README.md` and add a row to the "Project team members" table:

```
| <Chinese name> | <English name> | `<directory>/` | <flat or team> | <one-sentence responsibility> |
```

## Step 5: Read relevant communication space rules

- All agents: read `_agent_team_work_zone/meeting_room/README.md` to understand top-level meeting room rules
- Team lead additionally: read the newly created `<your_team>/roundtable/README.md` to understand department-internal communication rules

## Step 6: Completion confirmation

After all steps complete, report to the user:
- The created workstation directory path
- Workstation mode (flat / team lead)
- List of created files (5 for flat, more for team lead)
- Registered in the member table
- Current total project team member count; of which how many are flat / team
- **If team lead**: remind the user that the next step is to describe the task in natural language, and the lead will proactively suggest invoking `/spawn-team`

## Notes

- `/onboard` **runs only once**—it decides your mode at the start of the conversation. Do not rerun afterward
- If the user initially said flat workstation but later finds the task too complex, **do not** call `/onboard` again; use `/promote-to-team` instead
- Naming authority rests with the agent, but the user has veto power—don't be stubborn
- The 13 work rules **must** be fully copied into the new workstation's README (rule #6 role persistence)
