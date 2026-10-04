# Changelog — agent-team-work-zone (English Team Edition)

All notable changes are recorded in this file. Format follows [Keep a Changelog](https://keepachangelog.com/); versioning follows semantic versioning `vMAJOR.MINOR.PATCH`.

---

## v0.5.0 (2026-10-04)

MINOR (backward compatible): **teammates you can tell apart from "never started" and keep reachable, rules for a shared working tree, optional checkpoint saving in git with a git lock, a skill for broadcasting rule changes, optional CLAUDE.md sections, and upgrades that leave your own files alone**.

Requirement: the optional git lock needs git 2.5 or later. Everything else works without it.

### Changed
- TeammateIdle checkpoint hook: the age gate now measures from the later of the `working-context.md` mtime and `.started`, so a just-reactivated teammate is no longer nudged at its first idle. The reminder text still reports the time since the last save. With no `.started` present, behaviour is unchanged.
- Rules self-heal in the spawn/reactivate prompts: before replacing an old full rules section in a teammate README, the teammate copies it to `README.md.teammate_rules.bak.<UTC timestamp>` and reports the backup in its receipt; the lead mentions it to the user.
- Spawn, add and reactivate prompts use absolute `<project_root>` paths. A teammate's working directory is not necessarily the project root, and `CLAUDE_PROJECT_DIR` is not set in its Bash.
- `CLAUDE.md.template` (new installs only): the "read teammate signals from reports" principle now covers messages that arrive hours late and `[to X]` heartbeat summaries, allows inspecting landed state (`git log`, finished artifacts) after a missed deadline plus an unanswered ping, and forbids telling the user an unverified cause for a teammate's silence.
- `/checkpoint` has a new last step that runs the git save when the project has turned it on; the confirmation line carries its result. Confirmation is now Step 6.
- `/spawn-team`, `/add-teammate` and `/reactivate-team` prompts tell the teammate to read the team's `RULES_LEDGER.md`, record any rule it has not recorded yet, and acknowledge it in its receipt. The lead fills the ledger from those receipts.
- README skills table: the `loop` row now describes timed wake-ups while monitoring (see rule 13), and a new `/broadcast-rule` row; the team-lead-only note includes it.
- Template `.gitignore` also ignores teammate start markers, hook logs, the idle hook's counter, the registry backup, and temp files that an interrupted write can leave behind. Rules backups stay tracked, because they can hold user content.
- `bootstrap.sh` prints a warning when git is older than 2.5 (needed only by the optional git lock), and a one-line notice when git is not installed.

### Added
- Spawn and reactivation prompts start with a step 0: the teammate writes `teammates/<name>/.started` (current UTC time) before reading anything, so the lead can tell "never started" from "busy".
- Ready / Resumed receipts end with `Model: <name>, ID: <id>`, quoted from the teammate's own system prompt (or `Model: not stated`). The lead records the ID in the registry as the new optional field `model_resolved` and flags any mismatch with the requested model or the teammate README, editing neither. `schema_version` stays 2; registries without the field keep working.
- No-receipt procedure in `/spawn-team`, `/add-teammate` and `/reactivate-team`: after about 10 minutes without a receipt, the lead reads the teammate's tmux pane (best effort), checks `.started` against the spawn time, and tells the user the possible causes. It never respawns automatically.
- Tracker agent: a new watch-and-alert mode (Mode B). A low-cost Haiku teammate waits on one outcome via `/loop`, stays idle between checks, messages the lead only on a result, an anomaly or when it stops, and requires an explicit `stop_when`.
- Work rules (README rules block):
  - rule 1: shared working tree and index discipline — commit by explicit path; no `git add -A` / `commit -a` / `stash` / `pull --rebase` / non-fast-forward merge; use `pull --ff-only`; never delete an existing `.git/index.lock` (tell the lead if it persists); and the git lock for commits, merges and pulls in a shared checkout;
  - rule 7: decision provenance (who proposed, who approved, quoted verbatim; an agreement between peers is only a proposal until the lead rules), and a ruling says which work it cancels;
  - rule 13, teammate side: stay reachable (to watch a job, schedule a wake-up with `/loop` and end the turn — teammate messages arrive only when a turn ends), plus the `.started` and model-ID receipt duties;
  - rule 13, lead side: when a teammate goes quiet (messages can arrive hours late; after a missed deadline plus an unanswered ping, inspect only landed state; `[to X]` heartbeat summaries are not reports; never respawn automatically — list the possible causes to the user; wait with `/loop`; check `.started` and the model ID after a spawn), and send a working teammate one complete correction rather than several pieces.
- Teammate rules (`teammate_rules.md`, carried into every teammate README): a notice that the block is maintained by the framework and replaced on upgrade, with the old block backed up as `README.md.teammate_rules.bak.<timestamp>`; new items 8 (stay reachable via `/loop`), 9 (decision provenance) and 10 (shared working tree and index, and the git lock).
- A new "Before you start" section in the README, and the same guidance in the user manual's Quick Start: keep `_agent_team_work_zone/` inside your project directory and always start Claude Code in that directory (starting `claude` in your home directory on an HPC login node is the common mistake; using the home directory itself as the project still works); and tracking `_agent_team_work_zone/` in git is strongly recommended (backup and rollback of your agents' project memory, bringing the team up on another machine, coordinating several developers' teams through `git push` / `git pull`), with a caution about sensitive material in public repositories.
- User manual: a "Known Limitations" section — teammate messages are delivered only at turn end; subagents cannot run `/loop` (observed for Explore); one memory failure can take down the whole team (one memory-limited job, or in-process mode); resources of the same OS account are invisible to the framework, so never kill processes by name; no convention for using `meeting_room/` across repositories; one git worktree per teammate is not supported.
- Checkpoint saving in git (optional, off by default). Turn it on per project with `bash _agent_team_work_zone/resources/scripts/atwz_checkpoint_git.sh enable`. Each `/checkpoint` then also saves the teammate's workstation files in git, so a checkpoint survives a `git stash`, a bad merge or an accidental overwrite.
  - `snapshot` mode (the default) stores the files under a private reference `refs/atwz/checkpoints/<team>/<name>`; your branch, `HEAD`, `git status` and the shared staging area are untouched, and nothing shows up in your commits.
  - `commit` mode commits the workstation's files on the current branch in a commit that contains only those files (deletions included); anything else that is staged stays staged; commit hooks run as usual.
  - The setting lives in `_agent_team_work_zone/settings.conf` (`checkpoint_git = off | snapshot | commit`); commit it so other machines share it. Commands: `enable` / `disable` / `status`; `enable` tells you at once whether it will have any effect here.
  - Each save re-checks whether it can save and reports one `saved …` or `skipped: …` line in the checkpoint confirmation. A checkpoint never fails because of git.
  - `list` and `restore` bring back a saved copy; a current file that differs is first kept as `<file>.before-restore.<UTC time>`.
  - Snapshots stay on your machine: the framework never pushes them, a normal `git push` sends only branches, and a fresh clone does not fetch them.
- Git lock for a shared checkout: `cd <project root> && bash _agent_team_work_zone/resources/scripts/atwz_git_lock.sh run -- git …` runs one git command at a time across all agents. It waits while another git operation is running (it never deletes `.git/index.lock`), waits at most 3 minutes, then gives up with exit code 75. A lock on the same machine that is over 10 minutes old and whose process has exited is cleared. Commit mode uses the lock automatically.
- `/broadcast-rule` (team lead): sends a rule change to every live teammate in one complete message. Each teammate records it in a "## Team rule changes" section of its own README and replies `ACK` followed by the rule's id (for example `ACK R-20261004-1`). The lead keeps a standing `RULES_LEDGER.md` next to `TEAMMATE_INFO.json`; teammates that are offline or not yet spawned read the ledger when they are spawned or reactivated and acknowledge in their receipt.
- Optional `CLAUDE.md` sections in `resources/claude_md_optional/`: "Messages to the user (format)" (messages triggered by a teammate's report start with **Team brief**; messages the user should read start with **To Be Read By User** and a status line: Decision needed / Progress / Correction / Quiet round) and "Plain vocabulary" (plain words, no coined names, few abbreviations, and an inline list of words the user has rejected). On a first install, `bootstrap.sh` asks about each section (`[y/N]`, default No; skipped when there is no terminal). On y it appends the section once — it is skipped if its `<!-- ATWZ-OPTIONAL:<id> -->` marker is already in `CLAUDE.md`. Install and upgrade never modify or delete existing `CLAUDE.md` content; they only append — the framework sections if missing, and optional sections only when you answer y.

### Fixed
- Registry writes in `/spawn-team`, `/add-teammate`, `/reactivate-team`, `/bench-teammate` and `/remove-teammate`: the temp file is now created with `mktemp` next to the registry (it was a shared `/tmp/info.json`, which two writers could overwrite and which was not moved atomically when `/tmp` is on another filesystem); it is seeded with `cp -p`, so the registry keeps its file mode; and it is removed on failure.
- `/add-teammate`: a missing registry is initialized per schema v2 (the text said v1).
- `/add-teammate` gives the new teammate's README the teammate rules block, with its markers, when it creates it, as `/spawn-team` already did — so later upgrades can refresh it.
- `/reactivate-team` Step 4: the jq example now defines `info=…`; it was used undefined, and with `mktemp` it would have created the temp file in the current directory.

### Known issues
- The two new scripts were checked for macOS (bash 3.2 and BSD tools) by reading the code only; nothing has been run on a Mac yet.
- The git lock only coordinates commands run through it; a plain `git` command run without it is not held back. A lock left by another machine is never cleared automatically: remove it by hand after a crash there (until then, waiters give up with exit code 75). A stale lock on the same machine is cleared only after 10 minutes.
- Checkpoint snapshots are local to the machine (not pushed, not cloned), so they do not help on a new machine; tracking `_agent_team_work_zone/` in git does. `restore` cannot recreate a workstation directory that was deleted entirely. `git push --mirror`, or an explicit push of `refs/*`, would send the snapshots.
- `.before-restore.*` copies stay in the workstation until you delete them.

### Migration (v0.4.0 → v0.5.0)
- **Required**: `bash _agent_team_work_zone/upgrade.sh`. It overwrites the framework files (`resources/`, `docs/`, `CHANGELOG.md`), refreshes the top-level README framework / rules / reference blocks, refreshes the rules block of every lead/flat workstation README that has one and the `TEAMMATE_RULES` block of every teammate README that already has one (both with backup), appends the new `.gitignore` patterns, writes VERSION, and re-runs `bootstrap.sh` (which installs the new `/broadcast-rule` skill). A teammate README without the block is left alone and gets it on its next spawn or reactivation; text above the block is never changed.
- **Expect backups**: the rules text and the teammate rules text both changed in this release, so every README whose block is refreshed gets one backup next to it — `README.md.rules.bak.<timestamp>` (top-level README and lead/flat workstations) or `README.md.teammate_rules.bak.<timestamp>` (teammates). They are not cleaned up automatically.
- **`.gitignore`**: in `_agent_team_work_zone/.gitignore`, only these patterns are appended, and only the ones that are missing, under one comment line: `*_team/teammates/*/.started`, `.hook_logs/`, `*_team/teammates/*/.checkpoint_nudge_count`, `*_team/TEAMMATE_INFO.json.bak`, `*_team/.info.??????`, `**/.README.md.??????`, `/.VERSION.??????`, `/settings.conf.??????`. Your own lines are not rewritten, reordered or removed. If the install has no `.gitignore`, none is created; the upgrade prints where the template's version is and what it would ignore.
- **Not touched**: the upgrade never creates, changes or deletes `_agent_team_work_zone/settings.conf`, any `<team>_team/RULES_LEDGER.md` or any `TEAMMATE_INFO.json`, and never modifies existing `CLAUDE.md` content (the framework sections are appended only if they are missing). No user-data migration: a registry without `model_resolved` keeps working.
- **Optional CLAUDE.md sections are not offered during an upgrade.** To add one: `printf '\n' >> CLAUDE.md && cat _agent_team_work_zone/resources/claude_md_optional/<file>.md >> CLAUDE.md` (files: `user_message_format.md`, `plain_vocabulary.md`).
- **git**: the optional git lock needs git 2.5 or later; `bootstrap.sh` warns if yours is older. Checkpoint saving in git stays off until you run `atwz_checkpoint_git.sh enable`.

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
