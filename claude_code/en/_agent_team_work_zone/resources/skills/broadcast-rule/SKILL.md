---
name: broadcast-rule
description: >
  Team lead sends a rule change to every live teammate, records it in the team's standing
  RULES_LEDGER.md and tracks acknowledgements. Lead context only. Does not edit README text.
disable-model-invocation: false
allowed-tools: Read Write Edit Glob Grep Bash
---

# `/broadcast-rule` — Send a rule change to the whole team

Editing a rules file reaches nobody who is already running: a teammate's spawn prompt is fixed, and nothing makes it re-read its README. This skill pushes a rule change to every live teammate, has each one record it in its own README and acknowledge it, and keeps a standing record so that teammates who were benched, dead or not yet spawned pick it up later (their spawn and reactivation prompts tell them to read the ledger).

Invoke it once the user has agreed to the rule change (the same convention as `/add-teammate`).

## Identity precheck

**Must be invoked in team lead context**: your workstation is `_agent_team_work_zone/<name>_team/` (with `TEAMMATE_INFO.json`). If you are a teammate or a flat workstation → stop and tell the user: "This skill is only usable by a team lead."

## Step 1: Collect the rule

Collect, before sending anything:
- **the rule text, verbatim**, as the user (or you) worded it;
- a **one-line title**;
- **what it amends**: `README rule N` / `teammate_rules item N` / `new` (informational only; this skill does not edit README or `teammate_rules.md` text);
- **who approved it**: `user` (quote the approval verbatim) or `lead`.

If the text is ambiguous, ask before sending. A rule is sent **once, in its final wording**: one complete message, not a stream of corrections — a teammate receives nothing mid-turn, so corrections sent one after another all arrive together at its turn end.

## Step 2: Assign the id

`R-<UTC YYYYMMDD>-<n>`, where `n` = 1 + the number of that day's entries already in the ledger (0 if the ledger does not exist yet). Below, `<id>` stands for this whole id, prefix included — for example `R-20261004-1`.

## Step 3: Choose the recipients

Read `_agent_team_work_zone/<your_team>/TEAMMATE_INFO.json`. Recipients = `active_teammates` with `status ∈ {active, idle}`. Benched, `failed_to_reactivate` and offboarded teammates are **not** messaged; list them in the acknowledgement table as not live — they get the rule at reactivation.

## Step 4: Append to the ledger

The ledger is `_agent_team_work_zone/<your_team>/RULES_LEDGER.md`, next to `TEAMMATE_INFO.json`. It is **lead-owned** (rule 1): only the lead writes it; teammates read it. It is a standing record — never archive it. If it does not exist, create it with this header:

```
# Rules ledger — <team>_team
Rule changes broadcast to this team's teammates with /broadcast-rule. Lead-owned; teammates read it, never edit it.
Spawn and reactivation prompts tell every teammate to read this file and acknowledge any rule it has not recorded yet.
```

Then append one section (newest at the bottom; a plain file append — the ledger is Markdown, not the JSON registry):

```
## <id> — <one-line title>
- Issued: <UTC ts> by <lead name>; approved by: <user | lead> (quote the approval verbatim if it came from the user)
- Amends: <README rule N / teammate_rules item N / new>   (informational; the skill does not edit README text)
- Text (verbatim, as sent):
  > <rule text>
- Acknowledgements:
  | Teammate | Status at send | Sent (UTC) | ACK (UTC) | Note |
  |---|---|---|---|---|
  | <name> | active | <ts> | — | |
  | <name> | benched | — (not live) | — | gets it at reactivation |
```

## Step 5: Send one message per live teammate

Fill in `<id>` with the full id (so the reply you ask for reads, for example, `ACK R-20261004-1`). Loop over the recipients and send **one SendMessage per teammate** (never a single broadcast — the acknowledgement table is per teammate). Message, verbatim:

```
[RULE <id>] Team rule change — this supersedes any earlier instruction on the same point.
<rule text, verbatim>
Do now: (1) add it to the "## Team rule changes" section of your own README.md — create that section directly ABOVE the
<!-- TEAMMATE_RULES:START --> line if it doesn't exist (if your README has no such line, put the section at the end of your README;
never inside or below that block: the block is replaced on upgrade); copy the id and the text verbatim. (2) Reply to the lead,
using the SendMessage tool (a plain reply does not reach the lead), with exactly: ACK <id>
Follow the rule from now on.
```

Fill the **Sent** column with each send time. A send that errors with `No agent named X is currently addressable` → Note: "dead at send; gets it at reactivation".

## Step 6: End the turn — do not wait for ACKs in it

A teammate's reply reaches you only after your turn ends, so do not wait inside this turn. End it with one line:

```
<id> sent to N live teammates; ACKs pending
```

## Step 7: Record ACKs as they arrive

On later turns, when `ACK <id>` arrives, fill that row's **ACK** column with the time. Receipts from `/spawn-team`, `/add-teammate` and `/reactivate-team` can also carry `ACK <id>` (teammates catching up from the ledger) — fill those rows too.

A teammate silent past a reasonable window → follow rule 13, "When a teammate goes quiet". **Never resend in a loop.**

## Out of scope

- **Cross-team broadcast**: use `meeting_room/` with `to: ALL`.
- **Editing README or `teammate_rules.md` text**: a rule that should become permanent framework text is a separate, deliberate change.
