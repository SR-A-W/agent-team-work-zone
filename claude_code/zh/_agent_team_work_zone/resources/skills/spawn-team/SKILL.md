---
name: spawn-team
description: >
  Team lead 组建 Claude Code agent team 的结构化流程。6 阶段：任务分解 → 阵容提案
  (从 role_archetypes 选) → plan-mode gating → 对抗性检查 → 用户确认 → 用 Agent
  工具（携带 team_name + name）逐一 spawn 每个 teammate + 保存 team_recipe。Phase 5
  用户确认后直接 spawn，不再额外确认。Agent 可自主调用；若当前是扁平工位，会先引导
  /promote-to-team。
disable-model-invocation: false
allowed-tools: Read Write Edit Glob Grep Agent
mode: interactive
---

# `/spawn-team` — 结构化组建 Agent Team

本 skill 协助 **team lead** 把复杂任务拆解为 team 阵容，然后用 **Agent 工具**（携带 `team_name` + `name` 参数）逐一 spawn 每个 teammate。

> ⚠️ **创建 teammate 与创建 subagent 的区别**：调用 Agent 工具时**必须同时传 `team_name` 和 `name` 参数**，才能创建真正的 teammate（加入 Claude Code team、可互发消息）。缺少这两个参数就只是普通 subagent，无法参与 team 协作。

> **mode 字段**：当前只支持 `interactive`。未来会加 `autonomous` 模式配合 `/loop` 实现端到端自动化（详见 `docs/roadmap/autonomous_team_mode.md`），届时由更高阶模型驱动。

---

## 身份前置检查

**先从对话 context 推断**：如果你已经清楚自己是 team lead 还是扁平工位，直接使用该信息。

**无法推断时**才落地检查：
1. 定位当前对话对应的工位目录
2. 检查目录名是否以 `_team` 结尾 **AND** 存在 `roundtable/` 子目录

### 当前是扁平工位
**不直接执行 spawn-team 流程**，而是：
1. 向用户说明："我当前是扁平工位，需要先升级为 team lead 才能组建 team"
2. 询问用户："我建议运行 `/promote-to-team` 先升级，然后我们再回来 `/spawn-team`。你同意吗？"
3. 等待用户自然语言同意后，agent 自主调用 `/promote-to-team`
4. 升级完成后，回到本流程的 Phase 1

### 当前是 team lead
直接进入 Phase 1。

---

## Phase 1: 任务上下文收集

从对话 context 中提取用户给的任务描述。如果信息不完整，向用户补问：

- **目标**：这次任务要达成什么？成功标准是什么？
- **输入**：有哪些现成的文件/数据/代码/前期成果可以用？
- **输出**：最终产物是什么形式？写到哪里？
- **时间**：有 deadline 吗？是一次性任务还是长跑？
- **约束**：什么东西不能动？什么规则必须遵守？
- **风险**：你最担心哪个环节会翻车？

把回答整理成一个结构化任务描述，作为 Phase 2 的输入。

## Phase 2: 任务分解

将任务拆分成**可并行或有先后的子工作项**。对每个子项标注：

- **类型**：写代码 / 写配置 / 环境配置 / 容器构建 / 分析 / 调研 / 评审 / 对抗性质疑 / 结果汇总
- **依赖**：依赖哪些其他子项先完成
- **并行性**：和哪些子项可以同时跑
- **预估 context 消耗**（lead 的判断）：多 / 中 / 少

**关键原则**（rule 12）：lead 自己不做动手工作。所有动手的子项都要交给 teammate。

## Phase 3: 阵容提案

查阅以下资源：
- **通用 subagent**（`resources/agents/`）：tracker、investigator、reviewer、devil-advocate、git-repo-manager
- **角色原型**（`resources/role_archetypes/`）：coding (3) + config (2) + infra (2) + analysis (2)
- **本 team 已有的自定义 teammate**（`<SELF>_team/teammates/*.md`）：Tier 2 存档

根据 Phase 2 的分解结果，**组成 3~5 人的 team**（**最多 5 人**——更多会导致协调成本暴涨；如果必须超过 5，明确说明理由）。

对每个 teammate 输出：
- **角色名**（在 team 内的昵称，如 "Fixer"、"Tracker"）
- **角色来源**：
  - 引用通用 subagent（Claude Code 自动加载，直接 spawn 时指定 name）
  - 引用角色原型（需把原型 markdown 内容填入 spawn prompt，补入项目特定细节）
  - 引用 team Tier 2 存档
  - 完全原创的 inline persona
- **模型选择**：`haiku`（快/便宜，适合机械的轮询、小修改）/ `sonnet`（默认，适合大多数编码/评审）/ `opus`（贵，适合需要深度推理的架构设计）
- **plan-mode gating**：YES 则 teammate 进入 read-only plan mode 先提方案待 lead approve 再实施；NO 则直接执行
- **作用域**：具体可以碰哪些文件/目录；**禁区**列表
- **交付物**：这个 teammate 结束时要产出什么（代码 / 报告 / 配置 / 测试结果 ...）

### Plan-mode gating 的决策原则
- 需要修改核心文件或多文件 refactor → **YES**
- 结果会影响其他 teammate 的工作 → **YES**
- 单文件局部修改、测试脚本、只读分析 → NO
- 对抗性审阅（devil-advocate / reviewer）→ NO（本来就是只读）

## Phase 4: 对抗性检查（可选但推荐）

如果任务**复杂且方向不明**（例如没有现成 baseline、结果反常的调研、架构抉择），建议：

- 在 team 中加一个 **devil-advocate** teammate，明确指令是"找漏洞、质疑方案、列失败路径，但**不否决**——暴露盲点后决策权回 lead"
- 对于需要"竞争假设"的调研，可以开 2-3 个 investigator teammate 各自持不同初始假设，让它们互相挑战（**注意：这会显著增加 token 消耗**）

如果任务**路径清晰**（例如"把这个模型的 forward 重写成支持 flash-attn"），**不加** devil-advocate，直接进入 Phase 5。

## Phase 5: 向用户展示阵容 + 收集反馈

把完整提案展示给用户：

```
# Team 提案 — <任务简述>

## 任务分解
1. [子项 A] - 依赖: 无, 可并行: B
2. [子项 B] - 依赖: 无, 可并行: A
3. [子项 C] - 依赖: A, B
...

## 阵容 (N 人)

### Teammate 1: <昵称> — <来源: subagent_name / role_archetype/xxx.md>
- 模型: sonnet
- Plan-mode gating: YES  (理由: ...)
- 作用域: ...
- 禁区: ...
- 交付物: ...

### Teammate 2: ...

...

## 执行流程
- 阶段 1 (并行): Teammate 1 + Teammate 2 开工
- 阶段 2 (串行): Teammate 1/2 完成后 → Teammate 3 接手
- 阶段 3 (审阅): Reviewer 审阅所有产出

你同意这个阵容吗？要调整什么（加/减 teammate、换模型、改作用域、换来源）？
```

**迭代**：根据用户反馈调整，直到用户明确同意。**不要假装用户同意**——守则 #11，有疑问必须问。

## Phase 6: Spawn Team + 保存 Recipe

### 6a. 为每个 teammate 准备 spawn prompt

对 Phase 5 最终阵容中的每个 teammate，单独准备一段 `prompt` 字符串，包含：

```
你是 <昵称>，<team_name> 的 teammate。

## 角色定义
<角色原型内容 / 引用 subagent persona / 原创 inline persona>

## 当前任务
目标：<具体任务描述>
作用域：<可以操作的文件/目录>
禁区：<绝对不能动的文件/目录>
交付物：<完成时需要产出什么>
Plan-mode gating：<是/否；若是，说明批准标准>

## 协作方式
- 重要里程碑、完成通知、阻塞报告 → 写到 _agent_team_work_zone/<SELF>_team/roundtable/
  frontmatter 必须包含 kind 字段（TASK / DONE / ERR）
- 需要联系其他 teammate 或 lead → 通过 Claude Code 内置 mailbox（SendMessage）

## 工位与持久化（Rule 13）
你的工位：_agent_team_work_zone/<SELF>_team/teammates/<昵称>/
lead 已初始化 5 个骨架文件（README / working-context.md / completed.md / TODO.md / commitments.md）。
进入 idle 前、收到 checkpoint 提醒时、任务完成后 → 调用 /checkpoint 更新 working-context.md。
这是你跨 session 恢复状态的唯一桥梁（Claude Code 不自动保留 teammate session）。
```

### 6b. 初始化每个 teammate 的工位骨架

对 Phase 5 最终版的每个 teammate，创建工位目录和 5 个骨架文件（Rule 13 规定的 teammate 自维护文件）：

路径：`_agent_team_work_zone/<SELF>_team/teammates/<teammate-name>/`

- **`README.md`** — 角色定义：写昵称、模型、角色来源、作用域、禁区、交付物、plan-mode gating 说明，以及（可选）空的 `## Checkpoint Instructions` 段位供后续定制
- **`working-context.md`** — 初始占位：
  ```markdown
  # Working Context — <teammate-name>
  _Initialized at spawn. Run /checkpoint to populate._
  ```
- **`completed.md`** — 空文件（append-only 日志）
- **`TODO.md`** — 空文件
- **`commitments.md`** — 空文件

### 6c. 写入 / 更新 TEAMMATE_INFO.json

路径：`_agent_team_work_zone/<SELF>_team/TEAMMATE_INFO.json`

如果文件已存在（team 之前运行过 spawn-team），**不覆写**；而是把新成员 append 进 `active_teammates`。如果是第一次 spawn-team 或文件不存在，按 schema v1 初始化（见 `docs/teammate_info_schema.md`）。

每个新 teammate 的条目：
```json
{
  "name": "<teammate-name>",
  "role_source": { "type": "...", "path": "..." },
  "model": "<haiku|sonnet|opus>",
  "plan_mode_gating": <true|false>,
  "scope": "<作用域简述>",
  "spawned_at": "<ISO8601 当前时间>",
  "last_checkpoint_at": null,
  "revived_count": 0,
  "status": "active"
}
```

同时更新顶层 `updated_at`。

### 6d. 保存 team recipe 审计记录

将完整 spawn prompt + 任务上下文 + 阵容设计保存到：

```
_agent_team_work_zone/<SELF>_team/team_recipes/<YYYYMMDD_HHMM>_<slug>.md
```

格式：

```markdown
---
created: YYYY-MM-DD HH:MM
lead: <SELF>
task: <一句话任务摘要>
team_size: N
mode: interactive
---

# Team Recipe: <slug>

## 任务上下文
<Phase 1 的收集结果>

## 任务分解
<Phase 2 的结果>

## 阵容
<Phase 3 + Phase 5 的最终版>

## 对抗性检查
<Phase 4 是否加了 devil-advocate / 竞争假设，为什么>

## Spawn Prompts（每个 teammate 各一段）
<Phase 6a 为每个 teammate 准备的 prompt>

## 备注
<任何值得后续 team 复用的经验>
```

### 6e. 用 Agent 工具逐一 spawn 每个 teammate

Phase 5 的用户同意是最终授权——**不要再次询问**，直接开始 spawn。

对每个 teammate 调用 Agent 工具：

```
Agent(
    description="Spawn <昵称>: <一句话角色描述>",
    subagent_type="<见下方选择规则>",
    model="<haiku|sonnet|opus>",  # 来自 Phase 3 决策
    team_name="<SELF>_team",      # ← 必须有，否则只是 subagent
    name="<昵称>",                # ← 必须有，且与工位目录名一致
    prompt="<6a 中为该 teammate 准备的 prompt>"
)
```

**subagent_type 选择规则**：
- `role_source.type == "subagent"` → `subagent_type = role_source.subagent_name`（如 `"tracker"`、`"reviewer"`）
- `role_source.type == "archetype"` / `"tier2"` / `"inline"` → `subagent_type = "general-purpose"`（角色通过 prompt 注入）

**spawn 顺序**：按执行依赖顺序——可并行的 teammate 可以同时在一条消息里发出多个 Agent 调用，有先后依赖的串行调用。

**spawn 完成后**输出简短确认：

```
✅ teammates/ 工位骨架已创建（N 个 teammate × 5 文件）
✅ TEAMMATE_INFO.json 已初始化/追加（N 个 active_teammates）
✅ team_recipes/<timestamp>_<slug>.md 已保存
✅ Team spawned: <昵称1>、<昵称2>... 已就位，等待第一条任务指令
```

---

## 终端 / tmux 相关（仅在 spawn 报 tmux 错、或想调显示/持久化方式时看）

> tmux **不是** agent team 的必需品——in-process 模式在任何终端都能跑完整 team 功能。本段仅在遇到下列报错、或你想改显示/持久化方式时才相关，正常 spawn 流程**无需理会**。

**两个 tmux spawn 报错的含义**（硬性版本/环境检查由 `bootstrap.sh` 负责，本 skill **不**自己跑检查）：
- `Failed to create teammate pane: size invalid` → 你在 tmux 内、但 tmux 版本太老（< 3.0）。升级 tmux ≥ 3.0（3.6a 实测 OK），或退出 tmux 改用 in-process。
- `Could not determine current tmux pane/window` → PATH 里的 tmux 与当前 session（`$TMUX` socket）的 tmux 不是同一个（多版本共存）。让 PATH 指向启动当前 session 的那个 tmux。
- 这两个错 **bootstrap 会在你进 tmux 后预先拦截并诊断**——看到就**重跑 bootstrap**，按它的指引修。

**`teammateMode`（显示方式，settings.json 字段）**：

| 值 | 行为 |
|---|---|
| `auto`（默认）| 在 tmux 内**或** iTerm2 里 → split-pane（每个 teammate 一个窗格）；否则 → in-process |
| `split-pane` | 强制每 teammate 一个窗格（需 tmux 或 iTerm2）|
| `in-process` | 所有 teammate 同一终端，`Shift+Down` 循环切换；**任何终端可用** |

- 不想被拆窗格 → 用 `in-process`。**别手改 settings.json**——重跑 `bootstrap.sh`，它有交互选项帮你写（default 不改）。
- **强烈推荐把 Claude Code 跑在 tmux session 里**（即使显示用 in-process）：关终端 / SSH 断连时 tmux 保住进程、session 不中断，**省去事后频繁 `/reactivate-team` 重建 team**。装不装 tmux、跑不跑在 tmux 内都不影响 team 功能，但跑在 tmux 内能避免断连丢 team。详见 `docs/user_manual.md` 的 tmux 部分。

---

## 注意事项

- **Rule 12 贯穿全程**：lead 不做动手工作；复杂任务必须组建 team 而不是一个人扛
- **最多 5 人**：超过会显著增加 coordination 开销
- **对话是黑盒**：用户只用自然语言和 lead 交互，`/spawn-team` 被 agent 自主调起，用户不需要记命令
- **Team recipe 是可复用资产**：下次遇到类似任务，lead 可以先查 `team_recipes/` 找类似案例
- **Agent 工具必须带 `team_name` + `name`**：缺少任意一个就只是普通 subagent，无法参与 team 协作。Phase 5 用户同意 = 最终授权，直接调用，不二次确认
- **`mode: interactive` 标注**：frontmatter 已留好位置，将来切到 `autonomous` 时扩展本文件的 Phase 7（启动 `/loop` + hook）
