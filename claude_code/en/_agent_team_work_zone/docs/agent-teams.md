# Agent Teams Architecture — New Architecture Design Doc

> **Status**: ACTIVE
>
> This document supersedes `design/hierarchy.md` as the official design for hierarchical organization of multi-agent collaboration. The four mechanisms proposed in the original `hierarchy.md` (`org_chart.yaml` / frontmatter `cc` field / `role_templates/` / `departments/` subdirectory) have become obsolete with the arrival of Claude Code's built-in Agent Teams feature.

## Background

`agent-team-work-zone` is a multi-agent collaboration template that grew out of practical experience coordinating agent tasks in a shared file-based workspace. Early versions had a **flat structure**: all agents were peers, communicating asynchronously through a shared `meeting_room/` via files.

As the project scaled, the flat structure exposed three problems:
1. **No super-subordinate relations** — cannot express "tracker reports to the lead"
2. **Roles cannot be reused** — similar roles (multiple trackers) require duplicate writing
3. **No cross-reporting** — an agent may need to report to both a team and the overall owner simultaneously

`design/hierarchy.md` proposed a **progressive four-mechanism plan** as the direction for solving this.

## Claude Code's Built-in Agent Teams Feature

In 2025, Claude Code introduced the **experimental Agent Teams** feature (requires v2.1.32+ and the `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` env flag). Core capabilities:

- **Team Lead / Teammate model**: one Claude Code session acts as the lead and can spawn several teammate sessions
- **Teammates are independent sessions**: each teammate has its own context window, a complete Claude Code session
- **Inter-teammate mailbox**: teammates can communicate directly
- **Per-teammate plan-mode gating**: certain teammates can be required to propose a plan for the lead's approval before implementation
- **Display modes**: supports tmux split panes or in-process
- **Runtime state**: stored at `~/.claude/teams/{team-name}/config.json` (**user-level**, auto-generated, not hand-editable). As of CC ≥2.1.178, `{team-name}` is **`session-<id>`** — each session auto-creates a unique session-level team and auto-cleans it on exit; the disk **no longer** accumulates dead-member ghost entries.

**Key constraints**:
- **There is no** project-level team config file (like `.claude/teams/teams.json`)
- A team is runtime: each session auto-creates a session-level team and `Agent(name=…)` auto-joins it; the `team_name` parameter is now ignored, the `TeamCreate`/`TeamDelete` tools have been removed, and the team is auto-disposed when the session exits
- Custom subagents (`.claude/agents/*.md`) can be used as role templates for teammates
- The `skills` and `mcpServers` frontmatter fields are **not** propagated to teammates
- Recommended team size: 3–5 people; coordination cost increases beyond 5

## Why the hierarchy four-mechanism plan is superseded

| Original mechanism | Current state |
|---|---|
| **A: `org_chart.yaml`** | **Obsolete**. Hierarchical levels no longer need a static config file — a team is runtime-spawned, created and destroyed once per use. A static yaml would immediately go out of date |
| **B: frontmatter `cc` field** | **Retained**. Still useful — cc functionality for cross-team / cross-workstation communication; Claude Code's built-in mailbox does not provide this "read-only broadcast" |
| **C: `role_templates/`** | **Refactored**. The role templates of the original four mechanisms are collected under `resources/role_archetypes/`, but no longer directly source `.claude/agents/`. Role archetype + team lead concretization at spawn time = two-layer model |
| **D: `departments/` subdirectory** | **Refactored**. No longer a separate subdirectory layer. Instead, workstations are named with the **`_team` suffix**, each holding `roundtable/`, `archive/`, `team_recipes/`, `teammates/` substructures. Team and flat workstations are placed **at the same level** |

## New Architecture: Flat / Team Hybrid

Core idea: **flat for simple tasks, team for complex tasks**.

### Workstation types

```
_agent_team_work_zone/
├── secretary/                  # flat workstation (no _team suffix)
├── git_keeper/                 # flat workstation
├── architect_team/             # team workstation (ends with _team)
│   ├── README.md               # team lead role definition + rule 12
│   ├── notes.md / TODO.md / ...
│   ├── roundtable/             # intra-team communication
│   ├── archive/                # intra-team archive
│   ├── team_recipes/           # /spawn-team audit
│   └── teammates/              # Tier 2 custom role archive
└── planner_team/               # another team workstation
```

The **naming convention** is the sole basis for mode recognition:
- `<name>/` → flat
- `<name>_team/` + contains `roundtable/` → team lead

### Two-layer communication

| Layer | Location | Purpose | Frontmatter |
|---|---|---|---|
| **Top-level** | `_agent_team_work_zone/meeting_room/` | Cross-workstation / cross-team communication | `from: Architect` capitalized |
| **Intra-team** | `<team>/roundtable/` | Intra-team communication | `from: architect_team/tracker` lowercase with slash + `kind` field |

`/check-inbox` automatically scans the corresponding layer based on the current agent's identity — flat only scans the top level, team lead scans both the top level and its own team's roundtable.

### Workflow skeleton

```
1. /onboard creates a flat or team-lead workstation (runs only once)
2. A flat agent foresees that the task will become complex → /promote-to-team (agent autonomous)
3. A team lead receives a complex task → /spawn-team (agent autonomous)
4. /spawn-team produces a natural-language spawn prompt; Claude Code's built-in mechanism spawns teammates
5. During team work: the lead manages via /evaluate-team, /add-teammate, /remove-teammate
6. Long-running tasks: the lead uses /schedule to launch a tracker cron trigger
7. Teammates finish their work → leave naturally
8. /check-inbox + /sync continuously gather progress
```

## Skill Invocation Model

Each skill's `disable-model-invocation` field determines who can invoke it:

| Value | Effect |
|---|---|
| `true` | **Only the user** can enter `/skill` to trigger; the agent cannot invoke autonomously |
| `false` | Both user and agent can invoke; the agent **autonomously** triggers it when it deems necessary |

### Black-box principle toward the user

All operations related to **team management** and **scheduled tasks** are a black box to the user — the user interacts in natural language and does not memorize any commands.

- `/spawn-team` is autonomously invoked by the team lead agent (after user's natural-language agreement)
- `/promote-to-team` is autonomously invoked by a flat agent (when it detects the task becoming complex)
- `/evaluate-team`, `/add-teammate`, `/remove-teammate` are autonomously invoked by the team lead
- `/schedule` is autonomously invoked by the team lead to launch the tracker (default training 12h / eval 4h)

The user only needs to invoke basic operations manually: `/onboard`, `/sync`, `/check-inbox` (archival logic is built into step 9 — no need to call `/archive-resolved` separately).

## Two-tier Identity Check

Skills with identity constraints (spawn-team, promote-to-team, evaluate-team, add-teammate, remove-teammate) all implement a **two-tier identity check**:

1. **First infer from conversation context** (default zero token consumption) — the agent usually already knows who it is
2. **Only when inference fails** read files: Glob all workstation READMEs and compare with conversation history to find a match

This avoids file I/O on every skill invocation.

## Three-tier Storage for Role Definitions

Teammate definitions created by the team lead during `/spawn-team` have three storage levels:

| Tier | Location | Applicable scenarios | Naming |
|---|---|---|---|
| **1 (default)** | inline in spawn prompt + `<team>/team_recipes/<timestamp>.md` audit | one-shot tasks | no prefix |
| **2 (occasional)** | `<team>/teammates/<role>.md` | cross-task reuse within the team | no prefix (directory isolation) |
| **3 (rare)** | `.claude/agents/<team>_<role>.md` | want Claude Code to auto-load globally | **team prefix required** to avoid cross-team conflicts |

Tier 1 is the default path. `.claude/agents/` only retains the 5 project-wide general-purpose subagents (`git-repo-manager`, `tracker`, `investigator`, `reviewer`, `devil-advocate`).

## Rule 12: Team Leads Save Context

New work rule #12:

> **A team lead's context window is dedicated to coordination**: forming teams, reading teammate summaries, reporting to the user, routing across teams. **Do not** do specific hands-on work such as coding/configuring/testing. Tasks exceeding 1-2 files or requiring parallel investigation should always lean toward forming a team.

Supplement for flat workstations: when foreseeing that a task will become complex, proactively suggest `/promote-to-team`.

## Tracker Product Form

The physical existence of the tracker is a subagent definition (`resources/agents/tracker.md`), but its **invocation form is `/schedule`**:

- The team lead invokes `/schedule` to create a cron trigger
- On each trigger, Claude Code spawns a fresh remote agent (using tracker as the role template)
- The remote agent reads state files → writes a report to `<team>/roundtable/` → exits
- Zero token consumption between triggers
- **Default cron**: training 12h, eval 4h (adjustable by the team lead based on task nature)

## Reservation for Autonomous Mode

The frontmatter of `/spawn-team` reserves a `mode: interactive | autonomous` field; currently only `interactive` is implemented. In the future, end-to-end automation will be implemented through the `/loop` + hook mechanism, extending within the same skill.


## Relationship to hierarchy.md

`design/hierarchy.md` is retained as a record of the **historical reasoning process**. Its core value:
- A complete record of the limitations of the flat structure and the author's thinking
- Although the four-mechanism plan has been superseded by Claude Code's built-in features, its **spirit** (progressive, backward-compatible, optional mechanisms) still informs the new architecture
- Some decisions in the new architecture can be traced back to open questions in hierarchy (for example, the retention of the cc field)

After this document is published, a SUPERSEDED banner will be added to the top of `hierarchy.md`.

## Scope of Impact

This architectural change involves:

- **Added**: the entire `claude_code/zh/_agent_team_work_zone/` directory (template source)
- **Modified**: 4 existing skills (onboard, sync, check-inbox, archive-resolved)
- **Added**: 5 new skills (spawn-team, promote-to-team, evaluate-team, add-teammate, remove-teammate)
- **Added**: 4 new subagents (tracker, investigator, reviewer, devil-advocate); 1 retained (git-repo-manager)
- **Added**: 9 role archetypes
- **Modified**: work rules grow from 11 to 12 items; rule 8 gains cc semantics
- **Modified**: `install_skills.sh` changed to not delete the source and to include agent installation; added `bootstrap.sh`
- **Created**: `.claude/settings.json` (env flag)
- **Refactored**: live `_agent_team_work_zone/` refactored in place (Architect/Planner upgraded to `_team`)
- **Supersede**: `design/hierarchy.md`
- **Untouched**: `claude_code/zh/_agent_work_zone/` and `claude_code/en/_agent_work_zone/` (stable flat-edition templates)

## References

- Claude Code official documentation: agent-teams
- Claude Code official documentation: sub-agents
- `design/hierarchy.md` (historical reference)
