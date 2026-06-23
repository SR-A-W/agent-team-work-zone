# Changelog — agent-team-work-zone (English Team Edition)

All notable changes are recorded in this file. Format follows [Keep a Changelog](https://keepachangelog.com/); versioning follows semantic versioning `vMAJOR.MINOR.PATCH`.

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
