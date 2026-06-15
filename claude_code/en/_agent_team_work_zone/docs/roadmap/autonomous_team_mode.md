# Roadmap: Autonomous Team Mode (Terminal Form)

> **Status**: RESERVED — hook-in points reserved, not implemented
>
> **Activation conditions**:
> - A more advanced Claude model available (e.g., Mythos or subsequent models)
> - Token budget allows long-running team-lead sessions
> - At least a handful of real tasks have been validated through Pattern B (current interactive mode), accumulating a reliable library of failure modes

## Goal

Enable a team-lead conversation to **complete a complex task end-to-end automatically**:

1. After receiving a task description, autonomously form a team (`/spawn-team`)
2. After spawning teammates, **continuously loop** (`/loop`):
   - Periodically read tracker output and teammate progress
   - When issues are detected, recall the investigator or other debugging roles
   - After the previous phase is complete, dispatch the next phase's tasks
   - Adjust strategy based on teammate feedback
3. No user intervention required throughout; the user occasionally returns to check `/check-inbox`
4. Once the task is finally complete, automatically write a DONE report to the top-level meeting_room for the user

## Comparison with Pattern B (current interactive mode)

| | Pattern B (interactive) | Pattern A (autonomous) |
|---|---|---|
| Driver | User conversation drives it | Lead autonomously drives via `/loop` |
| Lead session | Short-term, exits when done | Long-term, continuously running |
| Token cost | Low (on-demand) | High (continuous consumption) |
| Automation level | Semi-automatic (user participates in decisions) | Fully automatic (lead decides autonomously) |
| Risk | Low (user can correct course in time) | High (lead may drift further in the wrong direction) |
| Applicable tasks | The vast majority | Tasks requiring long unattended end-to-end execution |
| Implementation time | Already landed | Hook-in points reserved, to be implemented later |

## Reserved Hook-in Points

### 1. `/spawn-team` skill frontmatter

```yaml
---
name: spawn-team
mode: interactive      # only interactive is supported currently
---
```

The `mode` field is already reserved in the frontmatter. When `autonomous` is implemented later, a Phase 7 "start autonomous loop" will be added.

### 2. "Autonomous mode" section in team-lead README

Each team-lead workstation's README has an "Autonomous mode" section (currently labeled "Not enabled"); when enabled later, behavior changes will be described here.

### 3. `resources/hooks/` directory

Reserved for hook configurations required by future autonomous mode. Currently empty.

### 4. `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` already enabled

Because interactive mode also requires agent-team support, this env flag is already enabled in `.claude/settings.json`. When autonomous mode is enabled, no additional env flag is needed (unless Claude Code introduces a new flag in the future).

## Implementation Plan (when activation conditions are met)

### Phase 0: Prerequisites
- [ ] Confirm Mythos or a peer model is available
- [ ] Confirm the budget can afford long-running team-lead sessions
- [ ] At least 5 case studies of failures in Pattern B tasks
- [ ] Accumulate a checklist of common "drift" patterns

### Phase 1: Design autonomous loop mechanism
- [ ] Design the specific trigger cadence for `/loop` (every 30 min? every hour? triggered by the tracker?)
- [ ] Design a hook mechanism: teammate completes → notify the lead (avoid the lead actively polling teammates on every loop)
- [ ] Design a **maximum loop count** safety gate (prevent infinite runs)
- [ ] Design a **cost cap** safety gate (stop when total token spend reaches a threshold)
- [ ] Design **stop-condition detection**: task complete, stuck in a loop, serious errors, etc.

### Phase 2: `/spawn-team` extension
- [ ] Add Phase 7: start autonomous loop
- [ ] Add the rule "after entering autonomous mode, lead no longer waits for user confirmation" to the spawn prompt
- [ ] Add a `/loop` launch instruction (triggered by spawn-team's output)

### Phase 3: `/promote-to-team` extension
- [ ] Ask the user whether to enable autonomous mode during upgrade
- [ ] If yes, update the team-lead README's "Autonomous mode" section to "Enabled"

### Phase 4: New skill `/pause-autonomous`
- [ ] Emergency pause of the autonomous loop
- [ ] Let the lead fall back to interactive mode, waiting for the user
- [ ] User-triggered manually

### Phase 5: Hook integration
- [ ] Configure `resources/hooks/`, including:
  - `PostToolUse` hook: listens for teammate tool calls
  - `SubagentStop` hook: notifies the lead when a teammate completes
  - `PreToolUse` hook: requires human confirmation for high-risk tool calls (e.g., `rm`, `git push --force`)
- [ ] Install hooks in bootstrap

### Phase 6: Pilot
- [ ] Choose a low-risk task (e.g., benchmark eval) as a pilot
- [ ] Record decisions and output for each loop
- [ ] Measure token consumption
- [ ] Analyze failure cases

### Phase 7: Failure case library
- [ ] Establish a `docs/autonomous_failures/` directory to record all pilot failure cases
- [ ] Each failure case records: task description, drift point, root cause, mitigation suggestions
- [ ] These cases feed back into `/spawn-team`'s Phase 2 task decomposition, avoiding them in advance

### Phase 8: Rollout
- [ ] After confirming stability, mark autonomous mode as "Available" in the README
- [ ] Update user_manual to add "when to use autonomous mode"

## Risks and Mitigations

| Risk | Mitigation |
|---|---|
| Lead drifts further in the wrong direction | Maximum loop count, cost cap, upfront warnings from the failure case library |
| Token cost out of control | Hard cap + monitoring + user can `/pause-autonomous` at any time |
| High-risk operations triggered by autonomous (`rm -rf`, `git push --force`) | `PreToolUse` hook mandates human confirmation, even in autonomous mode |
| Deadlock in teammate collaboration | Timeout mechanism + periodic teammate status summary |
| Lead and user expectations diverge | Proactively send a STATUS report to the top-level meeting_room for the user after completing each phase |

## Not in this phase

- **Do not** make autonomous mode the default behavior — it is opt-in
- **Do not** replace interactive mode — the two coexist
- **Do not** enable for simple tasks — only for complex long-running tasks
- **Do not** allow autonomous mode to span multi-team collaboration — each autonomous lead only manages its own team

## Notes

This roadmap is currently a **placeholder**; it is not a feasibility commitment. The actual implementation will need to be re-evaluated and adjusted based on the development of Claude Code features (including the maturity of the hooks mechanism and model capabilities).

Refer to `agent-teams.md` for the design principles of this architecture.
