#!/usr/bin/env bash
#
# migrations/v0.4.0_to_v0.5.0.sh
#
# Migrates a _agent_team_work_zone/ from v0.4.0 to v0.5.0.
#   $1 UPGRADE_DIR  $2 TARGET_DIR   (invoked by upgrade.sh; do not run directly)
#
# Behaviour: full framework-owned overwrite + the usual block refreshes, plus one
# new step for a user-owned file:
#   - resources/ + docs/ overwrite (new scripts, the /broadcast-rule skill and the
#     optional CLAUDE.md sections arrive here; bootstrap.sh, which upgrade.sh
#     re-runs, installs the skill).
#   - Top-level README: FRAMEWORK / RULES / REFERENCE refreshed (the new
#     "Before you start" section is inside FRAMEWORK).
#   - Lead / flat workstation READMEs: RULES refreshed (diff + backup).
#   - Teammate workstation READMEs: TEAMMATE_RULES refreshed (diff + backup);
#     no block yet → left alone. Text above the block is never touched.
#   - _agent_team_work_zone/.gitignore (user-owned): only the patterns that are
#     new in this version are appended, and only those missing. Nothing is
#     rewritten, reordered or removed. No .gitignore → not created (notice only).
#
# Never created, overwritten or deleted here: _agent_team_work_zone/settings.conf,
# <team>_team/RULES_LEDGER.md, TEAMMATE_INFO.json. (CLAUDE.md is bootstrap.sh's: append-only.)
# No schema change.
# Fail-soft: any single file's step can warn + skip without aborting the rest.

set -euo pipefail
[ $# -ge 2 ] || { echo "Usage: $0 <UPGRADE_DIR> <TARGET_DIR>" >&2; exit 2; }
UPGRADE_DIR="$1"; TARGET_DIR="$2"
MIG_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./common.sh
. "$MIG_DIR/common.sh"

print_step "migration v0.4.0 → v0.5.0"
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

# .gitignore: append only the patterns new in v0.5.0 that the install lacks.
NEW_GITIGNORE_LINES=(
    '*_team/teammates/*/.started'
    '.hook_logs/'
    '*_team/teammates/*/.checkpoint_nudge_count'
    '*_team/TEAMMATE_INFO.json.bak'
    '*_team/.info.??????'
    '**/.README.md.??????'
    '/.VERSION.??????'
    '/settings.conf.??????'
)
GITIGNORE_RESULT=""
print_step ".gitignore (append missing v0.5.0 patterns only)"
if [ -f "$TARGET_DIR/.gitignore" ]; then
    if append_missing_lines "$TARGET_DIR/.gitignore" \
        "# Added by the v0.5.0 upgrade: runtime-only files and temp files left by an interrupted write (rules backups stay tracked)." \
        "${NEW_GITIGNORE_LINES[@]}"; then
        if [ "$APPEND_MISSING_COUNT" -gt 0 ]; then
            GITIGNORE_RESULT="appended $APPEND_MISSING_COUNT missing pattern(s) to _agent_team_work_zone/.gitignore; your own lines were not changed"
        else
            GITIGNORE_RESULT="_agent_team_work_zone/.gitignore already had all the new patterns; not changed"
        fi
    else
        GITIGNORE_RESULT="could not append to _agent_team_work_zone/.gitignore (see the warning above); it was left as is"
    fi
else
    GITIGNORE_RESULT="no _agent_team_work_zone/.gitignore in this install; skipped, nothing created (see above)"
    print_warn "No _agent_team_work_zone/.gitignore in this install — not created (you may manage ignores elsewhere)."
    print_step "  The template's version is claude_code/en/_agent_team_work_zone/.gitignore in https://github.com/SR-A-W/agent-team-work-zone ."
    print_step "  Copying it into _agent_team_work_zone/ would make git ignore: the upgrade staging area (.upgrade/, except its README),"
    print_step "  teammate start markers (.started), hook logs (.hook_logs/), the idle-hook counter (.checkpoint_nudge_count),"
    print_step "  the registry backup (TEAMMATE_INFO.json.bak) and temp files from interrupted writes (.info.??????, .README.md.??????,"
    print_step "  .VERSION.??????, settings.conf.??????). Rules backups (*.rules.bak.*) would stay tracked."
fi

write_version "$TARGET_DIR/VERSION" "v0.5.0"

# --- What's new in v0.5.0 ---
print_step "v0.5.0 — what changed for you:"
print_step "  • README \"Before you start\": keep _agent_team_work_zone/ inside your project and always start Claude Code there; tracking it in git is strongly recommended."
print_step "  • Optional checkpoint saving in git (off by default): bash _agent_team_work_zone/resources/scripts/atwz_checkpoint_git.sh enable. Its setting lives in _agent_team_work_zone/settings.conf, which only that command creates."
print_step "  • Git lock for a shared checkout: bash _agent_team_work_zone/resources/scripts/atwz_git_lock.sh run -- git … runs one git command at a time across agents. The git lock needs git 2.5 or later."
print_step "  • New /broadcast-rule skill (team lead): sends a rule change to every teammate and keeps <team>_team/RULES_LEDGER.md, which only that skill creates."
print_step "  • Optional CLAUDE.md sections (message format, plain vocabulary) in resources/claude_md_optional/. They are offered only on a first install, not during an upgrade; to add one: cat _agent_team_work_zone/resources/claude_md_optional/<file>.md >> CLAUDE.md"
print_step "  • .gitignore: $GITIGNORE_RESULT."
print_step "  • This upgrade did not create, change or delete settings.conf, any RULES_LEDGER.md or TEAMMATE_INFO.json."
print_step "Backward compatible; no manual migration needed."

print_success "v0.5.0 applied"
