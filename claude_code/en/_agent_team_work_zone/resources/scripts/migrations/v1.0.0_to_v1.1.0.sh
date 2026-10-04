#!/usr/bin/env bash
#
# migrations/v1.0.0_to_v1.1.0.sh
#
# Migrates a _agent_team_work_zone/ from v1.0.0 to v1.1.0.
#   $1 UPGRADE_DIR  $2 TARGET_DIR   (invoked by upgrade.sh; do not run directly)
#
# MINOR: a new command and installer improvements.
#   - New: `npx agent-team-work-zone reconfigure` / `bash .../bootstrap.sh --reconfigure` asks the
#     install-time questions again on an existing install (nothing in the work zone changes).
#   - Every install-time question is an arrow-key menu; upgrades no longer ask about display
#     mode or auto permission; the optional CLAUDE.md sections are strongly recommended and
#     added by default on a first install (never on an upgrade).
#   - Warnings in bold orange-red, recommended options in green (terminal only, not with NO_COLOR).
#   - npm upgrade asks for the language when it cannot detect it.
#   - Docs: there is no separate "atwz" npm package.
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

print_step "migration v1.0.0 → v1.1.0"
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

write_version "$TARGET_DIR/VERSION" "v1.1.0"

# --- What's new in v1.1.0 ---
print_step "v1.1.0 — new command: npx agent-team-work-zone reconfigure (source install: bash _agent_team_work_zone/resources/scripts/bootstrap.sh --reconfigure). It asks the install-time questions again on this install — optional CLAUDE.md sections, git tracking, display mode, auto permission — without reinstalling, downloading, or changing anything in _agent_team_work_zone/."
print_step "v1.1.0 — every question during install is now an arrow-key menu (↑↓ to move, Enter to confirm)."
print_step "v1.1.0 — upgrades no longer ask about the teammate display mode or auto permission mode; your current settings are kept (change them with reconfigure)."
print_step "v1.1.0 — the two optional CLAUDE.md sections are now strongly recommended and added by default on a first install. Upgrades never add them; to add them to this project, run reconfigure."
print_step "v1.1.0 — warnings (⚠) are shown in bold orange-red and recommended menu options in green (in a terminal; not with NO_COLOR)."
print_step "v1.1.0 — npm upgrade asks you to choose the language when it cannot tell it from the install."
print_step "v1.1.0 — documentation fix: there is no separate \"atwz\" npm package. Use npx agent-team-work-zone <command>, or install once with npm i -g agent-team-work-zone and use the short command atwz <command>."
print_step "No manual migration needed."

print_success "v1.1.0 applied"
