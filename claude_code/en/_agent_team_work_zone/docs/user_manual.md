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
| **Linux** | ✅ `install.sh` / `upgrade.sh` | tmux + `/loop` | teammate + `/loop` |
| **macOS** | ✅ `install.sh` / `upgrade.sh` (same scripts as Linux; verified zero blockers) | tmux / iTerm2 split-pane / in-process | Desktop Scheduled Tasks |
| **Windows** (native) | ⏳ Next major version | in-process (weak persistence) | Desktop Scheduled Tasks |
| **Windows + WSL** | ✅ Use the Linux path | tmux inside WSL | teammate + `/loop` |

**Why the same scripts work on macOS**: all `.sh` files use `#!/usr/bin/env bash` (auto-picks Homebrew bash if installed, otherwise falls back to `/bin/bash 3.2` which also works), and the user path uses no bash 4+ features. `stat -c %Y` has a BSD fallback `|| stat -f %m`; there are no `sed -i` / `date -d` / `grep -P` or other GNU-only constructs. Dependencies (`curl` / `tar` / `git` / `bash`) ship with macOS.

**Why native Windows is deferred**: the 3 runtime hooks (`session_start_check.sh` / `teammate_idle_checkpoint.sh` / `session_end_final_checkpoint.sh`) must be ported to PowerShell — a significant effort scheduled for the next major release (v2.x). **WSL users can use it today** — drop the template into a project inside WSL and follow the Linux path.

---

## Quick Start

### 1. Clone and deploy the template

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

> The English version will be generated later by the Translator.

> **⚠️ Claude Code version requirement (this template)**: This template is adapted for **Claude Code 2.1.178**'s agent-teams API (session-level auto team, `TeamCreate`/`TeamDelete` removed, the `Agent` tool's `team_name` ignored) and requires **CC ≥ 2.1.178**. If your Claude Code is ≤ 2.1.177, use **[release v0.1.0](https://github.com/SR-A-W/agent-team-work-zone/releases/tag/v0.1.0)** instead (targets the old API).

Bootstrap will:
- Check the Claude Code version (>= v2.1.178); if it doesn't meet the floor, exit directly and point to release v0.1.0
- Check for tmux (**strongly recommended, not required** — see the note below; without it, in-process mode is the fallback)
- Sync skills + agents to `.claude/`
- Create or merge `.claude/settings.json` to enable `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`

> **💡 Strongly recommended: run Claude Code inside tmux** (not just on HPC — local benefits too). When the terminal closes / SSH disconnects, tmux keeps the Claude Code process alive and the session uninterrupted — **you come back, `tmux attach`, and keep going, sparing yourself frequent `/reactivate-team`**. It is strongly recommended but **not required**: without tmux you can still run the full agent-team feature set in in-process mode. To get "persistent **and** no extra panes", launch claude inside tmux + set `teammateMode: "in-process"` (see the developer manual's "Persistence comes from tmux" section).

> **🍎 macOS users**: dependencies (`curl` / `tar` / `git` / `bash`) ship with macOS, **just run `bash install.sh`**. tmux via `brew install tmux`, or use **iTerm2 split-pane** (auto-detected by the reactivate-team skill), or skip tmux entirely and rely on in-process. bash 3.2 (the system bash) is fine — the user path uses no bash 4+ features.

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
