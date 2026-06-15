---
name: bench-teammate
description: >
  把某个 teammate 临时下线（benched）：让它做最终 checkpoint、关闭其 session 腾出在线名额，
  但**保留全量档案 + 工位 + 文档**，并在 TEAMMATE_INFO.json 里把 status 置为 benched。
  与 /remove-teammate（永久下岗）不同——benched 语义是"还会回来"，日后用
  `/reactivate-team <name>` 单独唤回。Team lead 自主调用（用户同意后）。只在 team lead 上下文有效。
disable-model-invocation: false
allowed-tools: Read Write Edit Glob Grep Bash
---

# `/bench-teammate` — 把某个 teammate 临时下线（benched）

## 何时用

Claude Code 对**同时在线**的 teammate 数量有上限。当某个 teammate **当前阶段用不上**、或你需要**腾出在线名额**给别人时，把它 bench 掉：它不再占用在线名额，但工位、文档、档案全部保留，日后随时单独唤回。

- **bench vs remove**：`/remove-teammate` = 永久下岗（移入 `offboarded_teammates`、精简档案、语义"任务完成不再回来"）；`/bench-teammate` = 临时下线（**留在** `active_teammates`、`status=benched`、全量档案、语义"还会回来"）。
- **唤回是 lead 的常驻判断**（见 README 工作守则）：任何时候（尤其派活 / 开始某任务前）发现需要某个 benched 专长，向用户提议、经同意后用 `/reactivate-team <name>` 唤回。
- **状态表对用户黑箱**：bench / 唤回的状态字段由 lead 维护，用户只在"提议—同意"层面参与。

## 身份前置检查

**先从对话 context 推断**：你应该已经知道自己是 team lead（工位以 `_team` 结尾、含 `roundtable/` 和 `TEAMMATE_INFO.json`）。**无法推断时**按 `/evaluate-team` 的检查逻辑。若不是 team lead → **立即停止**并告知用户本 skill 只能在 team lead 上下文使用。

## Step 1: 确定要 bench 的 teammate + 校验

从用户描述确定昵称 `<name>`。读 `_agent_team_work_zone/<SELF>_team/TEAMMATE_INFO.json`，校验：

- `<name>` 在 `active_teammates` 且 `status ∈ {active, idle}` → 可 bench
- 若 `status` 已是 `benched` → 告知用户"它已是 benched，无需重复"，退出
- 若不在 `active_teammates`（可能已 offboarded）→ 告知用户，退出

向用户确认（并问下线原因，写入 `bench_reason`）：

```
你想把 <name> 临时下线（benched）吗？

它的手头任务：
- <列出 roundtable 中 to: <SELF>_team/<name> 的 OPEN/IN_PROGRESS，以及 from 它的 IN_PROGRESS>

下线时我会：
1. 要求它做**最终 checkpoint**（写 working-context.md 的 Part A 快照 + Part B 工作日志）
2. 关闭它的 session，腾出 1 个在线名额
3. 保留它的工位/文档/档案原封不动
4. TEAMMATE_INFO.json：status → benched，记录 benched_at + 原因（**仍留在 active_teammates**）

它手头未完成的工作会随工位保留，唤回后由它自己接着做；如果**现在就有人等它的产出**，你可能需要先把那几项重派——要我列出来供你决定吗？

下线原因（一句话）？确认下线吗？
```

等用户明确同意 + 给出原因。

> **手头任务**：benched 的前提是"还会回来"，所以未完成工作**默认随工位保留**、不强制交接（唤回后接着做）。仅当确有他人**当下**阻塞在它的产出上时，才按 `/remove-teammate` Phase 2 的方式把那几项重派——否则不动。

## Step 2: 强制最终 checkpoint（Rule 1 + Rule 13）

**最终 checkpoint 必须由该 teammate 自己完成**（rule #1 低耦合，lead 不能替它写工位文件）。分两种情况：

**(A) teammate 当前存活**（本 session ping 有 SendMessage 回执）：通过 SendMessage 要求它先 checkpoint：

```
You are being temporarily benched (not removed). Before I close your session, run
/checkpoint now to persist your final state — Part A snapshot AND a Part B journal
entry capturing recent context and your in-flight work, so the next time you're woken
you can resume cleanly. Your workstation at
_agent_team_work_zone/<SELF>_team/teammates/<name>/ will be fully preserved.
Reply with "Checkpoint written." when done.
```

等它回执 "Checkpoint written." 再进入 Step 3。

**(B) teammate 已死**（session 重启后从未在本 session 唤醒、或卡死无响应）：无法做新 checkpoint → 沿用它磁盘上的上次 checkpoint，直接进入 Step 3（无需关闭 session，因为它本就不在线）。向用户说明"它将以上次 checkpoint 的状态被标记 benched"。

## Step 3: 关闭 session 腾出名额（仅情况 A 需要）

若 teammate 存活，向它发**优雅关闭请求**（shutdown_request），结束它当前的 session、腾出在线名额：

```
Checkpoint received. You are now benched — shutting down your session. You will be
woken later via /reactivate-team if needed. Thank you.
```

> 关闭后它在 runtime 注册里可能留下 ghost 条目——这无害：日后 `/reactivate-team <name>` 唤回时会处理（参见该 skill「调用形态」对 Step 0 的说明：team 已有其他活成员时**不**做 TeamDelete/TeamCreate，直接 spawn）。
>
> **不要**把它从 team 注册里硬删/当永久 remove 处理——bench 只是结束 session，档案与成员身份都保留。

## Step 4: 更新 TEAMMATE_INFO.json

路径：`_agent_team_work_zone/<SELF>_team/TEAMMATE_INFO.json`。把 `<name>` 那条的 `status` 置为 `benched`，写入 `benched_at` + `bench_reason`，**保留在 `active_teammates` 数组、保留全部其它字段**。更新顶层 `updated_at`。

jq 示例（如果可用）：
```bash
name="<name>"
reason="<下线原因>"
ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
info=_agent_team_work_zone/<SELF>_team/TEAMMATE_INFO.json
jq --arg n "$name" --arg r "$reason" --arg ts "$ts" '
  .active_teammates |= map(
    if .name == $n then .status = "benched" | .benched_at = $ts | .bench_reason = $r else . end
  ) | .updated_at = $ts
' "$info" > /tmp/info.json && mv /tmp/info.json "$info"
```

**绝不**删除 / 改动它的工位目录 `teammates/<name>/`（working-context.md、completed.md、commitments.md、README.md、TODO.md 全部原样保留）。

## Step 5: 汇报完成

```
✅ <name> 已临时下线（benched）

- 最终 checkpoint: <已写 / 沿用上次（teammate 已死）>
- Session: <已关闭，腾出 1 个在线名额 / 本就不在线>
- 工位: 全部保留在 teammates/<name>/
- TEAMMATE_INFO.json: status → benched（仍在 active_teammates），原因: <reason>

当前在线 teammate: <剩余 active/idle 列表>
benched（临时下线）: <benched 列表>

需要时用 `/reactivate-team <name>` 单独唤回它。
```

## 注意事项

- **bench 是中性流程**，不带惩罚含义——只是名额管理 + 阶段性休眠。
- **最终 checkpoint 由 teammate 自己做**（Rule #1）：lead 不替写工位文件；teammate 已死则接受沿用上次 checkpoint。
- **工位/档案一律保留**——这正是 bench 与 remove 的核心区别。
- **默认不交接任务**：未完成工作随工位保留，唤回后续做；只有他人当下被阻塞时才重派那几项。
- **不要让用户接触状态字段**：bench / 唤回是 lead 维护的黑箱，用户只在对话层面同意。
- 关联：`/reactivate-team <name>`（唤回）、`/remove-teammate`（永久下岗）、`docs/teammate_info_schema.md`（benched 状态与字段）、Rule 13。
