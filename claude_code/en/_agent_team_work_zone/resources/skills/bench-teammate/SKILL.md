---
name: bench-teammate
description: >
  Temporarily take a teammate offline (benched): have it write a final checkpoint, close its
  session to free an online slot, but **keep its full record + workstation + docs**, and set its
  status to benched in TEAMMATE_INFO.json. Unlike /remove-teammate (permanent offboard), benched
  means "will come back" — wake it later with `/reactivate-team <name>`. Team lead invokes
  autonomously (after user consent). Only valid in team lead context.
disable-model-invocation: false
allowed-tools: Read Write Edit Glob Grep Bash
---

# `/bench-teammate` — Temporarily take a teammate offline (benched)

## When to use

Claude Code caps the number of **concurrently online** teammates. When a teammate is **not needed in the current phase**, or you need to **free an online slot** for someone else, bench it: it no longer occupies an online slot, but its workstation, docs, and record are all preserved, ready to be woken individually later.

- **bench vs remove**: `/remove-teammate` = permanent offboard (moved to `offboarded_teammates`, slim record, semantics "task done, not coming back"); `/bench-teammate` = temporary offline (**stays in** `active_teammates`, `status=benched`, full record, semantics "will come back").
- **Waking is the lead's standing judgment** (see README work rules): at any time (especially when assigning work / before starting a task) where a benched specialty is needed, propose it to the user and, after consent, wake it via `/reactivate-team <name>`.
- **The status table is a black box to the user**: bench / wake status fields are lead-maintained; the user only participates at the "propose—consent" level.

## Identity precheck

**First infer from conversation context**: you should already know you're the team lead (workstation ends in `_team`, contains `roundtable/` and `TEAMMATE_INFO.json`). **If inference fails**, follow `/evaluate-team`'s check logic. If not a team lead → **stop immediately** and tell the user this skill is only usable in team lead context.

## Step 1: Identify the teammate to bench + validate

Determine the name `<name>` from the user's description. Read `_agent_team_work_zone/<SELF>_team/TEAMMATE_INFO.json` and validate:

- `<name>` is in `active_teammates` and `status ∈ {active, idle}` → benchable
- If `status` is already `benched` → tell the user "it's already benched, no need to repeat"; exit
- If not in `active_teammates` (maybe offboarded) → tell the user; exit

Confirm with the user (and ask for the bench reason, written to `bench_reason`):

```
Do you want to temporarily bench <name>?

Its current tasks:
- <list roundtable files to: <SELF>_team/<name> that are OPEN/IN_PROGRESS, and IN_PROGRESS from it>

When benching I will:
1. Ask it to write a **final checkpoint** (Part A snapshot + Part B work journal in working-context.md)
2. Close its session, freeing 1 online slot
3. Keep its workstation/docs/record untouched
4. TEAMMATE_INFO.json: status → benched, record benched_at + reason (**still in active_teammates**)

Its unfinished work stays with its workstation and resumes when woken; if **someone is waiting on its output right now**, you may want to reassign those few items first — want me to list them so you can decide?

Bench reason (one line)? Confirm bench?
```

Wait for explicit consent + a reason.

> **Current tasks**: benching presumes "will come back", so unfinished work **stays with the workstation by default** — no forced handoff (it resumes when woken). Only when others are **currently** blocked on its output do you reassign those items, à la `/remove-teammate` Phase 2 — otherwise leave them be.

## Step 2: Force a final checkpoint (Rule 1 + Rule 13)

**The final checkpoint must be written by the teammate itself** (rule #1 low coupling; the lead cannot write its workstation files). Two cases:

**(A) Teammate currently alive** (a SendMessage receipt was received this session): SendMessage it to checkpoint first:

```
You are being temporarily benched (not removed). Before I close your session, run
/checkpoint now to persist your final state — Part A snapshot AND a Part B journal
entry capturing recent context and your in-flight work, so the next time you're woken
you can resume cleanly. Your workstation at
_agent_team_work_zone/<SELF>_team/teammates/<name>/ will be fully preserved.
Reply with "Checkpoint written." when done.
```

Wait for its "Checkpoint written." receipt before Step 3.

**(B) Teammate already dead** (never woken this session after a restart, or stuck/unresponsive): no new checkpoint possible → use its last on-disk checkpoint and go straight to Step 3 (no session to close, since it isn't online). Tell the user "it will be marked benched at the state of its last checkpoint".

## Step 3: Close the session to free the slot (only needed in case A)

If the teammate is alive, send it a **graceful shutdown request** (shutdown_request) to end its current session and free the online slot:

```
Checkpoint received. You are now benched — shutting down your session. You will be
woken later via /reactivate-team if needed. Thank you.
```

> After shutdown it may leave a ghost entry in the runtime registration — harmless: a later `/reactivate-team <name>` handles it (see that skill's "Invocation forms" note on Step 0: when the team has other live members, do **not** run TeamDelete/TeamCreate — spawn directly).
>
> **Do not** hard-delete it from the team registration or treat it as a permanent remove — bench only ends the session; the record and membership are preserved.

## Step 4: Update TEAMMATE_INFO.json

Path: `_agent_team_work_zone/<SELF>_team/TEAMMATE_INFO.json`. Set `<name>`'s `status` to `benched`, write `benched_at` + `bench_reason`, **keep it in the `active_teammates` array with all other fields intact**. Update top-level `updated_at`.

jq example (if available):
```bash
name="<name>"
reason="<bench reason>"
ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
info=_agent_team_work_zone/<SELF>_team/TEAMMATE_INFO.json
jq --arg n "$name" --arg r "$reason" --arg ts "$ts" '
  .active_teammates |= map(
    if .name == $n then .status = "benched" | .benched_at = $ts | .bench_reason = $r else . end
  ) | .updated_at = $ts
' "$info" > /tmp/info.json && mv /tmp/info.json "$info"
```

**Never** delete / alter its workstation directory `teammates/<name>/` (working-context.md, completed.md, commitments.md, README.md, TODO.md all preserved as-is).

## Step 5: Report completion

```
✅ <name> temporarily benched

- Final checkpoint: <written / reused last (teammate was dead)>
- Session: <closed, freed 1 online slot / was not online>
- Workstation: fully preserved at teammates/<name>/
- TEAMMATE_INFO.json: status → benched (still in active_teammates), reason: <reason>

Currently online teammates: <remaining active/idle list>
Benched (temporarily offline): <benched list>

Wake it back with `/reactivate-team <name>` when needed.
```

## Notes

- **Bench is a neutral process**, no punitive meaning — just slot management + phased dormancy.
- **The final checkpoint is written by the teammate itself** (Rule #1): the lead does not write its workstation files; if the teammate is dead, accept reusing its last checkpoint.
- **Workstation/record always preserved** — this is the core difference between bench and remove.
- **No handoff by default**: unfinished work stays with the workstation and resumes when woken; only reassign the few items others are currently blocked on.
- **Don't let the user touch status fields**: bench / wake is a lead-maintained black box; the user only consents at the conversation level.
- Related: `/reactivate-team <name>` (wake), `/remove-teammate` (permanent offboard), `docs/teammate_info_schema.md` (benched status & fields), Rule 13.
