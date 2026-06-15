#!/usr/bin/env bash
#
# install_skills.sh — Copy skills and agents from template resources/ to .claude/
#
# Differences from the old version (_agent_team_work_zone/scripts/install_skills.sh):
#   1. Source paths are at resources/skills/ and resources/agents/ (single source of truth)
#   2. **Does not delete source directories** (the old version's delete-after-install bug is fixed)
#   3. Idempotent: running again updates the target without errors
#   4. Handles skills and agents together
#
# Usage:
#   cd /path/to/your/project
#   bash _agent_team_work_zone/resources/scripts/install_skills.sh
#
# Development environment (dogfooding inside the agent-work-zone repo):
#   cd /path/to/agent-work-zone
#   bash claude_code/en/_agent_team_work_zone/resources/scripts/install_skills.sh
#
# Normally invoked by bootstrap.sh; no need to run directly.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# scripts lives under resources, so template root is 2 levels up
TEMPLATE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"

SKILLS_SRC="$TEMPLATE_ROOT/resources/skills"
AGENTS_SRC="$TEMPLATE_ROOT/resources/agents"
SKILLS_DST="$PROJECT_ROOT/.claude/skills"
AGENTS_DST="$PROJECT_ROOT/.claude/agents"

echo "[install_skills] template: $TEMPLATE_ROOT"
echo "[install_skills] project:  $PROJECT_ROOT"

# --- Skills ---
if [ -d "$SKILLS_SRC" ]; then
    mkdir -p "$SKILLS_DST"
    echo "[install_skills] syncing skills -> $SKILLS_DST"
    skill_count=0
    for skill_dir in "$SKILLS_SRC"/*/; do
        [ -d "$skill_dir" ] || continue
        skill_name="$(basename "$skill_dir")"
        target="$SKILLS_DST/$skill_name"

        # Remove-then-copy for idempotency (handles file deletions inside skill dir)
        rm -rf "$target"
        cp -r "$skill_dir" "$target"
        echo "  ✓ $skill_name"
        skill_count=$((skill_count + 1))
    done
    echo "[install_skills] $skill_count skill(s) synced"
else
    echo "[install_skills] ⚠ skills source not found at $SKILLS_SRC"
fi

echo ""

# --- Agents ---
if [ -d "$AGENTS_SRC" ]; then
    mkdir -p "$AGENTS_DST"
    echo "[install_skills] syncing agents -> $AGENTS_DST"
    agent_count=0
    for agent_file in "$AGENTS_SRC"/*.md; do
        [ -f "$agent_file" ] || continue
        fname="$(basename "$agent_file")"
        target="$AGENTS_DST/$fname"
        cp "$agent_file" "$target"
        echo "  ✓ $fname"
        agent_count=$((agent_count + 1))
    done
    echo "[install_skills] $agent_count agent(s) synced"
else
    echo "[install_skills] ⚠ agents source not found at $AGENTS_SRC"
fi

echo "[install_skills] done (sources preserved; do not edit .claude/ directly)"
