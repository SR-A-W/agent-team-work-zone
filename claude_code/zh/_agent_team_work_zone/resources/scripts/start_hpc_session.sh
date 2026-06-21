#!/usr/bin/env bash
#
# start_hpc_session.sh — HPC 上一键启动 tmux + claude
#
# 在 HPC / Linux 服务器上为 agent-teams 提供"SSH 断了不死"的会话基础。
# 必须在 lead 的 claude CLI 启动**之前**先建好 tmux session，
# 否则 teammateMode: "tmux" 会 silently fallback 到 in-process，
# tracker 等 teammate 无法在 SSH 断开时存活。
#
# 顺序：tmux 安装检查 → $TMUX 环境检查 → 条件性 new-session → 提示 attach
#
# 用法:
#   bash _agent_team_work_zone/resources/scripts/start_hpc_session.sh
#
#   # 自定义 session 名:
#   SESSION_NAME=my_session bash _agent_team_work_zone/resources/scripts/start_hpc_session.sh
#
# 开发环境（在 agent-team-work-zone 仓库内 dogfood）:
#   bash claude_code/zh/_agent_team_work_zone/resources/scripts/start_hpc_session.sh
#

set -euo pipefail

SESSION_NAME="${SESSION_NAME:-claude_hpc}"

echo "=================================================="
echo "  start_hpc_session — tmux + claude bootstrap"
echo "=================================================="
echo "Target tmux session: $SESSION_NAME"
echo ""

# --- 1. tmux 安装检查 ---
if ! command -v tmux >/dev/null 2>&1; then
    echo "✗ tmux not found on PATH."
    echo ""
    echo "  Install tmux (≥ 3.2 推荐):"
    echo "    Ubuntu / Debian:  sudo apt install tmux"
    echo "    RHEL / CentOS:    sudo yum install tmux"
    echo "    Fedora:           sudo dnf install tmux"
    echo "    macOS:            brew install tmux  (但 macOS 推荐用 Desktop Scheduled Tasks 而非本脚本)"
    echo ""
    echo "  没有 sudo 权限的 HPC 用户可考虑 conda: conda install -c conda-forge tmux"
    exit 1
fi

TMUX_VERSION="$(tmux -V | awk '{print $2}')"
echo "✓ tmux $TMUX_VERSION"

# --- 2. 已经在 tmux 内 → 直接 launch claude ---
if [ -n "${TMUX:-}" ]; then
    echo "✓ already inside a tmux session (\$TMUX is set)"
    echo "  → 直接在当前 pane 启动 claude"
    echo ""
    exec claude
fi

# --- 3. 不在 tmux 内 → 创建 detached session 并启动 claude ---

if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo "ℹ tmux session '$SESSION_NAME' 已经存在"
    echo "  Attach with:   tmux attach -t $SESSION_NAME"
    echo ""
    echo "  如果你想要全新 session，先停掉:  tmux kill-session -t $SESSION_NAME"
    exit 0
fi

tmux new-session -d -s "$SESSION_NAME"
tmux send-keys -t "$SESSION_NAME" 'claude' Enter

echo "✓ 已创建 tmux session '$SESSION_NAME' 并在其中启动 claude"
echo ""
echo "下一步:"
echo "  1. Attach 进入 session:        tmux attach -t $SESSION_NAME"
echo "  2. 在 claude 里 /onboard 等"
echo "  3. 离开但保持运行 (detach):    Ctrl-b d"
echo "  4. SSH 断开后重连恢复:         tmux attach -t $SESSION_NAME"
echo ""
echo "提醒: 确保 ~/.claude/settings.json 里有 \"teammateMode\": \"tmux\"（或 \"auto\"）。"
echo "      详见 docs/user_manual.md 的「HPC 部署指南」段。"
