#!/usr/bin/env bash
#
# migrations/v1.2.1_to_v1.3.0.sh
#
# Migrates a _agent_team_work_zone/ from v1.2.1 to v1.3.0.
#   $1 UPGRADE_DIR  $2 TARGET_DIR   (invoked by upgrade.sh; do not run directly)
#
# MINOR: teammate models by subscription tier, and a new skill /remote-collab.
#   - New scripts resources/scripts/atwz_detect_tier.sh and atwz_remote_collab.sh,
#     new skill resources/skills/remote-collab/ (installed into .claude/skills/ by
#     bootstrap's install_skills like every other skill), new docs/model_policy_schema.md.
#   - Work rule 10 gains the /remote-collab merge exception (README RULES block and
#     resources/teammate_rules.md).
#   - meeting_room/README.md: a section for a team on another machine.
#   - .gitignore: patterns for the policy-file temp file and the /remote-collab runtime files
#     (state, last-seen, digests, the watcher's loop job, the watch pid file, temp files).
# Behaviour: the usual framework-owned overwrite and block refreshes. The rules and
# teammate-rules texts changed, so each workstation README whose block differs gets a
# .bak of its old block. Also refreshes meeting_room/README.md and appends the missing
# new patterns to the install's .gitignore (append-only; nothing created if it is absent).
# Existing teams get no model_policy.json (their teammates stay on sonnet).
# settings.conf, RULES_LEDGER.md and TEAMMATE_INFO.json are never created,
# changed or deleted. No schema change, no user-data migration.

set -euo pipefail
[ $# -ge 2 ] || { echo "Usage: $0 <UPGRADE_DIR> <TARGET_DIR>" >&2; exit 2; }
UPGRADE_DIR="$1"; TARGET_DIR="$2"
MIG_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./common.sh
. "$MIG_DIR/common.sh"

print_step "migration v1.2.1 → v1.3.0"
cp_framework_files "$UPGRADE_DIR" "$TARGET_DIR" "resources" "docs"
[ -f "$UPGRADE_DIR/CHANGELOG.md" ] && { cp "$UPGRADE_DIR/CHANGELOG.md" "$TARGET_DIR/CHANGELOG.md"; print_step "CHANGELOG.md"; }
# meeting_room/README.md is framework-owned (the rest of meeting_room/ is user data).
[ -f "$UPGRADE_DIR/meeting_room/README.md" ] && { mkdir -p "$TARGET_DIR/meeting_room"; cp "$UPGRADE_DIR/meeting_room/README.md" "$TARGET_DIR/meeting_room/README.md"; print_step "meeting_room/README.md"; }
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

# .gitignore: append only the patterns new in v1.3.0 that the install lacks.
NEW_GITIGNORE_LINES=(
    '*_team/.policy.??????'
    '*_team/.remote_collab_state'
    '*/.remote_collab_state'
    '*_team/teammates/*/remote_seen'
    '*_team/teammates/*/digests/'
    '*_team/teammates/*/loop_job'
    '*_team/.remote_seen'
    '*/.remote_seen'
    '*_team/.remote_collab_watch.pid'
    '*/.remote_collab_watch.pid'
    '*_team/digests/'
    '*/digests/'
    '*/.rc.??????'
)
print_step ".gitignore (append missing v1.3.0 patterns only)"
if [ -f "$TARGET_DIR/.gitignore" ]; then
    if append_missing_lines "$TARGET_DIR/.gitignore" \
        "# Added by the v1.3.0 upgrade: the model policy's temp file, and /remote-collab runtime files (state, digests, loop job, watch pid; they change on every check, merge and push)." \
        "${NEW_GITIGNORE_LINES[@]}"; then
        [ "$APPEND_MISSING_COUNT" -gt 0 ] || print_step "  .gitignore already had all the new patterns; not changed"
    fi
else
    print_warn "No _agent_team_work_zone/.gitignore in this install — not created (you may manage ignores elsewhere)."
    print_step "  If you track the work zone in git, ignore these runtime files yourself: ${NEW_GITIGNORE_LINES[*]}"
fi

write_version "$TARGET_DIR/VERSION" "v1.3.0"

# --- What's new in v1.3.0 ---
print_step "v1.3.0 — teammate models follow your subscription: /quickstart and /onboard detect your plan and write <team>/model_policy.json (default teammate model and team size limit). Existing teams have no such file, so their teammates stay on sonnet; to use the defaults for your plan, have the lead run the \"Choose the teammate model\" step of /onboard."
print_step "v1.3.0 — new skill /remote-collab: two teams on two machines work on one repository through git and the meeting room (start, pull, push, stop, status; checks by a haiku watcher or by a background script). Work rule 10 gains its merge exception, so the rules blocks were refreshed and the old blocks backed up."
print_step "v1.3.0 — meeting_room/README.md: a section for a team on another machine."
print_step "No manual migration needed. Restart your Claude Code sessions afterwards and run /reactivate-team for each running team."

print_success "v1.3.0 applied"
