# Versioning and Release Conventions (VERSIONING)

This document defines the version-numbering rules, release flow, and release-artifact (commit, tag, CHANGELOG, migration script) conventions for the `_agent_team_work_zone` framework.

> **Audience**: framework maintainers (those who decide when to bump versions and write releases). Regular users only need `upgrade_guide.md`.

## 1. SemVer Rules (v0.x Phase)

Version format: `vMAJOR.MINOR.PATCH`, e.g., `v0.4.0`, `v0.5.0`, `v0.5.1`.

### MAJOR (X) — Breaking Architectural Changes

- Breaking renames of workstation/directory structure (e.g., v0.3.0 renamed `_agent_work_zone/` → `_agent_team_work_zone/`)
- Breaking changes to skill interfaces (removing a skill, changing required parameters)
- Breaking changes to `TEAMMATE_INFO.json` schema (removing a field, changing field semantics)
- Incompatible changes to the migration-script mechanism itself (e.g., dispatcher signature change)

**v0.x relaxed clause**: between v0.x releases, MINOR bumps may carry "controlled breaking changes" — as long as:
- A migration script handles the migration of user data automatically
- The CHANGELOG Migration section explicitly notes behavioral changes

This relaxed clause expires at v1.0.0; after that, any breaking change requires MAJOR.

### MINOR (Y) — New Features / Controlled Breaking Changes

- New skill / agent / hook / role archetype
- Adding optional parameters to existing skills
- New documentation sections
- v0.x phase: controlled, migration-script-backed breaking changes (e.g., renaming a workstation directory)

### PATCH (Z) — Fixes / Documentation / Tweaks

- Bug fixes
- Documentation wording adjustments
- Rule-text tweaks (no semantic change)
- Style polish (OK→✓, adding date comments, etc.)

### Decision Quick Reference

| Change you see | Which bump |
|---|---|
| Added a new skill | MINOR |
| Changed a skill's required parameter | MAJOR |
| Changed wording of a skill, no behavior change | PATCH |
| Added a hook | MINOR |
| Renamed a directory (with migration script) | MINOR in v0.x, MAJOR after v1.0.0 |
| Fixed a bug | PATCH |
| Added a section to a README | PATCH |
| Introduced a new top-level file under `_agent_team_work_zone/<new-file>` | MINOR |

---

## 2. Release Commit Convention

Release is a **standalone commit**, not merged with feature commits. The commit subject must start with `Release vX.Y.Z`:

```
Release v0.5.0: stable major + one-button upgrade
Release v0.5.1: fix curl pipe error swallow in upgrade.sh
Release v0.6.0: add /handoff skill + autonomous mode toggle
```

### The commit contains exactly

- `claude_code/zh/_agent_team_work_zone/VERSION` changed to the new version number
- `claude_code/en/_agent_team_work_zone/VERSION` changed to the new version number
- `claude_code/zh/_agent_team_work_zone/CHANGELOG.md` adds the new `## vX.Y.Z` entry
- `claude_code/en/_agent_team_work_zone/CHANGELOG.md` adds the new `## vX.Y.Z` entry
- `claude_code/zh/_agent_team_work_zone/resources/scripts/migrations/v<PREV>_to_vX.Y.Z.sh` is added

**Must not contain**: the feature changes carried in this release (those belong in earlier feature commits). A Release commit is "applying the label," not "doing new work."

### Why this convention matters

- `git log --grep="^Release v"` lists all release points in one line
- Tracing "what v0.5.0 did / what it affected" only requires looking at one commit
- Migration-script audit is decoupled from feature changes: the upgrade mechanism only cares about "what the release did," not implementation details
- Tooling support: `release.sh` enforces that the HEAD commit subject starts with `Release vX.Y.Z`

---

## 3. Git Tag Convention

Every release **must** create an annotated tag (not a lightweight tag):

```bash
git tag -a v0.5.0 -m "Release v0.5.0"
```

The tag is **placed on the Release commit** (not any feature commit).

### Annotated vs Lightweight

- Annotated (recommended): the tag has its own commit object, author, date, and message — an "independent release record"
- Lightweight: the tag is just a pointer with no metadata — do not use

### When to push tags

Push the Release commit and tag together: `git push --follow-tags` (git automatically pushes the corresponding tag).

### Historical v0.x tags

v0.1.0 .. v0.4.0 were backfilled (added during the v0.5.0 sprint), by reverse-looking-up the corresponding release commits via CHANGELOG dates. From v0.5.0 onward, `release.sh` enforces the convention.

---

## 4. CHANGELOG Convention

Format follows [Keep a Changelog](https://keepachangelog.com/). Each release adds a `## vX.Y.Z (YYYY-MM-DD)` section to the top of `CHANGELOG.md`.

### Required sections

```markdown
## v0.5.0 (2026-06-12)

One-sentence release summary.

### Fixed
- ...

### Changed
- ...

### Added
- ...

### Documentation
- ...

### Migration (vPREV → v0.5.0)
**Required**: (actions the user must take during the upgrade)
**Behavioral changes to know**: (backward-compatible but maintainers should know)
(If the release is a PATCH with no behavioral change, the Migration section may be omitted.)

### Notes
- ...
```

Any section without content can be omitted, but **an entirely empty CHANGELOG entry is not allowed** (`release.sh` will reject it).

### Bilingual symmetry

Each release's zh and en CHANGELOG entries must be **symmetric** — same sections, same items, translated faithfully.

---

## 5. Migration Script Convention

Every version bump **must** have a corresponding migration script:

```
claude_code/zh/_agent_team_work_zone/resources/scripts/migrations/v<PREV>_to_v<NEW>.sh
```

### Standard template (PATCH / MINOR)

Follow the `v0.0.0_to_v0.1.0.sh` pattern:
- `cp_framework_files` for `resources/` and `docs/`
- Where needed, overwrite `meeting_room/README.md`, `CHANGELOG.md`, `README.md` (FRAMEWORK section swap)
- End with `write_version "$TARGET_DIR/VERSION" "v<NEW>"`

### MAJOR upgrade exception

MAJOR involves breaking changes, so migration scripts may include structural operations (mkdir / mv / cross-directory moves), but **must never touch files inside user workstations**. See `upgrade_guide.md`'s "Framework files vs user files" inventory for the rules.

### Why this convention matters

Historical lesson: v0.2.0 / v0.2.1 releases forgot to write migration scripts, causing the v0.x → v0.4.0 chain to break mid-way. `release.sh` now enforces that the migration script exists, preventing this from happening again.

---

## 6. Release Workflow (from v0.5.0 onward)

The standard flow for a release (**all commands run from the repo root**):

```bash
# 0. cd to the repo root
cd /path/to/agent-work-zone

# 1. On a clean main branch, confirm all feature commits intended for v0.5.0 are merged.
git checkout main
git log --oneline -10

# 2. Lead writes release materials (bilingual symmetric):
#    - Update VERSION (zh + en)
#    - Write CHANGELOG v0.5.0 entry (zh + en)
#    - Write v0.4.0_to_v0.5.0.sh
git add \
  claude_code/zh/_agent_team_work_zone/VERSION \
  claude_code/en/_agent_team_work_zone/VERSION \
  claude_code/zh/_agent_team_work_zone/CHANGELOG.md \
  claude_code/en/_agent_team_work_zone/CHANGELOG.md \
  claude_code/zh/_agent_team_work_zone/resources/scripts/migrations/v0.4.0_to_v0.5.0.sh

# 3. Release commit
git commit -m "Release v0.5.0: <one-sentence summary>

<more detailed description>
"

# 4. Run release.sh: enforces checks + creates tag
bash claude_code/zh/_agent_team_work_zone/resources/scripts/release.sh v0.5.0
# Or dry-run first:
bash claude_code/zh/_agent_team_work_zone/resources/scripts/release.sh --dry-run v0.5.0

# 5. Push
git push --follow-tags
```

`release.sh` enforces 5 checks: VERSION matches / CHANGELOG entry present / migration script exists / working tree clean / HEAD commit subject starts with `Release v0.5.0`. Any failure exits 1 without creating a tag.

---

## 7. v1.0.0 Roadmap Placeholder

v1.0.0 is a commitment-level version, not yet planned. The intended direction: **release as an independently distributable package** (users no longer need to clone the entire agent-work-zone repo, but install via brew tap / curl install / similar mechanism).

Post-v1.0.0 commitments:
- No more breaking MINOR — all breaking changes go through MAJOR
- Skill interfaces, `TEAMMATE_INFO.json` schema, framework file inventory are treated as **public API**
- Any breaking change requires a deprecation period (deprecation warning first, removed in the next MAJOR)

The v0.x phase is not bound by these constraints, but maintainers **should aim toward this direction** — each time you bump, ask yourself "if this were post-v1.0.0, could it be PATCH, MINOR, or must be MAJOR?" That is the v1.0.0 dress rehearsal.

---

## 8. Deprecation Notice for the Old 4-Step Upgrade Flow

From v0.5.0 onward, the **manual 4-step flow** (`git pull → cp -r → bash dispatcher → cleanup`) is **officially deprecated**.

`upgrade_guide.md` from v0.5.0 onward describes only the new one-button script: `bash _agent_team_work_zone/upgrade.sh`.

### Migration path for legacy v0.x users

If your project is still on a legacy v0.x version (v0.0.0 .. v0.4.0):
1. **First, upgrade to v0.4.0 using the old method** — follow the old-version `upgrade_guide.md` (you can recover it with `git checkout v0.4.0`)
2. **Then use the new method**: from v0.4.0, `bash _agent_team_work_zone/upgrade.sh` will upgrade directly to latest

### The old dispatcher is still here

`resources/scripts/upgrade.sh` (the migration-chain dispatcher) is **preserved** — the new one-button script is its automation wrapper, not its replacement. So the upgrade mechanism internally still runs the migration chain; users just no longer have to cp manually.

---

## 9. Historical Decision References

Detailed version-design decisions and lessons learned:
- `notes/` top-level directory: design notes from past sprints
- `docs/design_history.md`: early architectural decision records
- `_agent_team_work_zone/upgrader_team/notes.md` (live dogfood): maintainer's working notes
- The individual CHANGELOG entries themselves: contain triggering factors and impact scope

If this document conflicts with code behavior, **code (especially `release.sh`) is authoritative** — it's the tool that enforces the conventions; the document is the human-readable version of the conventions.

---

## 10. Dev / Release Dual-Repo Version Mapping + the v1.0.x Evolution Scheme

The framework evolves across **two repositories**:

| Repo | Visibility | README audience | Role |
|---|---|---|---|
| **dev** (this `agent-work-zone` repo) | private | **developers** (framework maintainers) | source of truth: zh source + en mirror, live dogfood, migration scripts, release.sh, design notes all live here |
| **release** (future public repo) | public | **users** | the distributed edition carved out of dev; strips `release.sh` / migrations / dogfood / design notes |

### Version mapping rule

> **release MAJOR = dev MAJOR − 1; MINOR and PATCH stay synced.**

E.g. dev `v1.1.0` ↔ release `v0.1.0` (first public release); dev `v1.2.3` ↔ release `v0.2.3`; eventually dev `v2.0.0` ↔ release `v1.0.0` (i.e. the promise-level "v1.0.0 as a distributable package" from §7 — that v1.0.0 is the **release** edition's, corresponding to dev v2.0.0).

So dev always leads release by one major: dev is internally "mature at 1.x," but the public face is still 0.x ("public API may still evolve") — consistent with §7's promise, which it lands on the **release** side.

### Why dev jumps v0.5.0 → v1.0.1 (skipping v1.0.0)

`v0.5.0` is a **symbolic maturity baseline** — it delivered one-button `upgrade.sh` + release discipline `release.sh` + versioning conventions, so the framework is "good enough to call 1.0" from there. Rather than retroactively rename v0.5.0 to v1.0.0, we **declare v0.5.0 ≙ symbolic v1.0.0 in place** and continue dev from `v1.0.1`.

- dev's VERSION file content still keys on the **chain predecessor**: the migration is named `v0.5.0_to_v1.0.1.sh` (the on-disk VERSION content is `v0.5.0`; the migration chain matches on that, independent of any tag alias).
- GitKeeper / Upgrader separately adds a `v1.0.0` annotated tag **aliasing the v0.5.0 release commit** (pure tag op — does not touch the VERSION file, does not enter the migration chain).

### The "a significant standalone fix earns its own version" convention

Not every fix needs its own version — the vast majority of polish is **folded into a single PATCH** (e.g. v1.0.1 collected the checkpoint window, liveness hardening, count fix, and a batch of small changes). But a **serious, standalone, worth-tracking** fix **gets its own version number** for auditability and traceability.

E.g. the teammate idle hook's **cross-team same-name teammate workstation misattribution** bug (glob `*_team/` takes the alphabetically-first → reads the wrong team's mtime → false nudge) is a serious latent correctness bug; it takes `v1.0.2` on its own, separate from v1.0.1's routine polish.

### Target state after wrap-up

When this round of wrap-up is complete and the framework reaches its first "publishable" state: dev tags `v1.1.0`, and the release repo's `v0.1.0` is carved out as the **first public release**.
