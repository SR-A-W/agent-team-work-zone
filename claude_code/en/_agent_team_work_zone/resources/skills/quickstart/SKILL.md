---
name: quickstart
description: >
  Recommended for first-time use. After the user types /quickstart (optionally followed by a
  one-sentence task description), it asks no questions and does, in order: check the environment,
  look at the project, choose the team, create the lead workstation, spawn the teammates and wait
  until they are ready, then send one closing message saying who is on the team, how to use it, and
  proposing a small task that can be done in about 20 minutes. Use only in the project root, when the
  work zone has no team or workstation yet; once familiar, use /onboard and /spawn-team to choose the
  roles and team yourself.
argument-hint: "[one-sentence task description, optional]"
disable-model-invocation: true
allowed-tools: Read Write Edit Glob Grep Bash Agent SendMessage ToolSearch TaskStop Skill
---

# `/quickstart` — Build a first team with one command

/quickstart is an easier, fuller /onboard: /onboard asks the user questions, so it is not called directly here; instead this skill reads /onboard's quick mode section, fills in every answer for the user, and then goes on to build the team.

You are the user's current Claude Code session, and you are about to become this project's team lead. Follow the steps below in one run: look at the project → choose the team → create the lead workstation → spawn the teammates → wait until they are ready → detect the display mode → detect the login method → send the closing message.

**What it does**:
- checks the environment, looks at the project, chooses the team;
- creates the lead workstation, spawns the teammates, waits until all of them are ready;
- finally sends one closing message: who is on the team, how to use it, and a proposed small task that can be done in about 20 minutes.

**What it does not do**:
- It does not start any task on its own. Teammates only send their ready receipt after starting, then wait.
- It does not overwrite an existing workstation or team; it only continues its own unfinished run.
- It does not change global settings (`~/.claude/settings.json`).
- It asks the user no questions. When a precondition is not met, it explains the situation and the fix, and stops.

## Overall rule: text the user sees

During the whole run, the user sees text in only two places:
1. when your system prompt **clearly shows** you are not in auto permission mode, one notice at the start (see Step F);
2. the final closing message (see Step F).

The in-between turns while waiting for receipts **output nothing at all**, not even one word.

When a check fails and you stop, you output a **stop message**: only the two opening lines (when Step F's condition applies) plus the stop explanation given in Step A; it **never** has "## Your team is ready" or any other section of the closing message, and no other sentences. No other text, no questions. **After the closing message**, any wake-up in this run that the user did not start (a late receipt, a teammate's idle notice, a timer that was not stopped) only gets the necessary record-keeping and no text output; messages from the user are answered as usual.

## Terms used in this skill

- **Work zone**: the `_agent_team_work_zone/` directory in the project root.
- **Lead workstation**: `_agent_team_work_zone/<slug>_team/`, your (the lead's) directory.
- **slug**: the lead workstation's name without `_team`; only lowercase letters and digits. Teammate names are always `<slug>-<role>`.
- **Registry**: `TEAMMATE_INFO.json` in the lead workstation.
- **Receipt**: the one line `Ready. Model: …, ID: …` a teammate sends you with SendMessage after starting.
- **Quick mode**: /onboard and /spawn-team each have a section "Quick mode (used only by /quickstart)": it skips the step-by-step confirmations with the user and uses the answers this skill passes in.
- **Unfinished marker**: the file `.quickstart_incomplete` in the lead workstation. It is the first file written after the lead workstation directory is created, and it is deleted just before the closing message is sent. If it exists, that /quickstart run did not finish.

## Order of a run

```
User types /quickstart [task description]
  A  Checks (item 1 first, then item 0, then items 2–6)
     · item 0 hits → read the previous answers, handle as "Resuming"
     · system prompt clearly shows not auto mode → give one notice, continue
     · any other precondition not met → explain the situation and the fix, stop
  B  Look at the project, infer its type
  C  Settle the task description
  D  Choose the team
  E1 Create the lead workstation with /onboard's quick mode → the unfinished marker is the first file written
  E2 Call /spawn-team in quick mode → teammate workstations, registry, team recipe, spawn the teammates
  E3 Collect receipts until the deadline (first spawn + 600 seconds)
  E4 Detect the display mode: in-process or split panes
  E5 Detect the login method: claude.ai account or not
  F  Stop any running timer → delete the unfinished marker → send the closing message
```

---

## Step A: Checks (do not ask the user)

**Order: do item 1 first** (only look at the system prompt, call no tool), **then item 0, then items 2–6.** Item 0 and the later items run commands; if they ran first, in a mode that is not auto the confirmation prompts would appear before the notice.

Below, "the current directory" means the directory Claude Code was started in (the result of `pwd` in Bash).

**Item 1: is the permission mode auto mode**
- **Only look at** whether your own system prompt says what the current permission mode is (for example, a statement that auto mode is active). **Do not read any settings file**: in recent Claude Code versions auto mode is the built-in starting mode of interactive terminal sessions, so most users whose settings file has no `defaultMode` are in fact in auto mode, and judging from the file gives false alarms.
- The system prompt **clearly shows** it is not auto mode → output the "notice at the start" from Step F right away, then continue. Record "not auto mode".
- The system prompt clearly shows auto mode → record "auto mode", say nothing.
- You cannot tell → record "cannot tell", say nothing.

**Item 0: is there an unfinished /quickstart run**
- Check whether `_agent_team_work_zone/*_team/.quickstart_incomplete` exists (`ls -d _agent_team_work_zone/*_team/.quickstart_incomplete 2>/dev/null`).
- One → handle it as in "Resuming" at the end of this step, no matter what else that directory is missing; skip item 5.
- Two or more → stop, list those directories, and ask the user to delete the one they do not want and then type /quickstart again.
- None → continue. (If the current directory has no `_agent_team_work_zone/`, this item finds nothing and item 2 handles it.)

**Item 2: was Claude Code started in the project root, with the work zone installed**
- Check: the current directory has `_agent_team_work_zone/README.md`.
- Why: when started in a subdirectory, the skills and the root `CLAUDE.md` are found from the parent directories, so /quickstart still runs; but `.claude/settings.json` is read only from the starting directory, so the team feature switch and the hooks in it do not take effect. So this case must be caught here.
- Not met → **stop**, search in this order and give the matching explanation:
  1. Walk up the parent directories; one that has `_agent_team_work_zone/README.md` → "You started Claude Code in a subdirectory of the project. The skills work from here, but the team feature and the automatic save reminders do not. Please exit, go to `<parent directory>`, start Claude Code there, and type /quickstart."
  2. Look two levels down (`find . -maxdepth 3 -path '*/_agent_team_work_zone/README.md'`); if found → "The work zone is installed in `<subdirectory>`. Please exit, go to `<subdirectory>`, start Claude Code there, and type /quickstart."
  3. Neither → "agent-team-work-zone is not installed in this directory. From the project directory, run `npx agent-team-work-zone init --lang en` (needs Node.js 18+), then start Claude Code in the same directory and type /quickstart."

**Item 3: is the team feature active in the current session**

Signal (1) decides; use (2) and (3) only when (1) cannot tell (for example, you cannot read your own tool description), never to override (1).

- (1) **Main signal: does your own Agent tool have a `name` parameter.** Call no tool; read your own tool description. With the team feature on, the Agent tool's parameters include `name` (usually also `team_name` and `mode`); with it off, they do not. `name` present → active; absent → not active.
- (2) This session's own team directory: in two steps: first run `echo "$CLAUDE_CODE_SESSION_ID" | cut -c1-8` in Bash to get the first 8 characters of the session ID, then run `test -f ~/.claude/teams/session-<first 8>/config.json && echo yes` (replace `<first 8>` with the previous result). Output yes → active. Look only at this session's own directory, **not** at "is there any team directory" (a clean /exit removes that directory; a session that did not exit cleanly leaves it behind).
- (3) Quick "off" signal: in Bash, `printenv CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` prints nothing (the variable is not set; exiting with 1 is not a command failure) → not active. A value of `1` does not show it is on (it may come from the user's shell profile).
- **Do not use** these to decide: the output of ListAgents; whether SendMessage or ListAgents is in the tool list (the same in both states); whether an Agent call returns immediately; whether `.claude/settings.json` contains the switch (when started in a subdirectory, the file has it but the session did not read it).
- Not active → **stop**. First check whether `.claude/settings.json` in the **current directory** (item 2 confirmed it is the project root) has `"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"`:
  - (i) It does not → add it: back up first (`cp -p .claude/settings.json .claude/settings.json.bak`; skip the backup if the file does not exist), then merge the same way the install script does:
    ```bash
    f=.claude/settings.json; [ -f "$f" ] || echo '{}' > "$f"
    tmp="$(mktemp "$(dirname "$f")/.settings.XXXXXX")" \
      && jq '.env = (.env // {}) | .env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1"' "$f" > "$tmp" \
      && jq empty "$tmp" && cat "$tmp" > "$f"; rm -f "$tmp"
    ```
    Without jq, do not change the file; only tell the user to add `{ "env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1" } }` to `.claude/settings.json`. Then say: "The team feature is not on in this session. I added the switch to `.claude/settings.json` (or: please add … to `.claude/settings.json`). Please exit Claude Code, start it again in this directory, and type /quickstart."
  - (ii) It does → "The team feature is not on in this session. Please exit Claude Code, start it again in the project root `<current directory>`, and type /quickstart."
  - In both cases add: "The first time you start in this directory, Claude Code asks whether you trust this folder. Choose "Yes, I trust this folder" (the highlighted default is "No, exit", which exits right away)."

**Item 4: are the work zone skills installed**
- Check: `.claude/skills/onboard/SKILL.md` and `.claude/skills/spawn-team/SKILL.md` both exist.
- Not met → **stop**: "The team skills are not fully installed. In the project root run `bash _agent_team_work_zone/resources/scripts/bootstrap.sh` to reinstall them, then exit Claude Code, start it again in this directory, and type /quickstart."

**Item 5: is there already a team or workstation** (skipped when item 0 hits)
- Ignore every directory whose name starts with `.` (an install brings `.upgrade/`, hooks create `.hook_logs/`).
- Count only two kinds:
  1. a team: `_agent_team_work_zone/*_team/TEAMMATE_INFO.json`;
  2. a flat workstation: a directory under `_agent_team_work_zone/` that does not start with `.`, has a `README.md`, and is not `meeting_room/`, `archive/`, `resources/` or `docs/`.
- A team exists → **stop**: "There is already a team `<directory name>` here. After a computer or Claude Code restart, type /reactivate-team to bring its members back; to add another role, use /onboard."
- Only a flat workstation → **stop**: "There is already a workstation `<directory name>` here. Please continue in its original conversation, or create a new one with /onboard."

**Item 6: is this a git repository, and is the repository root the project root**
- Check: `git rev-parse --show-toplevel` succeeds and its result equals the current directory.
- Not a git repository → continue; record "not a git repository"; the closing message mentions the benefit.
- The repository root is further out → continue; in Step B every git-based fact counts as a weak signal.

**When a check command itself fails** (for example, no jq, a git error): do not treat it as "not met"; record "could not check: <which item, why>", continue, and mention it in the closing message.

### Resuming (when item 0 hits)

- Read the previous project summary, project type, team and task description from the unfinished marker; **do not infer them again** (skip Steps B, C and D). Check items 1–4 as usual; skip item 5; use item 6 only for the closing message.
- Decide where to continue from what the directory **already has**; add only what is missing, never rewrite what exists:
  1. Lead workstation files missing (README, registry, …) → continue from E1 (/onboard's quick mode adds only the missing files).
  2. No teammates in the registry → start from E2.
  3. Teammates in the registry → **handle each one; do not respawn them all**:
     - its receipt was already received in this session → ready;
     - otherwise send one probe as in E3: "not addressable" (`No agent named … is currently addressable`) → respawn; sent successfully → treat it as "still there" and wait for its receipt;
     - registered, but its workstation or the spawn prompt in the team recipe is missing → complete those first, then spawn.
  4. On entering E3, **set a new deadline** (now + 600 seconds); do not reuse the old one.
- Why probe each one: when resuming in the same session (for example, the user pressed Esc during spawning and typed /quickstart again), the teammates spawned earlier are still alive. Respawning all of them would create copies with a suffix and then move the live originals aside as broken. When resuming after a restart, all teammates are offline, every probe returns "not addressable", and the result is the same as respawning them all.

---

## Step B: Look at the project, infer its type

**Input**:
- The project's file list. Exclude `.git/`, `_agent_team_work_zone/`, `.claude/`, `node_modules/`, `.venv/`, `venv/`, `__pycache__/`, `dist/`, `build/`, `.ipynb_checkpoints/`, and every directory whose name starts with `.`. With more than 5000 files, look only at the first two levels.
- The whole top-level README (if any; only the first 200 lines if it is longer).
- The name and description fields of the top-level code manifest (if present): for example `name` and `description` in `package.json`, `pyproject.toml` or `Cargo.toml`.
- The structure of the top-level directory, two levels down.
- When git is available (item 6 found a git repository): the number of commits (`git log --format=%H | wc -l`), the number of authors and the top authors (`git log --format=%an | sort | uniq -c | sort -rn | head -3`), the date of the last commit (`git log -1 --format=%cs`), and the `origin` address (`git remote -v`; if the address contains a user name or token, use only the host and repository path). Use only the read-only commands git log, git remote, git config and git rev-parse; read no credentials.
- The task description.

**Project type**: from top to bottom; the first match wins. "Strong" means a clear signal; "weak" means not enough signal, and the team is chosen as in Step D's "weak signal".

| Order | Condition | Result | Strong/weak |
|---|---|---|---|
| 1 | After exclusion ≤ 3 files, all of the README, LICENSE, `.gitignore`, `CLAUDE.md` kind | Empty project | Strong |
| 2 | A code manifest at the top level: `package.json`, `pyproject.toml`, `setup.py`, `setup.cfg`, `Cargo.toml`, `go.mod`, `CMakeLists.txt`, `pom.xml`, `build.gradle` (`requirements.txt` and `Makefile` do not count on their own) | Codebase | Strong |
| 3 | A `.tex` file containing `\documentclass` at the top level or second level, no match on row 2, and < 20 code files | Paper or writing | Strong |
| 4 | ≥ 1 code file (`.py .js .ts .go .rs .java .c .cpp .h .sh .rb .jl .m .r` and similar), and the number of `.ipynb` plus data files (`.csv .tsv .parquet .jsonl .h5 .npy .pkl`) is larger than the number of code files | Data or experiments | Weak |
| 5 | ≥ 1 code file (including a new project with only `README.md` + `main.py`) | Codebase | Weak |
| 6 | `.ipynb` or data files, no other code | Data or experiments | Weak |
| 7 | Only files like `.md .txt .rst .pdf .docx` remain | Documents only | Weak |

**A codebase is one of two kinds: the user's own repository to keep developing, or someone else's repository to reproduce or use.** Decide this only when the project type is codebase; from top to bottom, the first match wins:

| Order | Condition | Result | Strong/weak |
|---|---|---|---|
| 1 | The task description contains, as **whole words**, words like "reproduce, replicate, run this repo, try out" (and their Chinese equivalents such as 复现、试用); words like "run the tests", "runtime", "retry" do not count | Someone else's | Strong |
| 2 | The task description contains, as whole words, "continue developing, add a feature, fix a bug, refactor, my project" (or their Chinese equivalents) | Own | Strong |
| 3 | `git config user.email` **is set** on this machine, and `git log --author="<<email>>" --fixed-strings --format=%H` prints more than 0 lines (the number of lines is the commit count written in the basis; angle brackets around the email, so only the full email in the author field matches). Skip this row when the email is not set: an empty `--author=` matches every commit | Own | Strong |
| 4 | gh is installed and logged in; the remote host is `github.com`; the remote owner equals `gh api user --jq .login` exactly (case-insensitive); and it is not a fork (`gh repo view --json isFork`) | Own | Strong |
| 5 | All preconditions of row 4 hold, but the owner differs; row 3 found zero commits; the email is set | Someone else's | Weak |
| 6 | Which remote: take `origin`; with no `origin` but exactly one remote, take that one; with several remotes and no `origin`, or a host other than `github.com` → rows 4 and 5 do not apply | — | — |
| 7 | None of the above gives a result | Cannot tell whose: choose the team as for "own", and use the "cannot tell whose" intent sentence in the closing message | Weak |

When item 6 found "the repository root is further out", rows 3, 4 and 5 always count as weak.

**Output**:
- **Project summary**: one to three sentences on what the project is, what language or tools it is written with, what its main parts are, and who wrote it or how big it is (for example "A text-generation experiment repository written with PyTorch, mostly training scripts and a few model configs; 27 commits by two authors, the last one in August this year"). Write only facts read from the files; if something cannot be read, write less; never invent. No summary for an empty project.
- the project type and its strength;
- for a codebase: own or someone else's, and its strength;
- the one or two facts behind each result (for example "`pyproject.toml` at the top level", "the local email has 3 commits in this repository").

All of these go into the unfinished marker and the team recipe (resuming uses them directly).

**On failure**: a git command fails → skip that fact; cannot decide → treat as weak.

**Overall signal**: the project type is "weak", or a codebase's "own or someone else's" is "weak" → the overall signal is "weak"; otherwise it is "clear".

## Step C: Task description

- **Given** (`$ARGUMENTS` is not empty): use it unchanged as the team's goal; it sets the team size (Step D) and the proposed small task (Step F).
- **Not given**: do not invent a goal; choose the team as in Step D's "no task description".
- **Task and project do not fit** (for example "reproduce" in an empty directory): build the team as the user asked, and say plainly in the closing message what is missing.

## Step D: Choose the team

**Common rules**:
- At least two members, at most 5.
- Every teammate's model is `sonnet`.
- Plan-mode approval is always off (`plan_mode_gating: false`).
- Scope: `planner` and `reviewer` only read project files and only write this team's `roundtable/`; the hands-on members may change project files. Nobody touches other workstations under `_agent_team_work_zone/`, `.claude/` or `.git/`.
- Teammate names are `<slug>-<role>`, with the role word chosen from: `coder`, `planner`, `setup`, `writer`, `reviewer`, `runner`, `reporter`.
- Two members with the same role are `coder` and `coderb`. Do not use a hyphen plus a number, so the name cannot be confused with the suffix the system adds automatically.

**When the signal is clear**, by project type:

| Project type | Hands-on member | Planning member | Add in this order when the task needs it |
|---|---|---|---|
| Empty project | `coder` (inline, coding) | `planner` (inline) | `setup` (archetype `resources/role_archetypes/infra/env-configurator.md`), `reviewer` (general subagent `reviewer`) |
| Codebase · own | `coder` (inline; state the project's language and test command) | `planner` | `reviewer`, `coderb`, `setup` |
| Codebase · someone else's | `setup` (archetype `resources/role_archetypes/infra/env-configurator.md`) | `planner` (reads the README, lists the reproduction steps and the numbers to match) | `runner` (archetype `resources/role_archetypes/coding/bash-scripter.md`), `reporter` (archetype `resources/role_archetypes/analysis/result-reporter.md`) |
| Paper or writing | `writer` (inline) | `planner` (organizes the structure, checks consistency) | `reviewer` (inline, finds problems by submission standards), `reporter` (figures and tables) |

**When the signal is weak**: `planner` + one hands-on member (the project has a code manifest or at least 1 code file → `coder`, otherwise → `writer`); for a big task add `reviewer`, then `setup`.

**Team size**:
1. No task description → two members: one hands-on member + `planner`. The hands-on member: with a clear signal, by the type table (empty projects and codebases get `coder`, papers or writing get `writer`); with a weak signal, `coder` if there is code, otherwise `writer`.
2. A task description → start from two; for each further clearly named kind of work in the task, add one member from the "add in this order" column.
3. A big goal (the task description contains, as whole words, words like "finish, complete, entire, all, full, end-to-end, from scratch", or lists three or more things) → at least 4 members.
4. Never more than 5.

**For each teammate, state**: name, one-sentence role, role source (inline / archetype path / general subagent name), model `sonnet`, scope, forbidden areas, deliverable ("none yet; wait for the lead to assign work").

**Archetype file missing**: use an inline role instead and note it in the team recipe.

**One-sentence inline roles** (written into the "Role definition" of the spawn prompt):
- `coder`: writes code and runs tests in this project; state the project's language and test command (if they can be seen).
- `planner`: reads the project, works out its structure, produces plans and the project map; only reads project files, only writes this team's `roundtable/`.
- `writer`: writes and revises the paper or documents.
- `reviewer`: read-only; finds problems as asked and writes review notes.
- `runner`, `reporter`, `setup`: use the archetype file; without one, say in one sentence which kind of work it is responsible for.

---

## Step E1: Lead workstation (with /onboard's quick mode)

**Slug rules**:
1. Split the project directory name into words: any non-alphanumeric character (`-`, `_`, `.`, space, …) separates words; so does a lowercase letter directly followed by an uppercase letter.
2. Lowercase each word, keep only `a-z` and `0-9`, and join them in their original order.
3. If the result starts with a digit, prefix `p` (`2024exp` → `p2024exp`). Add the prefix first, then check the length.
4. Total length ≤ 16: use it. Over 16: drop whole words from the end until it is ≤ 16; if the first word (with prefix) alone is over 16, cut it to 16 characters.
5. Empty result (for example, a directory name with only non-Latin characters) → use `proj`.

Examples: `codebase-others` → `codebaseothers`; `My-Project_v2` → `myprojectv2`; `deep-learning-experiments-2024` → `deeplearning`.

**Names**:
- Directory: `_agent_team_work_zone/<slug>_team/` (use the slug directly; do not derive it from `<Slug> Lead` with /onboard Step 2's "lowercase with underscores" rule).
- `lead_name` and the English name in the member table: `<Slug> Lead` (slug with a capital first letter); role name in the member table: "Project Lead".
- One-sentence responsibility: with a task description, "Leads the team to: <task description>"; without one, "Leads the team working on this project".

**Do it**: read `.claude/skills/onboard/SKILL.md`, find the section "## Quick mode (used only by /quickstart)", and follow it, handing it the names above and the unfinished marker content below. /onboard may only be invoked by the user directly, so do not call it with the skill tool; read the file and follow it.

**Unfinished marker content** (plain text; the **first** file written after the directory is created):

```
quickstart started: <ISO 8601 UTC time>
slug: <slug>
task: <task description, or none>
summary: <project summary, or none>
project type: <type> (<strong/weak>); basis: <one or two facts>
ownership: <own/someone else's/not applicable> (<strong/weak>); basis: <facts>
signal: <clear/weak>
lineup:
- <slug>-<role> | source: <inline / archetype path / subagent name> | model: sonnet | <one-sentence role>
- …
checks: <auto mode/not auto mode/cannot tell>; <git repository/not a git repository>; <items that could not be checked, or none>
```

It is deleted only just before Step F's closing message.

**On failure**: /onboard's quick mode reports "a directory with the same name exists and has no unfinished marker" → stop; the closing message says the directory is already taken and was not overwritten, and asks the user to rename the project directory or delete that directory.

## Step E2: Teammate workstations and spawning (call /spawn-team in quick mode)

Call `spawn-team` with the skill tool. The arguments start with `--quick`, followed by the answers in this fixed format:

```
--quick
team: <slug>_team
project_root: <absolute path of the current directory>
goal: <task description, or none>
basis: <project summary; project type, strength, facts, written as in the unfinished marker>
lineup:
- name: <slug>-<role> | source: <inline | archetype:<archetype path> | subagent:<subagent name>> | model: sonnet | role: <one-sentence role> | scope: <scope> | forbidden: <forbidden areas>
- …
```

/spawn-team does, in its quick mode: the spawn prompts, the teammate workstation skeletons, the registry, the team recipe (with a section "/quickstart inference basis"), and spawns all teammates in parallel. The "Current task" of every spawn prompt says: "None yet. After sending your ready receipt, wait for the lead to assign work; do not start any work on your own."

**Record the first spawn time**: just before the first Agent call, run `date -u +%s` and record it as T0. Deadline = T0 + 600 seconds (for resuming, see above).

After /spawn-team has spawned the teammates, come back to E3 of this skill; do not run /spawn-team's own waiting or its confirmation checklist.

**On failure**:
- Writing a workstation or the registry fails → do not spawn; the closing message reports the step that failed.
- The Agent tool reports an error (for example, tmux-related) → use /spawn-team's "Terminal / tmux" section to work out the cause and put it in the closing message.
- In both cases keep the unfinished marker; after the user fixes it, typing /quickstart again continues the run.

## Step E3: Wait for receipts and respawn safely

**Why respawning automatically is safe here**: /reactivate-team does not respawn automatically, because the original might still be alive and spawning another with the same name would give two copies. Here there are two protections: respawn only when the original's probe returns "not addressable"; and if two copies appear anyway, shut down the extra one right away.

**You are woken by**: a teammate's SendMessage (a receipt or any other message), a background `sleep` ending, or a teammate's idle notice. The timer only exists to check regularly when nobody sends a receipt.

**Deadline**: one fixed value = T0 + 600 seconds; respawning does not extend it.

**Timer**: run `sleep <seconds>` with Bash in the background (`run_in_background`), seconds = `min(180, deadline − now)`; record this background task's ID. When the time left is ≤ 0, start no new timer.

**In-between turns**: each turn only does the handling and **outputs nothing at all**, not even one word. If the user sends a message while you wait → answer the user first; receipt handling continues as usual.

**For each receipt**:
1. **Ignore a sender that is not in the registry** (a copy with a suffix starts up using the original's paths and then sends its receipt under the suffixed name).
2. Check the model: write the ID into that teammate's `model_resolved` (with /spawn-team 6c's validated jq write, adding `| .model_resolved = $mid`). The ID does not contain `sonnet` → note it for the closing message. `Model: not stated` → leave the field unset, note "did not report its model".
3. The receipt has `Unread: <file>` → use SendMessage to have it read the file to the end and confirm. Do not tell the user about this.
4. The receipt mentions a rules backup → note the backup location for the closing message.
5. All registered teammates have reported → go to Step F.

**Each time the timer ends (one check round)**: send a probe to **every** registered teammate that has not sent a receipt, whether or not its `.started` exists:
1. Send with SendMessage: "This is a startup check. If you have started, just send your ready receipt as usual."
   - "Not addressable" (`No agent named … is currently addressable`) → it is gone → **respawn** it with the same name and the same spawn prompt (it is in the team recipe).
   - Sent successfully → this only shows the message reached its inbox, **not that it is alive** → keep waiting.
2. Known limitation: a teammate that is stuck or has crashed but whose name still exists makes every probe "succeed", so it is not respawned and only counts as failed at the deadline.
3. Respawn each teammate at most 2 times, all within the same deadline.
4. Deadline not yet reached → start the next timer.

**A respawn comes back with a suffixed name** (for example, you asked for `myproj-coder` and the returned name is `myproj-coder-2`):
1. Immediately send the suffixed copy a shutdown request: SendMessage with message `{"type": "shutdown_request", "reason": "You were spawned by mistake. Do not write any files; approve the shutdown."}`. The request is delivered only when the copy's turn ends; by then it has most likely finished the startup steps using the original's paths and sent a receipt under the suffixed name. Those writes have the same content and do no harm; its receipt is ignored by the rule above.
2. Choose a new role name: add a letter to the role word, `coder` → `coderb` → `coderc`, skipping names already taken.
3. **First** create the new name's workstation skeleton (/spawn-team 6b) and add the new name's registry entry (6c's validated write), **then** spawn with the new name. Every path and name in the spawn prompt uses the new name.
4. Move the original name's registry entry to `offboarded_teammates`, noting "failed to start; replaced by <new name>"; leave the original name's workstation directory as it is.
5. Add one sentence at the end of the team recipe.
6. This spawn under the new name counts as one respawn for that role.
7. If the copy has not approved the shutdown by the deadline → note it; the closing message lists it.

**Teammates without a receipt at the deadline**:
- In the registry set their `status` to `failed_to_reactivate` (with 6c's validated write).
- Look at its `.started` (`<lead workstation>/teammates/<name>/.started`) and compare its modification time with T0 (`stat -c %Y`): exists and later than T0 → "it started, then stopped"; does not exist → "it could not start; it may be waiting on a confirmation screen".
- In split-pane display, use the best-effort method in /spawn-team 6e to read its pane; if it is waiting on a confirmation screen, the closing message asks the user to go and confirm it.

**Everyone has reported, or the deadline has passed** → do Step E4 and Step E5 first, then "Before finishing" after Step E5.

## Step E4: Detect the display mode: in-process or split panes

**Why**: with in-process display (the default in recent Claude Code), all teammates run inside your window and have no sessions of their own, so only you can join Remote Control; with split panes (tmux or iTerm2), each teammate has its own pane. The closing message's "how to talk to a member directly" sentence and its Remote Control section are both written from this result.

**When**: after all teammates are ready or the deadline has passed, before the closing message (by then the teammates exist, so method 1 has something to read).

**Decide in this order; once one step gives a result, skip the rest**:
1. **Read the teammates' display mode from this session's team file** (read it after the first spawn): get the session ID with Bash `echo "$CLAUDE_CODE_SESSION_ID"`, then use the Read tool on `~/.claude/teams/session-<first 8 characters of the session ID>/config.json`. **Look only at the entries of teammates other than the lead** — the lead's own entry is `"tmuxPaneId": "leader"`, `"backendType": "in-process"` even with split panes, so it cannot be used to decide.
   - Every teammate's `backendType` is `"in-process"` (and `tmuxPaneId` is `"in-process"` too) → in-process;
   - any teammate's `backendType` is `"tmux"` (`tmuxPaneId` like `"%6"`) or another value → split panes.
   - This is an internal Claude Code file, not a public interface; if it cannot be read (for example, in `-p` mode there is no such file) or has no teammate entries → go to step 2. Look only at this session's own directory.
2. **Read `teammateMode` from the user-level settings**: use the Read tool on `~/.claude/settings.json`.
   - Missing or `in-process` → in-process;
   - `tmux` or `iterm2` → split panes;
   - `auto` → in Bash run `printenv TMUX` and `printenv TERM_PROGRAM` (no output = not set; exiting with 1 is not a command failure): `TMUX` prints something, or `TERM_PROGRAM` is `iTerm.app` and `command -v it2` finds it → split panes; otherwise → in-process. If these commands could not run (refused or errored) → treat it as "unknown".
3. **Still undecided** → write it as in-process, record "could not confirm", and say in the closing message that this is an inference.

**On failure**: an error in any step does not affect the team; it only affects these two parts of the closing message.

## Step E5: Detect the login method: claude.ai account or not

**Why**: Remote Control works only when Claude Code is logged in with a claude.ai account. Detecting this beforehand lets the closing message say directly whether it can be turned on, so the user does not have to check their account type.

**How**: in Bash, run

```bash
claude auth status 2>/dev/null | jq -r '[.authMethod // "", .subscriptionType // ""] | @tsv'
printenv ANTHROPIC_BASE_URL
```

(When not logged in, the command exits with 1 but still prints JSON; decide by `authMethod` as usual.) There are three outcomes; record which one for the closing message:
- (a) `authMethod` is `claude.ai` **and** `subscriptionType` is not empty (for example `max`) → **claude.ai account login**; record `subscriptionType` exactly as given;
- (b) **Not a claude.ai account login**; Remote Control cannot be used. Two cases; record which one:
  - (b1) `authMethod` is any value other than `claude.ai`: `api_key`, `api_key_helper`, `third_party`, `oauth_token`, `none` (not logged in), and so on;
  - (b2) `ANTHROPIC_BASE_URL` is not empty and points to a host other than `api.anthropic.com`: even with `authMethod` `claude.ai`, Remote Control cannot be used.
- (c) **Unknown**: the command fails, prints nothing, or cannot be parsed (for example, no jq); or the second command could not run (it was refused or reported an error; printing nothing and exiting with 1 only means the variable is not set, which is not a failure); or `authMethod` is `claude.ai` but `subscriptionType` is empty (older versions also report an API-billed Console login as `claude.ai`, so it cannot be told apart).

Check (b2) first, then (a), (b1), (c). The command only reports the login method; it does not read credential files or print tokens. Its output does include the email address and organization name, so use only the two fields extracted above and **never** put the raw output into any message. (c) is not an "item that could not be checked": the closing message has its own wording for it, so do not put it in "One item could not be checked".

**On failure**: treat any error as (c); the team is not affected.

**Before finishing** (after Steps E4 and E5):
1. Stop any background timer still running with TaskStop (using the recorded ID);
2. Delete the unfinished marker (`rm -f <lead workstation>/.quickstart_incomplete`);
3. Send the closing message (Step F).

---

## Step F: The notice at the start and the closing message

**Notice at the start** (only when the system prompt clearly shows it is not auto mode; output right after item 1, word for word):

```
You are not in auto permission mode. While I build the team and the teammates start, a confirmation will pop up at each step; please choose allow. Once the team is ready, the closing message explains how to stop these confirmations.
```

**Start of the closing message and the stop message**: first look at the project root's `CLAUDE.md`. If it contains the marker `<!-- ATWZ-OPTIONAL:user_message_format -->` **or** the heading `## Messages to the user (format)` or `## 给用户的消息（格式）` (any one is enough) → start with these two lines:

```
# To Be Read By User
**Status: Decision needed**
```

Otherwise leave these two lines out: the closing message starts directly with "## Your team is ready"; the stop message is just the stop explanation.

**Closing message template** (angle brackets are to be filled in; square brackets are sentences that appear only in that situation; when not, drop the whole sentence; never output the square brackets themselves). Use only the sentences in the template; add no others. The one exception is the project summary at the start: write those one to three sentences yourself from Step B's output. When resuming, use the `summary:` line of the unfinished marker for <project summary> exactly as it is; do not rewrite it. The closing message is not a team brief: do not put a "Team brief:" line or anything like it in front of it, even if the project's CLAUDE.md has such a format rule. For the "Recommended: turn on Remote Control" section, choose one wording according to Step E5's result, and copy the chosen one **in full, without shortening it** (none of the three steps in the in-process version may be left out):

```
## Your team is ready

[Not an empty project: I looked through the project (read the README, the directory structure and the commit history; list in the parentheses only what was actually read): <project summary>.]
[Empty project: I looked through the project: apart from CLAUDE.md and the team framework's files, this directory has nothing else yet.]
[A task description was given: I built the team for your request "<task description>".]
[No task description, codebase · someone else's: It looks like you want to reproduce or use this project (because: <one fact>), so I built a first team.]
[No task description, codebase · own (ownership rows 1–4): It looks like this is your own project and you want to keep developing it (because: <one fact>), so I built a first team.]
[No task description, codebase · cannot tell whose (ownership row 7): This is a codebase; I cannot tell whether it is your own project or someone else's (because: <one fact>), so I built a first team for continuing development.]
[No task description, paper or writing: It looks like you are writing a paper or document (because: <one fact>), so I built a first team.]
[No task description, data or experiments: It looks like this is a data analysis or experiment project (because: <one fact>), so I built a first team.]
[No task description, documents only: It looks like this is a documentation project (because: <one fact>), so I built a first team.]
[No task description, empty project: This is an empty project, so I built the smallest team.]
[Clear signal: If that is wrong, just tell me.]
[Weak signal: I am not very sure about this: if it is wrong, just tell me. The planning member will first read the whole project, give you a project map, and then suggest whether to add people.]

| Member | Responsible for |
|---|---|
| <slug>-<role> | <one sentence> |

Normally you only need to talk to me: tell me what you want done, I split it up, give it to the right members, and bring the results back to you.
[In-process display (including could not confirm): To talk to a member directly: in the agent panel below the prompt, use the up and down arrow keys to select it, press Enter, and type.]
[Split-pane display: To talk to a member directly, click into its pane and type.]

The members use Claude's sonnet model. sonnet and opus are two tiers of Claude models: sonnet is faster and cheaper, good for seeing results first; opus is more capable and costs more.
[A receipt did not report a model ID: replace the first sentence above with: The members were started with the sonnet model; <name> did not report the model it actually uses.]
[A receipt's model ID does not contain sonnet: <name> reported the model <ID>, which differs from the expected sonnet.]
To switch a member to opus, just tell me "switch <member name> to opus". I will have it save its progress first, then restart it on opus; its work record is not lost.

[Partial failure: <member name> could not start (<the wording chosen from .started>). The other members are not affected. Once it is fixed, type /reactivate-team <member name> to bring it in.]
[Waiting on a confirmation screen: <member name> may be waiting on a confirmation screen; please go there and choose allow.]
[An extra copy that did not shut down: There is also one extra session <copy name>; it will not do anything. You can ignore it; it disappears after a restart.]
[A rules backup: <member name> tidied up its own instructions file when it started; the old content is backed up in <backup file>.]

## Adding or removing members later

To add or remove people, just tell me, for example "add one more person just for writing tests". To find out whether the team has enough people and who is busy or idle, ask me to "review the team"; I will check and give you suggestions.

## Suggested first small task

<the small task: one sentence saying what is done, what is delivered, and roughly how long it takes>.
[Big goal: What you asked for, "<task description>", is fairly big. I suggest doing one small part first: <the small part>. Once you have seen the result, decide how to split the rest.]

## Things you will need later

- **After a restart**: when the computer restarts or Claude Code exits, all members go offline, but their work records are kept in files. Start Claude Code again in this directory and type /reactivate-team to bring the whole team back.
- **How to give the next piece of work**: just tell me in one sentence what to do; no command needed.
[Not auto mode: - **Permission confirmations**: you are not in auto permission mode, so members will often ask for confirmation. Members inherit their permission mode from me when they start and can only be changed one by one afterwards. So switch like this: press Shift+Tab to switch to auto mode, then exit Claude Code, start it again in this directory, and type /reactivate-team.]
[Cannot tell whether it is auto mode: - **If members often ask you to confirm permissions**: press Shift+Tab to switch to auto mode, then exit Claude Code, start it again in this directory, and type /reactivate-team.]
[Not a git repository: - **Consider using git**: this directory is not a git repository yet. With git, every save of the team's work records keeps a version, so you can get it back if something breaks. Run `git init` in this directory.]
[An item could not be checked: - One item could not be checked: <which item, why>.]

[claude.ai account login, or login method unknown: this section's heading is: ## Recommended: turn on Remote Control to talk to the team from the web or your phone]
[Not a claude.ai account login: this section's heading is: ## Remote Control]

[Not a claude.ai account login (b1): this section has only the following sentence; write none of the other sentences in it: Remote Control lets you keep talking to me from the web or your phone, but it works only with a claude.ai account login; you are not logged in with a claude.ai account, so it is not available.]
[ANTHROPIC_BASE_URL is set (b2): this section has only the following sentence; write none of the other sentences in it: Remote Control lets you keep talking to me from the web or your phone, but you have set ANTHROPIC_BASE_URL to a service other than Anthropic's; with that setting Remote Control is not available, and you would need to unset the variable to use it.]
[claude.ai account login: Remote Control lets you keep talking to me from the web or your phone. You are logged in with a claude.ai account (plan <subscriptionType exactly as given>), so you can turn it on.][Plan is team or enterprise: on these two an admin must turn the feature on first.]
[Login method unknown: Remote Control lets you keep talking to me from the web or your phone. It requires Claude Code to be logged in with a claude.ai Pro, Max, Team or Enterprise account (an API key login does not work; on Team and Enterprise an admin must turn the feature on first).]
I cannot turn it on myself; please type these two lines, one after the other, in this conversation:
  /rename <slug>-lead
  /remote-control <slug>-lead
The first time, a confirmation box appears; choose "Enable Remote Control". After that, the session named <slug>-lead appears on claude.ai.
[Could not confirm the display mode: I could not confirm how the members are displayed, so the following assumes the default in-process display.]
[In-process display (including could not confirm): Right now all members run inside my window. According to the documentation, in in-process mode the members have no sessions of their own and only my session can join Remote Control; to talk to a member, tell me and I will pass it on.
If you want each member to have its own window, you need to switch to split-pane display by hand. You have to do this yourself:
  1. Get tmux (Linux: `sudo apt install tmux`; macOS: `brew install tmux`), or use iTerm2 on macOS.
  2. Change the display mode to split panes: run `npx agent-team-work-zone config` and choose auto in the display mode menu (installed from source: run `bash _agent_team_work_zone/resources/scripts/bootstrap.sh --reconfigure`). auto means: split panes when started inside tmux or iTerm2, otherwise still one window. This changes your global settings and affects every project on this machine.
  3. Exit Claude Code; if you use tmux, first run `tmux new -s <slug>` to enter tmux; then go to this project directory, start Claude Code, and type /reactivate-team to bring the team back.
After switching, each member has its own pane; type `/remote-control <member name>` in a member's pane (for example `/remote-control <slug>-coder`) to have it join Remote Control too.]
[Split-pane display: Each member has its own pane. To talk to a member directly from your phone, click into its pane and type `/remote-control <member name>` (for example `/remote-control <slug>-coder`); it joins Remote Control and appears under that name on claude.ai. If you would rather not turn them on one by one, tell me and I will pass your messages on.]

## Your decision

Should I start "<small task>" now? Just reply run or don't run.[ claude.ai account login, or login method unknown: I also recommend turning on Remote Control with the steps above.]
```

**Choosing the first small task** (whatever the signal):

| Situation | Small task |
|---|---|
| Empty project, no task description | The planning member writes one page of "possible directions and first steps" for you to choose from |
| Empty project, with a task description | Set up the project skeleton: directory structure + a draft README |
| Every other situation | The project map: "The planning member writes a one-page project map: what the project is, how to run it, what each main part does, who wrote it, and which members it suggests adding. About 20 minutes, delivered as one file to me, and I pass it on to you." |

When reproducing someone else's repository, the "how to run it" part of the project map only lists what is needed and checks which parts are already installed; it **does not install anything** (setting up an environment often takes more than 20 minutes).

**When every teammate fails** (no receipt at all by the deadline): the closing message keeps only the first two lines (under the condition above) and one failure report: which members could not start, the most likely cause based on `.started` and how to fix it; say that the members' directories and work records are all kept, and that after fixing it, typing /reactivate-team brings them in. Leave out every other section.

**Words that must not appear in the closing message**: roundtable, workstation, registry, slug, receipt, inline, archetype, and any internal numbering. Member names and command names may appear.

**After the user replies**: "run" → give the small task to the right member (project map, possible directions → `planner`; project skeleton → the hands-on member) and report as usual when it is done. "Don't run" → wait for the user to assign work. The user names some other work directly → assign that.

---

## Situations and handling

| Situation | How to tell | Handling |
|---|---|---|
| The previous /quickstart did not finish (same session or not) | Item 0: an unfinished marker exists | Resume: add only what is missing; probe each registered teammate and respawn only the unaddressable ones; set a new deadline |
| It stopped right after creating the directory and the marker | Marker present, no README and no registry | Resume, add the files from E1 |
| Started in a project subdirectory | No work zone in the current directory, one in a parent | Stop; explain how to restart in the root |
| Work zone installed in a subdirectory | Found two levels down | Stop; say where it is |
| Not installed at all | Found neither up nor down | Stop; give the install command |
| Skills not fully installed | onboard or spawn-team missing | Stop; give the reinstall command |
| Team feature not active | Item 3 | Stop: add the switch if the file lacks it; ask the user to restart in the root and choose Yes in the trust prompt |
| Fresh install (`.upgrade/`, `.hook_logs/` in the work zone) | Directories starting with `.` | Ignore; continue normally |
| A team or flat workstation already exists | Item 5 | Stop; point to /reactivate-team or /onboard |
| Not a git repository | Item 6 | Continue; the closing message mentions the benefit |
| Big goal | Step D team size rule 3 | At least 4 members; the small task becomes one small part first |
| A teammate sends no receipt | Step E3 | Probe, respawn, until the deadline |
| A respawn comes back with a suffix | Returned name ≠ requested name | Shut the copy down, ignore its receipt, respawn under a new role name |
| Every teammate fails | No receipt at all by the deadline | The closing message becomes a failure report; workstations are kept |
| In-process display, or the display mode could not be confirmed | Step E4 | The Remote Control section says only the lead can join and gives the three steps to switch to split panes; when not confirmed, say it is an inference |
| Split-pane display | Step E4 | The Remote Control section gives the lead's steps and one sentence on how each member joins on its own |
| Woken again after the closing message | Late receipt, idle notice, timer | Record only; no text |
| The user writes while you wait | A user message arrives while waiting for receipts | Answer the user first; receipt handling continues |
