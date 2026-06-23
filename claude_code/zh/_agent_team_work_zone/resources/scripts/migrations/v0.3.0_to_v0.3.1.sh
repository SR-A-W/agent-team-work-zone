#!/usr/bin/env bash
#
# migrations/v0.3.0_to_v0.3.1.sh
#
# Migrates a _agent_team_work_zone/ from v0.3.0 to v0.3.1.
#   $1 UPGRADE_DIR  $2 TARGET_DIR   (invoked by upgrade.sh; do not run directly)
#
# Behaviour: full framework-owned overwrite. v0.3.1 is a PATCH, backward-compatible
# release:
#   - bootstrap.sh §6/§7 now always write to global ~/.claude/settings.json
#     (fixes settings being written to project level, where CC ignores
#     permissions.defaultMode and teammateMode has no effect).
#   - bootstrap.sh §6 rewritten as a display-mode selector (auto/in-process/no-change).
#   - bootstrap.sh §6/§7 + upgrade.sh major-version gate now use arrow-key menus
#     (choose_option) instead of y/n text input.
#
# NO breaking change. NO TEAMMATE_INFO.json schema change.

set -euo pipefail
[ $# -ge 2 ] || { echo "Usage: $0 <UPGRADE_DIR> <TARGET_DIR>" >&2; exit 2; }
UPGRADE_DIR="$1"; TARGET_DIR="$2"
MIG_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./common.sh
. "$MIG_DIR/common.sh"

print_step "migration v0.3.0 → v0.3.1"
cp_framework_files "$UPGRADE_DIR" "$TARGET_DIR" "resources" "docs"
[ -f "$UPGRADE_DIR/CHANGELOG.md" ] && { cp "$UPGRADE_DIR/CHANGELOG.md" "$TARGET_DIR/CHANGELOG.md"; print_step "CHANGELOG.md"; }
[ -f "$UPGRADE_DIR/README.md" ] && { print_step "README.md (FRAMEWORK section)"; replace_framework_section "$UPGRADE_DIR/README.md" "$TARGET_DIR/README.md"; }
write_version "$TARGET_DIR/VERSION" "v0.3.1"

# --- What's new in v0.3.1 ---
print_step "v0.3.1 fixes bootstrap §6/§7 settings write target — now always global ~/.claude/settings.json:"
print_step "  • permissions.defaultMode is explicitly ignored at project level by CC; only global works."
print_step "  • teammateMode is also a user-level setting with no effect at project level."
print_step "  Affected users: re-run bootstrap after upgrade to reset your display-mode / permission preferences."
print_step "v0.3.1 also adds arrow-key menus (choose_option) replacing y/n text input."
print_step "Backward compatible; no manual migration needed."

print_success "v0.3.1 applied"
