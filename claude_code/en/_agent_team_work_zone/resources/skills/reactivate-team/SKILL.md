---
name: reactivate-team
description: >
  Team lead invokes after session restart: reads TEAMMATE_INFO.json to rebuild the team by
  using the Agent tool to spawn fresh sessions for each active teammate (name must be <slug>-<role>; permission mode inherits the lead, not set per-teammate at spawn),
  guiding each to read its workstation's working-context.md (Part A snapshot + Part B work journal)
  to self-recover state. No-arg invocation wakes only active/idle and **skips benched** (temporarily
  offline); `/reactivate-team <name>` wakes back one specified (usually benched) teammate. This is the
  ONLY way to "recover a team across sessions" — Claude Code does not auto-respawn teammates.
disable-model-invocation: false
allowed-tools: Read Write Edit Glob Bash Agent
---

<!--
[KEEP IN SYNC WITH /checkpoint]
working-context.md is two parts: Part A = the 9-section current-state snapshot; Part B =
an append-only work journal. The structure this skill guides a fresh teammate to read
(Part A 9 sections + Part B journal) must exactly match what /checkpoint writes. If you
change any section name/number/semantic, or Part B's existence/read-shape, also update
resources/skills/checkpoint/SKILL.md.
-->

# Reactivate Team — Rebuild the team and have each teammate self-recover

## Identity precheck

**Must be invoked in team lead context.** Determine:

1. First infer from conversation context — are you already clear you're the team lead? (workstation directory ends in `_team` with `roundtable/`, `TEAMMATE_INFO.json`)
2. If inference fails → Glob `_agent_team_work_zone/*_team/README.md`, read READMEs to match conversation history
3. If **not** a team lead → **stop immediately** and inform the user: "This skill is only usable in team lead context. Currently a flat workstation / teammate."

## Invocation forms: no-arg full restore vs. single named wake

This skill has two invocations:

- **`/reactivate-team` (no arg)** — the standard full restore after a session restart: wakes all teammates with `status ∈ {active, idle}`, **skipping `benched`** (temporarily offline). This is the default.
- **`/reactivate-team <name>` — wake back one specified teammate** (typically to bring a `benched` one back, or to force a single rebuild of an active one): spawn just that one name (Step 3). On success, if it was `benched`, flip it back to `active` and clear `benched_at` / `bench_reason` (see Step 4).
  - **No team-registration preprocessing (CC ≥2.1.178)**: just spawn directly. The session-level team is auto-managed by Claude Code; there is no need (and no way) to `TeamCreate`/`TeamDelete` — waking one named teammate won't disturb the other still-live teammates in this session.

> **Who decides to wake a benched one**: deciding whether to wake a benched teammate is the **team lead's standing management judgment** (see the README work rules) — at any point (especially when assigning work / before starting a task) where the lead finds it needs a benched specialty, it proposes to the user, and after consent (or the user naming it directly) executes via `/reactivate-team <name>`. **The no-arg invocation never auto-wakes benched, and never has the user pick from a list** — the status table is a black box to the user.

## Premise: how to judge whether a teammate is alive

**Core rule (time-ordering, not file-checking)**:

> A teammate is alive if and only if it was spawned by **the current, uninterrupted lead session** and the session has not restarted since. Any session restart (SSH drop / tmux crash / `/resume` / process exit) ⇒ all teammates of that team are necessarily dead, no exceptions.

Reframe the judgment from "let me check a file to see if it's alive" into a time question: **were these teammates spawned in MY current life? No → all dead, must reactivate.** Never judge liveness by checking files.

### Four "non-evidence" traps (named one by one)

The following are **all invalid** and cannot be used to infer that a teammate is alive:

1. **A member entry for it exists in `config.json` / any on-disk team file** → ✗
   An on-disk team file records historical registration, not whether any process is alive. (CC ≥2.1.178: the session-level team is auto-created and auto-cleaned by Claude Code and is not retained across sessions — but you still **cannot** infer liveness from any disk file; the only authoritative signal is a SendMessage receipt within the same session.)

2. **Its message is in the inbox (read or unread)** → ✗
   `inboxes/` are disk-residue files, not cleaned per session; a dead team's messages can linger for days. Reading an old message **does not mean it just replied** — this is the biggest misjudgment trap.

3. **`status:active` in `TEAMMATE_INFO.json`** → ✗ (**the most common and most absurd misjudgment**)
   `TEAMMATE_INFO.json` is a lead-maintained static file with zero connection to any runtime process. `status:active` is just the lead's subjective marker from its last operation, unrelated to whether the teammate is actually alive.

4. **The teammate produced output but not via SendMessage** → ✗
   A plain reply does not cross the agent boundary — the lead simply cannot see a teammate's ordinary output. That output exists only in the teammate's own session context, invisible to the lead.

### The only reliable positive liveness signal

**Receiving that teammate's SendMessage reply within the current session.**
An active ping (SendMessage → wait for the other side's SendMessage receipt) is the only reliable way to confirm a teammate is currently alive. No receipt = liveness unknown = treat as dead.

### Receipts expire; the common failure isn't user misuse — it's the lead assuming teammates are still alive

In practice it's almost never "the user mis-invoked `/reactivate-team`" — it's the **lead failing to confirm at the moment and still believing teammates are alive**, treating a receipt from several turns ago (or `TEAMMATE_INFO.json`'s `status:active`) as the current reality. Hold two rules:

- **A receipt is a point-in-time signal and EXPIRES**: alive several turns ago does **not** mean alive now — one teardown / restart in between wipes them all. **Every** time you make a live/dead judgment (**including the inverse "they're alive, no need to reactivate"**), you must **re-verify on the spot and NEVER rely on an earlier receipt**.
- **The fastest, hardest liveness check = throw a ping and read the `SendMessage` return** (no slow "no reply within a window" waiting):
  - returns `success:true` (`Message sent to X's inbox`) → the registration exists; but you still need a **reply** to confirm liveness.
  - returns **`No agent named X is currently addressable`** → **registration is gone = definitively dead** (instant, synchronous).
  - **earlier sends succeeded, now they fail** = a teardown happened in between, the prior "alive" is void, you must reactivate.

### Compaction ≠ restart; when you suspect death, ping before concluding

**Context compaction happens in the same process and does NOT kill teammates** — ones spawned earlier are usually still alive after a compaction. So "session restart ⇒ all dead" applies only to a **genuine restart** (startup / resume / process exit), **not to compaction**. The `SessionStart` hook now branches its text on `source` (on compact it says "likely still alive, ping first"), but **whatever the hook says**: before reporting a teammate as dead to the user, or deciding to reactivate, **first ping and wait for a receipt this session** — that is the only authoritative criterion. Do not report the conservative default ("assume dead") as established fact.

---

## Flow

> **No more Step 0 (CC ≥2.1.178)**: the old version needed to first `TeamDelete` → `TeamCreate` to rebuild team registration and clear leftover ghosts; those two tools have been **removed** in 2.1.178. The new version **automatically** creates a unique session-level team (named like `session-<id>`) when each session starts, and **automatically cleans up** teammates on exit, so the disk no longer accumulates dead-member ghosts. Reactivate therefore **starts directly at Step 1** — read `TEAMMATE_INFO.json`, confirm, and spawn each one via `Agent(...)`, with no team-registration preprocessing at all. When spawning, **do not pass `team_name`** (it is ignored); the teammate is auto-joined into the current session-level team by `Agent`.

### Step 1: Read TEAMMATE_INFO.json

Path: `_agent_team_work_zone/<your_team>/TEAMMATE_INFO.json`

**No-arg invocation**: from `active_teammates`, filter the **wake set** = `status ∈ {active, idle}` (**excluding `benched`**; `failed_to_reactivate` is the user's call to retry, not auto-included by default):
- File does not exist → tell the user "This team has never spawned a teammate (TEAMMATE_INFO.json does not exist)"; exit
- File exists but the wake set is empty → tell the user "No active teammates to restore (all may be offboarded or benched)"; if benched exist, append a read-only FYI (see Step 2), then exit
- Wake set non-empty → continue

**`/reactivate-team <name>` named invocation**: locate `<name>` directly in `active_teammates` (whatever its status — active / idle / benched / failed_to_reactivate); not found → tell the user that name isn't in active_teammates (may be offboarded); exit. The wake set = just this one.

### Step 2: Show status to user

List each active teammate's info:

```
Team: <team_name>
Teammates to restore (status ∈ active/idle): N

1. <name>
   - Role source: <role_source.type> (<path or subagent_name>)
   - Model: <model>
   - Originally spawned: <spawned_at>
   - Last checkpoint: <last_checkpoint_at | "never checkpointed">
   - Previously revived: <revived_count> times

2. <name>
   ...

[FYI — shown only if benched exist; read-only, no confirmation required]
Also K benched teammate(s) (temporarily offline, not woken this run): [<benchedA>, <benchedB>]
To bring one back, just tell me and I'll restore it with /reactivate-team <name>.

Confirm to begin reactivation?
(I'll spawn a new session for each teammate to restore, guiding it to read working-context.md
to self-recover. If some teammate's last checkpoint is old, it may not fully recover —
please decide whether to proceed for such teammates.)
```

> The benched line is purely informational — **do not** have the user pick which to wake here, and **do not** count benched in the "confirm reactivation" scope.

Wait for user confirmation. **Do not proceed without consent** — each Agent tool invocation costs tokens.

### Step 3: Reactivate one by one

For each teammate in the **wake set** (Step 1 already filtered it by invocation form — no-arg = `status ∈ {active, idle}` in array order; named = just that one):

**3.1 Prepare spawn prompt** (key: guide the teammate to read its workstation and self-recover):

```
You are {name}, a teammate previously active on team '{team_name}'. Your previous
Claude Code session was terminated (not by shutdown_request — by session
interruption such as the team lead's session exiting). Claude Code does NOT
automatically preserve teammate state across sessions, so this is a fresh session
and you have no memory of your prior work.

Before doing anything else:

1. Read _agent_team_work_zone/{team_name}/teammates/{name}/README.md — your role definition
2. Read _agent_team_work_zone/{team_name}/teammates/{name}/working-context.md — your
   last checkpoint. It has TWO parts: Part A = a 9-section current-state snapshot (the
   authoritative "where things stand now"); Part B = an append-only work journal with
   recent conversation, verbatim key exchanges, and the last 3-4 dialogue turns. Read
   BOTH — Part A in full, plus the most recent Part B entries (and their verbatim tail)
   to recover recent context and conversation. (Older format with only 9 sections and no
   Part B is fine — just use the snapshot.) Trust this document — the previous spawn of
   you wrote it for you.
3. Read _agent_team_work_zone/{team_name}/teammates/{name}/commitments.md — outstanding
   promises you must honor.
4. Optionally read _agent_team_work_zone/{team_name}/teammates/{name}/TODO.md and
   completed.md for additional context if working-context points to them.

If working-context.md looks corrupted, empty, or is missing sections, DO NOT
invent content — message the team lead via SendMessage asking for guidance
before starting work.

After reading, use the SendMessage tool to send the team lead exactly one line:
"Resumed from checkpoint at {last_checkpoint_at}. Ready."
(A plain reply will NOT reach the lead — you MUST use SendMessage.)

Do NOT start any new work until the team lead messages you with the next task.
```

**3.2 Call the Agent tool** to spawn:

```
Agent(
    description="Reactivate <name>",
    subagent_type="<determined from role_source>",   # e.g., "general-purpose" / "tracker" / etc.
    model="<model from TEAMMATE_INFO.json>",
    name="<slug>-<role>",                            # critical: its name within the team (reuse the original name; must be <slug>-<role>)
    prompt="<the self-recovery spawn prompt above>"
)
# Note (CC ≥2.1.178): no longer pass team_name — it is ignored; the teammate is auto-joined into the current session-level team by Agent.
# Also do not pass mode: a teammate's permission mode can't be set per-teammate at spawn; it inherits the lead's current mode (for auto, put the lead in auto / set permissions.defaultMode:"auto").
```

**subagent_type selection rules**:
- `role_source.type == "subagent"` → `subagent_type: role_source.subagent_name` (reference generic subagent)
- `role_source.type == "archetype"` or `"tier2"` or `"inline"` → `subagent_type: "general-purpose"` (generic agent; role is injected via spawn prompt)

**3.3 Receive response + record result**:

Binary judgment:
- **Success**: received that teammate's SendMessage receipt in the current session (containing "Resumed from checkpoint at X. Ready.") → mark success
- **Failure / unknown**: no SendMessage receipt received (including timeout) → warn the user, let the user decide (retry spawn / check working-context.md for damage / or /remove-teammate); **do not assume success**

> **Important**: disk artifacts (`working-context.md` / `last_checkpoint_at`) only tell you the state **before** reactivate; they can NEVER serve as the criterion for whether **this** reactivate succeeded — spawn success or failure, these static files look the same and do not reflect this run's runtime fact. See this skill's opening "Premise" section.

### Step 4: Update TEAMMATE_INFO.json

For each woken teammate (success or failure), update:

- Success:
  - `spawned_at` → current time
  - `revived_count` += 1
  - `status` set to `active` (if it was `benched` / `idle`, promote it too)
  - If it was `benched`: **delete** the `benched_at` and `bench_reason` fields
- Failure:
  - `status` → `failed_to_reactivate`
  - Do not update spawned_at (if it was benched, keep the benched fields for a later retry)

Globally:
- `updated_at` → current time

jq example (for each successful teammate, replacing N=name):
```bash
jq --arg name "N" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   '.active_teammates |= map(if .name == $name then .spawned_at = $ts | .revived_count += 1 | .status = "active" | del(.benched_at, .bench_reason) else . end) | .updated_at = $ts' \
   "$info" > /tmp/info.json && mv /tmp/info.json "$info"
```

### Step 5: Report to user

Output summary:

```
Team <team_name> reactivated:

✅ Successfully resumed (N):
- <name1>: "Resumed from checkpoint at <ts>. Ready."
- <name2>: ...

❌ Failed to reactivate (M):
- <name3>: <reason>

Status updated in TEAMMATE_INFO.json.

Next steps:
- For failed teammates, decide: (a) manual debug (check working-context.md for damage),
  (b) /remove-teammate, (c) /add-teammate to recruit anew
- All successful teammates are now idle awaiting your assignments. You can SendMessage
  them for next instructions, or have them /check-inbox first for unprocessed work.
```

## Special cases

### Ghost collision (dead member names lingering) — no longer happens on CC ≥2.1.178

Old version (CC ≤2.1.177): the on-disk `config.json`'s `members` array kept dead in-process member (ghost) entries from the previous session, and spawning with the original name got auto-suffixed `-2/-3`, causing name drift and `SendMessage` failing to find the teammate — the old version rooted this out with Step 0's `TeamDelete`→`TeamCreate` cleanup.

**CC ≥2.1.178 no longer has this problem**: each session's session-level team is **auto-cleaned** on exit, so the disk no longer accumulates ghosts; a new session spawning with the original name won't collide with leftovers and won't get suffixed. The skill has therefore **dropped Step 0**, and under the normal flow spawns get the original names back directly.

> If a name still occasionally gets suffixed (rare, e.g. spawning the same name twice within one session) → mark that teammate `failed_to_reactivate` and inform the user; or accept the new name and **update that member's name in TEAMMATE_INFO.json accordingly** (otherwise later `SendMessage` won't find it).

### If working-context.md is corrupted

The teammate's spawn prompt already instructs it — on corruption, the teammate will SendMessage the lead for guidance rather than blindly starting work.

### If TEAMMATE_INFO.json is malformed

Stop reactivate, tell the user "TEAMMATE_INFO.json parse failed; please check format". Do not attempt auto-repair — let the user intervene.

### Terminal / tmux (only read if a spawn reports a tmux error, or you want to tune display/persistence)

> tmux is **not** a requirement for agent teams — in-process mode runs the full team feature set in any terminal. This section is only relevant if you hit the errors below, or want to change display/persistence; the normal flow **needs none of it**.

**What the two tmux spawn errors mean** (the hard version/environment check is handled by `bootstrap.sh`; this skill does **not** run checks itself):
- `Failed to create teammate pane: size invalid` → you're inside tmux, but the tmux version is too old (< 3.0). Upgrade tmux ≥ 3.0 (3.6a verified), or exit tmux and use in-process.
- `Could not determine current tmux pane/window` → the tmux on PATH differs from the one owning the current session (`$TMUX` socket) — multiple tmux installs coexist. Point PATH at the tmux that started the current session.
- bootstrap **pre-empts and diagnoses** both of these once you're inside tmux — if you see one, **re-run bootstrap** and follow its guidance.

**`teammateMode` (display mode, a settings.json field)**:

| Value | Behavior |
|---|---|
| `auto` (default) | inside tmux **or** iTerm2 → split-pane (one pane per teammate); otherwise → in-process |
| `split-pane` | force one pane per teammate (needs tmux or iTerm2) |
| `in-process` | all teammates in one terminal, `Shift+Down` cycles between them; **works in any terminal** |

- Don't want panes split → use `in-process`. **Don't hand-edit settings.json** — re-run `bootstrap.sh`; it has an interactive option to write it for you (default leaves it unchanged).
- **Strongly recommended: run Claude Code inside a tmux session** (even with in-process display): when the terminal closes / SSH disconnects, tmux keeps the process alive and the session uninterrupted, **sparing you frequent `/reactivate-team` to rebuild the team**. Installing tmux or running inside tmux does not affect team functionality, but running inside tmux avoids losing the team on disconnect. See the tmux section of `docs/user_manual.md`.

## Don'ts

- **Do not** let old teammates and new teammates coexist during reactivate (chaos) — reactivate assumes old sessions are fully dead
- **Do not** modify any files under the teammate workstation (rule #1, especially working-context.md) — only the teammate itself may modify
- **Do not** reactivate too many teammates at once (>5) — each is an independent Agent call with linear token cost. For large teams, batch in groups.

## Why this skill exists

Claude Code's agent-teams feature **does not persist teammate sessions**. When the lead session crashes or exits:
- `~/.claude/teams/<team>/config.json` metadata remains
- `~/.claude/teams/<team>/inboxes/` mailbox remains
- **But all teammate sessions vanish**

This skill turns "recover team" from impossible (Claude Code can't) into possible, via the 3-step chain: "read TEAMMATE_INFO.json + Agent tool respawn + guide teammate to self-recover".

Related:
- Rule 13 (teammate workstation self-maintenance + checkpoint duty)
- `/checkpoint` skill (teammate writes working-context.md)
- `.claude/settings.json` `SessionStart` hook (lead reminded to run `/reactivate-team` on start)
- `docs/teammate_info_schema.md` (data structure reference)
