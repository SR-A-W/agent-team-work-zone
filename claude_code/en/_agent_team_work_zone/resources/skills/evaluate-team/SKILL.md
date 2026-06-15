---
name: evaluate-team
description: >
  Team lead evaluates the current team's efficiency and composition: who is busy, who idle,
  whether a role is missing, whether someone can be let go. Produces a structured evaluation
  report to help the lead decide whether to /add-teammate or /remove-teammate. The agent can
  invoke autonomously (after natural-language user consent).
disable-model-invocation: false
allowed-tools: Read Glob Grep Bash
---

# `/evaluate-team` — Team Efficiency and Composition Evaluation

## Identity precheck

**First infer from conversation context**: if you're already clear you're a **team lead** (directory `*_team/`, with `roundtable/`), continue.

**Only when unable to infer** do on-disk check:
1. Glob `_agent_team_work_zone/*_team/README.md`
2. Locate the team workstation corresponding to the current conversation
3. If not a team lead → stop immediately and warn:

   ```
   ⚠️ /evaluate-team is only valid in team lead context.
   Currently not a team lead. If you need to assemble a team first, run /promote-to-team.
   ```

## Phase 1: Collect current team state

### 1a. Read TEAMMATE_INFO.json (authoritative source)

**Read `_agent_team_work_zone/<SELF>_team/TEAMMATE_INFO.json`** — this is the **authoritative source** for current team roster; `team_recipes/` is only historical audit.

Extract:
- `active_teammates`: each entry's `name` / `role_source` / `model` / `scope` / `plan_mode_gating` / `spawned_at` / `last_checkpoint_at` / `revived_count` / `status`
- `offboarded_teammates`: historical offboard records (reference only)

**Pay special attention to**:
- `last_checkpoint_at` > 24h ago → flag "checkpoint stale" (may be dysfunctional or abnormally idle)
- `status == "failed_to_reactivate"` → last /reactivate-team spawn failed; user must decide manual fix vs /remove-teammate
- `status == "benched"` → temporarily offline (full record + workstation retained); **NOT counted as needing reactivate**; list as "benched, wake on demand" with `bench_reason` (note: a stale `last_checkpoint_at` is expected for benched, not an anomaly)
- `revived_count > 3` → repeated revival indicates instability; may be bad working-context.md or task unsuited for long running

If TEAMMATE_INFO.json doesn't exist or `active_teammates` is empty → team currently has no members; output "empty team" report and recommend `/spawn-team`.

Glob `_agent_team_work_zone/<SELF>_team/team_recipes/*.md` as **historical supplement**: read the latest recipe to understand what task the team was assembled for and the original design intent.

### 1b. Read roundtable/

Glob `_agent_team_work_zone/<SELF>_team/roundtable/*.md`, read frontmatter and content summary.

Count:
- **Each teammate's recent submission count** (aggregate by `from` field)
- **Each teammate's OPEN/IN_PROGRESS task count**
- **Each teammate's latest activity time** (latest file's date)

### 1c. Read ACTIVE_JOBS.md

Read `_agent_team_work_zone/<SELF>_team/ACTIVE_JOBS.md` to understand running long-term tasks (incl. tracker cron triggers).

## Phase 2: Efficiency analysis

For each teammate, judge:

| Dimension | Signal | Verdict |
|---|---|---|
| **Busy** | Frequent TASK / DONE / ERR submissions in roundtable (last 24h or per cron cadence); TODO has many items | Busy |
| **Idle** | No recent new output + no OPEN tasks on hand | Idle |
| **Stuck** | Has IN_PROGRESS with no follow-up update, or unresolved ERR | Stuck |
| **Redundant** | Two teammates have overlapping responsibilities (scopes in spawn prompt same or near-identical) | Redundant |
| **Gap** | Some type of work in the task decomposition has no one doing it (e.g. "needs smoke test" but no test-responsible teammate) | Missing role |

## Phase 3: Produce evaluation report

```markdown
# Team Evaluation — <SELF> — YYYY-MM-DD HH:MM

## Current team composition
- Total: N
- Most recent /spawn-team: <timestamp>, recipe: <slug>

## Member status
| Nickname | Role source | Model | Status | Last Checkpoint | Revive | Recent output | Open on hand | Notes |
|---|---|---|---|---|---|---|---|---|
| Fixer | code-implementer | sonnet | Busy | 10 min ago | 0 | 4 DONE (last 24h) | 2 | Main line |
| Tracker | resources/agents/tracker.md | haiku | Idle | 2h ago | 0 | 0 | 0 | Awaiting next cron |
| Reviewer | resources/agents/reviewer.md | sonnet | Stuck | ⚠️ 36h ago | 1 | 1 IN_PROGRESS | 1 | Checkpoint stale + no work update |
| DevilAdvocate | resources/agents/devil-advocate.md | sonnet | Idle | 1h ago | 0 | 2 challenge reports | 0 | Initial critique done |

## Issues found

### 🚨 Immediate action
- Reviewer stuck 36h without update → suggest lead check its session for blocker
- No teammate responsible for final xlsx result output → missing result-reporter role

### ⚠️ Consider
- DevilAdvocate finished initial critique; no recent output → can /remove-teammate to free resources
  (unless decision-time check is needed later)

### ✅ Running well
- Fixer has stable pace
- Tracker outputs on cycle

## Suggested actions

### Immediate
1. Check Reviewer session for blocker (may be technical block or context pollution)
2. /add-teammate a result-reporter (start from resources/role_archetypes/analysis/result-reporter.md)

### Optional
- /remove-teammate DevilAdvocate (if initial critique fully absorbed)

## Token cost estimate
- Active teammates last 24h consumed approx X tokens (estimated from roundtable file size)
- If current pace continues for 1 week → approx X * 7 tokens
```

## Phase 4: Request user confirmation

**Do not auto-execute** any action. Show report to user and ask:

```
What do you think of this evaluation? Which suggestion should I execute?
(Options: check Reviewer's blocker / add result-reporter / remove DevilAdvocate / other)
```

Based on user decision, call `/add-teammate`, `/remove-teammate`, or continue conversation.

## Notes

- **Evaluate only, don't execute**: this skill's role is diagnosis and recommendation, not directly changing the team
- **Imprecise quantification**: token estimate is only a rough sense; no strict statistics
- **Avoid over-optimization**: don't manufacture work just to "keep each teammate loaded"; the team lead's role is to let tasks run smoothly, not to keep teammates busy
- **Time window**: defaults to last 24h activity; adjust based on task duration
