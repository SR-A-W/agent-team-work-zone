# TEAMMATE_INFO.json Structure

> Human-readable documentation. **Not** a runtime dependency — `/spawn-team`, `/reactivate-team`, and related skills inline the JSON structures they use; they do not Read this file.

This file is the team lead's **registry**, recording the team's current member composition and state. One per team workstation.

## Path

```
_agent_team_work_zone/<team_name>/TEAMMATE_INFO.json
```

E.g. `_agent_team_work_zone/architect_team/TEAMMATE_INFO.json`.

## Who reads / who writes

| Operation | Writes | Reads |
|---|---|---|
| `/spawn-team` | ✅ Initializes or overwrites `active_teammates` array | - |
| `/add-teammate` | ✅ Appends to `active_teammates` | - |
| `/remove-teammate` | ✅ Moves member from `active_teammates` to `offboarded_teammates` | - |
| `/bench-teammate` | ✅ Sets member `status` to `benched`, writes `benched_at`/`bench_reason` (**stays in** `active_teammates`) | - |
| `/reactivate-team` | ✅ Updates `revived_count`, `spawned_at`, `status`; `<name>` waking a benched one clears `benched_at`/`bench_reason` | ✅ |
| `/checkpoint` (teammate-called) | **Does not write** (as of schema v2 a teammate never touches this registry; see below) | - |
| `/evaluate-team` | - | ✅ Authoritative source |
| `/sync` (team lead recovery path) | - | ✅ Detects whether reactivate is needed |
| `/onboard` / `/promote-to-team` | ✅ Initializes to empty structure | - |

**Teammates write nothing in this registry** (as of schema v2): the roster is 100% lead-written. A teammate's "last checkpoint time" is now reflected by its own workstation `working-context.md` — the `_Last updated:` header and the file **mtime** — and is no longer written back as `last_checkpoint_at` (that field is removed; see below). A teammate touching the `active_teammates` structure or any member's entry is still a rule #1 low-coupling issue.

## Complete Schema (v2)

```json
{
  "schema_version": 2,
  "team_name": "architect_team",
  "lead_name": "Architect",
  "updated_at": "2026-04-18T22:30:00Z",
  "active_teammates": [
    {
      "name": "architect-fixer",
      "role_source": {
        "type": "archetype",
        "path": "resources/role_archetypes/coding/bash-scripter.md"
      },
      "model": "sonnet",
      "plan_mode_gating": false,
      "scope": "_agent_team_work_zone/training/*.sh",
      "spawned_at": "2026-04-18T22:00:00Z",
      "revived_count": 0,
      "status": "active"
    }
  ],
  "offboarded_teammates": [
    {
      "name": "architect-oldtracker",
      "offboarded_at": "2026-04-17T10:00:00Z",
      "reason": "task completed"
    }
  ]
}
```

## Field reference

### Top level

| Field | Type | Meaning |
|---|---|---|
| `schema_version` | integer | Currently 2 (v2 removed `last_checkpoint_at`). Increments on schema evolution |
| `team_name` | string | Team workstation name (with `_team` suffix, e.g. `architect_team`) |
| `lead_name` | string | Team lead's English role name (e.g. `Architect`) |
| `updated_at` | ISO8601 string | Last modification time. Updated on every write |
| `active_teammates` | array | Currently active teammates |
| `offboarded_teammates` | array | Historical offboarded teammate records |

### `active_teammates[]` entry

| Field | Type | Meaning |
|---|---|---|
| `name` | string | Teammate's globally unique name, **which must be of the form `<slug>-<role>`**: `slug` = the team workstation name minus `_team`, a single token (no hyphen); `role` may contain hyphens. E.g. `architect-reviewer`, `architect-plan-a-author`. The idle checkpoint hook derives the workstation back from the name via `${name%%-*}_team`, so the slug must have no hyphen. Legacy names (e.g. `Fixer`) are tolerated; new ones must always use `<slug>-<role>` |
| `role_source` | object | Role definition source; see below |
| `model` | string | Model used: `sonnet` / `haiku` / `opus` or specific ID |
| `plan_mode_gating` | boolean | Whether plan-mode gating was enabled at spawn |
| `scope` | string | Brief scope description (human reference only; not machine-parsed). **Free-text fields must not contain an ASCII double quote `"`** — it breaks the JSON; when you need quotation use 「」/『』/curly quotes (zero expressive loss for zh/ja teams). Likewise keep it short (a stable scope-range description); do not stuff progress prose into it (that belongs in `working-context.md` — Markdown, harmless if broken) |
| `spawned_at` | ISO8601 string | Initial spawn time |
| `revived_count` | integer | Number of times rebuilt by /reactivate-team. 0 for initial spawn |
| `status` | string | See status enum below |
| `benched_at` | ISO8601 string | **Optional**, present only when `status=benched`: time temporarily benched by /bench-teammate. Deleted on wake |
| `bench_reason` | string | **Optional**, present only when `status=benched`: bench reason (human-readable one-liner). Deleted on wake |

### `role_source` object

```json
{
  "type": "archetype" | "subagent" | "tier2" | "inline",
  "path": "resources/role_archetypes/...",   // used for archetype and tier2
  "subagent_name": "tracker",                // used for subagent
  "inline_description": "..."                 // used for inline
}
```

| `type` | Meaning | Other fields |
|---|---|---|
| `archetype` | Filled from role_archetypes | `path`: archetype file path |
| `subagent` | References a generic subagent in .claude/agents/ | `subagent_name`: subagent's name |
| `tier2` | Team-custom Tier 2 role | `path`: `<team>/teammates/<name>.md` |
| `inline` | Original, defined in spawn prompt | `inline_description`: brief description |

### `status` enum

| Value | Meaning | Handling |
|---|---|---|
| `active` | Expected to be active in the current team | /reactivate-team (no-arg) will rebuild |
| `idle` | Previously active but currently no task (still in active_teammates) | Treated as active; rebuild then wait for lead assignment |
| `benched` | **Temporarily offline**: full record + workstation + docs retained; **not** woken by /reactivate-team (no-arg) by default | Stays in `active_teammates` (full entry, with `benched_at`/`bench_reason`); only `/reactivate-team <name>` wakes it back, after which it becomes `active` and the benched fields are cleared |
| `failed_to_reactivate` | /reactivate-team spawn failed | User to decide: remove vs. manual fix |
| `offboarded` | Has been offboarded via /remove-teammate | **Should NOT be in active_teammates** — offboard moves to offboarded_teammates |

**State machine**: `active` / `idle` ⇄ `benched` (`/bench-teammate` to offline, `/reactivate-team <name>` to wake back); `active` / `idle` / `benched` → `offboarded` (`/remove-teammate`). **benched vs offboarded**: benched stays in `active_teammates`, full record, semantics "will come back"; offboarded moves to `offboarded_teammates`, slim record, semantics "task done, not coming back". Whether to wake a benched one is the **team lead's standing management judgment** (see README work rules), a black box to the user — the user only participates at the "propose—consent" conversation level, never touching status fields.

### `offboarded_teammates[]` entry

| Field | Type | Meaning |
|---|---|---|
| `name` | string | Name at offboard time |
| `offboarded_at` | ISO8601 string | Offboard time |
| `reason` | string | Offboard reason (human-readable one-liner) |

**Note**: offboarded entries preserved for audit. **Names may be reused** by future teammates (reopening same team with same name is normal).

## Version evolution

Schema change rules:

- **Minor change** (new optional fields, new status values): edit in place; `schema_version` stays
- **Major change** (rename fields, change semantics, remove fields): bump `schema_version` and add migration logic in every read/write skill

**v1 → v2 (removed `last_checkpoint_at`)**: this is a "remove field" major change, so `schema_version` bumps to 2. But **no data migration is needed** — nothing reads `last_checkpoint_at` as authoritative anymore (`/reactivate-team` switched to `working-context.md` mtime); a legacy install still carrying the field is simply **tolerated and ignored**, and v2 never writes it.

## Related docs

- Triggering error report: `error_reports/2026-04-16_subagent_vs_teammate_confusion.md` (confirmed Agent tool supports team_name + name, making this schema meaningful)
- Rule 13 (work rules): `### 13. Teammate Workstation Self-Maintenance + Checkpoint Duty` in the zh/en team-variant README
