#!/usr/bin/env bash
#
# check_pending_checkpoint.sh — RETIRED (v0.2.3)
#
# Former purpose: UserPromptSubmit hook that read a .checkpoint_pending flag in the
#   teammate's workstation and, via additionalContext, reminded that teammate to run
#   /checkpoint.
#
# Why retired (the read/write asymmetry dead end): this "read side" chain never worked
#   for in-process teammates — the UserPromptSubmit payload carries no teammate identity;
#   in-process the teammate shares the lead's process and cwd = project root, so it cannot
#   tell whether the current turn is the lead or which teammate.
#
# As of v0.2.3, automatic checkpointing is done single-sidedly by teammate_idle_checkpoint.sh:
#   on the identity-bearing WRITE side (TeammateIdle) it uses a working-context.md mtime
#   gate + exit 2, feeding the reminder's stderr straight to the idling teammate — never
#   touching this identity-blind READ side. This consumer is therefore no longer needed.
#
# This file is kept as a HARMLESS no-op (immediate exit 0): if some downstream
#   .claude/settings.json still carries the old UserPromptSubmit hook (bootstrap's
#   deep-merge will NOT delete a key that's no longer in the template — the migration
#   must del it explicitly), it just exits at once, never blocks, never injects any
#   identity. settings_hooks_template.json has dropped the UserPromptSubmit entry; the
#   v0.2.2→v0.2.3 migration explicitly runs del(.hooks.UserPromptSubmit).

exit 0
