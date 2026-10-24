#!/usr/bin/env bash
#
# migrations/v1.2.0_to_v1.2.1.sh
#
# Migrates a _agent_team_work_zone/ from v1.2.0 to v1.2.1.
#   $1 UPGRADE_DIR  $2 TARGET_DIR   (invoked by upgrade.sh; do not run directly)
#
# PATCH: the /quickstart closing message explains how split-pane members join
# Remote Control (resources/skills/quickstart/SKILL.md, zh + en).
# Behaviour: the usual framework-owned overwrite and block refreshes (the rules
# and teammate-rules texts did not change, so no .bak files are expected).
# settings.conf, RULES_LEDGER.md and TEAMMATE_INFO.json are never created,
# changed or deleted. No schema change, no user-data migration.

set -euo pipefail
[ $# -ge 2 ] || { echo "Usage: $0 <UPGRADE_DIR> <TARGET_DIR>" >&2; exit 2; }
UPGRADE_DIR="$1"; TARGET_DIR="$2"
MIG_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./common.sh
. "$MIG_DIR/common.sh"

print_step "migration v1.2.0 → v1.2.1"
cp_framework_files "$UPGRADE_DIR" "$TARGET_DIR" "resources" "docs"
[ -f "$UPGRADE_DIR/CHANGELOG.md" ] && { cp "$UPGRADE_DIR/CHANGELOG.md" "$TARGET_DIR/CHANGELOG.md"; print_step "CHANGELOG.md"; }
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

write_version "$TARGET_DIR/VERSION" "v1.2.1"

# --- What's new in v1.2.1 ---
print_step "v1.2.1 — the /quickstart closing message now tells you how each split-pane member joins Remote Control: type /remote-control <member name> in its pane."
print_step "No manual migration needed. Restart your Claude Code sessions so that they load the updated /quickstart."

print_success "v1.2.1 applied"
