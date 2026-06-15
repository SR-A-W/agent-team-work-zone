# `.upgrade/` — Upgrade staging area

This directory is a **staging area used only by the upgrade flow**. Under normal conditions it should be empty; it is filled temporarily only when you run a framework upgrade.

## Purpose

When you want to upgrade an installed `_agent_team_work_zone/` to a newer version from the `agent-work-zone` repo:

1. `git pull` the `agent-work-zone` repo to the target version.
2. Copy the **entire contents** of that repo's `claude_code/en/_agent_team_work_zone/` directory into this directory:
   ```bash
   # Run from your project root, assuming agent-work-zone is at ~/Projects/agent-work-zone
   cp -r ~/Projects/agent-work-zone/claude_code/en/_agent_team_work_zone/. \
         _agent_team_work_zone/.upgrade/
   ```
   After copying, this directory should look like:
   ```
   .upgrade/
   ├── VERSION
   ├── CHANGELOG.md
   ├── README.md
   ├── docs/
   ├── resources/
   │   └── scripts/
   │       ├── upgrade.sh              ← the new dispatcher
   │       └── migrations/             ← the version-incremental migration chain
   │           ├── common.sh
   │           ├── v0.0.0_to_v0.1.0.sh
   │           └── ...
   └── ...
   ```
3. Run the new dispatcher:
   ```bash
   bash _agent_team_work_zone/.upgrade/resources/scripts/upgrade.sh
   ```
   The script determines the current version, picks the migration chain it needs to run, executes them in order, and finally re-runs `bootstrap.sh`.
4. After the upgrade you may clear this directory (keep the directory and this README):
   ```bash
   find _agent_team_work_zone/.upgrade/ -mindepth 1 ! -name README.md -exec rm -rf {} +
   ```
   (Or just `rm -rf .upgrade/` and let the next upgrade recreate it — its contents are all provided by the repo.)

## Why not run straight from the `agent-work-zone` repo?

Staging the new version in the project-local `.upgrade/` has several advantages:

- **Migration scripts travel with the version they belong to**: the `v0.0.9 → v0.1.0` migration lives in `.upgrade/resources/scripts/migrations/`, shipped by the new version itself; even if the user's local repo is behind, the migration chain stays complete.
- **Self-describing paths**: the dispatcher derives `.upgrade/` and `_agent_team_work_zone/` from `$0`, so the user passes no arguments and can't point it at the wrong project.
- **Resumable on failure**: after a failed run, `.upgrade/` is still there — fix the problem and run again; no need to re-pull the repo.

## Notes

- This directory should be Git-ignored (see the `.gitignore` one level up) so upgrade leftovers aren't committed with the user's project.
- Contents may be kept or deleted after an upgrade; keeping them lets the next upgrade skip the copy step, but then you must ensure they are up to date yourself.
