#!/usr/bin/env bash
#
# migrations/v0.1.0_to_v0.2.0.sh
#
# Migrates a _agent_team_work_zone/ from v0.1.0 to v0.2.0.
#   $1 UPGRADE_DIR  $2 TARGET_DIR   (invoked by upgrade.sh; do not run directly)
#
# Behaviour: full framework-owned overwrite. v0.2.0 adapts the framework to the
# Claude Code 2.1.178 agent-teams API:
#   - TeamCreate / TeamDelete tools removed → /reactivate-team drops Step 0.
#   - Agent(team_name=…) ignored → spawn/reactivate drop team_name; teammate permission
#     mode inherits the lead (can't be set per-teammate at spawn). Each session
#     auto-creates a unique session-level team (session-<id>), teammates auto-cleaned
#     on exit (no ghost accumulation).
#   - teammate_idle_checkpoint.sh: three-tier workstation addressing
#     (T1 payload team_name compat / T2 derive ${name%%-*}_team / T3 glob, >1 → exit 0).
#   - New teammate naming convention: <slug>-<role> (slug = workstation name minus
#     _team, single token, no hyphen) so the idle hook can derive the workstation.
#   - bootstrap.sh CC version floor raised to 2.1.178.
#
# This is framework code/doc only. NO TEAMMATE_INFO.json schema change (schema_version
# stays 1, no field renames) → NO user-data migration. Existing teammates keep their
# old names (tolerated by the idle hook's T3 glob fallback); only NEW spawns must use
# <slug>-<role>.
#
# ⚠️ REQUIRES Claude Code >= 2.1.178. On CC <= 2.1.177, do NOT upgrade to this version —
#    stay on v0.1.0: https://github.com/SR-A-W/agent-team-work-zone/releases/tag/v0.1.0

set -euo pipefail
[ $# -ge 2 ] || { echo "Usage: $0 <UPGRADE_DIR> <TARGET_DIR>" >&2; exit 2; }
UPGRADE_DIR="$1"; TARGET_DIR="$2"
MIG_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./common.sh
. "$MIG_DIR/common.sh"

print_step "migration v0.1.0 → v0.2.0"
cp_framework_files "$UPGRADE_DIR" "$TARGET_DIR" "resources" "docs"
[ -f "$UPGRADE_DIR/CHANGELOG.md" ] && { cp "$UPGRADE_DIR/CHANGELOG.md" "$TARGET_DIR/CHANGELOG.md"; print_step "CHANGELOG.md"; }
[ -f "$UPGRADE_DIR/README.md" ] && { print_step "README.md (FRAMEWORK section)"; replace_framework_section "$UPGRADE_DIR/README.md" "$TARGET_DIR/README.md"; }
write_version "$TARGET_DIR/VERSION" "v0.2.0"

# --- Breaking-change notice (behavioural change; print loudly for the maintainer) ---
print_warn "v0.2.0 adapts to the Claude Code 2.1.178 agent-teams API:"
print_warn "  • REQUIRES Claude Code >= 2.1.178 (bootstrap now hard-stops below that)."
print_warn "  • TeamCreate/TeamDelete removed; /reactivate-team no longer runs Step 0."
print_warn "  • Agent spawn drops team_name (ignored); teammate permission mode inherits the lead"
print_warn "    (can't be set per-teammate at spawn). Each session auto-creates a session-level team;"
print_warn "    teammates auto-clean on exit. For auto teammates, set permissions.defaultMode:\"auto\"."
print_warn "  • New teammates must be named <slug>-<role> (slug = single token, no hyphen)."
print_warn "    Existing teammates keep their names (idle-hook T3 glob fallback covers them)."
print_warn "  • If your Claude Code is <= 2.1.177, stay on v0.1.0: https://github.com/SR-A-W/agent-team-work-zone/releases/tag/v0.1.0"

print_success "v0.2.0 applied"
