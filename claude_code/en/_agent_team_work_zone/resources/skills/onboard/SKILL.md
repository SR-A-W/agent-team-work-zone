---
name: onboard
description: >
  Onboard a new agent: first ask whether it's a flat workstation or team lead, then create
  the corresponding directory structure, generate the role definition file and task tracking
  files, and register in the member table. Use at the start of a new agent conversation.
  For first-time use, /quickstart is recommended: it creates the lead workstation and the team in one go.
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
  "schema_version": 2,
  "team_name": "<english_name>_team",
  "lead_name": "<English Name>",
  "updated_at": "<ISO8601 current time>",
  "active_teammates": [],
  "offboarded_teammates": []
}
```

Schema details in `docs/teammate_info_schema.md`. Teammates **write nothing in this file** (as of schema v2 the roster is 100% lead-written; a teammate's "last checkpoint" is reflected by its workstation `working-context.md` mtime instead). Writes to this file go through the validated atomic write: `jq` → `jq empty` parse-check → back up `.bak` → atomic `mv`; never hand-edit the JSON.

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

## Quick mode (used only by /quickstart)

/quickstart does not call this skill with the skill tool (this skill may only be invoked by the user directly); it reads this file and follows this section. When the user types `/onboard` directly, this section does not apply.

**Answers passed in by /quickstart**:
- the slug (only lowercase letters and digits, already derived by /quickstart's rules);
- the English name `<Slug> Lead`, the role name "Project Lead", a one-sentence responsibility;
- the full text of the unfinished marker `.quickstart_incomplete`.

Any item missing → do not ask the user; stop and return to /quickstart, which reports the failure.

**Do this check first** (the rest of this skill has no such rule; it applies only in quick mode): when `_agent_team_work_zone/<slug>_team/` already exists —
- it has **no** `.quickstart_incomplete` → stop, overwrite nothing, return to /quickstart reporting "a directory with the same name exists";
- it **has** `.quickstart_incomplete` → in the steps below add only the missing files; never rewrite existing ones.

**How each step runs**:

| Step in this skill | In quick mode |
|---|---|
| `## Step 0: Confirm workstation mode (flat or team lead)` | Skip; always Team Lead |
| `## Step 1: Read the project team charter` | Do it |
| `## Step 2: Determine role name` | Skip the confirmation with the user; use the names passed in. **Do not derive the directory name with this step's "lowercase with underscores" rule**; use `<slug>_team` directly |
| `### Team Lead workstation branch` under `## Step 3: Create workstation directory and base files` | **Do it; do not skip.** The warning in it that "`<english_name>` must be a single token" here applies to the slug; check it as usual. After creating the directory, write `.quickstart_incomplete` **first** (with the full text passed in), then the other files. In `TEAMMATE_INFO.json` set `team_name` to `<slug>_team` and `lead_name` to `<Slug> Lead`. In the README's team-lead sections, also write the "Switching a teammate's model" part below |
| `### Work notes and task tracking common to both modes` under `## Step 3` | **Do it; do not skip** |
| `## Step 4: Register in the member table` | **Do it; do not skip.** Add one row in this step's format: role name "Project Lead", English name `<Slug> Lead`, directory `<slug>_team/`, mode team, the one-sentence responsibility; if the member table already has a row for this directory, do not add another |
| `## Step 5: Read relevant communication space rules` | Do it |
| `## Step 6: Completion confirmation` | Skip; do not report to the user; return to /quickstart, whose closing message reports |

**The "Switching a teammate's model" part** (write it into the team-lead sections of the lead workstation README word for word, only replacing `<slug>` with this team's slug):

````markdown
### Switching a teammate's model

When the user says "switch <member name> to <model>" (for example opus), treat that as confirmed and do these five steps without asking the user again:

1. Ask that teammate to run /checkpoint and wait for its confirmation.
2. Send it a shutdown request with SendMessage (`{"type": "shutdown_request"}`) and wait for it to approve. Its status in the registry stays `active`; do not change it to `benched`.
3. Change its `model` in the registry to the target model (validated atomic write):
   ```bash
   name="<member name>"
   model="opus"
   ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
   info=_agent_team_work_zone/<slug>_team/TEAMMATE_INFO.json
   tmp="$(mktemp "$(dirname "$info")/.info.XXXXXX")" && cp -p "$info" "$tmp" \
     && jq --arg n "$name" --arg m "$model" --arg ts "$ts" '
     .active_teammates |= map(if .name == $n then .model = $m else . end) | .updated_at = $ts
   ' "$info" > "$tmp" \
     && jq empty "$tmp" \
     && cp "$info" "$info.bak" \
     && mv "$tmp" "$info" || rm -f "$tmp"
   ```
4. Run `/reactivate-team <member name>`; it spawns the teammate with the new model from the registry. Its steps ask "Confirm to begin reactivation?" — the user already asked for the switch, so continue as confirmed; do not ask the user a second time.
5. Check the model ID in the receipt (it should contain the new model name, for example opus). Expect one line saying the model does not match, because the README says sonnet: /reactivate-team compares the receipt with the `Model` line of the teammate's README, and the README is the teammate's own file, which the lead does not edit. This line is expected, not an error; ask the teammate to change its README's model line to the new model at its next checkpoint.
````

## Notes

- `/onboard` **runs only once**—it decides your mode at the start of the conversation. Do not rerun afterward
- If the user initially said flat workstation but later finds the task too complex, **do not** call `/onboard` again; use `/promote-to-team` instead
- Naming authority rests with the agent, but the user has veto power—don't be stubborn
- The 13 work rules **must** be fully copied into the new workstation's README (rule #6 role persistence)
