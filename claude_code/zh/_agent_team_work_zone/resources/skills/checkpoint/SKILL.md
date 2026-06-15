---
name: checkpoint
description: >
  Teammate 把当前工作状态写到自己工位的 working-context.md：Part A 当前态快照（覆写）
  + Part B 工作日志（追加，含近期对话与关键往来原文），并按需追加 completed.md。
  由 TeammateIdle hook（working-context.md mtime 闸门 + exit 2 提醒）自动触发，
  或 lead 明确要求，或手动调用。**不是 /compact**——不破坏当前 context。
  Rule 13 规定 teammate 有义务定期调用本 skill。
disable-model-invocation: false
allowed-tools: Read Write Edit Glob Bash
---

<!--
[KEEP IN SYNC WITH /reactivate-team]
working-context.md 现为两段式：Part A = 下面的 9 节当前态快照（覆写）；
Part B = 追加式工作日志（近期对话 + 关键往来原文 + 最近 3-4 轮逐字）。
Part A 的任何 section 名称/编号/语义改动，以及 Part B 的存在与读取方式，
都必须同步更新 resources/skills/reactivate-team/SKILL.md——它是对面的读者，
spawn 时引导新 teammate 读这两段恢复状态。
-->

# Checkpoint — Externalize Working Context

## Critical Constraints

- **绝对不要调 `/compact`** 或任何会修改当前 context window 的命令。本 skill 是**非破坏性**的——只从 live context 读取信息后写入 `working-context.md`。当前 session 的 context 必须保持完整。
- **working-context.md 是两段式**：**Part A — 当前态快照**（9 节，**每次覆写重生**，可借此纠错）+ **Part B — 工作日志**（append-only，**每次追加一条**带时间戳条目，形成连续 work history）。
- **必须先 Read 现有的 `working-context.md` 再写**（与旧版相反）：Part B 是追加，你要读到已有日志末尾才能在其后 append；Part A 仍从当前对话状态重新生成、整段覆写。**不要重写或删除 Part B 的历史条目**——纠错靠追加新条目说明，或仅在明显写错时覆写那一条。**唯一例外**：写新条目时把**上一条**的"最近 3-4 轮逐字原文"降级为纪要（见 Step 3B 增长治理）。首次写新格式时：把既有的 9 节包进 Part A、新建空 Part B 开始追加。
- 写入路径是 `_agent_team_work_zone/<team_name>/teammates/<self_name>/working-context.md`。从对话 context 里知道自己的 team_name 和 name（spawn prompt 里有，不依赖环境变量）。

## 身份前置检查

在开始前，确认你是 teammate（不是 lead）：

- 你的工位应该在 `_agent_team_work_zone/<team_name>/teammates/<self_name>/`（teammates 子目录下）
- 如果你是 team lead（工位直接在 `_agent_team_work_zone/<name>_team/`），**本 skill 不适用**——lead 不用 /checkpoint，lead 用 TEAMMATE_INFO.json 跟踪团队状态

## 流程

### Step 0: 先读现有 working-context.md

在分析与写入**之前**，先 Read 现有 `working-context.md`（若存在），定位 Part B 工作日志的末尾，并看清上一条的"最近 3-4 轮逐字原文"在哪（本次要把它降级为纪要）。文件不存在或只有旧版 9 节（无 Part B）→ 视为首次写新格式：本次把 9 节内容收进 Part A、新建空 Part B。

### Step 1: Silent 分析

在写文件**之前**，先静默执行以下分析（不要 output 给用户）：

1. **时序扫描**：从上次 checkpoint（或从 spawn，如果是第一次）至今的对话。对每个有意义的事件识别：
   - 正在做的任务
   - 做出的决策及其理由
   - 修改的文件（完整路径 + 改动性质）
   - 遇到的错误及解决方式
   - lead 或 peer teammate 明确给的、你要继续遵守的指令
   - 你对别人做出的承诺
2. **为 Part B 工作日志另外提取**（新增，不要省）：
   - **近期对话纪要**：上次 checkpoint 至今，与 lead / peer / 用户的往来要点（谁说了什么、达成什么）
   - **关键往来原文**：重要决策 / 指令 / 需求处，圈定要**逐字引用**的原话
   - **最近 3-4 轮对话**：锁定最近 3（或 4）轮 lead↔你、用户↔你的对话，**准备原封不动**贴进本次日志条目
3. **区分"持久知识" vs "临时噪音"**：此区分**只作用于 Part A 快照**（保持精炼，丢掉"收到/谢谢"这类同步噪音）；**Part B 工作日志反而要保留近期对话**——别把它当噪音删掉。
4. 如果 Part A 某一节没有内容，写"无"（或英文 "None"）——**不要编内容填空**。

### Step 2: Customization hook（读自己的 README.md）

如果 `_agent_team_work_zone/<team_name>/teammates/<self_name>/README.md` 里有 `## Checkpoint Instructions` 段，读取并作为侧重强调应用到本次 checkpoint。例如 backend teammate 的 README 可能写："Always emphasize API contract changes in section 5."

如果没这个段，按默认结构走。

### Step 3A: 写 / 覆写 Part A — 当前态快照

文件路径：`_agent_team_work_zone/<team_name>/teammates/<self_name>/working-context.md`

**整个文件骨架**（Part A 覆写、Part B 追加）：

```markdown
# Working Context — <your agent name>
_Last updated: <ISO 8601 timestamp>_

## Part A — Current-State Snapshot（覆写式，每次重生，可纠错）
_Checkpoint trigger: task_completed | idle | manual | lead_request_

### 1. Current Objective
一句话描述你现在想做成的事。任务间隙写 "awaiting next assignment"。

### 2. Active Task
- Task ID 和 subject（来自 team 的共享 task list 或 roundtable）
- Acceptance criteria（你理解的）
- 你在本任务内的当前步骤

### 3. Completed Since Last Checkpoint
每个已完成单元：
- 做了什么（一行）
- 触及的文件（完整路径）
- 关键决策（一行，仅非显然的）

### 4. In-Flight Work
已开始但未完成的任何事。每项：
- 开始了什么
- 为什么没完成（blocked / paused / mid-implementation）
- 下一个 spawn 的你**接下来该做的具体动作**

### 5. Decisions and Rationale
本 session 做出的架构或非显然决策。一行一条：
- 决策: ... | 原因: ... | 考虑过的替代方案: ...

### 6. Open Questions and Blockers
你不知道但需要知道的事，或阻塞进度的事。

### 7. Commitments to Others
你对 lead 或 peer teammate 的承诺，下一个 spawn 的你**必须兑现**：
- To {who}: I will {what} by {when, if applicable}.

### 8. Critical File References
下一个 spawn 的你**必须**读的文件，以理解当前状态。只列路径：
- path/to/file.ext
- ...

### 9. Cross-Session Notes
不适合放前面任何一节、但未来的你必须知道的事。**节制使用**（不要什么都往这里塞）。

## Part B — Work Journal（追加式，append-only，形成 work history）
<!-- 每次 checkpoint 在本段末尾 append 一条；历史条目除"逐字降级"外不删改。 -->

### <ISO 8601 timestamp> — <一句话主题>
- **发生了什么**：本段时间窗内做的事（提炼，带文件完整路径）
- **近期对话纪要**：与 lead / peer / 用户的近期往来要点（谁说了什么、达成什么）
- **关键往来原文**：重要决策 / 指令 / 需求处，逐字引用原话（用 `>` 引用块）
- **最近 3-4 轮对话（逐字原文）**：把最近 3（或 4）轮 lead↔你、用户↔你的对话原封不动贴在此条末尾
```

**Part A 规则**：9 节结构 / 编号 / 语义**固定不变**，**每次整段覆写重生**——它永远反映"此刻的当前态"。某节无内容写"无"。

### Step 3B: 追加 Part B — 工作日志一条

在 Part B 末尾 **append 一条**新的带时间戳条目，按模板 4 个要点写（**发生了什么 / 近期对话纪要 / 关键往来原文 / 最近 3-4 轮逐字原文**）。

**增长治理（重要）**：逐字原文只为**最新这一条**保留。写本条时，**把上一条**里的"最近 3-4 轮对话（逐字原文）"**降级为纪要**（删掉逐字、留一句要点）——这是对历史条目的唯一允许改动。这样 verbatim 体量恒定为最近 3-4 轮、日志整体线性可控；很老的条目可在需要时进一步压缩（可选）。

若本次确无新的对话 / 进展（极少见），可追加一条极简条目注明"无实质进展"，或仅刷新 Part A 跳过 Part B。

### Step 4: 附加写 `completed.md`（仅当 trigger 是 task_completed 时）

如果本次 checkpoint 是因为你**刚完成一个任务**（trigger=`task_completed`），在 `_agent_team_work_zone/<team_name>/teammates/<self_name>/completed.md` 末尾 **append** 一行：

```
- <ISO date> | T<task-id> | <一行摘要> | files: <逗号分隔路径>
```

`completed.md` 是 **append-only 日志**，永远不覆盖之前的条目。

### Step 5: 更新 TEAMMATE_INFO.json 的 last_checkpoint_at

用 jq（如果可用）或手动编辑 JSON 方式，更新 `_agent_team_work_zone/<team_name>/TEAMMATE_INFO.json` 的 `active_teammates` 数组里你那一条的 `last_checkpoint_at` 字段为当前时间戳。

**只改自己那一条**——不要动别人的或 team lead 的结构字段。

示例（如果 jq 可用）：
```bash
jq --arg name "<self_name>" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   '.active_teammates |= map(if .name == $name then .last_checkpoint_at = $ts else . end) | .updated_at = $ts' \
   _agent_team_work_zone/<team>/TEAMMATE_INFO.json > /tmp/teammate_info.json && \
   mv /tmp/teammate_info.json _agent_team_work_zone/<team>/TEAMMATE_INFO.json
```

> **关于自动提醒的刹车（无需你手动操作）**：本次 checkpoint 写 `working-context.md`
> 会刷新它的 mtime。`teammate_idle_checkpoint.sh` 的闸门就是看这个 mtime——落盘后它判为
> fresh，下次 idle 不会再提醒你。所以你**不需要**清任何 flag，写完文件即自动止住提醒。
> （v0.2.3 前的 `.checkpoint_pending` flag 机制已退役。）

### Step 6: 确认

向 lead / user 输出**一行**确认：

```
Checkpoint written at <path>. Trigger: <task_completed|idle|manual|lead_request>.
```

**不要**把 snapshot 内容回读给用户——他们可以自己读文件。

## 各段该放 / 不该放什么

**Part A 快照**（保持精炼）：
- **不要**粘贴大段代码——用文件路径引用。
- **不要**包含逐字对话文本——提炼成事实。
- **不要**包含 lead 给过的、已完全完成且无后续影响的指令。
- **不要**包含同步消息 "ack" / "thanks" / "started" / "done — moving on"。

**Part B 工作日志**（要充实、可纠错地保留过程，向 `/compact` 看齐）：
- **应当**在关键决策 / 指令 / 需求处**逐字引用**原话，并把**最近 3-4 轮对话原封不动**保留——这正是 Part B 的价值。
- 但仍**不要**粘贴大段代码（用路径引用）；逐字原文只留"最近 3-4 轮"，更早的降级为纪要。
- "ack" / "thanks" 这类纯同步噪音不必逐字，并入纪要一句带过即可。

## Failure Handling

如果写入失败（磁盘满、权限拒绝等），把错误记一行到你的 output 然后**继续之前的任务**。不要无限重试。不要因本 skill 而阻塞。你的主任务优先。

## 为什么有这个 skill

Rule 13 规定了 teammate 的 checkpoint 义务。本 skill 是实现这个义务的工具。它写出来的 `working-context.md` 是**给未来 spawn 的你**的交接文档——下一次 `/reactivate-team` 会让一个新 teammate（同样的 name）读这份文件接手你的工作：Part A 告诉它"当前态"，Part B 告诉它"近期发生了什么、原话是什么"。

写得不好 → 下次的你恢复不了状态 → team 协作断裂。

参考：
- `docs/teammate_info_schema.md` — TEAMMATE_INFO.json 结构
- `resources/skills/reactivate-team/SKILL.md` — 对面的读者（必须和本 skill 的 Part A 9 节结构 + Part B 日志保持同步）
- Rule 13 in `../../README.md`

## Customization hook 示例

Teammate 的 README.md 可能写：

```markdown
## Checkpoint Instructions
Always emphasize API contract changes in section 5.
Pay special attention to database migration state in section 4.
```

遇到这种 README，生成 checkpoint 时**提升**这些维度的关注度——但**不改变** Part A 的 9 节结构或顺序、也不改变 Part B 的追加规则。
