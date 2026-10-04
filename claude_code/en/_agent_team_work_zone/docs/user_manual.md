# User Manual — `_agent_team_work_zone/`

## What is this

`_agent_team_work_zone/` is a **multi-agent collaboration workspace template** designed specifically for Claude Code's **experimental Agent Teams feature**. It lets you:

- Use a **single-person flat workstation** for simple tasks (Secretary, GitKeeper, etc.)
- Use a **team lead + team office** for complex tasks, where the lead forms a 3–5 person Claude Code agent team that works in parallel
- Achieve asynchronous communication and persistent auditing through a **file-system-driven** meeting_room and roundtable
- Keep it a **black box for the human user**: you interact in natural language, and the agent autonomously decides when to promote, when to form a team, and when to invoke a scheduled tracker

---

## Platform Support

| Platform | Install / Upgrade | Runtime Persistence | Tracker Scheduling |
|---|---|---|---|
| **Linux** | ✅ `npx agent-team-work-zone` (or `install.sh` / `upgrade.sh`) | tmux + `/loop` | teammate + `/loop` |
| **macOS** | ✅ `npx agent-team-work-zone` (or `install.sh` / `upgrade.sh`; same scripts as Linux; verified zero blockers) | tmux / iTerm2 split-pane / in-process | Desktop Scheduled Tasks |
| **Windows** (native) | ⏳ Next major version | in-process (weak persistence) | Desktop Scheduled Tasks |
| **Windows + WSL** | ✅ Use the Linux path | tmux inside WSL | teammate + `/loop` |

**Why the same scripts work on macOS**: all `.sh` files use `#!/usr/bin/env bash` (auto-picks Homebrew bash if installed, otherwise falls back to `/bin/bash 3.2` which also works), and the user path uses no bash 4+ features. `stat -c %Y` has a BSD fallback `|| stat -f %m`; there are no `sed -i` / `date -d` / `grep -P` or other GNU-only constructs. Dependencies (`curl` / `tar` / `git` / `bash`) ship with macOS.

**Why native Windows is deferred**: the 3 runtime hooks (`session_start_check.sh` / `teammate_idle_checkpoint.sh` / `session_end_final_checkpoint.sh`) must be ported to PowerShell — a significant effort scheduled for the next major release (v2.x). **WSL users can use it today** — drop the template into a project inside WSL and follow the Linux path.

---

## Quick Start

### 1. Install

**Requirements:** Node.js 18 or later (only to run the installer); bash — Linux, macOS, or WSL on Windows (native Windows is not supported); `jq` (the setup step uses it to add the framework's hooks to `.claude/settings.json` and stops without it); Claude Code 2.1.178 or later.

#### With npm (recommended)

From your project directory (it must already exist):

```bash
cd /path/to/your/project
npx agent-team-work-zone init --lang en     # or --lang zh for the Chinese edition
```

- This puts `_agent_team_work_zone/` into the project and runs its setup script (`bootstrap.sh` — see below). You can also name the project instead of changing into it: `npx agent-team-work-zone init /path/to/your/project --lang en`.
- Without `--lang`, it asks which language you want when run in a terminal, and uses English otherwise.
- It stops if `_agent_team_work_zone/` is already there. To update an existing install, see "Upgrading" below.
- For a shorter command, install once with `npm i -g agent-team-work-zone` and then use `atwz init --lang en`. `npx atwz init …` also works without installing. Install only `agent-team-work-zone` globally, not the separate `atwz` package as well: both provide an `atwz` command.
- **If the project already has a `.claude/` directory**, the install merges into it without asking. The framework's skills and agents are added or updated by name. Yours are kept if their names differ from the framework's; one with the same name as a framework skill or agent (for example `checkpoint` or `reviewer`) is replaced by the framework's version, with no backup, so rename or back up such a skill or agent before installing. `.claude/settings.json` is merged: on three hook events (`SessionStart`, `TeammateIdle` and `SessionEnd`) the framework's hooks replace any you had, and hooks on other events are kept. If you had hooks of your own on those three events, `settings.json` is first copied to `.claude/settings.json.bak.<UTC time>`, and that path is printed. To use your hooks again, copy your own entries for those three events from the backup into the same event lists in the new `settings.json`. The next upgrade replaces those three lists again (and makes a new backup), so you need to add them back after every upgrade.
- **If the install stops partway** (its setup step fails), `_agent_team_work_zone/` stays in place. Fix the problem it reports, then finish from the project directory with `bash _agent_team_work_zone/resources/scripts/bootstrap.sh`; running `init` again would stop, because the work zone is already there. A common case is a missing `jq`: install it (for example `sudo apt install jq` or `brew install jq`), then run that command.

#### From source (alternative)

```bash
# Clone the repo
git clone <repo-url>
cd agent-team-work-zone

# Copy the Chinese team template into your own project root
cp -r claude_code/zh/_agent_team_work_zone /path/to/your/project/
cd /path/to/your/project

# One-click bootstrap
bash _agent_team_work_zone/resources/scripts/bootstrap.sh
```

This runs `bootstrap.sh` directly, which merges into an existing `.claude/` in the same way as the npm install (see above). `bash _agent_team_work_zone/install.sh` does the same, but when `.claude/` already has content it first asks `Install into the existing .claude/? [y/N]`. Answering no, or running without a terminal, leaves `.claude/` unchanged and prints the `bootstrap.sh` command to finish the install later.

> The English version will be generated later by the Translator.

> **⚠️ Claude Code version requirement (this template)**: This template is adapted for **Claude Code 2.1.178**'s agent-teams API (session-level auto team, `TeamCreate`/`TeamDelete` removed, the `Agent` tool's `team_name` ignored) and requires **CC ≥ 2.1.178**. If your Claude Code is ≤ 2.1.177, use **[release v0.1.0](https://github.com/SR-A-W/agent-team-work-zone/releases/tag/v0.1.0)** instead (targets the old API).

Bootstrap will:
- Check the Claude Code version (>= v2.1.178); if it doesn't meet the floor, exit directly and point to release v0.1.0
- Check for tmux (**strongly recommended, not required** — see the note below; without it, in-process mode is the fallback)
- Sync skills + agents to `.claude/`
- Create or merge `.claude/settings.json` to enable `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`
- On first install, check git: if the project is not in a git repository, or is inside one but not at its root, it tells you. At the root of a repository it asks whether to track `_agent_team_work_zone/` in git (default yes, recommended). Answering no adds `/_agent_team_work_zone/` to the project's `.gitignore`; delete that line later if you change your mind. Without a terminal it does not ask and changes nothing.

> **💡 Strongly recommended: run Claude Code inside tmux** (not just on HPC — local benefits too). When the terminal closes / SSH disconnects, tmux keeps the Claude Code process alive and the session uninterrupted — **you come back, `tmux attach`, and keep going, sparing yourself frequent `/reactivate-team`**. It is strongly recommended but **not required**: without tmux you can still run the full agent-team feature set in in-process mode. To get "persistent **and** no extra panes", launch claude inside tmux + set `teammateMode: "in-process"` (see the developer manual's "Persistence comes from tmux" section).

> **🍎 macOS users**: dependencies (`curl` / `tar` / `git` / `bash`) ship with macOS, **just run `npx agent-team-work-zone init`** (Node.js does not ship with macOS: install it first, e.g. `brew install node`) **or, from source, `bash _agent_team_work_zone/install.sh`**. tmux via `brew install tmux`, or use **iTerm2 split-pane** (auto-detected by the reactivate-team skill), or skip tmux entirely and rely on in-process. bash 3.2 (the system bash) is fine — the user path uses no bash 4+ features.

> [!IMPORTANT]
> **Keep `_agent_team_work_zone/` inside your project directory, and always start Claude Code in that directory** — the directory that *contains* `_agent_team_work_zone/`.
>
> A common mistake is to log in to an HPC cluster (or any server) and start `claude` in your home directory while the work zone sits in a project folder. Then:
> - the project's hooks and settings in `.claude/` are not loaded, and its skills are not available at startup;
> - workstation (each agent's folder in the work zone) paths are resolved from the project root, so checkpoints and reactivation (`/reactivate-team`) look in the wrong place;
> - teammates start in the lead's current directory — if the lead runs in the wrong directory (or its shell has moved into a subdirectory), its teammates start there too and their relative paths fail.
>
> So: `cd /path/to/your/project`, then run `claude`. Using your home directory *as* the project is fine, as long as `_agent_team_work_zone/` is directly inside it and you start Claude there. We still strongly recommend a project-specific agent team work zone inside the project directory, with its own separate Claude Code session.

#### Track `_agent_team_work_zone/` in git (strongly recommended)

Commit `_agent_team_work_zone/` to your project's git repository together with your code, and don't add it to `.gitignore`. What git tracks is the agents' core working memory: role definitions, checkpoints, work journals, discussion notes and the team registry. Runtime-only temporary files are excluded by the work zone's own `.gitignore`.

- **The agents' working memory and logs are version-managed too.** Checkpoints, work journals, discussion notes and decisions are increasingly an important part of a project's development record. Tracking them in git — especially once pushed to GitHub — means the agents' project memory is managed by git: it is backed up, which greatly lowers the risk of losing it, and it can be rolled back, for example when the agents or the project have gone off track.
- **Easy migration to a new machine.** Clone the project on another machine, run `bash _agent_team_work_zone/resources/scripts/bootstrap.sh` there once from the project directory (it installs the skills and hooks and sets Claude Code up; this works the same whether you first installed with npm or from source), start Claude in the project directory, and `/reactivate-team` brings back an agent team with the same roles and the same state.
- **Multi-developer collaboration.** Each developer can run one or more agent teams in the same project. The teams learn about each other through the work zone, and communicate or leave messages for each other via `git push` / `git pull` (for example through `meeting_room/`).

```bash
git add _agent_team_work_zone
git commit -m "Track the agent team work zone"
```

> [!CAUTION]
> Workstations can contain sensitive material (paths, hostnames, excerpts of data or conversations). For a public repository, review or scrub before pushing, or keep the work zone in a private repository.

#### Upgrading

From the project directory:

```bash
npx agent-team-work-zone@latest upgrade      # or: npx agent-team-work-zone@latest upgrade /path/to/your/project
```

- With a global install: `npm i -g agent-team-work-zone@latest`, then `atwz upgrade`.
- From source: `bash _agent_team_work_zone/upgrade.sh` still works (it downloads the latest version from GitHub).
- Only the framework's own files are updated, and the skills and hooks in `.claude/` are refreshed. Your agents' work is not touched: their checkpoints, journals and to-do lists, the documents in the meeting room, the team registries and `settings.conf` stay as they are. (The rules section that the framework maintains inside each agent's README is updated.)
- `.claude/settings.json` is merged again at every upgrade, with the same rule as at install: on `SessionStart`, `TeammateIdle` and `SessionEnd` the framework's hooks replace yours, and if you had your own there, `settings.json` is first backed up to `.claude/settings.json.bak.<UTC time>`.
- An upgrade to a new major version asks you to confirm. Without a terminal, add `--yes` (with `upgrade.sh`, set `ATWZ_ASSUME_YES=1`).
- An upgrade runs the installer again. In a terminal it may ask once more about two global Claude Code settings it writes to `~/.claude/settings.json`: the teammate display mode and auto permission mode. To keep what you chose before, pick "no change" for the display mode and "skip (leave permission mode as-is)" for auto permission mode.
- **After any upgrade, restart your Claude Code sessions and run `/reactivate-team` for each running team.** Sessions and teammates that were already running may still be using the skills as they were loaded when they started: we have seen running teammates keep following the old `/checkpoint` steps after an upgrade until they were started again.

#### New-version notice

When a Claude Code session starts in the project, it shows a short notice with the upgrade commands if a newer version has been published. The latest version is looked up at most once a day, in the background, so session start never waits for it. Once a newer version has been found, the notice appears from the next session start on, and at every start until you upgrade. If a lookup fails (for example, no network), the version found last time is used; if no lookup has ever succeeded, nothing is shown. To turn the notice off, set the environment variable `ATWZ_UPDATE_CHECK=0`, or create the file `_agent_team_work_zone/.no_update_check` (commit that file to turn it off for everyone on the project).

### 2. Launch a conversation for each role

```bash
claude -n "Secretary"
```

After entering the conversation, run `/onboard`:

```
/onboard Assist the project owner in managing the project and multi-agent collaboration
```

The skill will first ask which you want:
- **(1) Flat workstation** — a one-person workstation, for simple tasks
- **(2) Team Lead** — with a team office, for complex tasks

Then it will automatically complete naming, workstation creation, and member-table registration.

### 3. Daily workflow

#### Assigning a task to an agent

**In natural language**, no need to memorize commands:

```
User: Architect, I want to refactor the training pipeline to support multi-node training
Architect: This task requires multiple capabilities (model architecture, launch scripts,
          environment configuration). I suggest forming a team for this. Is that OK?
User: OK
[Architect autonomously invokes /spawn-team, running through the 6-phase lineup process]
Architect: [presents the lineup proposal]
User: [provides feedback and adjustments]
Architect: [after adjustment emits the spawn prompt; Claude Code actually spawns the team]
```

#### Following up on progress

```bash
claude --resume "Architect"
# Enter conversation
/check-inbox
```

`/check-inbox` scans:
- The top-level `_agent_team_work_zone/meeting_room/` (cross-team communication)
- The `roundtable/` of Architect's own team (intra-team communication + tracker reports)

Items awaiting handling are shown in chronological order.

#### Restoring after a long period of inactivity

```
/sync
```

Will:
- Restore identity (two-tier identification: first infer from context, only read files if that fails)
- Scan project-team member changes
- Scan both levels of meeting_room / roundtable
- Output an action list

#### Handing off tasks to another agent

When an agent's responsibilities change, or when you need to entrust tasks in hand to someone else, use `/handoff`:

```
# Giver (e.g. you no longer own the auth module)
/handoff --give
[skill collects the task list + each task's why + progress + related files through dialogue]
[generates _agent_team_work_zone/meeting_room/<SELF>_HANDOFF_<date>_<slug>.md]

# Receiver (in the receiver's session)
/handoff --take
[skill scans HANDOFF files with to: <SELF>]
[presents the task list for user confirmation]
[appends to their own TODO.md, and changes the handoff document's status to IN_PROGRESS]
```

`/handoff` is **a single command with dual modes** — when invoked without arguments it asks which side you are (`--give` / `--take` are shortcut arguments). Treat the task as a black box: this skill is only responsible for passing information intact; it makes no assumptions about how the receiver will complete the task (the receiver is free to hand it off again, form a team, or handle it personally — none of that is within handoff's concern).

Typical scenarios:
- **Responsibility changes**: the original agent is no longer responsible for a certain area
- **Post-refactor migration**: in-flight tasks from an old workflow move to the agent corresponding to the new architecture
- **Temporary absence**: the giver needs to be offline for an extended period and temporarily entrusts tasks to someone else

---

## Core Concepts

### Flat workstation vs. Team workstation

| Type | Directory Naming | When to use |
|---|---|---|
| Flat workstation | `<name>/` | Simple tasks, completable solo (secretary, git management, translation, etc.) |
| Team workstation | `<name>_team/` | Complex tasks (involving multiple specialized skills, parallel work, adversarial review) |

Flat workstations have basic files such as README, notes, TODO.
Team workstations additionally have:
- `roundtable/` — intra-team communication
- `archive/` — intra-team archive
- `team_recipes/` — audit records produced by `/spawn-team`
- `teammates/` — archive of team-custom roles (optional)

### Upgrade path: flat → team lead

When a flat agent foresees that a task will become complex, it will **proactively** suggest an upgrade:

```
Flat agent: I see this task will involve multiple capabilities and parallel work.
          I suggest upgrading me to a team lead. After the upgrade, the directory
          is renamed from architect/ to architect_team/, and the work history is
          preserved intact. Agree?
User: Agreed
[agent autonomously invokes /promote-to-team]
```

**Important**: `/onboard` only runs once at conversation start; it does not handle upgrades. Upgrades use the dedicated `/promote-to-team`.

### Two-layer communication

| Layer | Purpose | Frontmatter |
|---|---|---|
| Top-level `meeting_room/` | Cross-workstation / cross-team / global announcements | `from: Architect` (capitalized) |
| Intra-team `<team>/roundtable/` | Team-internal lead ↔ teammate, tracker reports | `from: architect_team/tracker` (lowercase with slash) + `kind` field |

### Tracker — scheduled monitoring of long-running tasks

When a team lead needs to watch a long-running task, it launches a tracker based on the role definition in `resources/agents/tracker.md`. **The launch path splits by platform:**

- **HPC / Linux**: the lead summons tracker as a teammate via `/spawn-team`; tracker runs `/loop 12h <prompt>` in its own tmux pane to enter polling mode. **Survives SSH disconnect** (provided the lead's claude was launched inside tmux + `teammateMode: "tmux"`). See "HPC deployment guide" below.
- **macOS / Windows**: the lead creates a Scheduled Task in your Claude Code Desktop (Routines → New routine → Local form, or just tell Desktop "create a scheduled task ..."). At each fire, Desktop starts a fresh session running the tracker prompt → writes a report → exits. Zero tokens between firings. **Preconditions**: the computer must be awake, and on the first manual Run Now you must tick all "always allow" prompts (otherwise cron will be blocked by permission dialogs). For complete fields (name / instructions / model / schedule / working folder / worktree / permission mode) and tracker's recommended values see `resources/agents/tracker.md` "Option 2"; the prompt template is in `resources/desktop_task_skill_template.md`.

Common conventions:

- **Training tasks**: default every 12 hours
- **Eval tasks**: default every 4 hours
- Reports go to `<team>/roundtable/Tracker_REPORT_<timestamp>.md`
- **You don't touch deployment details directly** — handled by the team lead, a black box to you
- Full deployment guide: `resources/agents/tracker.md` → "Deployment options (split by OS)"

### HPC deployment guide

On HPC / Linux you must use tmux to survive SSH disconnects, otherwise teammates such as tracker get killed by SIGHUP. Full bring-up procedure:

#### 1. Install tmux ≥ 3.2

```bash
# Ubuntu / Debian
sudo apt install tmux

# RHEL / CentOS / Fedora
sudo yum install tmux  # or dnf

# HPC users without sudo
conda install -c conda-forge tmux
```

#### 2. Configure `~/.claude/settings.json`

```json
{
  "teammateMode": "tmux"
}
```

Or use `"auto"` — as long as the lead's claude is launched from within tmux.

#### 3. One-shot tmux + claude bootstrap

```bash
bash _agent_team_work_zone/resources/scripts/start_hpc_session.sh
# then:
tmux attach -t claude_hpc
```

The script: checks tmux is installed → checks whether you're already inside tmux → if not, `tmux new -s claude_hpc` and starts `claude` inside → prints attach instructions.

#### 4. Inside tmux, form a team and summon tracker

```
You: /onboard
You: Architect, I kicked off an SFT training (squeue id 12345); watchlist:
   ./runs/sft/status, tail of logs/train.log; monitor every 12h
[Architect spawns tracker as a teammate via /spawn-team, with the spawn prompt
 saying "On startup execute /loop 12h <polling task prompt>" ]
[tracker teammate starts in a new tmux pane → issues /loop itself → enters polling]
```

#### 5. SSH disconnect / reconnect

```bash
# After SSH drops:
tmux attach -t claude_hpc
# Both lead and tracker panes are still running
```

As long as the tmux session is alive, all panes are alive; conversations with the lead and tracker are not lost.

#### 6. Verify the teammate is really tmux-backed

```bash
jq '.members[] | {name, tmuxPaneId, backendType}' \
   ~/.claude/teams/<team-name>/config.json
```

- `tmuxPaneId` like `"%12"` → ✓ correct, survives SSH drop
- `tmuxPaneId == "in-process"` → ✗ fell back to in-process; restart the lead per the "HPC deployment guide"

#### 7. 7-day renewal reminder

`/loop` tasks **automatically expire after 7 days**: the cron task is deleted after one final fire on day 7, but the tracker session itself stays alive — it just stops polling. Handling:

- **Short tasks**: on day 6 the lead `SendMessage` tracker to re-issue `/loop` (recommended)
- **Long tasks (> 6 days)**: every epoch, spawn a fresh tracker — don't try to renew indefinitely
- **Don't** write an auto-renewal daemon — manual control is safer than invisible automation

### Role Archetypes (`resources/role_archetypes/`)

**Templates** referenced by the team lead during `/spawn-team`, not subagent definitions. 9 in total:

- **coding/**: bash-scripter, model-architect, dataset-specialist
- **config/**: training-config-author (LLaMA-Factory, VERL), eval-config-author (skythought, evalscope)
- **infra/**: env-configurator → container-builder (prerequisite chain)
- **analysis/**: data-analyzer, result-reporter

### General-purpose Subagents (`resources/agents/` → `.claude/agents/`)

5 project-wide general-purpose Claude Code subagents:

- **tracker** — scheduled monitoring (haiku)
- **investigator** — hypothesis-driven deep investigation (**opus**, flagship model)
- **reviewer** — checklist-based code review (sonnet)
- **devil-advocate** — adversarial challenge (**opus**, flagship model, no memory)
- **git-repo-manager** — git management (sonnet)

### Checkpoint git saving (optional)

Every `/checkpoint` can also save the teammate's workstation files in git, so a checkpoint survives a `git stash`, a bad merge or an accidental overwrite. It is **off by default**; turn it on per project.

**Two modes:**
- **`snapshot`** (recommended): the workstation's files are saved to a private git reference, `refs/atwz/checkpoints/<team>/<name>`. Your branch, `HEAD`, `git status` and the shared staging area are not touched, so nothing shows up in your commits.
- **`commit`**: the workstation's files are committed on the current branch with a commit that contains only those files (files deleted from the workstation are committed as deletions). Anything else that is staged stays staged and out of the commit. Commit hooks run as usual.

**Turn it on or off** (from the project directory):
```bash
bash _agent_team_work_zone/resources/scripts/atwz_checkpoint_git.sh enable            # snapshot mode
bash _agent_team_work_zone/resources/scripts/atwz_checkpoint_git.sh enable commit     # commit mode
bash _agent_team_work_zone/resources/scripts/atwz_checkpoint_git.sh disable
bash _agent_team_work_zone/resources/scripts/atwz_checkpoint_git.sh status
```
The setting is stored in `_agent_team_work_zone/settings.conf` (`checkpoint_git = off | snapshot | commit`); you can also edit it by hand. Commit this file, so teammates on other machines share the setting. `enable` tells you at once whether it will have any effect here.

**When it has no effect.** Each save checks again and, if it cannot save, reports one `skipped: …` line instead:
- the work zone is not inside a git work tree;
- the workstation's `working-context.md` is ignored by git (for example, `_agent_team_work_zone/` is in your `.gitignore`);
- nothing changed since the last snapshot.

Files that are untracked but not ignored are saved too, because `git stash -u` would otherwise remove them without a trace. Ignored files and runtime files (`.started`, `.checkpoint_nudge_count`, `*.before-restore.*` copies) are never saved. A checkpoint never fails because of git: the result appears as one extra line in the teammate's checkpoint confirmation.

**Getting a saved copy back:**
```bash
S=_agent_team_work_zone/resources/scripts/atwz_checkpoint_git.sh
bash $S list    /abs/path/to/_agent_team_work_zone/<team>/teammates/<name>                     # history
bash $S restore /abs/path/to/_agent_team_work_zone/<team>/teammates/<name>                     # all files, latest save
bash $S restore /abs/path/to/_agent_team_work_zone/<team>/teammates/<name> working-context.md --from <rev>
```
- A current file that differs from the saved one is first kept as `<file>.before-restore.<UTC time>`; delete those copies once you no longer need them.
- `--from` takes any revision shown by `list`, for example `refs/atwz/checkpoints/<team>/<name>~3`.
- With saving turned off, `list` and `restore` still read the snapshot reference. `restore` needs the workstation directory to exist; it cannot recreate a workstation that was deleted entirely.
- Restoring is done by the workstation's owner (the teammate, at the lead's request) or by you — the lead does not edit a teammate's files.
- Without the script: `git log refs/atwz/checkpoints/<team>/<name>` shows the history, and `git show refs/atwz/checkpoints/<team>/<name>:_agent_team_work_zone/<team>/teammates/<name>/working-context.md` prints the latest saved copy (`<ref>~N:` for older ones).

**Snapshots stay on your machine.** The framework never pushes them, and a normal `git push` sends only branches. A fresh `git clone` does not bring them either. Only `git push --mirror` or pushing `'refs/*'` explicitly would send them. To delete them: `git update-ref -d refs/atwz/checkpoints/<team>/<name>`, or all at once with `git for-each-ref --format='%(refname)' refs/atwz | xargs -n1 git update-ref -d`.

**The git lock.** Everyone in the project shares one checkout and one staging area, so two commits, merges or pulls at the same moment can interfere. `atwz_git_lock.sh` runs one git command at a time across all agents:
```bash
cd /path/to/your/project && bash _agent_team_work_zone/resources/scripts/atwz_git_lock.sh run -- git commit -m "…" -- <path>
```
(Run it from the project directory — the one that contains `_agent_team_work_zone/` — so it works even when the project is a subdirectory of a larger repository.)
It waits while another git operation is running (it never deletes `.git/index.lock`), waits at most 3 minutes, and then gives up with exit code 75. Commit mode uses this lock automatically.

**Requirements:** git 2.5 or later. The scripts are written for bash 3.2 (macOS) and Linux; macOS compatibility was checked by reading the code, not by running it on macOS.

### Changing rules for a running team

Editing a rules file does not reach teammates that are already running: their instructions were fixed when they were spawned. To change a rule for the whole team, ask the lead to send it with **`/broadcast-rule`** (after you agree to the change):
- every live teammate receives the rule once, in its final wording, records it in a "## Team rule changes" section of its own README, and replies `ACK <id>`;
- the lead records the rule and every acknowledgement in the team's `RULES_LEDGER.md` (next to `TEAMMATE_INFO.json`);
- teammates that are offline (benched) or not yet spawned read the ledger when they are reactivated or spawned, and acknowledge in their receipt.

The skill does not edit the framework README or `teammate_rules.md`. A rule that should become permanent framework text is a separate change. To reach other teams, use `meeting_room/` with `to: ALL`.

### Optional CLAUDE.md sections

Two optional sections can be added to your project's `CLAUDE.md`. On first install, `bootstrap.sh` asks about each one when run in a terminal (default No); an upgrade never asks, so to add one later, see below. In both cases, install/upgrade never modify or delete existing CLAUDE.md content; they only append — the framework sections if missing, and optional sections only when you answer y.

- **Messages to the user (format)** (`resources/claude_md_optional/user_message_format.md`): don't flood you with messages; a message triggered by a teammate's report starts with **Team brief:**; anything you should read or decide starts with a level-1 heading, `# To Be Read By User`, on its own line, followed by a bold status line (**Decision needed** / **Progress** / **Correction** / **Quiet round**). To use Chinese labels instead, replace `Team brief` with `队内简报` and the four status words with `需裁定 / 进展 / 更正 / 静默轮` (the heading stays `# To Be Read By User`).
- **Plain vocabulary** (`resources/claude_md_optional/plain_vocabulary.md`): plain, precise words; no coined metaphorical names; few abbreviations. It ends with a list of **words you have rejected**, kept inside `CLAUDE.md` so it is always loaded. Each time you reject a word, the lead (or a flat agent) adds it to that list; teammates send additions to their lead.

To add a section later, append it by hand from the project directory (skip it if its `<!-- ATWZ-OPTIONAL:… -->` marker is already in `CLAUDE.md`):
```bash
printf '\n' >> CLAUDE.md
cat _agent_team_work_zone/resources/claude_md_optional/user_message_format.md >> CLAUDE.md
printf '\n' >> CLAUDE.md
cat _agent_team_work_zone/resources/claude_md_optional/plain_vocabulary.md >> CLAUDE.md
```

---

## Typical Use Cases

### Use case 1: long-running training + proactive tracking

> **Platform note**: the dialogue below shows the **HPC / Linux** path (tmux + /loop teammate).
> For macOS / Windows see `resources/agents/tracker.md` "Option 2: macOS / Windows local — Desktop Scheduled Tasks".

```
User: Architect, I kicked off a long-running training run; I want to keep an eye on it
Architect: OK. This is a training task. I'll bring tracker into the team via
          /spawn-team; it will run /loop 12h in its own tmux pane, polling
          state every 12 hours and writing reports to architect_team/roundtable/.
          Next time you're back, /check-inbox will show you. Anomalies get
          high priority.

          Precondition: your claude was launched inside a tmux session
          (start_hpc_session.sh handles this), and settings.json has
          teammateMode: "tmux".
User: OK
[Architect spawns tracker as a teammate via /spawn-team, with the spawn prompt
 including "On startup execute /loop 12h <polling task>"]
[tracker teammate starts in a new tmux pane → issues /loop itself → enters polling]
Architect: Tracker teammate spawned (pane %12). Watchlist:
          squeue + ./runs/exp_42/status + tail of train.log.
          /loop will auto-expire in 7 days; I'll have it re-issue at that point.
          To stop, I can SendMessage it "/cron-list" + "/cron-delete <id>".
```

12 hours later:

```
User: /check-inbox
check-inbox: [TEAM] architect_team/roundtable/Tracker_REPORT_20260412_0300.md
             (from: architect_team/tracker, kind: TRACKER_REPORT, status: OPEN,
              priority: LOW, result: NORMAL)
             loss: 2.34 → 1.87, step 12000/100000, GPU util 98%, estimated 36h to completion
```

### Use case 2: complex architecture change + forming a team

```
User: Architect, I need to add flash-attn 3 support to the training code
Architect: This change involves:
          - Modifying the model forward to introduce flash_attn_func
          - Adjusting the training config for the new attention backend
          - Installing flash-attn 3 in the environment
          - A smoke test after the change
          I suggest a 4-person team:
          - model-architect (sonnet, plan-mode): modify forward
          - env-configurator (sonnet): install flash-attn 3
          - training-config-author (sonnet, plan-mode): modify training config
          - devil-advocate (opus): challenge the plan, find compatibility pitfalls

          Do you agree?
User: Agreed, but drop devil-advocate — keep it simple first
Architect: [calls /spawn-team, runs through 6 phases, emits spawn prompt]
[Claude Code agent-team mechanism spawns 3 teammates]
```

### Use case 3: abnormal investigation results

```
User: Architect, yesterday's eval results are abnormal — GSM8K is 5 points
     lower than baseline, and the code didn't error out
Architect: This is a textbook "ran successfully but results look abnormal"
          scenario; it requires the investigator to do hypothesis-driven
          deep investigation. I'll spawn an investigator teammate:
          - investigator (opus): read the eval log and checkpoint meta,
            enumerate ≥ 3 hypotheses, design verification plans (not execute)

          Do you agree?
User: Agreed
[spawn investigator]
[investigator produces an INVESTIGATION_REPORT to roundtable/]
```

---

## Known Limitations

These are runtime-environment issues the framework does **not** handle. They are not bugs, but they cause real losses; guard against them as each item suggests.

- **Teammates' messages are delivered only when a turn ends.** While a teammate's turn runs, messages from other teammates queue; neither a long blocking tool call (e.g. a shell `until … sleep` loop) nor a chain of short checks lets messages through; only ending the turn does. An agent that must watch a job and stay reachable should schedule a wake-up with `/loop`, then end its turn; ending the turn without a scheduled wake-up leaves the job unwatched. (Observed in split-pane mode on Claude Code 2.1.283; in-process mode untested. Delivery timing differs by message path: cross-session messages and subagent hand-backs can arrive mid-turn, between tool calls.) **Subagents (launched with the Agent tool) lack the scheduling tools `/loop` needs** (observed for an Explore subagent on Claude Code 2.1.283: `loop` is listed among its skills but cannot run; other subagent types untested); give long monitoring to a teammate.
- **One memory failure can end the whole team.** Two cases: (a) the whole team runs inside one memory-limited job or container (e.g. a SLURM allocation) — all sessions share that limit with the compute they launch, and an out-of-memory (OOM) kill may hit a session; (b) in in-process mode, teammates live in the lead's process, so a lead crash ends them all. Run memory-heavy compute in a separate job or container. Workstation files are unaffected; recover with `/reactivate-team`. (In split-pane mode each teammate is its own process, so on a plain desktop one OOM kills one process.)
- **Resources shared by the OS account are invisible to the framework.** GPU quotas, conda environments, disk quotas, and background processes are shared per OS account; the framework isolates only directories. Teams or projects under the same account can affect each other with no trace in any workstation. **Never kill processes by name** (`pkill -f`, `killall`, `kill $(pgrep …)`) — you may kill another agent's process. Record the PIDs of what you start and kill only those.
- **Cross-repository use of `meeting_room/` has no convention.** `meeting_room/` is designed for teams inside one work zone. A team from another repository writing files here works, but write access, naming, and archiving responsibility are undefined; agree on them in advance.
- **A separate git worktree per teammate is not supported.** Skills and hooks live in the project root's `.claude/`, and `/checkpoint` / `/reactivate-team` read workstations under the project root. Moving a teammate into a worktree splits the persistence layer in two. For git discipline when all agents share one checkout, see Work Rule 1, "Shared working tree and index".

---

## Troubleshooting

### Claude Code version too old

`bootstrap.sh` will error out. Upgrade to v2.1.32 or above.

### Skill modifications don't take effect

Claude Code loads skills at session start. After modifying the source:
1. `bash claude_code/zh/_agent_team_work_zone/resources/scripts/bootstrap.sh` to sync to `.claude/`
2. Restart the Claude Code session or refresh with the `/agents` command

### `/spawn-team` says I'm not a team lead

You are currently a flat workstation. Two options:
1. Let the agent invoke `/promote-to-team` to upgrade to a team lead (if the task truly requires it)
2. Stay flat and soldier on

### Tracker teammate not sending reports (HPC / Linux)

Check in this order:

1. **Verify the teammate is really tmux-backed**:
   ```bash
   jq '.members[] | {name, tmuxPaneId, backendType}' ~/.claude/teams/<team>/config.json
   ```
   `tmuxPaneId == "in-process"` → fallback mode; SSH disconnect kills everything. Restart the lead per "HPC deployment guide".

2. **Verify the spawn prompt contains the `/loop` directive**: tracker doesn't enter polling on its own — the spawn prompt must explicitly say *"On startup execute `/loop 12h <prompt>`"*. Open the tracker's tmux pane (`tmux attach -t claude_hpc`, switch to the tracker pane) to confirm.

3. **Check 7-day expiry**: tracker started more than 7 days ago? The `/loop` task has expired. Have the lead `SendMessage` tracker to re-issue `/loop`, or spawn a fresh tracker.

### Tracker scheduled task not firing (macOS / Windows)

Check in this order:

1. **The task exists and is Active**: in the Desktop sidebar `Routines`, find `tracker-<project>-...` and confirm Status is `Active`, not `Paused`. Also check the History tab — if there are runs but with status `skipped (slept)`, the computer was asleep at that time.

2. **First Run Now done with permissions pre-approved**: the very first run **must** be triggered manually with Run Now, ticking all "Always allow" dialogs. If you skip this, background cron firings will be blocked by the unanswered prompt and **you won't be notified**. Fix: hit Run Now once and approve everything.

3. **Computer wasn't asleep at the firing time**: enable `Settings → Desktop app → General → Keep computer awake`. Missed runs **don't stack** — at most one catch-up on next wake (the most recently missed time only, within 7-day lookback). Overnight tasks need never-sleep.

4. **Working folder is still trusted by Desktop**: if the project directory was moved / deleted / had permissions changed, Desktop will refuse to run there. Re-trust or fix the path.

5. **Schedule field is the expected cron**: GUI presets are only Manual / Hourly / Daily / Weekdays / Weekly. For `0 */12 * * *` and similar custom cron, you must change it via natural language after creation ("change the schedule of tracker-... to every 12 hours"); looking at the GUI preset alone may give a false sense it's set right.

6. **Prompt body intact**: if you've directly edited `~/.claude/scheduled-tasks/<task-name>/SKILL.md`, confirm the frontmatter is intact (`name` + `description`) and the body isn't broken. You can re-copy from `resources/desktop_task_skill_template.md`.

### Team spawn problems

Check whether `.claude/settings.json` contains `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`. Rerun bootstrap.

### Never edit `.claude/skills/` or `.claude/agents/` directly

Those are **runtime derived copies** and will be overwritten by the next bootstrap. The source is in `claude_code/zh/_agent_team_work_zone/resources/` (or `_agent_team_work_zone/resources/` in downstream projects) — **edit only the source**.

---

## Further Reading

- `agent-teams.md` — design doc for the new architecture (why & how)
