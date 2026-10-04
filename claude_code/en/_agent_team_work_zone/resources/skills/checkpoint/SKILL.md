---
name: checkpoint
description: >
  Teammate persists current work state to its workstation's working-context.md: Part A
  current-state snapshot (overwrite) + Part B work journal (append; recent conversation and
  verbatim key exchanges), and appends completed.md as needed. Triggered automatically by the
  TeammateIdle hook (working-context.md mtime gate + exit 2 reminder), or by explicit lead
  request, or manually. **Not /compact** — does not destroy current context. Rule 13 mandates
  that teammates call this skill regularly.
disable-model-invocation: false
allowed-tools: Read Write Edit Glob Bash
---

<!--
[KEEP IN SYNC WITH /reactivate-team]
working-context.md is now two parts: Part A = the 9-section current-state snapshot below
(overwrite); Part B = an append-only work journal (recent conversation + verbatim key
exchanges + last 3-4 turns). Any change to Part A's section names/numbers/semantics, AND
the existence/read-shape of Part B, must be mirrored into resources/skills/reactivate-team/SKILL.md
— it is the reader on the other side, guiding a fresh teammate to read both parts to recover.
-->

# Checkpoint — Externalize Working Context

## Critical Constraints

- **Never call `/compact`** or any command that modifies the current context window. This skill is **non-destructive** — it only reads from live context and writes to `working-context.md`. The current session's context must remain intact.
- **working-context.md is two parts**: **Part A — Current-State Snapshot** (9 sections, **overwritten/regenerated every time**, correctable) + **Part B — Work Journal** (append-only, **one timestamped entry appended each time**, forming a continuous work history).
- **You MUST read the existing `working-context.md` before writing** (the opposite of the old rule): Part B is appended, so you must read to the end of the existing journal to append after it; Part A is still regenerated from your current conversation state and fully overwritten. **Do not rewrite or delete Part B's historical entries** — correct via a new appended entry, or only overwrite the one entry if it's plainly wrong. **The sole exception**: when writing a new entry, demote the **previous** entry's "last 3-4 verbatim turns" to a summary (see Step 3B growth governance). First time writing the new format: wrap the existing 9 sections into Part A and start an empty Part B.
- Write path: `_agent_team_work_zone/<team_name>/teammates/<self_name>/working-context.md`. Know your name from conversation context (it was in the spawn prompt; do not rely on environment variables).
  - Here `<team_name>` means the **workstation directory name** (of the form `architect_team`), **not** the `Agent` tool's `team_name` parameter (which CC ≥2.1.178 ignores). Under the new naming, your name is of the form `<slug>-<role>`, and the workstation directory = `${name%%-*}_team` (the slug before the first hyphen in your name, plus `_team`); if the spawn prompt still carries a team_name, it is merely redundant — derive from your name instead.

## Identity precheck

Before starting, confirm you are a teammate (not the lead):

- Your workstation should be at `_agent_team_work_zone/<team_name>/teammates/<self_name>/` (under the teammates subdirectory)
- If you are the team lead (workstation directly at `_agent_team_work_zone/<name>_team/`), **this skill does not apply** — leads don't use /checkpoint; leads track team state via TEAMMATE_INFO.json
- **Confirm this workstation is actually yours (fail-closed, defense-in-depth)**: (a) your identity comes from **your own spawn prompt**, not from a hook reminder's text; (b) a `README.md` exists at the target `teammates/<self_name>/` naming you. If the *only* reason you are running `/checkpoint` is a reminder naming a workstation you cannot independently confirm is yours — e.g. you were spawned as a subagent by a teammate and have no workstation of your own — **REFUSE, write nothing, and report back to whoever spawned you.**

## Flow

### Step 0: First read the existing working-context.md

**Before** analyzing and writing, Read the existing `working-context.md` (if present), locate the end of Part B's work journal, and note where the previous entry's "last 3-4 verbatim turns" are (this run will demote them to a summary). File missing, or only old-format 9 sections (no Part B) → treat as first write of the new format: this run wraps the 9 sections into Part A and starts an empty Part B.

### Step 1: Silent analysis

Before writing, silently perform the following analysis (do not output to the user):

1. **Temporal scan**: walk from the last checkpoint (or from spawn, if this is the first) to now. For each meaningful event identify:
   - The current task being worked on
   - Decisions made and their rationale
   - Files modified (full paths + change nature)
   - Errors encountered and their resolution
   - Explicit instructions from the lead or peer teammates you must continue honoring
   - Commitments you made to others
2. **Additionally extract for the Part B work journal** (new — do not skip):
   - **Recent conversation summary**: since the last checkpoint, the key exchanges with lead / peers / user (who said what, what was agreed)
   - **Verbatim key exchanges**: at important decisions / instructions / requirements, mark the exact wording to **quote verbatim**
   - **Last 3-4 turns**: lock the last 3 (or 4) turns of lead↔you and user↔you dialogue, **ready to paste verbatim** into this journal entry
3. **Distinguish "persistent knowledge" vs. "transient noise"**: this distinction **applies only to Part A's snapshot** (keep it lean, drop "ack"/"thanks" synchronous noise); **Part B's journal, conversely, keeps recent conversation** — don't discard it as noise.
4. If a Part A section has no content, write "None" — **do not fabricate content to fill**.

### Step 2: Customization hook (read your own README.md)

If `_agent_team_work_zone/<team_name>/teammates/<self_name>/README.md` contains a `## Checkpoint Instructions` section, read it and apply as emphasis in this checkpoint. E.g. a backend teammate's README might say: "Always emphasize API contract changes in section 5."

If no such section, use the default structure.

### Step 3A: Write / overwrite Part A — Current-State Snapshot

Path: `_agent_team_work_zone/<team_name>/teammates/<self_name>/working-context.md`

**Whole-file skeleton** (Part A overwritten, Part B appended):

```markdown
# Working Context — <your agent name>
_Last updated: <ISO 8601 timestamp>_

## Part A — Current-State Snapshot (overwritten, regenerated each time, correctable)
_Checkpoint trigger: task_completed | idle | manual | lead_request_

### 1. Current Objective
One sentence describing what you're trying to accomplish right now. Between tasks write "awaiting next assignment".

### 2. Active Task
- Task ID and subject (from team's shared task list or roundtable)
- Acceptance criteria as you understand them
- Your current step within the task

### 3. Completed Since Last Checkpoint
For each completed unit:
- What was done (one line)
- Files touched (full paths)
- Key decision (one line, only if non-obvious)

### 4. In-Flight Work
Anything started but not finished. For each:
- What was begun
- Why not finished (blocked / paused / mid-implementation)
- The exact next action for the successor spawn of you

### 5. Decisions and Rationale
Architectural or non-obvious decisions made this session. One line each:
- Decision: ... | Reason: ... | Alternatives considered: ...

### 6. Open Questions and Blockers
Things you don't know but need to, or things blocking progress.

### 7. Commitments to Others
Promises to the lead or peer teammates that the next spawn of you **must honor**:
- To {who}: I will {what} by {when, if applicable}.

### 8. Critical File References
Files the next spawn of you **must** read to understand current state. List paths only:
- path/to/file.ext
- ...

### 9. Cross-Session Notes
Things that don't fit any prior section but future you must know. **Use sparingly.**

## Part B — Work Journal (append-only, forms a work history)
<!-- Each checkpoint appends one entry at the end; historical entries are not deleted/edited except "verbatim demotion". -->

### <ISO 8601 timestamp> — <one-line subject>
- **What happened**: what was done in this time window (distilled, with full file paths)
- **Recent conversation summary**: key exchanges with lead / peers / user (who said what, what was agreed)
- **Verbatim key exchanges**: at important decisions / instructions / requirements, quote the exact wording (use `>` blockquotes)
- **Last 3-4 turns (verbatim)**: paste the last 3 (or 4) turns of lead↔you and user↔you dialogue verbatim at the end of this entry
```

**Snapshot Part A before overwriting (guard against an irreversible mis-fire)**: **before** you overwrite Part A wholesale, first copy the **current** Part A verbatim into a new Part B entry titled like `### <ISO 8601 timestamp> — [auto-preserved prior Part A snapshot before overwrite]`, then overwrite Part A. This turns one bad overwrite from "unrecoverable" into "recoverable from Part B" (Part B is append-only — which is exactly why it survives accidents while an overwritten Part A does not). **Growth governance**: these auto-preserved snapshots are the **first** things to compact out of Part B — they are only insurance against a bad overwrite, and may be dropped once the next legitimate Part A is confirmed good.

**Part A rule**: the 9-section structure / numbering / semantics are **fixed and unchanging**, **fully overwritten/regenerated each time** — it always reflects "the current state right now". A section with no content gets "None".

### Step 3B: Append Part B — one work-journal entry

**Append one** new timestamped entry at the end of Part B, following the template's 4 bullets (**What happened / Recent conversation summary / Verbatim key exchanges / Last 3-4 verbatim turns**).

**Growth governance (important)**: verbatim text is kept only for the **newest** entry. When writing this entry, **demote the previous entry's** "last 3-4 verbatim turns" to a summary (delete the verbatim, keep a one-line takeaway) — this is the only permitted edit to a historical entry. This keeps the verbatim volume constant at the last 3-4 turns and the journal linearly bounded; very old entries may be further compressed if needed (optional).

If there is genuinely no new conversation / progress this time (rare), you may append a minimal entry noting "no substantive progress", or refresh only Part A and skip Part B.

> **About the auto-reminder's brake (nothing to do manually)**: this checkpoint writes
> `working-context.md`, refreshing its mtime. The gate in `teammate_idle_checkpoint.sh`
> reads exactly that mtime — after you save, it sees the file as fresh and won't remind
> you on the next idle. So you do **not** need to clear any flag; writing the file
> automatically stops the reminders. (The pre-v0.2.3 `.checkpoint_pending` flag mechanism
> is retired.)

### Step 4: Also append to `completed.md` (only when trigger is task_completed)

If this checkpoint is because you **just completed a task** (trigger=`task_completed`), **append** a line to `_agent_team_work_zone/<team_name>/teammates/<self_name>/completed.md`:

```
- <ISO date> | T<task-id> | <one-line summary> | files: <comma-separated paths>
```

`completed.md` is an **append-only log**; never overwrite prior entries.

### Step 5: Git save (only if the project enabled it)

Run, with the ABSOLUTE path of the workstation you just wrote:

    bash <workstation>/../../../resources/scripts/atwz_checkpoint_git.sh save <workstation>

(`<workstation>` = the absolute directory containing the working-context.md you just wrote — your spawn prompt gives it as an absolute path; never use a relative one, because your working directory is not necessarily the project root.) The script decides everything itself:
if the project has not enabled checkpoint git saving, it prints nothing; otherwise it prints exactly one line (`saved …` or `skipped: <reason>`).
It always exits 0 — never retry it, never "fix" a skip, never run other git commands as part of /checkpoint. Copy its line, if any,
into the confirmation below. To recover a saved copy later: `atwz_checkpoint_git.sh list <workstation>` / `restore <workstation> [file…]`.

### Step 6: Confirm

Output **one line** confirmation to lead/user (**name who wrote it + the path**, so whoever spawned you can spot an out-of-bounds write at a glance):

```
Checkpoint written by <self_name> to <path>. Trigger: <task_completed|idle|manual|lead_request>.[ <script line, if any>]
```

**Do not** read the snapshot content back to the user — they can read the file themselves.

## What each part should / should not include

**Part A snapshot** (keep it lean):
- **Do not** paste large code blocks. Reference files by path.
- **Do not** include verbatim dialogue text. Distill to facts.
- **Do not** include instructions from the lead that are already fully done and have no downstream effect.
- **Do not** include synchronous messages "ack" / "thanks" / "started" / "done — moving on".

**Part B work journal** (be substantial, preserve the process correctably — toward `/compact`):
- **Do** quote the exact wording verbatim at key decisions / instructions / requirements, and keep the **last 3-4 turns of dialogue verbatim** — this is exactly Part B's value.
- But still **do not** paste large code blocks (reference by path); keep verbatim text to only the "last 3-4 turns", demoting earlier ones to summaries.
- Pure synchronous noise like "ack" / "thanks" need not be verbatim — fold it into the summary in a sentence.

## Failure Handling

If writing fails (disk full, permission denied, etc.), log a one-line error and **continue your prior task**. Do not retry indefinitely. Do not block on this skill — your main task has priority.

## Why this skill exists

Rule 13 mandates teammates' checkpoint duty. This skill is the tool that implements that duty. The `working-context.md` it produces is **the handoff document to the future spawn of you** — the next `/reactivate-team` will guide a new teammate (with the same name) to read it and pick up your work: Part A tells it "the current state", Part B tells it "what recently happened and the exact words".

Poor writing → the next you can't recover state → team collaboration breaks.

References:
- `docs/teammate_info_schema.md` — TEAMMATE_INFO.json structure
- `resources/skills/reactivate-team/SKILL.md` — the reader on the other side (must stay in sync with this skill's Part A 9-section structure + Part B journal)
- Rule 13 in `../../README.md`

## Customization hook example

A teammate's README.md may contain:

```markdown
## Checkpoint Instructions
Always emphasize API contract changes in section 5.
Pay special attention to database migration state in section 4.
```

With such a README, **elevate** those dimensions when generating a checkpoint — but **do not change** Part A's 9-section structure or order, nor Part B's append rules.
