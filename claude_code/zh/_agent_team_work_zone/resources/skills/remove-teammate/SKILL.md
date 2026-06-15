---
name: remove-teammate
description: >
  让某个 teammate 下岗：优雅完成交接、归档其产出、从 team 中移除。
  Team lead 可自主调用（用户自然语言同意后）。只在 team lead 上下文有效。
disable-model-invocation: false
allowed-tools: Read Write Edit Glob Grep Bash
---

# `/remove-teammate` — 让某个 teammate 下岗

## 身份前置检查

**先从对话 context 推断**：你应该已经知道自己是 team lead。**无法推断时**按 `/evaluate-team` 的检查逻辑。若不是 team lead → 立即停止并警告。

## Phase 1: 确定要移除的 teammate

从用户描述或 `/evaluate-team` 的结果中确定要移除的 teammate 昵称。

向用户确认：

```
你想让 <Teammate 昵称> 下岗吗？

它的近期产出：
- <列出 roundtable 中 from 该 teammate 的文件清单>

它的手头任务：
- <列出 IN_PROGRESS 或 OPEN 且 to 该 teammate 的任务>

移除前，我需要：
1. **要求它做最终 checkpoint**（它自己调 /checkpoint 写 working-context.md 和 completed.md）
2. 把它手头的任务交接给其他 teammate 或放回待分配
3. 把它的产出（DONE 报告、代码等）收尾归档
4. 从 Claude Code agent-team 中正式移除它
5. 更新 TEAMMATE_INFO.json：把它从 active_teammates 移到 offboarded_teammates
6. 更新 team_recipes/ 的最新 recipe，追加 Amendment 记录此次下岗

你确认移除吗？
```

等用户明确同意。

## Phase 1.5: 强制最终 checkpoint（Rule 1 + Rule 13）

**关键：最终 checkpoint 必须由被移除的 teammate 自己完成**（rule #1 低耦合，lead 不能替它写工位文件）。

> **若该 teammate 当前 `status=benched`**（已临时下线、不在线）：跳过下面的 SendMessage——它在 bench 时已做过最终 checkpoint，直接沿用其工位上的 working-context.md，进入 Phase 2。（benched → offboarded 是合法转移。）

通过 SendMessage 给该 teammate：

```
Before shutdown, run /checkpoint to persist your final state. This is your final
checkpoint — after it, I will remove you from the team. Your workstation files
(working-context.md, completed.md, commitments.md) will be preserved at
_agent_team_work_zone/<SELF>_team/teammates/<昵称>/ for audit and potential future
reactivation under a different task.
```

等待 teammate 确认 "Checkpoint written." 再进入 Phase 2。

如果 teammate 因为任何原因（卡死 / session 已死 / 无响应）无法做 final checkpoint：
- 告知用户："<昵称> 无法自行最终 checkpoint（原因：...）。它的 working-context.md 保留上次状态；如需强制 offboard 请明确同意放弃最新工作状态。"
- 等用户决定继续还是先处理 teammate 卡死

## Phase 2: 交接手头任务

### 2a. 识别未完成工作
扫 `_agent_team_work_zone/<SELF>_team/roundtable/` 中：
- `from: <SELF>_team/<teammate>` 且 `status: IN_PROGRESS` 的文件（它自己提交的但未完成）
- `to: <SELF>_team/<teammate>` 且 `status: OPEN` 或 `IN_PROGRESS` 的文件（别人派给它还没做完）

### 2b. 决定去向
对每个未完成项向用户询问：

```
未完成任务交接:

1. <file1.md> (IN_PROGRESS, from: <teammate>)
   进度: <摘要>
   选项:
     (a) 让它先收尾后再下岗
     (b) 强制接管 — 由 lead 或另一 teammate 继续
     (c) 放弃这项工作

2. <file2.md> (OPEN, to: <teammate>)
   选项:
     (a) 重派给另一 teammate (指定谁)
     (b) 放回待分配，记录到 <SELF>_team/TODO.md
     (c) 取消

你的决定？
```

### 2c. 执行交接
按用户决定：
- **重派**：修改目标文件的 `to` 字段
- **放回待分配**：在 `<SELF>_team/TODO.md` 追加一项，并把原文件归档或标为 WITHDRAWN
- **收尾后下岗**：向用户建议先等 teammate 完成再运行 `/remove-teammate`

## Phase 3: 归档该 teammate 的已完成产出

把该 teammate 的 RESOLVED 文件（`from: <teammate>` 且 `to` 指向 lead 或其他已离场 teammate 的）从 roundtable 移到 `<SELF>_team/archive/`：

```bash
mv _agent_team_work_zone/<SELF>_team/roundtable/<file>.md _agent_team_work_zone/<SELF>_team/archive/
```

守则 #8 依然适用：
- `from: <SELF>_team/<teammate>` 的文件 lead 有权归档（因为 teammate 即将下岗，相当于 lead 接管它的发文权）
- `to: ALL` 的文件不归档
- `cc` 中的文件不归档

## Phase 4: 从 agent-team 中正式 remove

产出一段 natural-language remove 指令（Claude Code 内置机制识别）：

```
从当前 <SELF> team 中移除 teammate <昵称>。它的未完成任务已经交接（详见 roundtable），
它的产出已归档到 archive/。请正式 remove 它。
```

## Phase 5: 更新 TEAMMATE_INFO.json

路径：`_agent_team_work_zone/<SELF>_team/TEAMMATE_INFO.json`

把被移除的 teammate 从 `active_teammates` 数组**移除**，并 append 到 `offboarded_teammates` 数组：

```json
{
  "name": "<被移除的昵称>",
  "offboarded_at": "<ISO8601 当前时间>",
  "reason": "<一句话原因：task completed / redundant role / stuck / user decision>"
}
```

同时更新顶层 `updated_at`。

jq 示例（如果可用）：
```bash
name="<昵称>"
reason="<原因>"
ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
jq --arg n "$name" --arg r "$reason" --arg ts "$ts" '
  .offboarded_teammates += [{name: $n, offboarded_at: $ts, reason: $r}] |
  .active_teammates |= map(select(.name != $n)) |
  .updated_at = $ts
' _agent_team_work_zone/<SELF>_team/TEAMMATE_INFO.json > /tmp/info.json && \
mv /tmp/info.json _agent_team_work_zone/<SELF>_team/TEAMMATE_INFO.json
```

**不删除** teammate 的工位目录 `_agent_team_work_zone/<SELF>_team/teammates/<昵称>/`——保留原位作为历史审计（Rule 1 低耦合 + 便于日后如果相同任务重启可参考历史 working-context.md）。

## Phase 6: 更新 team_recipes 的最新 recipe

找到 `<SELF>_team/team_recipes/` 下最新的 recipe，在末尾追加：

```markdown
---

## Amendment — YYYY-MM-DD HH:MM — remove-teammate

### 下岗
- **昵称**: <teammate>
- **原因**: <来自用户或 /evaluate-team 的判断>

### 交接处理
- 未完成任务交接: <摘要>
- 产出归档: N 份 RESOLVED 移到 archive/

### 当前 team 人数: <剩余人数>
```

## Phase 7: 汇报完成

```
✅ <Teammate 昵称> 已下岗

交接:
- <file1.md> → 重派给 <new teammate>
- <file2.md> → 放回 TODO
- ...

归档:
- <N 份文件> → <SELF>_team/archive/

Team 更新:
- 人数: <before> → <after>
- TEAMMATE_INFO.json: active_teammates -1, offboarded_teammates +1
- team_recipes/<latest>.md 已追加 Amendment
- Claude Code agent-team 已正式 remove
- 工位目录保留在 teammates/<昵称>/（审计用，不删除）

当前 team 剩余成员:
- <list>
```

## 注意事项

- **不要丢任务**：未完成工作必须有明确去向（重派 / 放回 / 取消），不能直接消失
- **最终 checkpoint 由 teammate 自己做**（Rule #1 低耦合）：lead 不能替它写工位文件。如果 teammate 已经卡死无法响应，接受放弃最新状态——不要 lead 越俎代庖
- **不删除工位目录**：保留 `teammates/<昵称>/` 作为历史审计 + 潜在的 reactivation 参考
- **守则 #8 适用**：归档 roundtable 文件时按权限过滤，`to: ALL`、`cc` 中的文件绝不归档
- **Amendment 保留历史**：team_recipes 要能反映 team 的演化轨迹（加入、移除）
- **正式 remove 必须通过 Claude Code 机制**：不能只"假装"，要用自然语言 prompt 让 Claude Code 内置机制真的把 teammate 的 session 关掉
- **下岗不等于 fire**：teammate 本来就是一次性协作者，"下岗"是中性的工作流程，不带惩罚含义
