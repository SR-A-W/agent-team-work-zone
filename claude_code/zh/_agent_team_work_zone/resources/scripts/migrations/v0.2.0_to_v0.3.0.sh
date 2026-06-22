#!/usr/bin/env bash
#
# migrations/v0.2.0_to_v0.3.0.sh
#
# Migrates a _agent_team_work_zone/ from v0.2.0 to v0.3.0.
#   $1 UPGRADE_DIR  $2 TARGET_DIR   (invoked by upgrade.sh; do not run directly)
#
# Behaviour: full framework-owned overwrite. v0.3.0 is a MINOR, backward-compatible
# release:
#   - Adds CLAUDE.md template (always-loaded operating instructions for downstream
#     projects that install this framework).
#   - bootstrap.sh now installs CLAUDE.md into the project root at install time:
#     fresh projects get it created; existing CLAUDE.md files get the
#     agent-team-work-zone + Coding Engineering Principles sections appended
#     (existing content is preserved).
#   - Adds teammate-signal interpretation rule: read teammate status from reports,
#     not heartbeats or files.
#
# NO breaking change. NO TEAMMATE_INFO.json schema change (schema_version stays 1,
# no field renames) → NO user-data migration needed.

set -euo pipefail
[ $# -ge 2 ] || { echo "Usage: $0 <UPGRADE_DIR> <TARGET_DIR>" >&2; exit 2; }
UPGRADE_DIR="$1"; TARGET_DIR="$2"
MIG_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./common.sh
. "$MIG_DIR/common.sh"

print_step "migration v0.2.0 → v0.3.0"
cp_framework_files "$UPGRADE_DIR" "$TARGET_DIR" "resources" "docs"
[ -f "$UPGRADE_DIR/CHANGELOG.md" ] && { cp "$UPGRADE_DIR/CHANGELOG.md" "$TARGET_DIR/CHANGELOG.md"; print_step "CHANGELOG.md"; }
[ -f "$UPGRADE_DIR/README.md" ] && { print_step "README.md (FRAMEWORK section)"; replace_framework_section "$UPGRADE_DIR/README.md" "$TARGET_DIR/README.md"; }
write_version "$TARGET_DIR/VERSION" "v0.3.0"

# --- What's new in v0.3.0 ---
print_step "v0.3.0 adds CLAUDE.md (always-loaded operating instructions) for projects using this framework."
print_step "After upgrade, bootstrap.sh installs CLAUDE.md into your PROJECT ROOT:"
print_step "  • No CLAUDE.md present → created from the template."
print_step "  • CLAUDE.md already exists → agent-team-work-zone + Coding Engineering"
print_step "    Principles sections are APPENDED (your existing content is preserved)."
print_step "  Review the result after running bootstrap.sh."
print_step "Backward compatible; no manual migration needed."

print_success "v0.3.0 applied"
