#!/usr/bin/env bash
#
# migrations/v0.5.0_to_v1.0.0.sh
#
# Migrates a _agent_team_work_zone/ from v0.5.0 to v1.0.0.
#   $1 UPGRADE_DIR  $2 TARGET_DIR   (invoked by upgrade.sh; do not run directly)
#
# MAJOR-NOTICE: v1.0.0 does not change how your team works. It adds:
# MAJOR-NOTICE:   - an npm way to install and upgrade: npx agent-team-work-zone init / upgrade
# MAJOR-NOTICE:     (or, after npm i -g agent-team-work-zone, the short command atwz);
# MAJOR-NOTICE:   - a notice at session start when a newer release is out (can be turned off);
# MAJOR-NOTICE:   - a git check on first install.
# MAJOR-NOTICE: The major version marks the new way of distributing the framework, not a breaking change;
# MAJOR-NOTICE: `bash _agent_team_work_zone/upgrade.sh` keeps working as before.
#
# Behaviour: the usual framework-owned overwrite and block refreshes, plus the
# root entry upgrade.sh (new: UPGRADE_SOURCE_DIR). The rules and teammate-rules
# texts did not change in this release, so no .bak files are expected. Nothing else: no .gitignore change, no schema change, no user-data
# migration. settings.conf, RULES_LEDGER.md and TEAMMATE_INFO.json are never
# created, changed or deleted. Fail-soft per README, as in earlier migrations.
#
# The "# MAJOR-NOTICE:" lines above are printed by the dispatcher before it asks
# for confirmation of this major-version upgrade.

set -euo pipefail
[ $# -ge 2 ] || { echo "Usage: $0 <UPGRADE_DIR> <TARGET_DIR>" >&2; exit 2; }
UPGRADE_DIR="$1"; TARGET_DIR="$2"
MIG_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./common.sh
. "$MIG_DIR/common.sh"

print_step "migration v0.5.0 → v1.0.0"
cp_framework_files "$UPGRADE_DIR" "$TARGET_DIR" "resources" "docs"
[ -f "$UPGRADE_DIR/CHANGELOG.md" ] && { cp "$UPGRADE_DIR/CHANGELOG.md" "$TARGET_DIR/CHANGELOG.md"; print_step "CHANGELOG.md"; }
# Root entry upgrade.sh (framework-owned): v1.0.0 adds UPGRADE_SOURCE_DIR to it.
# It may be the very script that started this upgrade and bash reads scripts as
# it runs, so never rewrite it in place: write a temp file beside it (keeping its
# mode) and rename it over the old one — the running copy keeps its old inode.
if [ -f "$UPGRADE_DIR/upgrade.sh" ]; then
    if _t="$(mktemp_beside "$TARGET_DIR/upgrade.sh")" && cat "$UPGRADE_DIR/upgrade.sh" > "$_t" && mv "$_t" "$TARGET_DIR/upgrade.sh"; then
        print_step "upgrade.sh"
    else
        rm -f "${_t:-}"
        print_warn "Could not update $TARGET_DIR/upgrade.sh — the old one still works; copy it from the new template later."
    fi
fi
[ -f "$UPGRADE_DIR/README.md" ] && { print_step "README.md (FRAMEWORK section)"; replace_framework_section "$UPGRADE_DIR/README.md" "$TARGET_DIR/README.md"; }
[ -f "$UPGRADE_DIR/README.md" ] && { print_step "README.md (RULES section)"; refresh_rules_section "$UPGRADE_DIR/README.md" "$TARGET_DIR/README.md"; }
[ -f "$UPGRADE_DIR/README.md" ] && { print_step "README.md (REFERENCE section)"; refresh_reference_section "$UPGRADE_DIR/README.md" "$TARGET_DIR/README.md"; }

print_step "Scanning workstation READMEs for the rules section (skipping docs/resources/meeting_room/archive/.upgrade)"
for d in "$TARGET_DIR"/*/; do
    d="${d%/}"
    base="$(basename "$d")"
    case "$base" in
        docs|resources|meeting_room|archive|.upgrade) continue ;;
    esac
    # Lead / flat workstation: full rules block — diff, back up, replace only if it differs.
    [ -f "$d/README.md" ] && refresh_rules_section "$UPGRADE_DIR/README.md" "$d/README.md"
    if [ -d "$d/teammates" ]; then
        for td in "$d/teammates"/*/; do
            [ -d "$td" ] || continue
            # Teammate workstation: TEAMMATE_RULES block, same diff + backup; no block → left alone.
            [ -f "${td}README.md" ] && refresh_teammate_rules_section "$UPGRADE_DIR/resources/teammate_rules.md" "${td}README.md"
        done
    fi
done

write_version "$TARGET_DIR/VERSION" "v1.0.0"

# --- What's new in v1.0.0 ---
print_step "v1.0.0 — how your team works is unchanged. New: an npm package for installing and upgrading:"
print_step "  • new project:      npx agent-team-work-zone init [project-dir] [--lang zh|en]"
print_step "  • existing install: npx agent-team-work-zone upgrade [project-dir] [--yes]  (uses the templates shipped in the package; no download)"
print_step "  • short name after a global install (npm i -g agent-team-work-zone): atwz init / atwz upgrade."
print_step "  • bash _agent_team_work_zone/upgrade.sh still works as before; it can also take a local template directory: UPGRADE_SOURCE_DIR=<dir> bash _agent_team_work_zone/upgrade.sh"
print_step "  • Major-version upgrades now print what the release changes, and can be confirmed without a terminal with ATWZ_ASSUME_YES=1 (npm: --yes)."
print_step "  • New: a short notice at session start when a newer release is out (checked at most once a day, in the background; it never upgrades by itself). Turn it off with ATWZ_UPDATE_CHECK=0 or a file _agent_team_work_zone/.no_update_check."
print_step "  • New installs: bootstrap.sh checks git once (warns outside a repository or below its root; at the repository root asks whether to track _agent_team_work_zone/). Upgrades do not ask."
print_step "Backward compatible; no manual migration needed."

print_success "v1.0.0 applied"
