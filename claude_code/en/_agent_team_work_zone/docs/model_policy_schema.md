# model_policy.json Structure

> Human-readable documentation. **Not** a runtime dependency — `/quickstart`, `/onboard`, `/spawn-team`, and `/add-teammate` inline the JSON structures they use; they do not Read this file. The rules in the final section "How to write the suggestion to the lead" are implemented by `resources/scripts/atwz_detect_tier.sh`; change the script together with them.

This file records which model a team's teammates use **by default**, how many teammates the team should have at most, and the model and effort level suggested for the lead. It is set from the user's subscription tier, so that a new team does not use up the usage limits right away. One per team workstation.

Teammates use the effort level of the lead's current session: the Agent tool's `effort` parameter has no effect on team members (in-process and split-pane alike), so this file records no teammate effort, only a suggestion for the lead.

## Path

```
_agent_team_work_zone/<team_name>/model_policy.json
```

It sits next to `TEAMMATE_INFO.json` and is tracked in git.

## Who reads and writes

| Operation | Writes | Reads |
|---|---|---|
| `/quickstart` | ✅ detects the subscription tier when building the team and writes the default plan (does not ask the user) | ✅ when resuming |
| `/onboard` (Team Lead workstation) | ✅ detects the tier, shows the user the default / conservative / custom choices, writes the one the user picks | - |
| `/spawn-team`, `/add-teammate` | - | ✅ default teammate model for the lineup proposal, and the team size limit |
| `/reactivate-team` | - | **Does not read it**: re-spawning follows the registry only |
| the lead (when the user asks to switch "future teammates / all teammates" to … or to "set effort to …") | ✅ changes `member_model` or `lead_effort_suggested`, sets `choice` to `custom` | - |
| teammates | **Never write** | - |

The tier is detected by `resources/scripts/atwz_detect_tier.sh`. It reads only the login method and subscription type from `claude auth status`; when the plan is Max, it also reads one tier field to tell Max 5x from Max 20x (an undocumented Claude Code internal field that may be renamed later; when it cannot be read, Max 5x is assumed). When not logged in, the tier is `unknown`.

## Full schema (v1)

```json
{
  "schema_version": 1,
  "tier": "max_20x",
  "tier_source": "subscriptionType=max; organizationRateLimitTier=default_claude_max_20x",
  "choice": "default",
  "member_model": "opus",
  "max_members": 5,
  "lead_model_suggested": "opus",
  "lead_effort_suggested": "high",
  "decided_by": "quickstart (automatic)",
  "detected_at": "2026-10-25T03:14:00Z",
  "updated_at": "2026-10-25T03:14:00Z"
}
```

## Fields

| Field | Type | Meaning |
|---|---|---|
| `schema_version` | integer | Currently 1 |
| `tier` | string | `pro` / `max_5x` / `max_20x` / `team` (includes Enterprise) / `api` (API key, cloud provider, `ANTHROPIC_BASE_URL` pointing elsewhere) / `unknown` (could not tell, including not logged in) |
| `tier_source` | string | The field names and values the decision was based on. **Never** an email, organization name, account ID or token |
| `choice` | string | `default` / `conservative` / `custom` |
| `member_model` | string | `haiku` / `sonnet` / `opus`. **`fable` is not allowed**: a teammate session on Fable may need pay-as-you-go usage, which shows a consent prompt; with no answer in 5 minutes the turn is dropped and the teammate is stuck. When the user names `fable` for one teammate, do it, but record it only in that teammate's registry entry, not here |
| `max_members` | integer | Suggested maximum number of teammates. Going over it means telling the user and asking for confirmation, never a hard refusal. The `/remote-collab` watcher (`<slug>-remotewatch`, always haiku) is not counted |
| `lead_model_suggested` | string or null | The model suggested for the lead (the user's current session). Skills cannot change the lead's model, only suggest it in the closing message; null means no suggestion. On Max 20x the closing message compares against `fable` (enough usage, so Fable is recommended) |
| `lead_effort_suggested` | string or null | The effort level suggested for the lead: `low` / `medium` / `high`; teammates spawned or re-spawned afterwards use the lead's effort level at that time. null means no suggestion |
| `decided_by` | string | `quickstart (automatic)` / `onboard (user confirmed)` / `user request` |
| `detected_at` | ISO8601 string | When the tier was detected |
| `updated_at` | ISO8601 string | Last modification time of this file |

## Values per tier

Default plan:

| `tier` | `member_model` | `max_members` | `lead_model_suggested` | `lead_effort_suggested` |
|---|---|---|---|---|
| `pro` | `haiku` | 2 | `sonnet` | `medium` |
| `max_5x` | `sonnet` | 4 | `opus` | `medium` |
| `max_20x` | `opus` | 5 | `opus` | `high` |
| `team` | `sonnet` | 4 | `opus` | `medium` |
| `api` | `sonnet` | 5 | null | null |
| `unknown` | `sonnet` | 5 | null | null |

Conservative plan (offered only in `/onboard`; team size limit as in the default plan):

| `tier` | `member_model` | `lead_model_suggested` | `lead_effort_suggested` |
|---|---|---|---|
| `pro` | `haiku` | `sonnet` | `low` |
| `max_5x` | `haiku` | `sonnet` | `low` |
| `max_20x` | `sonnet` | `opus` | `medium` |
| `team` | `haiku` | `sonnet` | `low` |
| `api` / `unknown` | `sonnet` | null | null |

The framework's own tracker (scheduled watcher) keeps using haiku as its own definition says; this file does not affect it.

## Order of precedence for the teammate model at spawn

Take the first of these that has a value:

1. What the user named in the conversation ("use opus for this teammate") — always wins;
2. When re-spawning (`/reactivate-team`): the teammate's existing `model` in the registry. **This file is not read**, so existing teammates are not switched when this file changes;
3. `member_model` in this file;
4. No such file (an older team): `sonnet`.

No `effort` is passed at spawn, and the registry records no effort level.

## How to write the suggestion to the lead

**Implemented by the script**: `resources/scripts/atwz_detect_tier.sh --model "<the lead's current model>" [--plan default|conservative]` builds the whole sentence by the rules in this section and prints it in the JSON as `lead_advice` (an empty string when there is no suggestion). /quickstart's closing message and /onboard's completion confirmation use it unchanged; the model does not build it on the spot. This section describes the rules; change the script together with it.

- Suggested values: by tier and plan (`--plan`, `default` if omitted; /onboard passes `conservative` when the user chose the conservative plan), `lead_model_suggested` and `lead_effort_suggested` from the two tables in "Values per tier" above. On Max 20x's default plan, the model is compared against `fable` (enough usage, so Fable is recommended). `api` and `unknown` have no suggested values and get no suggestion.
- Current values: the model given with `--model` (compared only when it is recognisably haiku / sonnet / opus / fable; otherwise no suggestion); the effort is the `lead_effort_current` the script reads.
- Compare by rank: models `haiku` < `sonnet` < `opus` < `fable`; effort `low` < `medium` < `high` < `xhigh` < `max`. For each item: equal → leave it out; current above the suggestion → "to lower"; current below → "to raise". Both groups empty → no suggestion.
- Within each group, on Pro put effort first and then the model; on the other plans the model first and then effort. Write the items as "type /model <suggested model>" (when the suggestion is fable, add " (Fable uses at most half of your weekly limits)") and "type /effort <suggested effort> (teammates spawned or re-spawned afterwards use the same effort level)"; when a group has two items, write "first <first item>, then <second item>".
- Put it together as one sentence, in this order:
  1. If there is anything "to lower": "You are <using <current model> / on <current effort> effort (only the items to lower, joined with "and")>, which uses up your <plan name> limits fast[on Pro when the current model is fable, add: , and Fable is pay-as-you-go on Pro]; I suggest you <items to lower>".
  2. If there is anything "to raise":
     - Max 20x without part 1: "Your Max 20x plan has enough usage; for stronger planning and judgment, you can <items to raise>". "Enough usage" is used only on Max 20x.
     - Pro: after part 1, "; for stronger planning and judgment, you can also switch <the model / the effort, joined with "and"> to <suggested values, joined with "and"> (<items to raise>); on Pro, watch your usage"; without part 1, the same starting with "For stronger planning and judgment, you can switch" (no "also").
     - Others: after part 1 "; for stronger planning and judgment, you can also <items to raise>", without part 1 "For stronger planning and judgment, you can <items to raise>".
  3. End with: ". This also becomes the default for your later sessions; you can change it again any time."
- <plan name>: Pro for `pro`, Max 5x for `max_5x`, Max 20x for `max_20x`, Team / Enterprise for `team`.
- Examples (actual script output):
  - Pro, currently opus on high effort → "You are using opus and on high effort, which uses up your Pro limits fast; I suggest you first type /effort medium (teammates spawned or re-spawned afterwards use the same effort level), then type /model sonnet. This also becomes the default for your later sessions; you can change it again any time."
  - Pro, currently haiku on medium effort → "For stronger planning and judgment, you can switch the model to sonnet (type /model sonnet); on Pro, watch your usage. This also becomes the default for your later sessions; you can change it again any time."
  - Max 20x, currently opus on medium effort → "Your Max 20x plan has enough usage; for stronger planning and judgment, you can first type /model fable (Fable uses at most half of your weekly limits), then type /effort high (teammates spawned or re-spawned afterwards use the same effort level). This also becomes the default for your later sessions; you can change it again any time."
