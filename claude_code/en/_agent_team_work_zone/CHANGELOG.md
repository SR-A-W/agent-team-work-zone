# Changelog — agent-team-work-zone (English Team Edition)

All notable changes are recorded in this file. Format follows [Keep a Changelog](https://keepachangelog.com/); versioning follows semantic versioning `vMAJOR.MINOR.PATCH`.

---

## v0.4.0 (2026-10-04)

MINOR (backward compatible): **checkpoint safety — teammates no longer write the shared registry, registry writes are validated, subagents are kept out of checkpoint loops — plus upgrade refreshes that no longer silently lose your content**.

### Changed
- Teammates no longer write `TEAMMATE_INFO.json`: `/checkpoint` drops its registry-update step, so the registry is written only by the lead. This removes the lost-update race when several teammates checkpointed at once.
- Registry `schema_version` 1 → 2: the `last_checkpoint_at` field is removed. A teammate's last checkpoint time now comes from its `working-context.md` file mtime in `/reactivate-team`, `/evaluate-team` and `/sync`. Old registries that still carry the field keep working; it is ignored. `/onboard` and `/promote-to-team` create new registries with `schema_version: 2`, and `/spawn-team` initializes per schema v2.
- `/reactivate-team` shows "Last checkpoint" as how long ago `working-context.md` was modified, with the file's `_Last updated:` line as the readable time. The receipt line reads "Resumed from checkpoint at <time>. Ready."
- `/checkpoint` confirmation names the writer: "Checkpoint written by <name> to <path>. Trigger: …".
- SessionStart hook: when a detected team is not the current agent's own workstation, the reminder now says to stay silent about it, both after a restart and after a context compaction. Previously it said "briefly mention it to the user".
- Teammate rule 2 (resend): a successful SendMessage means delivered, and silence is not loss. Resend only if SendMessage errored or the recipient says it did not arrive. Address the lead by its registered name, copied verbatim.
- Rules refresh on upgrade: where an existing README had no RULES markers yet, the rules block used to run up to the next `## ` heading, so notes written after the rules were moved into `.rules.bak`. The block now ends at the last line that matches the framework rules, extended to the end of the last numbered `### N.` rule, and stops at the first separator: `---`/`***`/`___`, an un-numbered `##`/`###` heading, or `<!--`. Lines taken into the block, or left outside it, are counted with a ⚠ warning. A same-named heading with no framework text under it (your own rules section) is skipped. To keep notes outside the managed block, separate them from the rules with `---` or an un-numbered heading.

### Added
- `/checkpoint` identity check (fail closed): a teammate confirms the workstation is its own, using its spawn prompt plus a `README.md` naming it, before writing. A subagent that only received a reminder naming someone else's workstation refuses and reports back.
- `/checkpoint` preserves the previous Part A snapshot as a Part B entry before overwriting Part A, so a bad overwrite can be recovered.
- `/reactivate-team` checks that `TEAMMATE_INFO.json` parses before spawning anyone (`jq empty`, or a PowerShell equivalent). On failure it spawns no teammate and gives restore commands: from `TEAMMATE_INFO.json.bak`, else from git.
- Registry writes in `/spawn-team`, `/add-teammate`, `/reactivate-team`, `/bench-teammate` and `/remove-teammate` are validated: write to a temp file, `jq empty` parse check, back up to `TEAMMATE_INFO.json.bak`, then `mv`. Nothing is written if a step fails. Every lead write therefore leaves a `TEAMMATE_INFO.json.bak` next to the registry.
- Schema doc: free-text fields such as `scope` must not contain an ASCII double quote. Use 「」/『』 or curly quotes, and keep progress notes out of the registry.
- Teammate README rules blocks (`TEAMMATE_RULES`) are backed up before an upgrade replaces them: `<README>.teammate_rules.bak.<timestamp>`, with a ⚠ warning. Previously a changed block was replaced with no backup.

### Fixed
- Idle-checkpoint hook no longer drives subagents into checkpoint loops: it exits early when the payload carries `agent_id`, which is present only inside a subagent call. The reminder text also tells a subagent, or an agent without file-write tools, to ignore it and report to whoever spawned it.
- Upgrading from v0.3.1 or earlier no longer overwrites user content written after the Troubleshooting section (for example a `<!-- USER:* -->` section). The reference block now ends at the last line that matches the framework text instead of at the end of the file.
- Upgrade writes are fail-soft and keep file modes: if a backup cannot be written the block is left as is (warned, "NOT refreshed") and the migration continues; temp files are created next to the target, so rewritten READMEs keep their permissions (previously they became 600) and a newly created `VERSION` gets the normal default mode.

### Known issues
- The validated registry write in five skills still uses a fixed `/tmp/info.json` temp path, so two leads writing at the same moment could collide, and the final `mv` is not atomic when `/tmp` is on a different filesystem from the project. Fixed in v0.5.0.
- If you upgraded to v0.3.2 from v0.3.1 or earlier, that upgrade may already have overwritten a section you had added after Troubleshooting in the top-level README (for example a `<!-- USER:* -->` section), with no backup. v0.4.0 prevents this from now on but cannot restore it. Check that README and, if something is missing, recover it from git (for example `git log -p -- _agent_team_work_zone/README.md`).
- `/add-teammate` still says "initialize per schema v1" while `/spawn-team` says v2. Harmless (it only appends an entry); corrected in v0.5.0.

### Migration (v0.3.2 → v0.4.0)
- **Required**: `bash _agent_team_work_zone/upgrade.sh` overwrites framework files, refreshes the top-level README framework / rules / reference blocks, refreshes the rules block of every lead/flat workstation README that has one, refreshes the `TEAMMATE_RULES` block of every teammate README that already has one (with backup), and writes VERSION. A teammate README without the block is left alone and gets it on its next spawn/reactivate.
- **Expect one `.teammate_rules.bak.<ts>` per teammate workstation that already had the block**: the teammate rules text changed in this release (rule 2), so every such block differs and is backed up before it is replaced. The full rules text did not change, so a lead/flat workstation only gets a `.rules.bak` if you edited its rules block or it had no markers yet.
- **No user-data migration**: existing `TEAMMATE_INFO.json` files are not modified; a registry at `schema_version: 1` with `last_checkpoint_at` keeps working and the field is ignored.
- **New files you may see**: `TEAMMATE_INFO.json.bak` (left by every lead registry write), `*.rules.bak.<ts>` and `*.teammate_rules.bak.<ts>` (left by the refresh when content differed). They are not cleaned up automatically.
- **File modes after an earlier upgrade**: upgrading to v0.3.2 could leave rewritten READMEs and `VERSION` at mode `600`. v0.4.0 keeps whatever mode a file has and does not restore it; if you see `600` there, restore it with `chmod 644 <file>`.
- **Check the ⚠ lines** the migration prints: text "taken into" a rules block is in the backup; text "kept outside" a block is untouched and may be old framework wording or your own content.

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
