# Release Publish Instructions

This file describes how to push the contents of this directory to the public
`agent-team-work-zone` GitHub repository as the v0.1.0 initial release.

## Prerequisites

- You have created a new empty GitHub repo: `github.com/SR-A-W/agent-team-work-zone`
- You have cloned it locally (or initialized a local repo pointing at it)
- You have `git` and `gh` (optional) available

## Steps

```bash
# 1. Go to your local clone of the new (empty) release repo
cd ~/path/to/agent-team-work-zone   # adjust to your actual path

# 2. Copy everything from this release-build directory
cp -r /tmp/release-build/. .

# 3. Verify the tree looks right
ls .
# → should show: .gitignore  LICENSE  README.md  README.zh.md  claude_code/  RELEASE_PUBLISH_INSTRUCTIONS.md

ls claude_code/zh/_agent_team_work_zone/resources/scripts/migrations/
# → should show ONLY: common.sh   (no v*.sh files)

cat claude_code/zh/_agent_team_work_zone/VERSION
# → v0.1.0

grep 'REPO_ARCHIVE_URL' claude_code/zh/_agent_team_work_zone/upgrade.sh | head -1
# → must contain: agent-team-work-zone  (NOT agent-work-zone without -team)

# 4. Stage everything
git add .

# 5. Commit — title must start with "Release v0.1.0" (release.sh convention)
git commit -m "Release v0.1.0: Initial public release"

# 6. Create annotated tag
git tag -a v0.1.0 -m "Release v0.1.0"

# 7. Push commits + tag
git push -u origin main --follow-tags
```

## Verification Checklist

After pushing, verify on GitHub:

- [ ] Repo is public (or as intended)
- [ ] Top-level contains only: `.gitignore`, `LICENSE`, `README.md`, `README.zh.md`, `claude_code/`, `RELEASE_PUBLISH_INSTRUCTIONS.md`
- [ ] `claude_code/zh/_agent_team_work_zone/VERSION` shows `v0.1.0`
- [ ] `claude_code/zh/_agent_team_work_zone/resources/scripts/migrations/` has only `common.sh`
- [ ] `claude_code/zh/_agent_team_work_zone/upgrade.sh` URL points to `agent-team-work-zone` (not `agent-work-zone`)
- [ ] Tag `v0.1.0` appears under Releases / Tags

## After Push: Test upgrade.sh Round-trip

Once the repo is live, test that upgrade.sh works for a fresh v0.1.0 install:

```bash
WORK=$(mktemp -d)
cp -r /tmp/release-build/claude_code/zh/_agent_team_work_zone "$WORK/"
cd "$WORK"

# upgrade.sh should report "Already up-to-date" since VERSION matches remote v0.1.0
NO_COLOR=1 bash _agent_team_work_zone/upgrade.sh
# Expected: "Already up-to-date (v0.1.0 ≥ v0.1.0)"
```

## Notes

- `RELEASE_PUBLISH_INSTRUCTIONS.md` (this file) is safe to keep in the repo or delete after push.
- The `agent-team-work-zone-dev` repo (internal) is separate. Do not confuse the two.
- Future releases: bump VERSION in dev, write CHANGELOG entry, write migration script,
  run `release.sh`, then run a new release-publish sprint to push a new snapshot here.
