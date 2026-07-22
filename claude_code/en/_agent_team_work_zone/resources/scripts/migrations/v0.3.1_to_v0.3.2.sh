#!/usr/bin/env bash
#
# migrations/v0.3.1_to_v0.3.2.sh
#
# Migrates a _agent_team_work_zone/ from v0.3.1 to v0.3.2.
#   $1 UPGRADE_DIR  $2 TARGET_DIR   (invoked by upgrade.sh; do not run directly)
#
# Behaviour: full framework-owned overwrite, PLUS a new rules-refresh pass:
#   - Work Rules text now lives inside <!-- RULES:START --> / <!-- RULES:END -->
#     markers in README.md (independent of the existing FRAMEWORK markers), so
#     it can be kept in sync across upgrades instead of only living outside the
#     FRAMEWORK block where nothing ever touched it.
#   - Lead workstations and flat workstations are swept: if a README already
#     has a rules section, the RULES markers are self-healed in if missing,
#     then the block is diffed against source and refreshed (with a backup of
#     the old block) only if it actually differs.
#   - Teammate workstations get a SEPARATE, deliberately asymmetric mechanism:
#     a condensed 7-rule <!-- TEAMMATE_RULES:START/END --> block sourced from
#     resources/teammate_rules.md (new in this version — see the inline
#     comments below for why the two mechanisms differ).
#   - Files with no rules section / no TEAMMATE_RULES block at all are left
#     untouched — that gap is closed on the spawn/reactivate side, not by this
#     migration.
#
# NO breaking change. NO TEAMMATE_INFO.json schema change. Fail-soft: any
# individual README's rules refresh can warn+skip without aborting the rest.

set -euo pipefail
[ $# -ge 2 ] || { echo "Usage: $0 <UPGRADE_DIR> <TARGET_DIR>" >&2; exit 2; }
UPGRADE_DIR="$1"; TARGET_DIR="$2"
MIG_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./common.sh
. "$MIG_DIR/common.sh"

print_step "migration v0.3.1 → v0.3.2"
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
    # Lead / flat workstation: the 13-rule block is hand-copied by the agent per
    # /onboard, so it may carry user customization (already observed 4 diverged
    # copies in practice) — diff against source, back up the old block, and
    # replace ONLY if it actually differs.
    [ -f "$d/README.md" ] && refresh_rules_section "$UPGRADE_DIR/README.md" "$d/README.md"
    if [ -d "$d/teammates" ]; then
        for td in "$d/teammates"/*/; do
            [ -d "$td" ] || continue
            tgt_readme="${td}README.md"
            if [ -f "$tgt_readme" ]; then
                # Teammate workstation: the TEAMMATE_RULES block is a framework-owned
                # literal excerpt, deliberately asymmetric to the lead/flat path above
                # (no diff-backup mechanism — see refresh_rules_section's docstring for
                # why the two are allowed to differ). But this migration does NOT
                # fabricate a TEAMMATE_RULES block where none exists: per Rule #1, a
                # migration script does not reach into another agent's workstation to
                # invent content it never had. Pre-existing teammate workstations spawned
                # before this version simply have no block yet — that gets delivered the
                # next time the teammate is spawned/reactivated (spawn-team/reactivate-team
                # already append it), not by this migration.
                if grep -q '<!-- TEAMMATE_RULES:START -->' "$tgt_readme"; then
                    # Block already present (created by a spawn/reactivate on or after
                    # this version) — refresh it, but only rewrite the file if the
                    # content actually changed, so a repeat upgrade doesn't needlessly
                    # touch every teammate README's mtime.
                    do_replace=1
                    if grep -q '<!-- TEAMMATE_RULES:END -->' "$tgt_readme"; then
                        tgt_block="$(awk '/<!-- TEAMMATE_RULES:START -->/{c=1} c{print} /<!-- TEAMMATE_RULES:END -->/{c=0}' "$tgt_readme")"
                        src_block="$(awk '/<!-- TEAMMATE_RULES:START -->/{c=1} c{print} /<!-- TEAMMATE_RULES:END -->/{c=0}' "$UPGRADE_DIR/resources/teammate_rules.md")"
                        [ "$tgt_block" = "$src_block" ] && do_replace=0
                    fi
                    if [ "$do_replace" -eq 1 ]; then
                        replace_marked_section "$UPGRADE_DIR/resources/teammate_rules.md" "$tgt_readme" \
                            '<!-- TEAMMATE_RULES:START -->' '<!-- TEAMMATE_RULES:END -->' \
                            "$(basename "$td")/README.md teammate-rules block refreshed"
                    fi
                else
                    print_step "teammates/$(basename "$td"): no TEAMMATE_RULES block yet — will be delivered on next spawn/reactivate (no action needed)"
                fi
            fi
        done
    fi
done

write_version "$TARGET_DIR/VERSION" "v0.3.2"

# --- What's new in v0.3.2 ---
print_step "v0.3.2 introduces RULES:START/END markers, independent of the FRAMEWORK markers, covering the Work Rules section."
print_step "Previously the rules section lived outside the FRAMEWORK markers, so upgrades never refreshed it; teammate workstation READMEs also had no rules section at all."
print_step "This upgrade sweeps the top-level README plus lead / flat workstation READMEs, self-healing markers as needed and refreshing the 13-rule section (backed up only when it actually changed)."
print_step "Teammate workstations now use a separate condensed 7-rule TEAMMATE_RULES block (resources/teammate_rules.md): if a workstation already has the block, it's refreshed only when the content actually changed (no backup); workstations spawned before this version have no block yet — this migration leaves them alone, and the block is delivered the next time that teammate is spawned/reactivated (Rule #1: don't modify another agent's workstation files)."
print_step "If the rules section actually changed, the old block is backed up to <file>.rules.bak.<timestamp> for review/rollback."
print_step "The top-level README also gains REFERENCE:START/END markers, covering the Pre-installed Skills / Custom Subagents / Role Archetype / Role Definition Storage / Troubleshooting sections: these were also outside the markers and never refreshed before; they're now overwritten unconditionally on every upgrade (pure framework content, no user customization, no backup)."
print_step "Backward compatible; no manual migration needed."

print_success "v0.3.2 applied"
