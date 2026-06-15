---
name: handoff
description: >
  任务交接：单个 skill 支持交出方（生成交接文档）和接收方（读取交接文档并吸收任务）
  两种模式。开头询问使用者身份，然后进入对应流程。交接文档遵守顶层 meeting_room 的
  frontmatter 约定，新增 kind: HANDOFF 类型。用于 agent 职责变更或重构后的任务迁移
  场景。把任务当成黑箱：本 skill 不关心接收方将如何完成任务。
argument-hint: "[--give | --take]"
disable-model-invocation: true
allowed-tools: Read Write Edit Glob Grep Bash
---

# 任务交接 Handoff（双向单文件 skill）

把一个或多个待完成的任务从 agent A 转移到 agent B。**单一 `/handoff` 命令同时支持交出方和接收方**——开头询问使用者身份，然后进入对应分支。

典型场景：
- **职责变更**：某个 agent 的职责范围变了，手上的任务需要交给其他 agent 继续
- **重构后迁移**：老工作流中的 in-flight 任务需要交到新架构对应的 agent 手上
- **临时回避**：交出方需要长期不在线，把任务暂时托付给他人

> **黑箱原则（贯穿全 skill）**：本 skill 把每个 agent 当成不透明的黑盒。**不关心**接收方会用什么方法完成任务——直接动手、再次转手、组建协作小组、调用某个工具——都是接收方在自己的 session 里自主决定的事，与本 skill 无关。本 skill 的唯一职责是**把任务的完整信息从 A 完整传到 B**。

---

## Step 0: 模式选择

`$ARGUMENTS` 可能包含 `--give` 或 `--take` 作为快捷方式。

- 若包含 `--give` → 直接进入【模式 A：交出方】
- 若包含 `--take` → 直接进入【模式 B：接收方】
- 若都没有 → 向用户提问：

```
请问你是：
  (1) 交出任务的一方 — 你正在把一个或多个任务交给其他 agent
  (2) 接收任务的一方 — 你要读取别人之前写的交接文档并接手任务
```

等用户明确回答后，进入对应模式。**不要猜测**——按守则 #11，模糊就问。

---

# 模式 A：交出方（生成交接文档）

## A1. 身份确认（两级检查）

**先尝试从对话 context 推断**：你的英文角色名（例如 `Secretary`、`SkillSmith`、`Architect`）。如果你清楚自己是谁，直接用，跳到 A2。

**只有 context 无法确定时**才落地检查：
1. Glob `_agent_team_work_zone/*/README.md` 找到所有工位
2. 读取 README 的"身份"章节，对照对话历史找到匹配的工位
3. 若仍无法确定，**立即停止并向用户提问**

记为 `<SELF>`。

## A2. 通过自然语言对话收集任务

向用户询问（或从对话 context 中提取已经知道的信息）：

```
我们要把哪些任务交出去？请告诉我：

1. 一共有几个任务？
2. 每个任务：
   - 目标是什么？（做什么）
   - 为什么存在？（why — 这条最容易丢，必须明确）
   - 当前进度？（已完成 / 卡在哪里 / 未开始）
   - 涉及哪些文件、路径、中间产物？
   - 在 meeting_room 里有没有相关的 OPEN/IN_PROGRESS 文件？
3. 接收方是谁？（对方的英文角色名；如果还不确定，可以写 TBD，之后再更新）
4. 整体交接原因？
   - responsibility_change（职责变更）
   - post_refactor_migration（重构后迁移）
   - other（自由描述）
5. 整体优先级？（HIGH / MEDIUM / LOW）
```

**收集时的关键原则**：
- **why 必问**：每个任务都要问出动机。任务的"做什么"容易写，"为什么"才是交接最容易丢失的部分
- **不要模板化**：复杂任务的细节用自然语言对话收集，不要强求填表格
- **不假设接收方流程**：不要问"接收方将如何做"——那是接收方的事
- **空任务清单友好提示**：如果用户说"其实没什么要交接的"，就告诉他"那不需要 handoff，结束"

## A3. 整理交接文档

按以下 7 个章节组织 markdown 文档：

```markdown
# 任务交接：<SELF> → <接收方 or TBD>

## 1. 交接元数据
- 交出方：<SELF>
- 接收方：<接收方 or TBD>
- 日期：<YYYY-MM-DD HH:MM>
- 原因：<responsibility_change / post_refactor_migration / other>
- 任务数：<N>
- 整体优先级：<HIGH/MEDIUM/LOW>

## 2. 任务清单

### 任务 1：<简短标题>
- **目标**：<做什么>
- **Why**：<为什么这个任务存在 — 初始动机>
- **当前进度**：<已完成 X，卡在 Y，未开始 Z>
- **状态**：<未开始 / 进行中 / 部分完成 / 卡住>
- **相关文件**：
  - `path/to/file1`
  - `path/to/file2`
- **关键决策已做**：<如果有，写在这里；如果没有，写"无">
- **未决问题**：<等待接收方决定的事>

### 任务 2: ...
（同上结构）

## 3. 上下文快照
（任务本身之外，接收方需要知道的环境信息）
- 关键路径：<...>
- 常用命令：<...>
- 依赖与环境约定：<...>
- 外部资源链接：<...>

## 4. 已做的决策
（避免接收方重复讨论已经定过的事）
- 决策 1：<内容> — 原因 <...>
- 决策 2：<...>

## 5. 未决的问题
（等待接收方或用户决定的悬置问题）
- 问题 1：<...>
- 问题 2：<...>

## 6. 建议的下一步（非强制，接收方可自行判断）
- <step 1>
- <step 2>

> **本节是参考，不是命令**。接收方完全可以采用其他路径。

## 7. 相关文件引用
（meeting_room 里的相关 OPEN / IN_PROGRESS 文件路径，方便接收方顺藤摸瓜）
- `_agent_team_work_zone/meeting_room/<file_a>.md` — <一句话说明>
- `_agent_team_work_zone/meeting_room/<file_b>.md` — <一句话说明>
```

如果某些章节没有内容（例如没有"已做的决策"），保留章节标题并写"无"，**不要省略章节**——保持文档结构稳定让接收方知道在找什么。

## A4. 写入 meeting_room

**文件路径**：`_agent_team_work_zone/meeting_room/<SELF>_HANDOFF_<YYYYMMDD>_<HHMM>_<slug>.md`

`<slug>` 是简短描述（用下划线连接，例如 `auth_module_rewrite` 或 `failed_eval_followup`）。

**获取精确时间戳**：用 Bash `date '+%Y%m%d %H%M %Y-%m-%d %H:%M'` 一次拿到文件名用的部分和 frontmatter 用的部分。

**Frontmatter 必填**：

```yaml
---
kind: HANDOFF
status: OPEN
from: <SELF>
to: <接收方英文名 或 TBD>
date: YYYY-MM-DD HH:MM
priority: HIGH | MEDIUM | LOW
handoff_reason: responsibility_change | post_refactor_migration | other
task_count: <N>
---
```

`kind: HANDOFF` 是新增的类型前缀。其他类型 (`TASK`、`ERR`、`STATUS`、`DONE`、`PROJECT_STATUS`) 仍由原有 skill 处理。

## A5. 同步更新交出方的工位文件

**`TODO.md`**：对每个交出去的任务，**不要删除原条目**——在条目末尾追加标记：
```markdown
- [ ] 原任务描述 [HANDED OFF → <接收方 or TBD> at YYYY-MM-DD HH:MM, 详见 meeting_room/<filename>]
```

**`ACTIVE_JOBS.md`**：同样保留原条目，加 `[HANDED OFF → ...]` 标记。如果是长任务（例如 cron trigger），还要在备注中说明接收方是否需要继承运行权。

> **为什么不删除**：保留交出记录是审计痕迹。将来可以追溯到"这个任务在 X 时交给了 Y"。

## A6. 向用户汇报

```
✅ 交接文档已生成：
- 文件：_agent_team_work_zone/meeting_room/<filename>
- 交接 N 个任务给 <接收方>
- 交接原因：<reason>
- 优先级：<priority>

工位文件已同步：
- TODO.md：N 项加 [HANDED OFF] 标记
- ACTIVE_JOBS.md：M 项加 [HANDED OFF] 标记

下一步：
- 等接收方在他/她的 session 中运行 /handoff --take 来吸收任务
- 若 to 字段为 TBD，请尽快指定接收方（编辑 frontmatter 的 to 字段即可）
```

如果 `to` 是 TBD，**额外提醒用户**："交接文档已生成但没有指定接收方。等你确定了接收方，请告诉我，我会更新文件的 `to` 字段。"

---

# 模式 B：接收方（读取交接文档）

## B1. 身份确认（两级检查）

同模式 A 的 A1 —— context 推断优先，落地检查兜底，无法确定立即提问。记为 `<SELF>`。

## B2. 扫描 HANDOFF 文件

```
Glob: _agent_team_work_zone/meeting_room/*_HANDOFF_*.md
```

对每个匹配文件读取 frontmatter，过滤出：
- `kind: HANDOFF`
- `status: OPEN`
- `to: <SELF>`（**单一收件人或列表中包含 `<SELF>`**）

> 如果 `to: TBD`，跳过——TBD 还没分配，不应被任何人误吸收。

按 `date` 字段**升序排序**（最早交接的先处理）。

**如果一份都没有**：
```
没有等待你处理的交接文档。
（搜索范围：_agent_team_work_zone/meeting_room/ 中 to: <SELF> 且 status: OPEN 的 *_HANDOFF_* 文件）
```
然后结束 skill。

## B3. 展示清单让用户选择

```
找到 N 份等待你处理的交接文档（按时间升序）：

1. <filename1>  from: X, date: YYYY-MM-DD HH:MM, task_count: 3, priority: HIGH
   原因：responsibility_change
2. <filename2>  from: Y, date: YYYY-MM-DD HH:MM, task_count: 1, priority: MEDIUM
   原因：post_refactor_migration

是否一次处理全部？还是只处理其中几份？请告知。
```

按用户的选择决定后续要处理哪些文件。

## B4. 逐份读取并吸收

对选中的每份交接文档（按时间顺序），执行 B5 ~ B7。

## B5. 完整读取交接文档

用 Read 读取整份 markdown，**不要只看 frontmatter**。理解：
- 任务清单（每个任务的 why、进度、相关文件）
- 上下文快照（路径、命令、约定）
- 已做的决策（不重复讨论）
- 未决的问题（哪些等你拿主意）
- 建议的下一步（参考，不强制）
- 相关文件引用（顺藤摸瓜的入口）

## B6. 向用户确认接收

```
我准备从交接文档 <filename> 中吸收 N 个任务（来自 <前任>，原交接时间 <date>）：

任务摘要：
1. <任务 1 标题> — why: <一句话动机>
2. <任务 2 标题> — why: <...>
3. ...

确认接手吗？接手后我会：
- 把任务追加到我的 TODO.md（注明来源是 HANDOFF）
- 如有运行中的任务，加到 ACTIVE_JOBS.md
- 把交接文档 status 改为 IN_PROGRESS
```

等用户明确确认。

## B7. 更新自己的工位文件 + 改交接文档 status

**`TODO.md`**：每个吸收的任务追加一条：
```markdown
- [ ] [来自 HANDOFF, from <前任>, date: YYYY-MM-DD] <任务标题> — why: <动机> — 详见 meeting_room/<filename>
```

**`ACTIVE_JOBS.md`**：如果交接的是正在运行的任务（SLURM job、cron trigger 等），追加相关元数据。

**`notes.md`**：仅在交接文档里有**长期复用**价值的信息时（例如关键路径、命令约定）才追加。一次性信息不进 notes（守则 #10）。

**修改交接文档**：将 `status` 从 `OPEN` 改为 `IN_PROGRESS`。按守则 #8，`to` 字段是你（或包含你），有权修改。

## B8. 向用户汇报

```
✅ 已吸收交接文档 <filename>：
- 接手 N 个任务，已追加到 TODO.md
- ACTIVE_JOBS.md 新增 K 个进行中任务
- notes.md 追加 M 条长期参考
- 交接文档 status: OPEN → IN_PROGRESS

我接下来准备做的事（基于交接文档的"建议下一步"+ 我自己的判断）：
- ...
- ...

如果有疑问或要调整优先级，请告诉我。
```

## B9.（可选）任务全部消化后关闭交接文档

当你觉得交接文档里的内容都已经完全吸收（TODO 已经在推进、相关文件就位、关键决策已了解）时，可以：
- 在交接文档末尾追加一段"接收完成备注"（时间 + 接收人 + 摘要）
- 把 `status` 改为 `RESOLVED`

**本 skill 不自动归档**。接收方完成吸收后只需将 `status` 改为 `RESOLVED`；归档由 issuer（`from`）在下次 `/check-inbox` 步骤 9 时执行。

---

## 边界（与其他 skill 的关系）

- **vs `/check-inbox`**：check-inbox 被动扫描所有指向你的消息（TASK / ERR / STATUS 等所有类型）。handoff 是**主动**针对"一份完整的交接清单需要吸收"的专门场景。如果你只是日常处理新任务，用 check-inbox 即可；HANDOFF 文件也会被 check-inbox 扫到，但要逐项吸收交接清单还是用 `/handoff --take` 更顺手。
- **vs `/sync`**：sync 是恢复工作区状态和身份认知（成员变更、消息扫描、任务回顾）。handoff 是转移**具体的待办任务**。两者职能正交。

---

## 注意事项

- **黑箱原则**：本 skill 不假设接收方将如何完成任务，也不在交接文档中嵌入实施细节。"接收方应该这样做"是越界
- **why 必问**：每个任务的"为什么存在"必须明确收集——这是最容易在交接中丢失的部分
- **不自动归档**：本 skill 不归档完成的交接文件；接收方完成后只改 `status: RESOLVED`，归档由 issuer 在下次 `/check-inbox` 时执行
- **TBD 支持**：交出方可以先生成 `to: TBD` 的文档，等用户后续指定接收方再更新 `to` 字段。TBD 文件不会被任何接收方误吸收
- **保守拒绝假冒**：如果交出方声称自己是 X 但身份核对失败 → 拒绝写入文件，按守则 #11 向用户提问
- **空清单**：没有要交接的任务 → 友好告知"不需要 handoff"，不创建空文件
- **不要模板化复杂任务**：本 skill 的大部分逻辑应该是"agent 通过自然语言对话与用户收集信息"——不要强求所有情况都套同一个表格
- **保留审计痕迹**：交出方的 TODO/ACTIVE_JOBS 中的原条目**永远不删除**，只追加 `[HANDED OFF → ...]` 标记
