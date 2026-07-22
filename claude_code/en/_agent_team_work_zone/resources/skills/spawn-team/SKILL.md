---
name: spawn-team
description: >
  Structured flow for a team lead to assemble a Claude Code agent team. 6 phases: task
  decomposition → lineup proposal (selected from role_archetypes) → plan-mode gating →
  adversarial check → user confirmation → spawn each teammate via the Agent tool
  (name must be <slug>-<role>; permission mode inherits the lead, not set per-teammate at spawn) + save team_recipe. After Phase 5 user confirmation, Phase 6 spawns
  immediately with no additional confirmation. The agent can invoke autonomously; if
  currently a flat workstation, it will first guide through /promote-to-team.
disable-model-invocation: false
allowed-tools: Read Write Edit Glob Grep Agent
mode: interactive
---

# `/spawn-team` — Structured Agent Team Assembly

This skill helps a **team lead** decompose a complex task into a team lineup, then spawn each teammate via the **Agent tool** (with the `name` parameter).

> ⚠️ **Teammate vs subagent**: when calling the Agent tool, you **must pass the `name` parameter** to create a real teammate (one that joins the current session-level team and can exchange messages); without `name` you only get a regular subagent. `name` **must be of the form `<slug>-<role>` and globally unique** (see the Phase 3 naming convention).
>
> **About `team_name` (CC ≥2.1.178)**: **do not pass `team_name` anymore** — that parameter is now ignored. Each session auto-creates a unique session-level team at startup, and `Agent(name=…)` auto-joins the teammate into it; the teammate is auto-cleaned on exit.

> **`mode` field**: currently only `interactive` is supported. A future `autonomous` mode will work with `/loop` for end-to-end automation, driven by a higher-capability model.

---

## Identity precheck

**First infer from conversation context**: if you're already clear whether you're a team lead or a flat workstation, use it directly.

**Only if unable to infer** do the on-disk check:
1. Locate the workstation directory corresponding to the current conversation
2. Check whether the directory name ends with `_team` **AND** has a `roundtable/` subdirectory

### Currently a flat workstation
**Do not directly execute the spawn-team flow**; instead:
1. Explain to the user: "I'm currently a flat workstation; I need to first promote to team lead before assembling a team"
2. Ask the user: "I suggest running `/promote-to-team` first to upgrade, then we can come back to `/spawn-team`. Do you agree?"
3. After natural-language user consent, the agent autonomously invokes `/promote-to-team`
4. After promotion, return to Phase 1 of this flow

### Currently a team lead
Proceed directly to Phase 1.

---

## Phase 1: Task context collection

Extract the task description the user gave from conversation context. If info is incomplete, ask the user follow-up questions:

- **Goal**: what is this task meant to achieve? What is the success criterion?
- **Input**: which existing files/data/code/prior outputs can we use?
- **Output**: in what form is the final artifact? Written where?
- **Timing**: is there a deadline? One-off or long-running?
- **Constraints**: what can't be touched? What rules must be followed?
- **Risks**: which step are you most worried will fail?

Organize answers into a structured task description as input to Phase 2.

## Phase 2: Task decomposition

Break the task into **parallel or sequenced sub-work-items**. For each sub-item annotate:

- **Type**: write code / write config / environment config / container build / analysis / investigation / review / adversarial challenge / result reporting
- **Dependencies**: which other sub-items must complete first
- **Parallelism**: which sub-items can run concurrently
- **Estimated context consumption** (lead's judgment): high / medium / low

**Key principle** (rule 12): the lead does not do hands-on work. All hands-on sub-items go to teammates.

## Phase 3: Lineup proposal

Consult the following resources:
- **General subagents** (`resources/agents/`): tracker, investigator, reviewer, devil-advocate, git-repo-manager
- **Role archetypes** (`resources/role_archetypes/`): coding (3) + config (2) + infra (2) + analysis (2)
- **This team's existing custom teammates** (`<SELF>_team/teammates/*.md`): Tier 2 archive

Based on Phase 2 decomposition, **assemble a 3–5 person team** (**max 5**—more causes coordination cost to explode; if more than 5 are needed, explain why).

For each teammate output:
- **Role name** (`name`, **must be of the form `<slug>-<role>`, globally unique**):
  - `slug` = this team's workstation name minus the `_team` suffix, a **single token** (no `-`/`_`). E.g. team workstation `architect_team` → slug `architect`.
  - `role` = a short name for the teammate's responsibility, **may contain hyphens**. E.g. `reviewer`, `plan-a-author`.
  - Joined: `architect-reviewer`, `architect-plan-a-author`.
  - ⚠️ This naming is **load-bearing**: the idle checkpoint hook derives the workstation back from the name via `${name%%-*}_team` (the slug must be a single token with no hyphen for the hook to split it correctly). Legacy nicknames (`Fixer`, `Tracker`) are tolerated only for **existing** teammates; **every new spawn must use `<slug>-<role>`**.
- **Role source**:
  - Reference a general subagent (Claude Code auto-loads; specify by name at spawn)
  - Reference a role archetype (fill the archetype markdown content into the spawn prompt, add project-specific details)
  - Reference a team Tier 2 archive
  - Fully original inline persona
- **Model choice**: `haiku` (fast/cheap, good for mechanical polling, small edits) / `sonnet` (default, good for most coding/review) / `opus` (expensive, good for deep-reasoning architectural design)
- **Plan-mode gating**: YES means the teammate enters read-only plan mode first and submits a plan for lead approval before implementing; NO means direct execution
- **Scope**: which files/directories it can touch; **forbidden** list
- **Deliverables**: what this teammate must produce at the end (code / report / config / test results …)

### Plan-mode gating decision principles
- Requires modifying core files or multi-file refactor → **YES**
- Result will affect other teammates' work → **YES**
- Single-file local edits, test scripts, read-only analysis → NO
- Adversarial review (devil-advocate / reviewer) → NO (read-only by nature)

## Phase 4: Adversarial check (optional but recommended)

If the task is **complex with unclear direction** (e.g. no existing baseline, counterintuitive investigation results, architectural choice), suggest:

- Add a **devil-advocate** teammate to the team with explicit instruction to "find holes, challenge the plan, list failure paths, but **do not veto**—after exposing blind spots, decision authority returns to the lead"
- For investigations requiring "competing hypotheses", open 2-3 investigator teammates each holding different initial hypotheses and let them challenge each other (**note: this significantly increases token consumption**)

If the task **path is clear** (e.g. "rewrite this model's forward to support flash-attn"), **do not add** devil-advocate; proceed to Phase 5.

## Phase 5: Display lineup to user + collect feedback

Show the full proposal to the user:

```
# Team Proposal — <task summary>

## Task decomposition
1. [Sub-item A] - deps: none, parallel with: B
2. [Sub-item B] - deps: none, parallel with: A
3. [Sub-item C] - deps: A, B
...

## Lineup (N members)

### Teammate 1: <nickname> — <source: subagent_name / role_archetype/xxx.md>
- Model: sonnet
- Plan-mode gating: YES  (reason: ...)
- Scope: ...
- Forbidden: ...
- Deliverables: ...

### Teammate 2: ...

...

## Execution flow
- Phase 1 (parallel): Teammate 1 + Teammate 2 start
- Phase 2 (sequential): after Teammate 1/2 finish → Teammate 3 takes over
- Phase 3 (review): Reviewer reviews all outputs

Do you agree with this lineup? What to adjust (add/remove teammate, change model, change scope, change source)?
```

**Iterate**: adjust per user feedback until explicit user agreement. **Do not pretend the user agreed**—rule #11: when in doubt, ask.

## Phase 6: Spawn Team + Save Recipe

### 6a. Prepare a spawn prompt for each teammate

For each teammate in the Phase 5 final lineup, prepare a separate `prompt` string containing:

```
You are <nickname>, a teammate on <team_name>.

## Role definition
<archetype content / referenced subagent persona / original inline persona>

## Current task
Goal: <specific task description>
Scope: <files/directories you may touch>
No-go zones: <files/directories strictly off-limits>
Deliverables: <what to produce when done>
Plan-mode gating: <yes/no; if yes, explain approval criteria>

## Collaboration
- Important milestones, completion notices, blockers → write to _agent_team_work_zone/<SELF>_team/roundtable/
  frontmatter must include a kind field (TASK / DONE / ERR)
- Need to reach another teammate or the lead → use Claude Code's built-in mailbox (SendMessage)

## Workstation & persistence (Rule 13)
Your workstation: _agent_team_work_zone/<SELF>_team/teammates/<nickname>/
The lead has initialized 5 skeleton files (README / working-context.md / completed.md / TODO.md / commitments.md).
Before going idle, when prompted, and after task completion → call /checkpoint to update working-context.md.
This is the only bridge for recovering your state across sessions (Claude Code does not preserve teammate sessions).
If your workstation README has an old full rules section (heading matches `## Work Rules` or
`## 工作守则`, and it is NOT inside a <!-- TEAMMATE_RULES:START --> block), replace that old
section (from that heading through the next `## ` heading of the same level, or through end
of file — heading included) with the content of _agent_team_work_zone/resources/teammate_rules.md;
otherwise, if your workstation README has no <!-- TEAMMATE_RULES:START --> block, copy that
block from the same file and append it to the end of your own README (you may only edit your
own file).
```

### 6b. Initialize each teammate's workstation skeleton

For each teammate in the Phase 5 final version, create the workstation directory and 5 skeleton files (the 5 teammate self-maintained files mandated by Rule 13):

Path: `_agent_team_work_zone/<SELF>_team/teammates/<teammate-name>/`

- **`README.md`** — role definition: write the nickname, model, role source, scope, no-go zones, deliverables, plan-mode gating description, plus (optional) an empty `## Checkpoint Instructions` section for later customization; **and append the full content of `resources/teammate_rules.md` (including the `<!-- TEAMMATE_RULES:START/END -->` markers) to the end of the file**
- **`working-context.md`** — initial placeholder:
  ```markdown
  # Working Context — <teammate-name>
  _Initialized at spawn. Run /checkpoint to populate._
  ```
- **`completed.md`** — empty file (append-only log)
- **`TODO.md`** — empty file
- **`commitments.md`** — empty file

### 6c. Write / update TEAMMATE_INFO.json

Path: `_agent_team_work_zone/<SELF>_team/TEAMMATE_INFO.json`

If the file already exists (team has previously run spawn-team), **do not overwrite**; append new members to `active_teammates` instead. If this is the first spawn-team or the file doesn't exist, initialize per schema v1 (see `docs/teammate_info_schema.md`).

Each new teammate's entry:
```json
{
  "name": "<teammate-name>",
  "role_source": { "type": "...", "path": "..." },
  "model": "<haiku|sonnet|opus>",
  "plan_mode_gating": <true|false>,
  "scope": "<scope summary>",
  "spawned_at": "<ISO8601 current time>",
  "last_checkpoint_at": null,
  "revived_count": 0,
  "status": "active"
}
```

Also update the top-level `updated_at`.

### 6d. Save team recipe audit record

Save the full spawn prompt + task context + lineup design to:

```
_agent_team_work_zone/<SELF>_team/team_recipes/<YYYYMMDD_HHMM>_<slug>.md
```

Format:

```markdown
---
created: YYYY-MM-DD HH:MM
lead: <SELF>
task: <one-sentence task summary>
team_size: N
mode: interactive
---

# Team Recipe: <slug>

## Task context
<Phase 1 collection result>

## Task decomposition
<Phase 2 result>

## Lineup
<Phase 3 + Phase 5 final version>

## Adversarial check
<Phase 4: added devil-advocate / competing hypotheses? why>

## Spawn prompts (per teammate)
<Phase 6a prompt for each teammate>

## Notes
<Any experience worth reusing in future teams>
```

### 6e. Spawn each teammate via the Agent tool

Phase 5 user confirmation is the final authorization — **do not ask again**; start spawning immediately.

Call the Agent tool for each teammate:

```
Agent(
    description="Spawn <name>: <one-line role>",
    subagent_type="<see selection rules below>",
    model="<haiku|sonnet|opus>",   # from Phase 3 decision
    name="<slug>-<role>",          # ← required; without this it's just a subagent; must be <slug>-<role>, matching the workstation directory name
    prompt="<prompt prepared for this teammate in 6a>"
)
```
> CC ≥2.1.178: **do not pass `team_name`** (it is ignored). The teammate is auto-joined into the current session-level team by `Agent(name=…)`.
> **Also do not pass `mode`**: a teammate's permission mode cannot be set per-teammate at spawn — it **inherits the lead's current permission mode** (see "Permission mode vs `teammateMode`" below).

**subagent_type selection rules**:
- `role_source.type == "subagent"` → `subagent_type = role_source.subagent_name` (e.g. `"tracker"`, `"reviewer"`)
- `role_source.type == "archetype"` / `"tier2"` / `"inline"` → `subagent_type = "general-purpose"` (role injected via prompt)

**Spawn order**: follow execution dependencies — teammates that can run in parallel may be spawned together in a single message with multiple Agent calls; those with ordering dependencies spawn sequentially.

**After all spawns complete**, output a brief confirmation:

```
✅ teammates/ workstation skeletons created (N teammates × 5 files)
✅ TEAMMATE_INFO.json initialized/appended (N active_teammates)
✅ team_recipes/<timestamp>_<slug>.md saved
✅ Team spawned: <nickname1>, <nickname2>... — standing by for first task
```

---

## Terminal / tmux (only read if a spawn reports a tmux error, or you want to tune display/persistence)

> tmux is **not** a requirement for agent teams — in-process mode runs the full team feature set in any terminal. This section is only relevant if you hit the errors below, or want to change display/persistence; the normal spawn flow **needs none of it**.

**What the two tmux spawn errors mean** (the hard version/environment check is handled by `bootstrap.sh`; this skill does **not** run checks itself):
- `Failed to create teammate pane: size invalid` → you're inside tmux, but the tmux version is too old (< 3.0). Upgrade tmux ≥ 3.0 (3.6a verified), or exit tmux and use in-process.
- `Could not determine current tmux pane/window` → the tmux on PATH differs from the one owning the current session (`$TMUX` socket) — multiple tmux installs coexist. Point PATH at the tmux that started the current session.
- bootstrap **pre-empts and diagnoses** both once you're inside tmux — if you see one, **re-run bootstrap** and follow its guidance.

**Permission mode vs `teammateMode` (two different things, don't conflate)**:

- **Permission mode** (`default` / `acceptEdits` / `auto` / `plan` / `bypassPermissions`): controls whether the teammate prompts for permission on tool calls. **A teammate inherits the lead's permission mode at spawn — official docs state per-teammate modes cannot be set at spawn time** (`Agent(mode=…)` has no effect on a teammate's permission mode). To start teammates in **auto mode**, put the **lead itself in auto** (`Shift+Tab`, or set `permissions.defaultMode:"auto"` in `settings.json` so the lead starts in auto and teammates inherit it); after spawn you can only change modes per-teammate by hand.
- **`teammateMode` (a `settings.json` field)**: controls only **how the teammate is displayed** in the terminal (pane-split vs in-process); nothing to do with permissions.

**`teammateMode` (display mode, a settings.json field)**:

| Value | Behavior |
|---|---|
| `in-process` | all teammates in the main terminal; ↑↓ to navigate + Enter to view/message; works in any terminal. **Default (since CC v2.1.179)** |
| `auto` | inside a tmux session **or** iTerm2 → split panes; otherwise falls back to in-process |
| `tmux` | enables split panes; auto-detects whether to use tmux or iTerm2 |
| `iterm2` (CC v2.1.186+) | explicitly use iTerm2 native split panes (requires `it2` CLI) |

- `teammateMode` is a **user-level** setting (`~/.claude/settings.json`); you can also use `--teammate-mode` to override for a single session; split panes require tmux or iTerm2.
- Want split panes → use `auto` (inside tmux/iTerm2) or `tmux`; **idle teammates stay visible**: one independent pane per teammate, so you can see who is working, stuck, or idle at a glance.
- Don't want panes split → use `in-process` (works in any terminal, no loss of functionality). **Don't hand-edit settings.json** — re-run `bootstrap.sh`'s "display mode selection" menu (it writes to the **global** `~/.claude/settings.json`). See the tmux section of `docs/user_manual.md`.

---

## Notes

- **Rule 12 applies throughout**: the lead does not do hands-on work; complex tasks must be teamed, not done solo
- **Max 5**: beyond that coordination overhead spikes significantly
- **Dialogue is the black box**: the user interacts with the lead in natural language only; `/spawn-team` is invoked autonomously by the agent, and the user doesn't need to memorize commands
- **Team recipe is a reusable asset**: for future similar tasks, the lead can first check `team_recipes/` for precedent
- **Agent tool must carry `name` (`<slug>-<role>`)**: without `name` you only get a regular subagent that cannot join the team or exchange messages; `team_name` is ignored on CC ≥2.1.178 — don't pass it. Phase 5 user agreement = final authorization — call Agent directly, no second confirmation
- **`mode: interactive` annotation**: the frontmatter position is reserved; when switching to `autonomous` in the future, extend this file's Phase 7 (start `/loop` + hook)
