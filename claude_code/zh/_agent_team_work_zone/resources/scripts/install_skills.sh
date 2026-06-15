#!/usr/bin/env bash
#
# install_skills.sh — Copy skills and agents from template resources/ to .claude/
#
# 与旧版（_agent_team_work_zone/scripts/install_skills.sh）的差异：
#   1. 源路径在 resources/skills/ 和 resources/agents/（单一 source of truth）
#   2. **不删除源目录**（旧版 delete-after-install bug 已修复）
#   3. 幂等：再次运行会更新目标，不会报错
#   4. 同时处理 skills 和 agents
#
# 用法:
#   cd /path/to/your/project
#   bash _agent_team_work_zone/resources/scripts/install_skills.sh
#
# 开发环境（在 agent-work-zone 仓库内 dogfood）:
#   cd /path/to/agent-work-zone
#   bash claude_code/zh/_agent_team_work_zone/resources/scripts/install_skills.sh
#
# 通常由 bootstrap.sh 调用，不需要直接运行。
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# scripts 位于 resources 下，所以 template root 是 2 级上
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
    echo "[install_skills] syncing skills → $SKILLS_DST"
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
    echo "[install_skills] syncing agents → $AGENTS_DST"
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
