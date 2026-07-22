# Changelog — agent-team-work-zone (English Team Edition)

All notable changes are recorded in this file. Format follows [Keep a Changelog](https://keepachangelog.com/); versioning follows semantic versioning `vMAJOR.MINOR.PATCH`.

---

## v0.3.2 (2026-07-21)

PATCH (bug fix, fully backward compatible): **Work Rules and the five framework reference sections now actually refresh across upgrades on existing installs; teammate condensed rules now self-heal by replacement (eliminates dual copies)**.

### Fixed
- **Rules now refresh across upgrades**: previously the "Work Rules" section lived outside the README's `FRAMEWORK:START/END` markers, so no `upgrade.sh` run ever touched it — existing installs stayed frozen at whatever version they were first installed with. Adds independent `<!-- RULES:START/END -->` markers plus three new `common.sh` functions: `replace_marked_section` (a generic marker-block replacer), `ensure_rules_markers` (self-heals missing markers on existing installs — count-insensitive, recognizes the rules-section heading in either language, locates the rules section, and injects markers when absent), and `refresh_rules_section` (orchestration: self-heal → diff against source → back up the old block and replace only when there's an actual difference). The migration script now sweeps every workstation README (flat workstations and `<team>_team/` lead workstations), refreshing the rules section as needed.
- **Reference sections now refresh across upgrades**: the "Pre-installed Skills / General-purpose Custom Subagents / Role Archetype Quick Reference / Team-Created Role Definition Storage / Troubleshooting" sections in the README also lived outside the markers — once installed, they **never updated**, so users could be looking at a stale command/skill table. Adds `<!-- REFERENCE:START/END -->` markers plus two new `common.sh` functions: `ensure_reference_markers` (self-heals by locating the "Pre-installed Skills" heading and wrapping everything through end-of-file — the five sections form one combined block, not five separate ones) and `refresh_reference_section` (orchestration: self-heal → **unconditional overwrite**, no diff, no backup, since this content is 100% framework-owned). The migration adds one call for the top-level README only; workstation READMEs never contain these five sections.
- **README rules-section opening sentence rewritten**: the old "every agent must copy these rules in full into their own workstation README" text contradicted the new asymmetric distribution (teammates actually carry a condensed subset, not the full set). Replaced with: "these rules are framework-maintained and refresh on upgrade; flat workstations and team leads carry the full set (refreshed in place); teammates carry a condensed subset (`resources/teammate_rules.md`, written in by `/spawn-team`); do not hand-edit this block — changes are overwritten on the next upgrade; customize the user area outside the marker instead."

### Added
- **Teammate condensed-rules distribution + self-heal replacement**: adds `resources/teammate_rules.md` (a 7-rule excerpt wrapped in `<!-- TEAMMATE_RULES:START/END -->` markers, independent of the full 13-rule set). `/spawn-team` now writes this file's content into every new teammate workstation skeleton; both `/spawn-team`'s and `/reactivate-team`'s spawn prompts now include a self-heal instruction — if the teammate's README still has an old full rules section (heading matches the "Work Rules" title, not inside a `TEAMMATE_RULES` block), it **replaces** that old section with the condensed block (eliminating the old-and-new dual copy); otherwise, if there's no old section and no `TEAMMATE_RULES` block, it appends. The migration refreshes the `TEAMMATE_RULES` block on teammate READMEs that already have it, only when the content differs (no backup); teammate workstations that don't have the block yet are left untouched by the migration and get it the next time that teammate is spawned/reactivated.
- **Two teammate-rules additions**: rule 1 now notes that peer-to-peer collaboration (asking questions, sharing, challenging, helping) is encouraged and a core team value, while formal task assignment and prioritization remains the lead's coordination responsibility; rule 7 now notes that if you posted a roundtable report and every recipient has marked it RESOLVED, you archive it yourself.

### Migration (v0.3.1 → v0.3.2)
- **Required**: `bash _agent_team_work_zone/upgrade.sh` automatically overwrites framework files, refreshes the rules section, refreshes the reference section, and writes VERSION.
- **No user-data migration**: `TEAMMATE_INFO.json` `schema_version` stays 1, no field renames. Fully backward compatible.
- **Existing teammate workstations**: if a `TEAMMATE_RULES` block already exists and differs, it's refreshed automatically; if it doesn't exist yet (including workstations that still carry an old full rules section), the migration leaves it alone — the next time that teammate is spawned/reactivated, it replaces or appends per the self-heal instruction.

---

## v0.3.1 (2026-06-22)

PATCH (bug fix + UX improvement, fully backward compatible).

### Fixed
- **`bootstrap.sh` §6/§7 settings write target**: display mode (`teammateMode`) and permission mode (`permissions.defaultMode:"auto"`) now always write to the **global `~/.claude/settings.json`**. Previously they defaulted to the project-level `.claude/settings.json` — but `permissions.defaultMode` at project level is explicitly ignored by Claude Code (only the global value takes effect), and `teammateMode` is also a user-level setting with no effect at project level.

### Improved
- **`bootstrap.sh` §6 rewritten as "display mode selection"**: adds an option to enable split panes (`auto`) — previously only `in-process` (hide panes) was offered; updates stale copy (CC v2.1.179+ default is `in-process`); default highlight is "no change" (option 3).

### UX
- **`bootstrap.sh` §6/§7 and `upgrade.sh` major-version confirmation gate** replaced with arrow-key selection menus (new reusable `choose_option` function) — replaces the previous `y/n` text input.

### Docs
- Corrected `teammateMode` value table in `reactivate-team/SKILL.md` and `spawn-team/SKILL.md`: `in-process` is now the default (since CC v2.1.179); added `tmux` and `iterm2` (CC v2.1.186+); removed the invalid `split-pane` value; added user-level / per-session-override notes.

### Migration (v0.3.0 → v0.3.1)
- **Required**: `bash _agent_team_work_zone/upgrade.sh` — overwrites framework files + writes VERSION.
- **No user-data migration**: `TEAMMATE_INFO.json` `schema_version` stays 1, no field renames. Fully backward compatible.
- **Recommended after upgrade**: re-run `bootstrap.sh` to reset display-mode / permission preferences (any preferences previously written at project level were silently ignored by CC and should be set again in the global settings).

---

## v0.3.0 (2026-06-22)

MINOR (new feature, backward compatible): **Adds `CLAUDE.md` (always-loaded operating instructions)**. No breaking change.

### Added
- **`CLAUDE.md`**: always-loaded operating instructions for projects that use this framework — the operations-layer core principles (files over context, own your files, liveness, checkpoints, lead-coordinates / teammates-implement, teammate-signal interpretation) + **Coding Engineering Principles** (reproduced verbatim under the MIT License from [multica-ai/andrej-karpathy-skills](https://github.com/multica-ai/andrej-karpathy-skills), based on Andrej Karpathy's observations on LLM coding pitfalls; see the repo-root README acknowledgments).
- **bootstrap installs CLAUDE.md into the project root**: created if absent; if a CLAUDE.md already exists, the two sections are appended (your content is preserved), idempotent.

### Migration (v0.2.0 → v0.3.0)
- **Required**: `bash _agent_team_work_zone/upgrade.sh` auto-upgrades from v0.2.0 to v0.3.0 and installs CLAUDE.md into the project root when it re-runs bootstrap.
- **No user-data migration**: `TEAMMATE_INFO.json` `schema_version` stays 1. Backward compatible.

### Notes
- zh + en kept symmetric.

---

## v0.2.0 (2026-06-20)

Adapts to the **Claude Code 2.1.178** agent-teams API. **Requires Claude Code ≥ 2.1.178.** This release adds no new feature — it is the necessary Claude Code adaptation.

### Adapting to the 2.1.178 API changes
- **`/reactivate-team` drops Step 0**: the `TeamCreate`/`TeamDelete` tools were removed in 2.1.178. Each session auto-creates a unique session-level team (`session-<id>`), teammates auto-clean on exit, and no ghost entries accumulate on disk — so reactivate just re-spawns via `Agent(...)`.
- **`Agent(...)` spawn changes**: no longer pass `team_name` (ignored); **set no `mode`** — a teammate's permission mode can't be set per-teammate at spawn, it **inherits the lead's current mode**. For auto teammates, set `permissions.defaultMode:"auto"` or put the lead in auto first; `bootstrap.sh` now has an interactive prompt (default-on, strongly recommended).
- **Idle-hook three-tier addressing** (`teammate_idle_checkpoint.sh`): T1 payload team_name (older-CC compat) → T2 derive `${name%%-*}_team` (primary) → T3 glob fallback (>1 hits → exit 0, don't guess). Fixes cross-team same-name teammate misresolution.
- **`<slug>-<role>` naming convention**: new teammate names must be `<slug>-<role>` (slug = workstation name minus `_team`, a single token with no hyphen) so the hook can derive the workstation from the name. Existing legacy names are covered by the T3 fallback and are not force-renamed.
- **bootstrap CC floor** raised to `2.1.178`; below that it hard-stops.

### Migration (v0.1.0 → v0.2.0)
- **Required**: `bash _agent_team_work_zone/upgrade.sh` auto-upgrades from v0.1.0 to v0.2.0 (overwrites framework files + writes VERSION + prints the breaking-change notice).
- **No user-data migration**: `TEAMMATE_INFO.json` `schema_version` stays 1, no field renames.
- **Confirm Claude Code ≥ 2.1.178 before upgrading.** On CC ≤ 2.1.177, stay on v0.1.0.

### Notes
- zh + en kept symmetric.
- This release is **team-only**: the session-level team is auto-created/cleaned by Claude Code.

---

## v0.1.0 (2026-06-12)

**Initial public release** — a complete multi-agent collaboration framework.

### Contents

- Complete multi-agent collaboration framework (file-based, 12 working rules, flat + team hybrid architecture)
- Skills, subagents, hooks, role archetypes, bootstrap toolchain
- One-button `upgrade.sh` (pulls latest from GitHub main)
- Friendly `install.sh` first-time install entry point
