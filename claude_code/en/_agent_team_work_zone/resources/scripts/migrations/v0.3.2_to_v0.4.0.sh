#!/usr/bin/env bash
#
# migrations/v0.3.2_to_v0.4.0.sh
#
# Migrates a _agent_team_work_zone/ from v0.3.2 to v0.4.0.
#   $1 UPGRADE_DIR  $2 TARGET_DIR   (invoked by upgrade.sh; do not run directly)
#
# Behaviour: full framework-owned overwrite, plus a rules-refresh sweep so the
# changed rules text actually reaches existing installs:
#   - The checkpoint-safety changes touch skills, hooks, docs and
#     resources/teammate_rules.md. Skills/hooks/docs arrive with the
#     resources/ + docs/ overwrite (and bootstrap.sh, which upgrade.sh re-runs);
#     the teammate rules excerpt only reaches teammate READMEs through the
#     TEAMMATE_RULES refresh below.
#   - The rules refresh itself is the fixed one: self-healed RULES
#     markers end at the last framework rule instead of the next "## " heading,
#     and teammate blocks are backed up before being replaced.
#   - Top-level README: FRAMEWORK / RULES / REFERENCE refreshed.
#   - Lead / flat workstation READMEs: RULES refreshed (diff + backup).
#   - Teammate workstation READMEs: TEAMMATE_RULES refreshed (diff + backup);
#     a README with no block yet is left alone (delivered on next
#     spawn/reactivate — Rule #1: a migration does not invent content in
#     another agent's workstation).
#
# NO breaking change. TEAMMATE_INFO.json schema_version 1 → 2 is zero-migration
# (the only change is that last_checkpoint_at is no longer written; an old
# registry that still carries it is tolerated and ignored), so this script does
# NOT touch any TEAMMATE_INFO.json. Fail-soft: any individual README's refresh
# can warn + skip without aborting the rest.

set -euo pipefail
[ $# -ge 2 ] || { echo "Usage: $0 <UPGRADE_DIR> <TARGET_DIR>" >&2; exit 2; }
UPGRADE_DIR="$1"; TARGET_DIR="$2"
MIG_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./common.sh
. "$MIG_DIR/common.sh"

print_step "migration v0.3.2 → v0.4.0"
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
    # Lead / flat workstation: full rules block, hand-copied per /onboard and
    # possibly customised — diff, back up the old block, replace only if it differs.
    [ -f "$d/README.md" ] && refresh_rules_section "$UPGRADE_DIR/README.md" "$d/README.md"
    if [ -d "$d/teammates" ]; then
        for td in "$d/teammates"/*/; do
            [ -d "$td" ] || continue
            # Teammate workstation: condensed TEAMMATE_RULES block, same diff +
            # backup treatment; no block yet → left alone (see header).
            [ -f "${td}README.md" ] && refresh_teammate_rules_section "$UPGRADE_DIR/resources/teammate_rules.md" "${td}README.md"
        done
    fi
done

write_version "$TARGET_DIR/VERSION" "v0.4.0"

# --- What's new in v0.4.0 ---
print_step "v0.4.0 — checkpoint safety:"
print_step "  • Teammates no longer write TEAMMATE_INFO.json during /checkpoint; only the lead maintains the registry, so concurrent checkpoints can no longer overwrite each other's registry updates."
print_step "  • The TeammateIdle checkpoint hook exits early for subagent calls (payload carries agent_id), so subagents are no longer told to checkpoint."
print_step "  • /reactivate-team stops with a clear error on a corrupt TEAMMATE_INFO.json and points to the .bak / git copy to restore from; checkpoint ages now come from each teammate's working-context.md mtime."
print_step "  • /checkpoint checks the teammate's identity first, keeps a copy of the previous Part A snapshot before overwriting it, and replies with an identity-bearing receipt."
print_step "  • TEAMMATE_INFO.json schema_version 1 → 2: the last_checkpoint_at field is dropped. Existing registries need no change — the old field is simply ignored. This upgrade does not touch your registry."
print_step "v0.4.0 — rules refresh no longer loses your content:"
print_step "  • Teammate READMEs: a TEAMMATE_RULES block that differs from the new one is first backed up to <README>.teammate_rules.bak.<timestamp>, then replaced."
print_step "  • When RULES markers are added to a README that has none yet, the block now ends after the last framework rule instead of at the next \"## \" heading. To keep your own notes outside the block, separate them from the rules with --- (or *** / ___) or an un-numbered ##/### heading; text glued straight onto the last rule is taken in and goes into <file>.rules.bak.<timestamp> (reported with ⚠)."
print_step "  • Content you appended after the reference sections (e.g. a <!-- USER:* --> segment) is no longer swallowed when REFERENCE markers are added."
print_step "  • Every ⚠ line above names the file; where a backup was taken, a separate line gives its path; .bak files are never deleted automatically — review and remove them yourself."
print_step "Backward compatible; no manual migration needed."

print_success "v0.4.0 applied"
