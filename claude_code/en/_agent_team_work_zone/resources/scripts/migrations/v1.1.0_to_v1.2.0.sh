#!/usr/bin/env bash
#
# migrations/v1.1.0_to_v1.2.0.sh
#
# Migrates a _agent_team_work_zone/ from v1.1.0 to v1.2.0.
#   $1 UPGRADE_DIR  $2 TARGET_DIR   (invoked by upgrade.sh; do not run directly)
#
# MINOR: a new skill, a short command name and rule/skill text changes.
#   - New skill /quickstart (resources/skills/quickstart/, installed into .claude/skills/ by
#     bootstrap's install_skills like every other skill); quick modes in /onboard and /spawn-team.
#   - New: `config` as a short name for `reconfigure` in the npm command (`reconfigure` still works).
#   - The optional "Plain vocabulary" CLAUDE.md section ships with a starter list of rejected
#     words (CLAUDE.md itself is not touched by an upgrade).
#   - Rules and skills: read workstation files to the end; commitments get open/done/void;
#     the idle notification may carry a summary but is not acted on.
#   - meeting_room/README.md: conventions for a team from another repository.
# Behaviour: the usual framework-owned overwrite and block refreshes. The rules and
# teammate-rules texts changed, so each workstation README whose block differs gets a
# .bak of its old block. Also refreshes meeting_room/README.md (changed in this version;
# earlier upgrades had stopped copying it) and the root entry upgrade.sh.
# settings.conf, RULES_LEDGER.md and TEAMMATE_INFO.json are never created,
# changed or deleted. No schema change, no user-data migration.

set -euo pipefail
[ $# -ge 2 ] || { echo "Usage: $0 <UPGRADE_DIR> <TARGET_DIR>" >&2; exit 2; }
UPGRADE_DIR="$1"; TARGET_DIR="$2"
MIG_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./common.sh
. "$MIG_DIR/common.sh"

print_step "migration v1.1.0 → v1.2.0"
cp_framework_files "$UPGRADE_DIR" "$TARGET_DIR" "resources" "docs"
[ -f "$UPGRADE_DIR/CHANGELOG.md" ] && { cp "$UPGRADE_DIR/CHANGELOG.md" "$TARGET_DIR/CHANGELOG.md"; print_step "CHANGELOG.md"; }
# meeting_room/README.md is framework-owned (the rest of meeting_room/ is user data).
[ -f "$UPGRADE_DIR/meeting_room/README.md" ] && { mkdir -p "$TARGET_DIR/meeting_room"; cp "$UPGRADE_DIR/meeting_room/README.md" "$TARGET_DIR/meeting_room/README.md"; print_step "meeting_room/README.md"; }
# Root entry upgrade.sh (framework-owned). It may be the very script that started
# this upgrade and bash reads scripts as it runs, so never rewrite it in place:
# write a temp file beside it (keeping its mode) and rename it over the old one —
# the running copy keeps its old inode.
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

write_version "$TARGET_DIR/VERSION" "v1.2.0"

# --- What's new in v1.2.0 ---
print_step "v1.2.0 — new skill /quickstart: for a first-time setup, start Claude Code in the project root and type /quickstart; it builds a first team without asking questions. /onboard stays for choosing the roles yourself."
print_step "v1.2.0 — new short command: npx agent-team-work-zone config (or atwz config), the same as reconfigure; reconfigure still works. If you see Unknown command: config, your atwz or the version cached by npx is older: run npx agent-team-work-zone@latest config, or keep using reconfigure."
print_step "v1.2.0 — the optional \"Plain vocabulary\" CLAUDE.md section now ships with a starter list of rejected words. The upgrade does not change your CLAUDE.md; to get these entries, copy them by hand from resources/claude_md_optional/plain_vocabulary.md."
print_step "v1.2.0 — rules and skills: read workstation files to the end (a file not finished is named in the receipt as Unread: <file>); commitments are open, done or void, and voiding is ruled by the lead; the idle notification may carry a summary but the lead does not act on it, so problems go in the SendMessage report."
print_step "v1.2.0 — meeting_room/README.md: conventions for a team from another repository."
print_step "No manual migration needed. Restart your Claude Code sessions afterwards and run /reactivate-team for each running team."

print_success "v1.2.0 applied"
