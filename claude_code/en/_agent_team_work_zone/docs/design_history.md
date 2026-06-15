# Design History — Agent Teams Refactor

> This document records the design-decision process of the `_agent_team_work_zone/` refactor during 2026-04, as historical reference. For the final architecture, see `agent-teams.md`.

## Timeline

- **2026-04-08**: Secretary submits `Secretary_TASK_20260408_1600_experimental_hierarchical_zh_template.md` to the meeting_room, proposing to land the original hierarchical plan (four mechanisms) in an experimental Chinese subdirectory.
- **2026-04-09**: Architect onboards (`/onboard`), reads the Secretary's task and `design/hierarchy.md`.
- **2026-04-09 ~ 2026-04-11**: Architect has multiple rounds of discussion with the project owner, gradually confirming the direction of the new architecture.
- **2026-04-11**: The final plan is settled and approved through plan mode, entering the implementation phase.

## Key Decision Points and Rationale

### 1. Why the original hierarchical four-mechanism design was abandoned

The original `design/hierarchy.md` proposed four mechanisms (`org_chart.yaml` / `cc` field / `role_templates/` / `departments/` subdirectory) as a progressive hierarchical adoption plan.

**Decision**: abandon A (org_chart.yaml) and part of D (departments/ as a separate subdirectory layer); keep B (cc field) and the **spirit** of C (refactored into role archetypes + custom subagents).

**Rationale**:
- Claude Code's built-in Agent Teams feature directly covers the "hierarchical organization" need — a team is runtime-spawned, and a static yaml would immediately go out of date
- The original plan was "a workaround designed for a Claude Code with no team mechanism at all"; it is no longer necessary
- But the cc field is still useful (for cross-team communication scenarios), and the **idea** of the dept substructure is kept (named with a `_team` suffix instead of a separate directory layer)

### 2. Why "flat + team hybrid" instead of turning everything into a team

**Discussed**: whether to upgrade all agents to team leads?

**Decision**: do **not** turn everything into teams. Simple tasks such as Secretary, GitKeeper, and Translator remain flat.

**Rationale**:
- Every teammate in a team occupies an independent session; **token consumption increases significantly**
- For "coordination" tasks, "single-thread tasks", and "single-file modification" tasks, solo work is more efficient
- Only complex tasks (multiple specialized skills, parallel workflows, adversarial investigation) are worth the coordination overhead of a team
- The user clearly prefers: don't use a team for the sake of using a team

### 3. Why management skills such as spawn-team became agent-autonomous

**Discussed**: the original design had `/spawn-team` as `disable-model-invocation: true`, user-triggered manually.

**Decision**: change to `disable-model-invocation: false`; the agent invokes autonomously (after the user agrees in natural language).

**Rationale**:
- User feedback: "The human user should converse in natural language and shouldn't have to remember commands"
- The team lead agent knows best whether a task needs a team, which roles are needed, and when to form one
- Ideal user experience: describe the task → the agent proposes to form a team → the user agrees → the agent autonomously executes
- Black box to the user: `/spawn-team`, `/promote-to-team`, `/schedule` (for tracker), etc. are all handled by agents

**Skills retained as manual-trigger**: `/onboard`, `/sync`, `/check-inbox`, `/archive-resolved`. These are skills the project owner would actively run when "reviewing project state" — keep user control.

### 4. Why the tracker uses `/schedule` rather than `/loop` + long-running team-lead session

**Two polling mechanisms were discussed**:

#### Pattern A: `/loop` + long-running team-lead session
- The team lead runs `/loop`, automatically checking progress and deciding the next step every so often
- **Pros**: end-to-end fully automatic
- **Cons**: (1) extremely high token consumption; (2) the lead may drift further and further in the wrong direction

#### Pattern B: `/schedule` + scheduled tracker
- The tracker is an independent scheduled remote agent; each trigger starts a fresh session that reads state, writes a report, and exits
- **Pros**: low cost; the session does not need to run persistently; can be landed now
- **Cons**: not end-to-end automatic (the user reads reports and makes decisions when back)

**Decision**: Pattern B as the primary landing; Pattern A reserved as "terminal form" (the `mode: autonomous` field) to be implemented when more advanced models are available.

### 5. Why `/onboard` runs only once and does not handle upgrades

**Discussed**: whether `/onboard` should handle both first-time onboarding and subsequent upgrades.

**Decision**: `/onboard` runs only once at the start of the conversation; upgrades use the dedicated `/promote-to-team`.

**Rationale**:
- `/onboard` is a one-time operation at conversation establishment
- Upgrade is a dynamic change during operation, and must preserve existing work history (notes, TODO, etc.)
- Splitting into two skills gives clearer responsibilities

### 6. Why intra-team communication is called `roundtable` rather than `meeting_room`

**Candidates discussed**: `roundtable`, `huddle`, `war_room`, `workshop`, `briefing`, `squad_room`.

**Decision**: `roundtable`.

**Rationale**:
- Forms a clear hierarchical contrast with the top-level `meeting_room` (big hall vs. a small roundtable)
- Neutral, usable, positive semantics, translatable between Chinese and English
- The user originally proposed it

### 7. Why `resources/` instead of `commons/` or `lib/`

**Candidates discussed**: `resources`, `commons`, `library`, `toolbox`, `depot`, `armory`.

**Decision**: `resources` (tentative; may adjust in the future).

**Rationale**:
- Most direct; developers can tell its purpose at a glance
- No association with a specific tech stack
- Can note in the developer_manual that "future versions may rename"

### 8. Why team workstations use the `_team` suffix instead of `departments/<name>/`

**Discussed**: whether to place all team workstations under a `departments/` subdirectory as a separate layer.

**Decision**: abandon the `departments/` layer; all workstations (flat and team) are placed **at the same level** under `_agent_team_work_zone/`, distinguished by the naming convention `_team` suffix.

**Rationale**:
- Reduces directory depth
- Flat and team can be seen at a glance without switching directories
- The naming convention is sufficient to express type
- Upgrade path is simple: `mv architect architect_team && mkdir roundtable archive ...`

### 9. Why three tiers of role definition storage (Tier 1/2/3)

**Discussed**: the user was concerned about naming conflicts when two teams have roles with the same name (both have eval-config-author).

**Decision**: three-tier strategy:
- Tier 1 (default): inline in spawn prompt + `<team>/team_recipes/` audit
- Tier 2 (occasional): `<team>/teammates/<role>.md` archived; directory isolation avoids conflicts
- Tier 3 (rare): `.claude/agents/<team>_<role>.md`; **team prefix required** to avoid conflicts

**Rationale**:
- Default Tier 1 keeps `.claude/agents/` clean, containing only the 5 globally general subagents
- Tier 3's team-prefix rule completely eliminates conflicts
- Progressive layering — Tier 1 is sufficient for most scenarios

### 10. Why role archetypes are not subagent definitions

**Discussed**: whether to make roles like "tracker" and "bash-scripter" into Claude Code auto-loaded subagents.

**Decision**: only **precisely scoped** roles are made subagents (5 of them: tracker, investigator, reviewer, devil-advocate, git-repo-manager). Roles like "bash-scripter" and "coder" that have **insufficient granularity** are made into **role archetype** templates (9 of them).

**Rationale**:
- User feedback: "A name like 'coder' is too broad — writing training config vs. writing PyTorch vs. writing bash requires completely different system prompts"
- Role archetypes follow a **generic template + task-level concretization** two-layer model: layer 1 is a project-agnostic responsibility description, and layer 2 is project-specific details filled in by the team lead at spawn time
- Precisely scoped subagents (tracker, reviewer, investigator, devil-advocate) essentially only do **read-only / observe / critique**-type work — those responsibilities can naturally be precisely defined
- Implementation-layer coder work is customized per project by the team lead

### 11. Why result-reporter specifically produces xlsx tables

**Discussed**: the core output form of result-reporter.

**Decision**: specifically emphasize xlsx tables + visualization charts.

**Rationale**:
- User feedback: "Reports are for **humans** to read, not for agents; xlsx tables are the most efficient way for humans to absorb data"
- Especially for eval results, "the human owner should understand at a glance"
- Distinguish data-analyzer (fact extraction for agents to consume) from result-reporter (presentation for humans)

### 12. Why env-configurator and container-builder have a prerequisite chain

**Discussed**: the division of responsibility for infra-type roles.

**Decision**: two independent roles, env-configurator **first**, container-builder **second**; container-builder **assumes the env is already working**, and when encountering pip issues must recall env-configurator rather than solving them itself.

**Rationale**:
- User feedback: "The environment-configuring agent shouldn't be responsible for writing SLURM scripts; on the contrary, SLURM scripts are more like bash scripts" — implying that infra role responsibilities should be clear
- Further feedback: "container-builder should focus on the image itself; for pip issues it should recall env-configurator"
- The prerequisite chain is written at the top of both archetypes, avoiding the team lead mismatching roles during `/spawn-team`

### 13. Why live `_agent_team_work_zone/` is retained and gitignored

**Discussed**: whether to also include the live workspace in git tracking.

**Decision**: `_agent_team_work_zone/` is kept in `.gitignore` as the developer's personal dogfood field; not published as a template.

**Rationale**:
- The live workspace contains each developer's personal conversation state (notes, TODO, team_recipes, etc.), which is not suitable for sharing
- The template source-of-truth is published under `claude_code/zh/_agent_team_work_zone/`, clean and copyable
- The existence of live allows the dev repo itself to work with the template (dogfood) — a special convention

### 14. Why the two-tier identity check (context first, file as fallback)

**Discussed**: how a skill should know the current agent's identity and mode.

**Decision**: two-tier check — first infer from conversation context (zero I/O); read files as fallback (Glob + comparison) only on failure.

**Rationale**:
- User feedback: "Agents usually already know who they are and don't need to read files each time — it consumes tokens"
- But for robustness, file fallback is needed when context is unreliable (when context has been compressed)
- The two-tier strategy satisfies both normal efficiency and edge-case safety

### 15. Why the default tracker cron is 12h / 4h rather than 30 minutes

**Candidates discussed**: 30 minutes (aggressive) vs. 12 hours (conservative).

**Decision**: training 12h, eval 4h (user's choice).

**Rationale**:
- User feedback: "30 minutes is too frequent; my tokens will be blown up"
- 12h/4h is sufficient to catch abnormal signals (at the scale of multi-day training / multi-hour eval)
- The team lead can adjust based on the nature of the task, but the default puts token budget first

## Undecided and Deferred

### Deferred implementation
- **Terminal form (Pattern A) autonomous mode** — awaiting more advanced models + sufficient budget
- **English version** (`claude_code/en/_agent_team_work_zone/`) — to be generated by the Translator once zh is stable
- **ML-specific role archetypes** — such as slurm-submitter and vllm-compat-specialist, to be added when the project actually needs them

### Needs verification
- Usability of `bootstrap.sh` in real downstream user projects (currently only verified via dev-repo dogfooding)
- Whether the natural-language prompt emitted by `/spawn-team` is reliably recognized by the Claude Code agent-team mechanism
- Stability of tracker actually running in an HPC SLURM environment

## Participants

- **Project owner** — final decision-maker on all architecture decisions
- **Architect (team lead, myself)** — research, proposal, implementation
- **Secretary** — raised the original TASK, coordinated task dispatch
- **SkillSmith** — independently designed and implemented the `/handoff` skill (task handoff tool)
- Other agents were not directly involved in this refactor (some will be passively synced to the new architecture via `/sync`)

---

## Follow-up notes (patches discovered during actual use)

### 2026-04-12: First `/spawn-team` dogfood and patches

After the refactor, we conducted the **first real `/spawn-team` end-to-end test** — translating `claude_code/zh/_agent_team_work_zone/` into `claude_code/en/_agent_team_work_zone/` (35 markdown + 2 bash scripts) via a 4-person parallel agent team.

**Result**: Translation succeeded, en version's bootstrap runs independently. Several important issues surfaced.

#### Finding 1: Rule #1 was too vague, needed concrete sub-clauses

**Incident**: During Phase 6 live-workspace refactor, Architect ran `mv planner planner_team` + created team subdirs + rewrote the README as a team-lead version **on behalf of Planner** — violating Planner's ownership of its workstation.

**Root cause**: Original Rule #1 only said "no overstepping", without explicitly forbidding "**do not modify other agents' workstation directories**". `/promote-to-team` was correctly designed to only be self-invoked, but no rule prevented manual bypass.

**Patch** (applied): Rule #1 expanded into 5 sub-clauses covering workstation ownership, team boundaries, promotion-must-be-self-invoked, helping-is-not-an-excuse, and the cost of violation. Modified in both zh and en READMEs.

#### Finding 2: `run_in_background: true` + session interruption = dead agents

**Incident**: First spawn of 4 translators used `run_in_background: true`. Parent session was interrupted mid-work; all 4 agents died, their temporary output files were cleaned, and zero files were written.

**Root cause**: Claude Code background agents are child tasks of the parent session; when the parent is interrupted, they are terminated.

**Lesson**: For "wait-for-results" work, use **foreground parallelism** (multiple Agent calls in a single message execute in parallel; parent blocks until all complete). Background mode suits "launch and forget" workflows — with session interruption risk.

**Patch**: No skill change (this is generic Claude Code behavior). Recorded in `notes/`.

#### Finding 3: `/spawn-team` prompt didn't warn about Unicode in code strings

**Incident**: Translator-Mech replaced `✓`/`✗`/`⚠`/`↻` inside bash echo strings with ASCII — treating them as "emoji" and applying the generic no-emoji rule. These were functional characters in the zh source.

**Lesson**: For translator-type teammates, explicitly state in the spawn prompt: "Unicode symbols inside code strings are functional, not decorative emoji — preserve as-is."

**Patch**: Remember for future spawn prompts; not baked into the `/spawn-team` skill.

#### Finding 4: ~~Agent tool schema lacks `team_name` parameter~~ **[2026-04-16 RETRACTED]**

> **⚠ This finding has been disproven.** See [`error_reports/2026-04-16_subagent_vs_teammate_confusion.md`](../../../error_reports/2026-04-16_subagent_vs_teammate_confusion.md) (report in Chinese).
>
> **Truth**: The Agent tool's displayed schema does not list `team_name` and `name`, but the **runtime actually accepts** these parameters. **The original issue was my misreading of the schema, not a Claude Code bug.** The 4 "translator teammates" in the 2026-04-12 task were in fact subagents — I never actually started a team.
>
> Verified on 2026-04-16 with test-teammate: passing `team_name` + `name` to the Agent tool successfully spawns a real teammate, adds it to the team config members array, SendMessage routes by name through the mailbox, and the response format is `<teammate-message>` (not subagent `<task-notification>`).
>
> **The 2026-04-12 translation output remains valid** (subagents can do mechanical work just fine), but the "first real team dogfood" framing was inaccurate. A true team dogfood is deferred to the upcoming TODO #16.

#### Finding 5: Phase 3 of `/spawn-team` could prompt about teammate communication mode

**Incident**: No teammate-to-teammate communication in this task — the lead judged it independent parallel work. Result was correct, but Phase 3 currently does not explicitly guide the lead to decide whether communication is needed.

**Patch** (optional/deferred): Future Phase 3 could include a "communication mode: independent / partial / tight" sub-step. Noted for later.

#### Finding 6: Agent tool subagents are ephemeral, leave no history

**Incident**: The 4 translators auto-released after completion; no preserved conversation history; `architect_team/teammates/` remains empty.

**Clarification**: Expected behavior — `teammates/` is for Tier 2 custom role templates, not runtime teammate history. The audit trail for a given spawn is in `team_recipes/`.

**Lesson**: First-time users may confuse these concepts. Consider clarifying in user_manual.

**Patch** (deferred): A future pass on user_manual to clarify "what happens after a team completes & where to find historical evidence".

---

### Summary

First dogfood revealed 1 critical rule-hole fixed immediately (rule #1 sub-clauses), 3 lessons to track long-term (background agent lifecycle, Unicode handling, team_name schema mismatch), and 2 optional future optimizations. **The core architecture is sound** — 35 files translated in parallel, en version's bootstrap runs independently.
