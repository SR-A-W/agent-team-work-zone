#!/usr/bin/env bash
#
# teammate_idle_checkpoint.sh — TeammateIdle hook（fires in LEAD session）
#
# 新机制（v0.2.3）：working-context.md mtime 闸门 + exit 2 逼 checkpoint。
#
#   teammate 干完一轮、即将 idle → 本 hook 在 lead session 触发，payload 带 teammate_name。
#   定位该 teammate 工位的 working-context.md，按"距上次落盘多久"决策：
#     - 距上次落盘 < N 分钟（默认 15）         → exit 0，放它 idle。
#     - 距上次落盘 ≥ N 分钟                    → stderr 写"先跑 /checkpoint" + exit 2。
#         exit 2 会【阻塞该 teammate 的 idle 并把 stderr 直接喂给它】，逼它在 idle 前多做
#         一轮 = 跑真 /checkpoint。checkpoint 覆盖写 working-context.md → mtime 刷新 →
#         下次 idle 闸门判 fresh → exit 0，循环自然刹住。
#
# 为什么这条路对 in-process teammate 也成立（旧 flag + UserPromptSubmit 链路对它从不工作）：
#   本 hook 全程只在【写侧】(TeammateIdle，payload 带 teammate 身份) 动作；exit 2 的 stderr
#   由 Claude Code 直接投递给【正在 idle 的那个 teammate】，不经过【读侧】(UserPromptSubmit，
#   payload 不带身份、in-process 下 cwd=项目根、根本认不出是谁)。所以彻底绕开了旧链路那个
#   "读侧认不出 in-process teammate"的死结。
#
# 安全铁律：
#   - 绝不输出非法 JSON：TeammateIdle 不支持 hookSpecificOutput/additionalContext（输出会
#     报 "Invalid input"）。本 hook 只用 stderr + 退出码。
#   - 任何不确定（取不到 name / 找不到工位 / stat 失败 / jq 缺失 / 取不到 mtime）→ exit 0
#     静默放行，绝不阻塞 teammate。
#   - 硬安全帽：连续 nudge 上限（防 teammate 持续无视提醒 → mtime 一直旧 → 无限 exit 2 死循环）。
#
# 输入（stdin JSON）：session_id / cwd / teammate_name / team_name / ...
#   （CC ≥2.1.178 起，每个 session 自动建唯一会话级 team，payload 的 team_name 形如
#    "session-<前8位>"，已**不再**对应磁盘工位名 "architect_team"；故工位定址改用
#    "由 teammate_name 派生" 为主路径，详见下方三级定址。）
# 输出：stdout 空；stderr 仅在 nudge 时写；exit 0（放行）或 exit 2（逼 checkpoint）。
# 配置位置：`.claude/settings.json` 的 hooks.TeammateIdle
#
# Rule 13 参考

set -uo pipefail

# ---- 可调参数 ----
CHECKPOINT_INTERVAL_SEC=900   # N = 15 分钟（用户 2026-06-11 定：10 分钟触发过频、费 token；
                              #               15 分钟平衡"意外丢失上限"与 token 开销）
MAX_CONSECUTIVE_NUDGES=3      # 硬安全帽：连续逼 checkpoint 上限，防死循环

payload=$(cat)

# 没 jq 无法解析 payload → 放行（不确定就别阻塞）
command -v jq >/dev/null 2>&1 || exit 0

# Debug：把 payload 写到临时 log（排查 hook schema 时取消注释）
# echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) $payload" >> /tmp/teammate_idle_hook.log

teammate_name=$(echo "$payload" | jq -r '.teammate_name // .teammate // .agent_name // .name // empty' 2>/dev/null)
cwd=$(echo "$payload" | jq -r '.cwd // empty' 2>/dev/null)
[ -z "$cwd" ] && cwd="$PWD"

# 取不到 teammate 身份 → 放行
[ -n "$teammate_name" ] || exit 0

# 定位项目根（含 _agent_team_work_zone/ 的目录）。优先用 CLAUDE_PROJECT_DIR——Claude Code 设定、
# 整个 session 内稳定、不随 cd 漂移（官方文档：cwd 会因 cd 变化，CLAUDE_PROJECT_DIR 不会）。
# 取不到或其下无工位根时，再回退到 cwd 向上 dirname 回溯（cwd 可能是子目录，如 claude_code/）。
# 二者皆失败 → 放行，绝不阻塞。
project_root="${CLAUDE_PROJECT_DIR:-}"
if [ -z "$project_root" ] || [ ! -d "$project_root/_agent_team_work_zone" ]; then
    project_root="$cwd"
    while [ "$project_root" != "/" ] && [ ! -d "$project_root/_agent_team_work_zone" ]; do
        project_root=$(dirname "$project_root")
    done
fi
[ -d "$project_root/_agent_team_work_zone" ] || exit 0

# 定位该 teammate 的工位目录 —— 三级定址（CC ≥2.1.178 适配）：
#   T1（兼容兜底）：payload team_name 给定且其下工位真存在 → 用之。
#       CC ≥2.1.178 的 team_name 是 "session-<id>"、磁盘无此工位 → 落空到 T2；保留 T1 仅为
#       兼容旧版（旧版 team_name="architect_team" 时仍能精确命中）。
#   T2（新版主路径）：由 teammate_name 派生工位名 "${name%%-*}_team"。新命名约定 teammate 名为
#       "<slug>-<role>"，slug = 工位名去 _team、单 token（无连字符）；故 "${name%%-*}" 取回 slug，
#       "${slug}_team" 即其工位。例 "architect-reviewer" → "architect_team"。
#       （旧式无连字符名如 "Fixer"：派生 "Fixer_team" 多半不存在 → 落空到 T3，无害。）
#   T3（旧名兜底）：glob 所有 *_team/ 收集含该 teammate 的工位。
#       命中恰好 1 个 → 用之；命中 0 或 >1 个 → exit 0 不猜（修掉"跨 team 同名 teammate 被
#       字母序 glob 首个命中误判"的老 bug：upgrader 的 reviewer idle 误读 architect 的 reviewer mtime）。
team_name=$(echo "$payload" | jq -r '.team_name // empty' 2>/dev/null)
teammate_ws=""
# T1：payload team_name 精确命中（兼容旧版）
if [ -n "$team_name" ] && [ -d "$project_root/_agent_team_work_zone/${team_name}/teammates/${teammate_name}" ]; then
    teammate_ws="$project_root/_agent_team_work_zone/${team_name}/teammates/${teammate_name}"
fi
# T2：由 name 派生工位（新版主路径）
if [ -z "$teammate_ws" ]; then
    derived_team="${teammate_name%%-*}_team"
    if [ -d "$project_root/_agent_team_work_zone/${derived_team}/teammates/${teammate_name}" ]; then
        teammate_ws="$project_root/_agent_team_work_zone/${derived_team}/teammates/${teammate_name}"
    fi
fi
# T3：glob 兜底，仅当唯一命中才用（>1 歧义 → 不猜）
if [ -z "$teammate_ws" ]; then
    match_count=0
    glob_ws=""
    for team_dir in "$project_root"/_agent_team_work_zone/*_team/; do
        [ -d "$team_dir" ] || continue
        if [ -d "${team_dir}teammates/${teammate_name}" ]; then
            glob_ws="${team_dir}teammates/${teammate_name}"
            match_count=$((match_count + 1))
        fi
    done
    # 唯一命中才采纳；0 或 >1（跨 team 同名歧义）→ 放行不猜
    [ "$match_count" -eq 1 ] && teammate_ws="$glob_ws"
fi
# 找不到工位（或歧义）→ 放行
[ -n "$teammate_ws" ] || exit 0

wc_file="$teammate_ws/working-context.md"
nudge_file="$teammate_ws/.checkpoint_nudge_count"

# ---- 闸门：working-context.md mtime（主时间戳，每次 checkpoint 必被覆盖写）----
# Linux 用 stat -c %Y；BSD/macOS fallback stat -f %m
wc_mtime=""
if [ -f "$wc_file" ]; then
    wc_mtime=$(stat -c %Y "$wc_file" 2>/dev/null || stat -f %m "$wc_file" 2>/dev/null || echo "")
fi
# 取不到 mtime（文件不存在/stat 失败）→ 放行
[ -n "$wc_mtime" ] || exit 0

now_epoch=$(date -u +%s)
age=$((now_epoch - wc_mtime))

if [ "$age" -lt "$CHECKPOINT_INTERVAL_SEC" ]; then
    # fresh：距上次落盘 < N 分钟。放它 idle，并清掉 nudge 计数（循环已刹住）。
    rm -f "$nudge_file" 2>/dev/null || true
    exit 0
fi

# ---- stale：距上次落盘 ≥ N 分钟，需要逼 checkpoint ----

# 硬安全帽：teammate 若持续无视 nudge（收到提醒却不跑 checkpoint，mtime 一直旧），
# 不要无限 exit 2 把它卡死——达到上限就放弃逼迫、放它 idle、重置计数。
nudge_count=0
[ -f "$nudge_file" ] && nudge_count=$(cat "$nudge_file" 2>/dev/null || echo 0)
case "$nudge_count" in (''|*[!0-9]*) nudge_count=0 ;; esac

if [ "$nudge_count" -ge "$MAX_CONSECUTIVE_NUDGES" ]; then
    rm -f "$nudge_file" 2>/dev/null || true
    # echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) give up nudging $teammate_name after $nudge_count tries" >> /tmp/teammate_idle_hook.log
    exit 0
fi

echo $((nudge_count + 1)) > "$nudge_file" 2>/dev/null || true

# exit 2：阻塞该 teammate 的 idle，stderr 直接喂给它，逼它在 idle 前跑 /checkpoint
mins=$((age / 60))
threshold_min=$((CHECKPOINT_INTERVAL_SEC / 60))
echo "[checkpoint 提醒] 你（${teammate_name}）距上次 /checkpoint 落盘已约 ${mins} 分钟（阈值 ${threshold_min} 分钟）。在进入 idle 之前，请立刻运行 /checkpoint，把当前工作状态写入 working-context.md，以防会话意外中断（SSH 断 / 崩溃）导致最新工作丢失。这是 Rule 13 规定的义务。完成 checkpoint 后即可正常 idle，不会再被重复提醒。" >&2
exit 2
