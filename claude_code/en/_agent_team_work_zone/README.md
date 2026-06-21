<!-- FRAMEWORK:START -->
# _agent_team_work_zone/ — Multi-Agent Collaboration Workspace (Team Edition)

> This directory is a multi-agent collaboration template **that supports Claude Code's built-in Agent Teams feature**. Each Claude Code conversation takes on a specific role; simple tasks use a flat workstation for solo work, while complex tasks use the **team lead + team office** organizational structure, leveraging Claude Code's built-in capabilities such as agent-team spawn to complete end-to-end collaboration.

> **This template is adapted for Claude Code 2.1.178** (session-level auto team, `TeamCreate`/`TeamDelete` removed, the `Agent` tool's `team_name` ignored) and requires **CC ≥ 2.1.178**. If your Claude Code is ≤ 2.1.177, use **[release v0.1.0](https://github.com/SR-A-W/agent-team-work-zone/releases/tag/v0.1.0)** instead (targets the old API).

## Environment Requirements

- **Claude Code** ≥ v2.1.178 (adapted for the 2.1.178 agent-teams API; older versions use release v0.1.0)
- **tmux** ≥ 3.2 (strongly recommended: split-pane display + survives SSH disconnects; not required — falls back to in-process if absent)
- **jq** (optional, for bootstrap to merge settings.json)

---

## Initial Setup

### 1. One-click bootstrap

```bash
bash claude_code/zh/_agent_team_work_zone/resources/scripts/bootstrap.sh
```

The script will:
- Check the Claude Code version
- Install `resources/skills/` and `resources/agents/` under `.claude/`
- Create or merge `.claude/settings.json` to enable the experimental agent teams feature
- Not delete the source directory (unlike the destructive behavior of the old install_skills.sh)

### 2. Launch an interactive conversation for each role and complete onboarding

```bash
claude -n "Architect"
```

In the conversation, run the onboard skill (the agent will first ask whether you are recruiting a flat workstation or a team lead):

```
/onboard Responsible for project architecture design and experimental refactoring
```

### 3. Resume a conversation

```bash
claude --resume "Architect"
```

### 4. Sync state

After a long period of inactivity, run `/sync` in the conversation to scan workspace changes, restore identity if necessary, and check new messages.

### 5. Display mode (optional, user-level)

The display mode for team spawn must be configured in `~/.claude.json` or via a CLI flag (it cannot be fixed at the project level):

```json
{ "teammateMode": "auto" }
```

Or specify at launch: `claude --teammate-mode tmux`. See the official Claude Code documentation for details.

---

## Directory Structure

```
_agent_team_work_zone/
├── README.md                  ← the file you are reading (project charter)
├── meeting_room/              ← top-level meeting room: global communication across workstations / teams
│   ├── README.md
│   └── <Agent>_<type>_<YYYYMMDD>_<HHMM>_<description>.md
├── archive/                   ← top-level archive
├── <agent_name>/              ← flat workstation (no _team suffix)
│   ├── README.md              ← role definition
│   ├── notes.md / TODO.md / ACTIVE_JOBS.md / COMPLETED_JOBS.md
├── <agent_name>_team/         ← team workstation (ends with _team)
│   ├── README.md              ← team lead's role definition
│   ├── notes.md / TODO.md / ACTIVE_JOBS.md / COMPLETED_JOBS.md
│   ├── TEAMMATE_INFO.json     ← ★ team active-member registry (lead maintains; see docs/teammate_info_schema.md)
│   ├── roundtable/            ← intra-team communication (lead↔teammate within the team, tracker reports, etc.)
│   │   └── README.md
│   ├── archive/               ← intra-team archive
│   ├── team_recipes/          ← historical records produced by /spawn-team
│   └── teammates/             ← one subdirectory per teammate (persistent workstation; /reactivate-team restores from it on restart)
│       └── <teammate_name>/
│           ├── README.md              ← teammate's role definition (may contain ## Checkpoint Instructions section)
│           ├── working-context.md     ← Part A current-state snapshot (overwrite) + Part B work journal (append) (written by /checkpoint per rule 13)
│           ├── completed.md           ← append-only production log
│           ├── TODO.md                ← teammate's own to-do list
│           └── commitments.md         ← promises to lead / peer teammates
│
├── resources/                 ← all non-member resources
│   ├── README.md
│   ├── skills/                ← source of truth for skills (synced by bootstrap to .claude/skills/)
│   │   ├── onboard/SKILL.md
│   │   ├── sync/SKILL.md
│   │   ├── check-inbox/SKILL.md
│   │   ├── archive-resolved/SKILL.md
│   │   ├── handoff/SKILL.md
│   │   ├── spawn-team/SKILL.md
│   │   ├── promote-to-team/SKILL.md
│   │   ├── evaluate-team/SKILL.md
│   │   ├── add-teammate/SKILL.md
│   │   ├── remove-teammate/SKILL.md
│   │   └── bench-teammate/SKILL.md
│   ├── agents/                ← source of truth for general-purpose subagents (synced by bootstrap to .claude/agents/)
│   │   ├── git-repo-manager.md
│   │   ├── tracker.md
│   │   ├── investigator.md
│   │   ├── reviewer.md
│   │   └── devil-advocate.md
│   ├── role_archetypes/       ← role archetype quick reference (not auto-loaded by Claude Code)
│   │   ├── README.md
│   │   ├── coding/   (bash-scripter / model-architect / dataset-specialist)
│   │   ├── config/   (training-config-author / eval-config-author)
│   │   ├── infra/    (env-configurator / container-builder)
│   │   └── analysis/ (data-analyzer / result-reporter)
│   ├── scripts/
│   │   ├── bootstrap.sh
│   │   └── install_skills.sh
│   └── hooks/                 ← reserved, to be enabled by terminal-form automation mode
│
└── docs/                      ← documentation
    ├── agent-teams.md         ← new architecture design doc
    ├── teammate_info_schema.md
    ├── upgrade_guide.md
    └── user_manual.md
```

### Workstation Naming Conventions

| Type | Convention | Example |
|---|---|---|
| Flat workstation | `<role_name>/` (**no** `_team` suffix) | `secretary/`, `git_keeper/` |
| Team workstation | `<role_name>_team/` (**ends with** `_team`) | `architect_team/`, `planner_team/` |
| Intra-team communication | `roundtable/` under the workstation | `architect_team/roundtable/` |
| Intra-team archive | `archive/` under the workstation | `architect_team/archive/` |
| Team audit | `team_recipes/` | `architect_team/team_recipes/` |
| Team-custom role (Tier 2) | `teammates/` | `architect_team/teammates/pytorch_patcher.md` |

**Key identification**: to determine whether a conversation is currently a flat workstation or a team lead, a skill only needs to check whether the workstation directory ends with `_team` and contains a `roundtable/` subdirectory.

---

<!-- FRAMEWORK:END -->

## Project Team Members

| Role Name | English Name | Workstation Directory | Mode | Brief Responsibilities |
|--------|--------|----------|------|----------|

> **After a new agent onboards, they must add their own information to this table**. The `Mode` column takes `flat` or `team`.

---

## New Agent Onboarding Guide

When the user assigns you a role in a new Claude Code conversation, follow these steps:

### Recommended: use the `/onboard` skill

```
/onboard <task/role description>
```

The skill will first ask whether you are a **flat workstation** or a **team lead** (based on the nature of the task), then automatically complete:
- Role name extraction (decided autonomously by the agent)
- Workstation directory creation (based on the flat/team choice, create `<name>/` or `<name>_team/` and populate team-specific substructure)
- README, notes, TODO/ACTIVE_JOBS/COMPLETED_JOBS generation
- Member table registration

### Manual onboarding (for understanding the internal workflow)

1. Read this file (the project charter)
2. Decide whether you are a flat workstation or a team lead (flat / team)
3. Create the workstation directory:
   - Flat: `_agent_team_work_zone/<name>/`
   - Team: `_agent_team_work_zone/<name>_team/` plus the subdirectories `roundtable/`, `archive/`, `team_recipes/`, `teammates/`
4. Write README.md (including the full 13 work rules as a context-recovery anchor)
5. Write notes.md (working notes, organized by topic)
6. Write TODO.md / ACTIVE_JOBS.md / COMPLETED_JOBS.md
7. Register yourself in the project team member table above
8. Read `meeting_room/README.md` and (if you are a team lead) `<your workstation>/roundtable/README.md`

---

## Meeting Room and Roundtable

This project has **two levels** of communication spaces:

### Top-level `meeting_room/`

Global communication across workstations and teams. All flat workstations and team leads must scan this. Suitable for:
- Task handoff across teams
- Global announcements
- Communication between flat workstations

### `roundtable/` under each team workstation

Intra-team communication. **Only the corresponding team's lead and internal members** can see and modify it. Suitable for:
- Team lead dispatching tasks to teammates
- Collaboration between teammates
- Periodic status reports from the tracker
- Intra-team completion notifications

### Frontmatter Distinctions

**Top-level meeting_room** (unchanged):
```yaml
---
status: OPEN | IN_PROGRESS | RESOLVED
from: Architect              # agent English name, capitalized
to: Secretary                 # or ALL
date: 2026-04-11 15:30
priority: HIGH | MEDIUM | LOW
cc: [Planner, SkillSmith]    # optional, cc (read-only, no modification)
---
```

**Intra-team roundtable** (adds `kind` field; `from`/`to` use `<team>/<role>` lowercase with a slash):
```yaml
---
kind: TRACKER_REPORT | TASK | DONE | ERR | STATUS
status: OPEN | IN_PROGRESS | RESOLVED
from: architect_team/tracker  # lowercase, with team prefix
to: architect_team/lead
date: 2026-04-11 15:30
priority: HIGH | MEDIUM | LOW
---
```

See `meeting_room/README.md` and each team workstation's `roundtable/README.md` for details.

---

## Work Rules (13 items)

> **Important**: Every agent must copy the following rules in full into the README.md of their own workstation, to prevent them from being forgotten after context compression.

### 1. Low Coupling
Each agent only does what falls within its own responsibilities; no overstepping. **Specifically**:

- **Workstation ownership**: Each workstation directory (`<name>/` or `<name>_team/`) and everything inside it **belongs to its agent**. A workstation that isn't yours — **do not modify it**, including README, notes, TODO, roundtable, or any other file.
- **Team boundaries**: If you are not a team's lead or teammate, **do not write into that team's roundtable / archive / team_recipes / teammates**.
- **Promotion and migration**: Upgrading a flat workstation to a team lead **can only be invoked by that workstation itself** via `/promote-to-team`. A team lead **must not act on behalf of** another agent to do the promotion.
- **Helping out is not an excuse**: Even if you think another agent needs help, **send a TASK via meeting_room** and let them act themselves — do not modify their files directly.
- **Cost of violating this rule**: The affected agent discovers on their next `/sync` that their workstation was modified without knowing by whom or why — this breaks continuity and trust.

### 2. Sufficient Information
Reports submitted to meeting_room / roundtable must be self-contained — readers should not need to conduct additional investigation to understand them.

### 3. No Duplicate Work
Before starting work, first check whether there is already relevant information in meeting_room (and in the roundtable of your team, if applicable).

### 4. File names must include the agent name and a precise timestamp
For all files submitted to meeting_room / roundtable, use the naming format:
```
<AgentEnglishName>_<type>_<YYYYMMDD>_<HHMM>_<brief description>.md
```
The timestamp must be precise to the minute (HHMM).

The `date` field in frontmatter must also include the time:
```yaml
date: 2026-04-11 15:30
```

### 5. Keep Meeting Room / Roundtable Clean
- `meeting_room/` and each `*_team/roundtable/` should only retain files in `OPEN` and `IN_PROGRESS` state
- After a task becomes `RESOLVED`, the agent handling the task moves the file to the corresponding level's `archive/` directory (top-level files → top-level archive, team files → team archive)
- `archive/` holds historical records — don't delete them, but they don't need daily attention

### 6. Role Persistence
Each agent's `README.md` is the anchor for role memory. After context compression, read it to restore role awareness.

### 7. The User is the Project Owner
Task assignment and priorities are decided by the user; agents do not directly assign tasks to each other (except that a team lead may assign tasks to teammates within their own team).

### 8. Meeting Room / Roundtable File Permissions
- **Archival authority belongs exclusively to the issuer (`from`)**: only the file's publisher (where `from` is you) may move a file to archive. All other agents have **no archival authority**, regardless of whether `to` points to them.
- Files whose `to` field **explicitly points to you**: you may modify their `status` (e.g. set to RESOLVED), but **you may not archive them** (archiving is done by the issuer).
- Files with `to: ALL` are status reports belonging to the publisher; other agents are read-only — do not modify or archive.
- Reports you submit yourself (`from` is you) can be managed by yourself (including archiving). Archive only after confirming all recipients have marked RESOLVED.
- **`cc` field**: if you are in `cc` (and not in `to`), the file is for your awareness only — **read-only, do not change status, do not archive**.
- **Intra-team roundtable** files follow the same permission logic, but `from`/`to` are parsed as `<team>/<role>`.
- **Team lead roundtable archival coordination**: the lead is the only role that scans its own roundtable (a teammate's `/check-inbox` does not scan roundtable), so for **completed-but-unarchived** roundtable docs — if the issuer is an active teammate, the lead **may immediately notify that issuer to archive it** (the archival action is still performed by the issuer; authority is unchanged); if the issuer has been disbanded, the lead **verifies the situation, then archives it itself or transfers the doc's ownership**.
- **Violating this rule may cause loss of other agents' work state**

### 9. Task Tracking (TODO.md / ACTIVE_JOBS.md / COMPLETED_JOBS.md)

Each agent maintains three task-tracking files **under their own workstation directory**:

- **`TODO.md`**: to-do items
- **`ACTIVE_JOBS.md`**: tasks currently running (SLURM jobs, scheduled tracker triggers, etc.)
- **`COMPLETED_JOBS.md`**: history of completed or canceled tasks

**⚠ These files MUST live in the workstation directory, NOT in `~/.claude/tasks/`**:

- ✅ Correct path: `_agent_team_work_zone/<your-workstation>/TODO.md` (on local disk, persistent, survives across sessions)
- ❌ Wrong path: `~/.claude/tasks/<session-id>/...` (Claude Code's **session-scoped** task list storage — **disappears the moment the current conversation ends**; any long-term TODO there will be permanently lost)

**Can I use Claude Code's built-in `TaskCreate` / `TaskList`?** Yes, but only for **in-session short-term tracking** (e.g., "a few steps I need to do in sequence within this conversation"). It is **not** a substitute for persistent TODO. Anything you need to remember across sessions **must** be written into the workstation's `TODO.md` / `ACTIVE_JOBS.md` / `COMPLETED_JOBS.md` — only markdown files in the workstation directory have persistent local-disk backing.

**Workflow**: TODO → start execution → ACTIVE_JOBS → complete/cancel → COMPLETED_JOBS

### 10. Accumulate Working Notes (notes.md)
Each agent maintains a `notes.md` file under their own workstation directory, recording **important knowledge that will be reused** accumulated through work:
- Understanding of the project directory structure
- Frequently used commands, paths, and file formats
- Pitfalls encountered and how they were resolved
- Experience summaries for specific workflows

**How to do it**:
- Append at any time, organized by topic (not a chronological stream)
- Keep it concise; record only knowledge that is truly reused
- In the "Context Recovery" section of your own README.md, guide yourself to read notes.md

### 11. Ask Questions Readily
For non-technical questions regarding the project's core requirements, purpose, and direction, **proactive questions are encouraged**. A wrong assumption costs far more than one extra question.

### 12. Team Leads Save Context Window
If you are a **team lead** (your workstation directory ends in `_team` and contains `roundtable/`), your context window is dedicated to **coordination** — forming teams, reading teammate summaries, reporting to the user, routing across teams. You do **not** do specific hands-on work such as coding/configuring/testing; that is delegated to teammates produced by `/spawn-team`.

When receiving a task that requires hands-on work, first judge:
- Can it be done in a few messages without burning context → handle it yourself
- Exceeds 1-2 files or requires parallel investigation → form a team

**Principle**: it's better to form a team early than to scramble after the context is exhausted.

**For flat workstations**: Rule 12 also reminds you — if you foresee that a task will become complex (requires multiple specialized skills, parallel workflows, adversarial investigation), **proactively suggest to the project owner to run `/promote-to-team`** to upgrade you to a team lead. Don't soldier on alone.

### 13. Teammate Workstation Self-Maintenance + Checkpoint Duty

**If you are a teammate** (workstation at `<team>/teammates/<your-name>/`):

- The 5 files in your workstation (`README.md` / `working-context.md` / `completed.md` / `TODO.md` / `commitments.md`) are **maintained only by you**. Lead reads but does not modify (rule #1).
- After each task completion, before going idle, when you receive a "run /checkpoint" reminder, or when the lead asks, you **must** invoke `/checkpoint` to update `working-context.md`.
- **Automatic reminder (works for in-process too, as of v0.2.3)**: when you've gone more than 15 minutes since your last save and try to go idle, the `TeammateIdle` hook blocks you with `exit 2` and feeds the "run /checkpoint first" reminder straight to you, forcing a save before idle. This path sidesteps the old chain's inability to identify in-process teammates, so it works in **both** in-process and tmux modes.
- ⚠️ But **do not treat the auto-reminder as your only safety net**: it catches you at most once every 15 minutes, so an unexpected exit can still lose up to ~15 minutes of work. Checkpointing remains your **proactive duty** — write one as soon as you finish meaningful progress, don't just wait to be blocked.
- `working-context.md` is your **handoff document to your future self (the next spawn of you)**. Poorly written → next-you cannot recover state.
- `commitments.md` records promises you made to others. Anything unfinished here must be picked up by next-you even if `/checkpoint` didn't capture it in working-context.

**If you are a team lead**:

- `TEAMMATE_INFO.json` (at the root of your workstation) is your **registry**. `/spawn-team` / `/add-teammate` / `/remove-teammate` / `/bench-teammate` / `/reactivate-team` update it automatically — **do not edit it by hand**.
- Every time you start a session (`claude --resume`), pay attention to the `SessionStart` hook's reminder — if there are teammates, **run `/reactivate-team` immediately** (no-arg; restores only active/idle — benched/temporarily-offline ones are skipped). Do not assume they came back on their own (**Claude Code does not automatically respawn teammates**).
- **When you suspect a teammate is dead, ping before concluding (the most common failure point)**: in practice it's almost never "the user mis-invoked `/reactivate-team`" — it's the **lead failing to confirm and assuming a teammate is still alive**. Any static signal — the `SessionStart` hook's text, `TEAMMATE_INFO`'s `status:active`, old inbox messages, `config.json` — is **evidence of neither life nor death**; **a receipt from several turns ago doesn't count either** (a receipt is point-in-time and expires — one teardown in between voids it). So **every** time you judge live/dead (**including the inverse "they're alive, no need to reactivate"**), **re-ping on the spot and never rely on an earlier receipt**: `SendMessage` returning **`No agent named X addressable` = definitively dead** (the fastest, hardest signal); succeeded-to-inbox but no reply = unknown. **Also: context compaction ≠ session restart** — compaction is same-process and teammates are usually still alive; don't be fooled by "Session restarted" (the hook branches on `source`, but still go by the ping).
- **Temporary offline (benched) and on-demand wake**: the number of online teammates is capped by Claude Code. When a teammate is not needed in the current phase, or you need to free an online slot, use `/bench-teammate` to take it temporarily offline (full record + workstation retained, `status=benched`, **not** woken by no-arg `/reactivate-team`). Conversely, **at any point — especially when assigning work / before starting a task — the moment you judge you need a benched member's specialty, immediately propose waking it to the user**, and after the user consents (or names it directly) wake it via `/reactivate-team <name>`. The status table (active / idle / benched / offboarded) is yours to maintain and is **a black box to the user** — the user participates only at the "propose—consent" level, never touching status fields or picking from any list.
- **Proactively have teammates checkpoint before risky operations**: the automatic reminder (`TeammateIdle` + exit 2) only fires when a teammate is **itself about to go idle** and is >15 minutes past its last save, and it only caps the loss window at ~15 minutes. So before a restart / shutdown / long suspension, still `SendMessage` each active teammate to run `/checkpoint` and confirm it landed — treat the auto-reminder as a backstop, not the only safety net.
- Do not modify any teammate's workstation files (rule #1). To make a teammate do something → `SendMessage`, never edit their files directly.

**Why this rule must exist**: Claude Code's agent-teams feature **does not persist teammate state across sessions**. When the lead restarts, all teammate sessions are gone — only the teammate's own `working-context.md` + the lead's `TEAMMATE_INFO.json` + `/reactivate-team` (the three pillars) can bring the team back.

**Cost of violating this rule**: teammate state is lost, lead hallucinates that teammates still exist, team collaboration completely collapses.

---

## Pre-installed Skills

After installation, they can be triggered in a conversation via `/skill_name`. Some skills allow autonomous invocation by the agent (`disable-model-invocation: false`); others can only be triggered manually by the user.

### User-only manual trigger (`disable-model-invocation: true`)

| Skill | Command | Function |
|-------|------|------|
| onboard | `/onboard <description>` | New agent onboarding: first ask whether flat or team lead, then automatically complete naming, workstation creation, and member-table registration |
| sync | `/sync` | Sync workspace changes + role recovery after context compression |
| check-inbox | `/check-inbox` | Check the top-level meeting_room (for everyone) + the roundtable of the current team (for team leads), processed in chronological order |
| archive-resolved | `/archive-resolved` | Following rule #8, move RESOLVED meeting_room / roundtable files to the corresponding archive |
| handoff | `/handoff [--give\|--take]` | Task handoff: single skill with dual modes. The giver generates a handoff document (including why / progress / context); the receiver reads it and absorbs it into their own TODO. Treat the task as a black box |

### Agent-autonomous invocation (`disable-model-invocation: false`)

| Skill | Command | Invoked by | Function |
|-------|------|--------|------|
| promote-to-team | `/promote-to-team` | flat agent autonomously | Upgrade a flat workstation to a team lead: rename the directory, populate team substructure, add rule 12 and lead-specific sections to the README |
| spawn-team | `/spawn-team` | team lead autonomously / any agent (if flat, will first trigger promote) | 6-phase structured team formation: task decomposition, lineup proposal, plan-mode gating, adversarial check, user confirmation, emit spawn prompt + save recipe |
| evaluate-team | `/evaluate-team` | team lead autonomously | Analyze current team efficiency: which teammates are busy, idle, missing roles, redundant |
| add-teammate | `/add-teammate` | team lead autonomously | Add a teammate to an existing team |
| remove-teammate | `/remove-teammate` | team lead autonomously | Retire a teammate: graceful handoff + archive their output |
| bench-teammate | `/bench-teammate <name>` | team lead autonomously | Temporarily take a teammate offline (benched): final checkpoint + close session to free a slot, keep full record; wake later with `/reactivate-team <name>` |

**Important**: `/evaluate-team`, `/add-teammate`, `/remove-teammate`, and `/bench-teammate` are only valid in **team-lead context**. If mistakenly invoked from a flat workstation, the skill will immediately alert and refuse to execute.

### Claude Code built-in skills (use directly)

| Skill | Command | Purpose |
|-------|------|------|
| schedule | `/schedule ...` | Create scheduled remote agents (cron triggers); commonly used by team leads to launch a tracker |
| loop | `/loop <interval> <prompt>` | Repeatedly run a prompt at intervals within the current session (reserved for future autonomous mode) |

---

## General-purpose Custom Subagents

Located in `.claude/agents/` (synced by bootstrap from `resources/agents/`). These are **project-wide general-purpose** subagents that every workstation can reference via the `Agent` tool or team spawn mechanism.

| Subagent | Model | Responsibilities |
|----------|------|------|
| git-repo-manager | sonnet | Git repository management: branches, merge conflicts, history review, cleanup, tags |
| tracker | haiku | Read task status on a cron schedule and write snapshot reports. **Default intervals: training 12h / eval 4h**. Launched by the team lead via `/schedule` |
| investigator | **opus** (alias, auto-tracks latest flagship) | **Deep hypothesis-driven investigation for "the run completed but results look abnormal" cases** (not for runtime error debugging). Read-only. Uses the flagship model because deep reasoning is required |
| reviewer | sonnet | Review diffs/files against a checklist with tiered output (blocker/suggestion/nit). Read-only |
| devil-advocate | **opus** (alias, auto-tracks latest flagship) | Adversarial challenge on a plan: find counterexamples, question assumptions, enumerate failure paths. Fresh each time (no accumulated memory). Uses the flagship model because the strongest critical thinking is required |

---

## Role Archetype Quick Reference

Located under `resources/role_archetypes/`. These are **templates referenced by team leads during `/spawn-team`** — **not auto-loaded by Claude Code**, **not subagent definitions**. Their granularity sits between "general-purpose subagent" and "project-specific teammate", helping a team lead quickly draft a spawn prompt.

See `resources/role_archetypes/README.md` for details.

---

## Storage Layers for Team-Created Role Definitions (Three Tiers)

When a team lead uses role archetypes to form a team, the concrete teammate definitions produced have three storage options:

| Tier | Location | When to use | Naming |
|---|---|---|---|
| **1 (default)** | inline in the spawn prompt + `<team>/team_recipes/<timestamp>_<slug>.md` audit | one-shot task, no cross-task reuse | no prefix |
| **2 (occasional)** | `<team>/teammates/<role>.md` | same custom role reused multiple times within the team | no prefix (directory isolation) |
| **3 (rare)** | `.claude/agents/<team>_<role>.md` | want Claude Code to auto-load and be globally referenceable | **team prefix is required** to avoid cross-team conflicts |

The default path is Tier 1 — this keeps `.claude/agents/` always clean, containing only the 5 globally-general subagents. Tier 3 is only used in rare cross-team referencing scenarios.

---

## Troubleshooting

- **Claude Code version too old**: `bootstrap.sh` will error out. Upgrade to ≥ v2.1.178 (or use [release v0.1.0](https://github.com/SR-A-W/agent-team-work-zone/releases/tag/v0.1.0))
- **A skill is missing under `.claude/skills/`**: rerun `bootstrap.sh`; confirm that the source file exists at `resources/skills/<name>/SKILL.md`
- **Skill modifications don't take effect**: Claude Code loads skills when a session starts. Restart the session or refresh via the `/agents` command
- **Never edit `.claude/skills/` or `.claude/agents/` directly**: these are runtime derived copies and will be overwritten by the next bootstrap. **The source is in `resources/`; edit only the source**
