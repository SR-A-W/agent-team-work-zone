---
name: sync
description: >
  同步工作区变更并恢复上下文。扫描项目组成员变动、会议室新消息、部门结构更新，
  识别需要调整的内容并生成行动清单。Team lead 会额外扫自己部门的 roundtable。
  也用于上下文压缩后的角色恢复。
argument-hint: "[--recover]"
disable-model-invocation: true
allowed-tools: Read Write Edit Glob Grep Bash
---

# Sync — 工作区同步与上下文恢复

本 skill 帮助你快速同步工作区的所有变更，并在需要时恢复角色认知。

适用场景：
- 项目组来了新成员，汇报关系或协作对象变了
- 离开一段时间后回来，需要了解发生了什么
- 上下文被压缩，需要恢复身份和工作状态
- 定期同步，确保自己的信息是最新的

---

## 执行流程

### Phase 0: 身份检查（两级）

**先尝试从对话 context 推断**：如果你在当前对话中已经清楚自己的角色、工位、职责（例如刚入职、系统提示里有标注、最近读过自己的 README），直接使用该信息，**跳到 Phase 1**。

**只有在 context 中无法确定自己身份时**，才进入**恢复模式**：

1. 用 `Glob` 扫描 `_agent_team_work_zone/*/README.md` 和 `_agent_team_work_zone/*_team/README.md`，找到所有工位
2. 逐个读取 README 的"身份"章节，对照对话历史中的线索，找到属于当前对话的工位
3. 读取该工位的 `README.md` — 恢复角色定义、职责范围、13 条工作守则
4. 读取该工位的 `notes.md` — 恢复积累的工作知识
5. 向用户确认："我是 <角色名>，工位在 `<目录>`，模式：<flat/team lead>，对吗？"

### Phase 1: 识别自己的工位模式

基于 Phase 0 的结果，明确：
- `<SELF>` — 自己的英文角色名
- `<workstation>` — 工位目录路径
- `<mode>` — `flat` 或 `team_lead`（通过目录是否以 `_team` 结尾 + 是否存在 `roundtable/` 子目录判断）

后续步骤会根据 mode 分叉。

### Phase 2: 扫描项目组变更

读取 `_agent_team_work_zone/README.md` 中的**项目组成员表格**。

对比你已知的成员列表（从 notes.md 或记忆中），识别：
- **新加入的成员**：谁是新来的？角色、工位模式（flat / team）、职责？
- **离开的成员**：之前存在但现在不在表格中的
- **角色变更**：成员的职责或模式发生了变化（例如某个扁平工位被 `/promote-to-team` 升级了）

输出变更摘要。

### Phase 3: 扫描部门结构（仅 team lead）

如果你是 **team lead**：
- **读 `TEAMMATE_INFO.json`**（权威的当前 roster 源）
  - 文件不存在 → team 从未 spawn 过 teammate，忽略
  - `active_teammates` 非空 → 记录下每个 teammate 的 `name` / `status` / `last_checkpoint_at`
- **检测是否需要 reactivate**：Claude Code 不跨 session 自动 respawn teammate。如果 `active_teammates` 里任何条目 `status=active` 或 `status=idle`，**本 session 启动时这些 teammate 并不在**（除非 `/reactivate-team` 刚跑过）。`status=benched` 的临时下线成员**不计入**需要 reactivate——它们本就有意离线，由 lead 按需用 `/reactivate-team <name>` 单独唤回
  - 如果 `SessionStart` hook 已经通过 `additionalContext` 提醒过你（看 session 开头的 system notice），无需重复判断
  - 否则在后续 Phase 6 的行动清单里加一条：**运行 `/reactivate-team` 恢复 N 个 teammate**
- **检测 stale teammate**：若某 teammate 的 `last_checkpoint_at` 距今 > 24h，标记为"checkpoint 过期"——spawn 记录还在但可能已经失能
- 检查 `team_recipes/` 中是否有最近的 team 组建记录（历史参考）
- 检查是否有待 issuer 归档的 RESOLVED roundtable 文件（`from: <SELF>` 且 status: RESOLVED 的，提示在下次 `/check-inbox` 步骤 9 中处理）

如果你是 **扁平工位**：跳过此步骤。

### Phase 4: 扫描会议室和 Roundtable

**所有 agent 都要扫**：读取 `_agent_team_work_zone/meeting_room/` 中的所有文件（排除 README.md）。

**如果你是 team lead，还要扫**：`_agent_team_work_zone/<your_team>/roundtable/` 中的所有文件。

**与我相关的消息**：
- `to` 字段包含我的角色名 → 需要我处理的任务
- `cc` 字段包含我的角色名 → 需要我知晓的信息（只读，不能改 status、不能归档）
- `to: ALL` → 全局公告

**按优先级排序**：HIGH → MEDIUM → LOW
**按状态分组**：OPEN（需要行动）→ IN_PROGRESS（跟进中）

对 team lead，分开展示 `[TOP]`（顶层 meeting_room）和 `[TEAM]`（自己的 roundtable）的消息。

输出待处理消息清单。

### Phase 5: 检查自身任务状态

读取我工位下的任务跟踪文件：
- `TODO.md` — 有哪些待办？有没有过期或需要更新的？
- `ACTIVE_JOBS.md` — 有哪些任务在跑？状态是否需要更新？**注意**：如果你是 team lead 且之前启动过 tracker cron trigger，这里也会列出
- `COMPLETED_JOBS.md` — 最近完成了什么？

输出任务状态摘要。

### Phase 6: 生成行动清单

基于以上所有扫描结果，生成一份**具体的行动清单**：

```markdown
## 需要执行的操作

### 立即行动
- [ ] 回复 meeting_room 中的 [文件名] (status: OPEN, to: 我)
- [ ] 处理 roundtable 中 teammate 的进度汇报 (仅 team lead)
- [ ] ...

### 建议操作
- [ ] 更新 notes.md，记录新成员 XXX 的角色
- [ ] 审阅新 teammate 定义（仅 team lead）
- [ ] ...

### 仅知晓
- 新成员 ZZZ 加入了项目组，负责 [职责]（与我无直接关联）
- [cc] 某某消息抄送到我，只读不改
```

### Phase 7: 执行确认

将行动清单展示给用户，**不要自动执行**。等待用户确认后再逐项执行。

对于"更新自己的文件"类操作，告知用户具体要改什么。

---

## 输出格式

```markdown
# Sync Report — <角色名> — YYYY-MM-DD HH:MM

## 身份状态
✓ 角色: <名称> | 工位: <目录> | 模式: <flat/team_lead> | 恢复方式: <context/file>

## 项目组变更
- 新成员: N 个（列表）
- 离开: N 个（列表）
- 模式变更: N 个（例如 Architect 被 promote 为 team lead）

## Team 状态（仅 team lead）
- TEAMMATE_INFO.json: active_teammates=N, offboarded_teammates=M
- 需要 reactivate: <是/否> (理由: <session 启动后 teammate 未自动 respawn>)
- Checkpoint 过期 (>24h): <列出 teammate 名和时间> 或 "无"
- 最近 team_recipes: <文件名>, <文件名>
- 待 issuer 归档的 roundtable RESOLVED 文件 (from: <SELF>): N 个

## 待处理消息（N 条）
### [TOP] 顶层 meeting_room
#### OPEN（需要行动）
- <文件名> from: X | priority: HIGH | 摘要
### [TEAM] <your_team>/roundtable/（仅 team lead）
#### OPEN
- <文件名> from: teammate_X | kind: TASK | 摘要
### 仅知晓（CC / ALL）
- <文件名> from: Y | 摘要

## 任务状态
- 待办: N 项
- 进行中: N 项（含 N 个 tracker cron trigger）
- 最近完成: N 项

## 行动清单
### 立即行动
- [ ] ...
### 建议操作
- [ ] ...
```

## 注意事项

- **默认零文件 I/O**：Phase 0 先尝试 context 推断，失败才读文件
- **cc 字段**：出现在 cc 中的文件只读，不要尝试修改 status 或归档（守则 #8）
- **team lead 多扫一步**：别忘了扫自己的 roundtable
- **不自动执行行动**：清单只展示，等用户确认
