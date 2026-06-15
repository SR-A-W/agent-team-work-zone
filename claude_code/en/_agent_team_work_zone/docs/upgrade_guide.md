# Upgrade Guide

This guide explains how to upgrade your project's installed `_agent_team_work_zone/` to a new version of the `agent-work-zone` repo.

> **Quick version**: in your project root, run `bash _agent_team_work_zone/upgrade.sh` — one command does it all.
> See below for details.

## Check your current version

```bash
cat _agent_team_work_zone/VERSION
```

Version numbers follow SemVer `vMAJOR.MINOR.PATCH`:

- **MAJOR (X)**: breaking architectural changes
- **MINOR (Y)**: new features (new skills / agents / hooks), backward compatible
- **PATCH (Z)**: documentation revisions, bug fixes, fully backward compatible

Before upgrading, review the `CHANGELOG.md` to understand the scope of changes. For detailed versioning conventions, see `VERSIONING.md`.

## Framework-file ownership inventory

During upgrades, the following files are **framework-owned** (overwritten by the upgrade script):

```
_agent_team_work_zone/
├── upgrade.sh                 ← framework-owned (one-button entry, v0.5.0+)
├── VERSION                    ← framework-owned
├── CHANGELOG.md               ← framework-owned
├── README.md                  ← partial update (only between FRAMEWORK:START~END)
├── meeting_room/
│   └── README.md              ← framework-owned
├── docs/                      ← framework-owned, whole-tree overwrite
└── resources/                 ← framework-owned, whole-tree overwrite
    ├── skills/
    ├── agents/
    ├── role_archetypes/
    ├── scripts/
    ├── hooks/
    └── settings_hooks_template.json
```

The following files are **user-owned** (the upgrade script must not touch them):

```
_agent_team_work_zone/
├── meeting_room/
│   └── *.md (except README.md)  ← user messages
├── archive/                     ← archived messages
├── <any workstation dir>/        ← all workstations (flat or _team)
│   e.g. secretary/, architect_team/, etc.
│   including TEAMMATE_INFO.json, teammates/, roundtable/, team_recipes/
└── the "Team Members" section of README.md  ← user-maintained roster (after FRAMEWORK:END)
```

### README.md special handling

`README.md` contains both framework content (rules, skill list, etc.) and user content (the team members table). The framework content is delimited by HTML comment markers:

```
<!-- FRAMEWORK:START -->
(framework content, auto-replaced by upgrade script)
<!-- FRAMEWORK:END -->

## Team Members
(user content, never touched by upgrade script)
```

The upgrade script only replaces content between `FRAMEWORK:START` and `FRAMEWORK:END`; the members table and content after `FRAMEWORK:END` are fully preserved. If your `README.md` has lost these markers, the script will print a warning and **skip** README replacement.

## How to upgrade

### Recommended (v0.5.0+): one-button script

In your project root (the one containing `_agent_team_work_zone/`), run:

```bash
bash _agent_team_work_zone/upgrade.sh
```

The script will:
1. Download the latest framework tarball from GitHub main branch to a temp directory
2. Extract and copy the template into the `_agent_team_work_zone/.upgrade/` staging area
3. Invoke the migration-chain dispatcher to run all necessary migrations (incremental upgrade with mid-chain resume support)
4. Auto re-run `bootstrap.sh` to refresh `.claude/skills` / `.claude/agents` / `.claude/settings.json` hooks
5. Clean up the staging area (preserves `.upgrade/README.md` as the directory placeholder)

**Zero arguments, zero config files, zero residue.** On failure, exits non-zero and preserves staging for debugging; the temp download dir is auto-cleaned by an EXIT trap.

### Fork users

If you're running a fork of `agent-work-zone`, override the download source with an env var:

```bash
export UPGRADE_REPO_URL="https://github.com/<your-fork>/agent-work-zone/archive/refs/heads/main.tar.gz"
bash _agent_team_work_zone/upgrade.sh
```

### Old 4-step flow (deprecated but still works)

From v0.5.0 onward, the **manual 4-step flow is no longer recommended**. But `resources/scripts/upgrade.sh` (the migration-chain dispatcher) is preserved — the new one-button script is just its automation wrapper. If you need to run it manually for debugging or customization:

```bash
# 1. Clone agent-work-zone repo locally
git clone https://github.com/SR-A-W/agent-work-zone.git /tmp/agent-work-zone

# 2. Copy template into your project's .upgrade/ staging area
cp -r /tmp/agent-work-zone/claude_code/zh/_agent_team_work_zone/. \
      _agent_team_work_zone/.upgrade/

# 3. Run the dispatcher (same one the one-button script invokes)
bash _agent_team_work_zone/.upgrade/resources/scripts/upgrade.sh

# 4. The dispatcher auto-cleans the staging area (preserves .upgrade/README.md)
```

Regular users no longer need this path — the one-button script is fully equivalent.

### For legacy users on pre-v0.5.0 versions (v0.0.0 .. v0.4.0)

The new one-button script `_agent_team_work_zone/upgrade.sh` was introduced in v0.5.0. If your project is on a pre-v0.5.0 version, use the old 4-step flow once to upgrade to v0.4.0+. Then use the new method. Or run the old 4-step flow directly to latest: the dispatcher will detect your current version and run all migrations in the chain.

Once on v0.5.0+, all subsequent upgrades only require `bash _agent_team_work_zone/upgrade.sh`.

## How to roll back

An upgrade is essentially a file overwrite. To roll back, restore via Git:

```bash
cd /path/to/your/project
git diff _agent_team_work_zone/                              # see what the upgrade changed
git checkout HEAD -- _agent_team_work_zone/resources/        # roll back resources/
git checkout HEAD -- _agent_team_work_zone/docs/             # roll back docs/
git checkout HEAD -- _agent_team_work_zone/README.md         # roll back README framework section
git checkout HEAD -- _agent_team_work_zone/VERSION _agent_team_work_zone/CHANGELOG.md
# Or roll back everything (including your own changes — use with care):
git checkout HEAD -- _agent_team_work_zone/
```

After rolling back, if the hooks in `.claude/settings.json` need to match the old version, re-run the old `bootstrap.sh`.

Past releases have annotated git tags (from v0.1.0 onward), so you can `git checkout v0.4.0` to inspect what that release looked like.

## Common failure modes

| Symptom | Cause | Handling |
|---|---|---|
| `curl: (6) Could not resolve host github.com` | Network issue | Check network, retry |
| `✗ Extracted archive does not contain expected VERSION file.` | Corrupted tarball or wrong URL | Verify GitHub repo URL, retry |
| `dispatcher` failed mid-chain | Migration script error | Staging is preserved; debug manually or git-restore and retry |
| `bootstrap.sh exited non-zero` | `.claude/` sync failed | Follow the error and re-run bootstrap manually |
| `## v0.X.Y` already in VERSION file | Already on latest | Exit, no-op |

## CHANGELOG format

Each release adds a `## vX.Y.Z (YYYY-MM-DD)` section to the top of `CHANGELOG.md`:

```markdown
## vX.Y.Z (YYYY-MM-DD)

One-sentence release summary.

### Fixed / Changed / Added / Documentation
- ...

### Migration (vPREV → vX.Y.Z)
**Required**: (actions you need to take during upgrade)
**Behavioral changes to know**: (backward-compatible but worth knowing)
```

For the full versioning / Release commit / git tag / migration-script conventions, see `VERSIONING.md`.
