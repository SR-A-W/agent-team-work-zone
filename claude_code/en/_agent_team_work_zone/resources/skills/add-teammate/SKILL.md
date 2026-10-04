---
name: add-teammate
description: >
  Add a teammate to an existing team: runs a simplified spawn-team flow (single person only).
  Team lead can invoke autonomously (after natural-language user consent). Valid only in team
  lead context.
disable-model-invocation: false
allowed-tools: Read Write Edit Glob Grep
---

# `/add-teammate` — Add a Teammate to an Existing Team

## Identity precheck

**First infer from conversation context**: you should already know you're a team lead. **When unable to infer**:
1. Glob `_agent_team_work_zone/*_team/`
2. Locate the team corresponding to the current conversation
3. If not a team lead → stop immediately and warn

## Phase 1: Collect new teammate requirements

From the user or conversation context, collect:
- **Why a new teammate is needed**: what capability is missing from the existing team?
- **Task details**: what concrete work will the new teammate do?
- **Boundaries**: what can / cannot it touch?
- **Relationship to existing teammates**: collaborate / take over / review?

## Phase 2: Choose role source

Consult:
- **General subagents** (`resources/agents/`): tracker / investigator / reviewer / devil-advocate / git-repo-manager
- **Role archetypes** (`resources/role_archetypes/`): 9 options
- **This team's Tier 2 archive** (`<SELF>_team/teammates/`)

**Principle**:
- Prefer existing general subagents (no customization; reference by name at spawn)
- Next use role archetypes (fill project-specific details)
- Only as last resort use original inline persona or new Tier 2 entry

## Phase 3: Show proposal to user

```
## New teammate proposal

- **name**: <slug>-<role> (**must** be `<slug>-<role>` format: slug = this team's workstation name minus `_team`, a single token with no hyphen; role may contain hyphens. E.g. `architect-reviewer`. Globally unique)
- **Role source**: <subagent name / role_archetype path / original>
- **Model**: <haiku / sonnet / opus>
- **Plan-mode gating**: <YES / NO>
- **Scope**: <concrete files/directories it can touch>
- **Forbidden**: <can't touch>
- **Deliverables**: <what it produces>
- **Collaboration with existing team**: <who assigns it work, who receives its output>

Do you agree to add this teammate?
```

Proceed to Phase 4 only after explicit user consent.

## Phase 4: Create teammate workstation skeleton + register in TEAMMATE_INFO.json

### 4a. Create teammate workstation directory + 5 skeleton files

Path: `_agent_team_work_zone/<SELF>_team/teammates/<teammate-name>/`

Create 5 files (the 5 teammate self-maintained files mandated by Rule 13):

- **`README.md`** — role definition: write the nickname, model, scope, no-go zones, deliverables, plan-mode gating description collected in Phase 3, plus (optional) an empty `## Checkpoint Instructions` section for later customization; **and append the full content of `resources/teammate_rules.md` (including the `<!-- TEAMMATE_RULES:START/END -->` markers) to the end of the file**
- **`working-context.md`** — initial placeholder:
  ```markdown
  # Working Context — <teammate-name>
  _Initialized at spawn. Run /checkpoint to populate._
  ```
- **`completed.md`** — empty file (append-only log; `/checkpoint` with task_completed trigger appends)
- **`TODO.md`** — empty file
- **`commitments.md`** — empty file

### 4b. Append to TEAMMATE_INFO.json

Append an entry to the `active_teammates` array in `_agent_team_work_zone/<SELF>_team/TEAMMATE_INFO.json` (if the file doesn't exist, first initialize it per schema v2 — see `docs/teammate_info_schema.md`):

```json
{
  "name": "<teammate-name>",
  "role_source": {
    "type": "archetype" | "subagent" | "tier2" | "inline",
    "path": "..." // or subagent_name or inline_description
  },
  "model": "<haiku|sonnet|opus>",
  "plan_mode_gating": <true|false>,
  "scope": "<scope summary>",
  "spawned_at": "<ISO8601 current time>",
  "revived_count": 0,
  "status": "active"
}
```

Also update the top-level `updated_at`.

jq example (if available) — **validated atomic write**: `jq --argjson` auto-escapes (so a stray ASCII quote in a free-text field can't break the JSON) + a self-generated UTC timestamp; write to a temp file → `jq empty` parse-check → back up `.bak` → atomic `mv`; if any step fails, nothing is written and the original file is preserved. **Do not hand-write / hand-edit the JSON.**
```bash
info=_agent_team_work_zone/<SELF>_team/TEAMMATE_INFO.json
# temp file next to the registry (atomic mv, no shared /tmp name), seeded with cp -p so the registry keeps its file mode
tmp="$(mktemp "$(dirname "$info")/.info.XXXXXX")" && cp -p "$info" "$tmp" \
  && jq --argjson entry '<json object>' --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   '.active_teammates += [$entry] | .updated_at = $ts' \
   "$info" > "$tmp" \
  && jq empty "$tmp" \
  && cp "$info" "$info.bak" \
  && mv "$tmp" "$info" || rm -f "$tmp"
```

## Phase 5: Generate add-teammate spawn prompt

> **Replace `<project_root>` with an ABSOLUTE path** — the absolute directory that contains `_agent_team_work_zone/` directly — normally the directory your own session was started in. `git rev-parse --show-toplevel` is only a hint: use its output only after checking that `_agent_team_work_zone/` is directly inside it, because when the project is a subdirectory of a larger repository it points to the outer repository. A teammate's working directory is not necessarily the project root, so relative paths can fail.

```
I want to add a new teammate to the existing <SELF> team:

<nickname> (model: <model>)
Step 0 for the new teammate — before reading anything, record that you have started:
date -u +%Y-%m-%dT%H:%M:%SZ > <project_root>/_agent_team_work_zone/<SELF>_team/teammates/<nickname>/.started
(Lets the lead tell "never started" from "busy". Write it only here, once per spawn. If the write
fails, carry on, but end the Ready receipt with " .started write FAILED: <error>".)
Role definition: <reference or filled content>
Task: <details>
Plan-mode gating: <YES/NO + approval criteria>

Your workstation is at <project_root>/_agent_team_work_zone/<SELF>_team/teammates/<nickname>/ (5 files
— README/working-context/completed/TODO/commitments — already initialized by the lead).
Maintain it per Rule 13: call /checkpoint to update working-context.md before going idle,
when prompted, and after task completion.

Its output is written to <project_root>/_agent_team_work_zone/<SELF>_team/roundtable/, collaborating with other
teammates via mailbox.

Rule changes: if <project_root>/_agent_team_work_zone/<SELF>_team/RULES_LEDGER.md exists, read it; record every rule whose id is not yet in the "## Team rule changes" section of your README (create that section directly above the <!-- TEAMMATE_RULES:START --> line; if your README has no such line, put the section at the end of your README; never inside or below that block), and end your receipt line with " ACK <id>, <id>…" (or " Rules: up to date").

Ready receipt: when set up, the new teammate uses the SendMessage tool to send the lead exactly
one line: "Ready. Model: <model name>, ID: <model ID>" — quoting the model name and ID exactly
as its system prompt states them, or "Model: not stated" if it does not (never guess).
(A plain reply will NOT reach the lead.)

Please spawn this new teammate to join the existing team.
```

## Phase 6: Update team_recipes/

**Do not create a new recipe file** (that's `/spawn-team`'s job). Instead:
- Find the most recent recipe (first in descending-time order under `<SELF>_team/team_recipes/`)
- Append an "Amendment" section at its end:

```markdown
---

## Amendment — YYYY-MM-DD HH:MM — add-teammate

### Added teammate
<Phase 3 proposal content>

### Reason
<Phase 1 requirements>

### Spawn prompt
<Phase 4 generated prompt>
```

This lets subsequent `/evaluate-team` or next `/spawn-team` see the complete team evolution history.

## Phase 7: Send spawn prompt

In the next message send the Phase 5 prompt; Claude Code's built-in mechanism recognizes and spawns.

```
✅ teammate workstation skeleton created (5 files)
✅ TEAMMATE_INFO.json appended with new entry
✅ team_recipes/<latest>.md amended
Next: send spawn prompt to Claude Code agent-team mechanism
```

**After the spawn — receipt (same handling as `/spawn-team` 6e)**: the spawn time is the time you noted immediately BEFORE spawning to the second (e.g. `date -u +%s`; compare it with the `.started` mtime, `stat -c %Y`); wait for `Ready. Model: <name>, ID: <id>`.
- **Model check**: write the ID into the new entry as `model_resolved` (optional field; validated jq write as in 4b, `| .model_resolved = $mid` on the matching entry). Compare with the registry `model` and the README model line (alias matches if the ID contains it; a specific ID must be equal); on a mismatch **flag it** to the user, edit neither. `Model: not stated` → leave it unset, report "model unconfirmed". A cross-check, not a guarantee.
- **No receipt after ~10 minutes**: (1) best-effort tmux pane check (`tmuxPaneId` in `~/.claude/teams/<current session-level team>/config.json` → `tmux capture-pane -p -t <id>`; these are Claude Code internals — on any failure skip to (2), and a failed lookup is never evidence); a confirmation prompt on screen → ask the user to confirm it there. (2) `teammates/<name>/.started` absent or older than the spawn time → never started (or its step-0 write failed); newer but no receipt → working (messages reach it only when its turn ends), wait or check its artifacts. (3) Tell the user the possible causes; **never respawn automatically**. Full procedure: `/reactivate-team` Step 3.3.

## Notes

- **Do not reassemble the whole team**: only add one person; keep existing team intact
- **Inherit team conventions**: the new teammate's spawn prompt must clearly specify writing output to `<SELF>_team/roundtable/`
- **Amendment is not a new recipe**: use append rather than new file to keep team evolution history clear
- **Keep under 5 members**: if adding pushes past 5, first warn the user and ask whether truly needed (or whether a redundant member should be removed)
