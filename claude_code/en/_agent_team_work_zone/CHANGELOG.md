# Changelog — agent-team-work-zone (English Team Edition)

All notable changes are recorded in this file. Format follows [Keep a Changelog](https://keepachangelog.com/); versioning follows semantic versioning `vMAJOR.MINOR.PATCH`.

---

## v1.1.0 (2026-10-04)

MINOR (backward compatible): **a `reconfigure` command, arrow-key menus for every question, clearer warnings, and recommended `CLAUDE.md` sections added by default**.

### Added
- **`reconfigure`**: `npx agent-team-work-zone reconfigure [project-dir]` (or `atwz reconfigure`; source install: `bash _agent_team_work_zone/resources/scripts/bootstrap.sh --reconfigure`). It re-runs the setup on an existing install: re-syncs the framework skills, agents and hooks, merges `.claude/settings.json` (backing it up first if you had your own hooks on `SessionStart`, `TeammateIdle` or `SessionEnd`), adds any missing framework sections to `CLAUDE.md`, and asks again every install-time question (the two optional sections, git tracking, display mode, auto permission mode; as on a first install, the auto permission menu defaults to Enable, so pressing Enter through `reconfigure` turns it on). It is not a reinstall and not an upgrade: it uses the version already installed, and it does not change anything inside `_agent_team_work_zone/`. It needs an install of v1.1.0 or later; upgrade an older install first.

### Changed
- **Every question during install and upgrade is an arrow-key menu** (↑/↓ to move, Enter to confirm, number keys to pick): the language, the optional sections, git tracking, and the source installer's question about an existing `.claude/`. Defaults are unchanged except for the optional sections (below). Without a terminal nothing is asked and defaults apply, as before.
- **The two optional `CLAUDE.md` sections** ("Messages to the user (format)" and "Plain vocabulary") are now strongly recommended and **added by default on a first install**, also when there is no terminal (the installer then prints how to remove them: delete the section marked `<!-- ATWZ-OPTIONAL:<id> -->`). **An upgrade never adds them and never asks**, so after upgrading, your agents keep writing to you as before; to add them, run `reconfigure` in a terminal. `reconfigure` without a terminal leaves them alone. They are only ever appended; existing `CLAUDE.md` content is never changed or removed.
- **Upgrades no longer ask about display mode and auto permission mode.** These are asked on a first install and by `reconfigure` only; an upgrade keeps your current settings and tells you how to change them. (Before, pressing Enter through an upgrade could turn auto permission mode on.)
- **Warnings stand out**: lines starting with ⚠ are bold orange-red, and options marked as recommended are green. Colours appear only in a terminal and never when `NO_COLOR` is set; logs and pipes get plain text.
- **npm `upgrade`**: if it cannot tell whether the install is the Chinese or the English edition, it shows a language menu (without a terminal it still asks for `--lang`).

### Fixed
- v1.0.0 described a separate npm package named `atwz` so that `npx atwz …` would work. npm does not accept that name, so that package does not exist. The `atwz` command itself is unchanged: install the main package once with `npm i -g agent-team-work-zone`, then use `atwz <command>`; for one-off use, run `npx agent-team-work-zone <command>`. The npm README, the `help` text and the guides are corrected.

### Migration (v1.0.0 → v1.1.0)
- `npx agent-team-work-zone@latest upgrade`, or `bash _agent_team_work_zone/upgrade.sh`. No user data is migrated and the work rules did not change, so no `.bak` files are created. The upgrade does not add the optional `CLAUDE.md` sections and does not touch your display-mode or permission settings; run `reconfigure` afterwards if you want to change any install-time choice.

---

## v1.0.0 (2026-10-04)

MAJOR (no breaking change): **install and upgrade with npm**. How your agent teams work is unchanged; this release adds a new way to install and upgrade the framework, a notice when a newer version is out, and a git check on first install. The major version marks the new distribution channel. `bash _agent_team_work_zone/upgrade.sh` keeps working as before.

### Added
- **npm package** `agent-team-work-zone` (Node.js 18 or later, plus bash and jq; native Windows is not supported):
  - `npx agent-team-work-zone init [project-dir] [--lang zh|en]` sets up `_agent_team_work_zone/` in a project (the current directory if none is given) and runs the installer. If the project already has a `.claude/` directory, it merges into it: framework skills and agents are added or updated by name, your own are kept, and `.claude/settings.json` is merged (the framework's `SessionStart`, `TeammateIdle` and `SessionEnd` hooks replace any you had for those three events; if you had any, your original file is first saved as `.claude/settings.json.bak.<timestamp>` and the installer prints its path). It refuses if the work zone already exists. Without `--lang` it asks when run in a terminal, and uses English otherwise.
  - `npx agent-team-work-zone upgrade [project-dir] [--yes]` upgrades an existing install from the package itself, with no download. It detects the installed language.
  - `--version` and `help`.
  - Install it once with `npm i -g agent-team-work-zone` to get the short command `atwz` (`atwz init`, `atwz upgrade`). A small package named `atwz` also exists so that `npx atwz …` works; install only one of the two globally. *(Corrected in v1.1.0: npm did not accept that package name, so it does not exist.)*
- **New-version notice**: when Claude Code starts, a hook compares your version with the latest published one and, if yours is older, prints the upgrade commands (npm and source) and the reminder to restart sessions afterwards. It looks up the latest version at most once a day, in the background (once a newer version is found, every session start shows the notice until you upgrade), and stays silent on any failure, so it never slows down or blocks a session. Turn it off with `ATWZ_UPDATE_CHECK=0` or by creating `_agent_team_work_zone/.no_update_check`.
- **Git check on first install**: if the project is not in a git repository, or the work zone is not at the repository root, the installer warns. At the repository root it asks whether to track `_agent_team_work_zone/` in git (strongly recommended; default yes). Answering no adds `/_agent_team_work_zone/` to the project's `.gitignore`. Without a terminal it does not ask and leaves tracking on. Upgrades never ask.
- `UPGRADE_SOURCE_DIR=<dir> bash _agent_team_work_zone/upgrade.sh` upgrades from a local copy of the framework instead of downloading it.

### Changed
- **Major-version upgrades** now print what the new major version changes, what the upgrade overwrites (framework files; the framework-maintained rules blocks in READMEs are refreshed, with backup; `.claude/settings.json` is merged again) and what it leaves alone (what you wrote in your workstations and `meeting_room/`, registries, `settings.conf` and other data), and suggest committing `_agent_team_work_zone/` to git first; the upgrade itself makes no backup. Confirm in a terminal, or with `--yes` (`ATWZ_ASSUME_YES=1`) when there is no terminal. Without either it cancels with exit code 3 and says how to confirm (it used to print only "Upgrade cancelled" and exit 0).
- At the end of an upgrade: restart your Claude Code sessions and run `/reactivate-team` for running teams — sessions and teammates that were already running may still use the old skills.
- Source install (`install.sh`) in a project that already has a `.claude/` directory: the question now says what actually happens (a merge, as described above for `init`); declining, or running without a terminal, exits with code 3 and prints the command to finish the install (`bash _agent_team_work_zone/resources/scripts/bootstrap.sh`). It used to exit 0. Its closing message now gives both upgrade commands (npm and source).
- The upgrade now also replaces the top-level `_agent_team_work_zone/upgrade.sh` with the new version (safely, while the old one is running).
- The optional "Messages to the user (format)" `CLAUDE.md` section now asks for the heading to be a level-1 Markdown heading (`# To Be Read By User`) followed by a bold status line, so it stands out. Optional sections are only ever appended, so if you added this section earlier, your `CLAUDE.md` keeps the old wording: update it by hand from `resources/claude_md_optional/user_message_format.md`.
- `docs/upgrade_guide.md`: new sections on npm, upgrading from a local directory, major-version upgrades, the new-version notice, and what to do after an upgrade.

### Fixed
- Running the installer no longer changes the file mode of an existing `.claude/settings.json` (it used to become `600`). Hook commands now quote the project path, so they also work when the path contains spaces. An upgrade cancelled at the confirmation step, or one that finds you are already up to date, no longer leaves a copy of the new framework in `_agent_team_work_zone/.upgrade/`.

### Known issues
- If your `CLAUDE.md` contains the framework sections under headings in the other language (or under renamed headings), running the installer again, or upgrading, appends a second copy of those sections (running the installer again also repeats the first-install questions; an upgrade does not ask). Nothing existing is changed or removed; delete the duplicate by hand. A fix is planned.
- A skill or agent of your own that has the same name as a framework one is replaced by the framework's, without a backup. Rename yours (or back it up) before installing.
- Hooks you add again to `SessionStart`, `TeammateIdle` or `SessionEnd` are replaced again at the next install or upgrade (a new `settings.json.bak.<timestamp>` is made each time). Hooks on other events are kept.
- `jq` is required by the installer and the upgrade (to write and merge `.claude/settings.json`); without it they stop with exit code 1. The installer's own `jq` check still calls it optional, which is wrong.
- Installing both `agent-team-work-zone` and `atwz` globally fails because both provide the `atwz` command; install only one. *(No longer applies: see v1.1.0.)*
- The new scripts were checked for macOS by reading the code; they have not yet been run on a Mac.

### Migration (v0.5.0 → v1.0.0)
- **With npm**: `npx agent-team-work-zone@latest upgrade` (add `--yes` when there is no terminal). **From source**: `bash _agent_team_work_zone/upgrade.sh`.
- This is a major version, so the upgrade asks you to confirm and shows what it overwrites. No user data is migrated, and the work rules did not change, so no `.rules.bak` files are created.
- After upgrading, restart your Claude Code sessions and run `/reactivate-team` for running teams.

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
