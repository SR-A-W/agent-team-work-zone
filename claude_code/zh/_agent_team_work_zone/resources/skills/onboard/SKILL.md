---
name: onboard
description: >
  新 agent 入职: 先询问是扁平工位还是 team lead，然后创建对应目录结构、
  生成角色定义文件和任务跟踪文件、在成员表中注册。在新 agent 对话开始时使用。
argument-hint: "<任务/角色描述>"
disable-model-invocation: true
allowed-tools: Read Write Edit Glob Bash
---

# Agent 入职流程（支持扁平工位和 Team Lead 两种模式）

你正在为一个新 agent 执行入职。请按以下步骤完成。

## 输入信息

用户通过 `$ARGUMENTS` 提供角色或任务描述。描述中可能已包含明确的命名，但**命名优先由你 agent 自行决定**，只有当用户主动提出偏好或拒绝你的命名时，才采用用户的指示。

## Step 0: 确认工位模式（扁平 or Team Lead）

在开始任何操作前，**先根据任务描述询问用户**：

```
我理解你需要的角色职责是：<从 $ARGUMENTS 中归纳的一句话>

请问这个角色应该是：
  (1) 扁平工位 — 一个人的工位，适合单人能完成的简单任务（如秘书、Git 管理、翻译等）
  (2) Team Lead — 带一个部门办公室，适合需要多人协作、并行工作流、对抗性调研的复杂任务
       （team lead 不做具体的编码/配置/测试，通过 /spawn-team 组建 team，由 teammate 完成动手工作）

你希望是哪种？
```

等用户明确回答后再进入对应分支。**不要自行猜测**——如果描述模糊，按守则 #11 主动提问。

> **升级**：如果将来发现扁平工位承担不了了，可以通过 `/promote-to-team` 升级。但 **`/onboard` 只在对话开始时执行一次**，这里决定的模式就定型了。

## Step 1: 阅读项目组总纲

读取 `_agent_team_work_zone/README.md`，了解：
- 项目组的工作流程
- 已有的成员列表
- 13 条工作守则
- 当前使用的模式（扁平/team 混合）

## Step 2: 确定角色名

**你需要自行确定以下三项**：
- **角色中文名** — 简短（2-4 字，如：秘书、架构师、规划师）
- **角色英文名** — 简短英文（如：Secretary、Architect、Planner）
- **一句话职责描述** — 概括核心职责

**命名原则**：
- 从用户的任务描述中提炼合适的命名
- 英文名用于目录命名时转为小写下划线格式
- 扁平工位目录：`<english_name>/`
- Team Lead 工位目录：`<english_name>_team/`（**必须以 `_team` 结尾**）
- 命名应简短、明确、易于区分

**向用户确认命名**：

```
我建议这个角色叫：
  中文：<中文名>
  英文：<English Name>
  工位目录：_agent_team_work_zone/<english_name>[_team]/
  一句话职责：<描述>

你同意这个命名吗？如果不同意，请告诉我你的偏好。
```

若用户否决，按用户偏好重命名后再次确认。

## Step 3: 创建工位目录和基础文件

### 扁平工位分支

创建目录和 5 个文件：

```
_agent_team_work_zone/<english_name>/
├── README.md           ← 角色定义 + 13 条工作守则 + 扁平工位的升级提醒
├── notes.md            ← 工作笔记
├── TODO.md             ← 待办事项
├── ACTIVE_JOBS.md      ← 活跃任务
└── COMPLETED_JOBS.md   ← 已完成任务
```

README.md 必须包含以下章节：

1. **身份** — 角色名称 + 一句话职责描述
2. **职责范围** — 做什么 / 不做什么
3. **工作流程** — 典型工作步骤
4. **关键文件** — 经常需要访问的文件路径
5. **工作守则** — 从项目组总纲**完整复制** 13 条工作守则（防止上下文压缩后遗忘）
6. **工作笔记** — 说明本工位有 notes.md
7. **何时升级为 team lead** — 提醒自己：预见到任务会变复杂时主动建议用户 `/promote-to-team`（以下内容必须写入）：

   > **何时升级**：如果新分配的任务需要多种不同专业技能（例如既要改代码又要配环境又要写脚本）、
   > 会有多个可并行工作项、需要对抗性审阅或多角度调研、或单人完成会显著消耗 context window
   > （> 50% 用于执行细节而非决策），你应该**主动**建议项目主管运行 `/promote-to-team` 升级。
   > **原则：宁可提前升级，不要事后抢救**。一旦 context 已经被任务细节挤满再组建 team，lead 就无法有效指挥了。

8. **上下文恢复** — 压缩后怎么恢复（读 README + notes + 相关 meeting_room 文件）

### Team Lead 工位分支

创建目录、5 个文件 **+ team 特有子结构**：

```
_agent_team_work_zone/<english_name>_team/
├── README.md                ← 含 team lead 专属章节 + rule 12/13 + 13 条工作守则
├── notes.md
├── TODO.md / ACTIVE_JOBS.md / COMPLETED_JOBS.md
├── TEAMMATE_INFO.json       ← Team 注册表（初始空 active_teammates）
├── roundtable/              ← 部门内部沟通
│   └── README.md            ← 从项目模板或 meeting_room README 派生
├── archive/                 ← 部门内部归档
│   └── .gitkeep
├── team_recipes/            ← /spawn-team 产出的审计记录
│   └── README.md            ← 说明 team_recipes 的用途
└── teammates/               ← 每 teammate 自己的工位 + Tier 2 存档
    └── README.md            ← 说明工位结构 + Tier 2 存档用途
```

**初始化 TEAMMATE_INFO.json**（team lead 新工位必建，为后续 `/spawn-team` / `/add-teammate` / `/reactivate-team` 读写做准备）：

```json
{
  "schema_version": 1,
  "team_name": "<english_name>_team",
  "lead_name": "<English Name>",
  "updated_at": "<ISO8601 当前时间>",
  "active_teammates": [],
  "offboarded_teammates": []
}
```

Schema 详见 `docs/teammate_info_schema.md`。Teammate 不得修改此文件的结构；只允许 teammate 调用 `/checkpoint` 时更新**自己那条**的 `last_checkpoint_at`。

README.md 必须包含 Flat 版所有章节 **+** 以下 team lead 专属章节：

- **Team 职责范围** — 这个 team 负责什么领域 / 典型任务类型 / 边界
- **团队管理** — 使用 `/spawn-team`、`/evaluate-team`、`/add-teammate`、`/remove-teammate` 的指南
- **Context 保留原则**（即 rule 12）：

  > **重要 — Rule 12**：作为 team lead，你的 context window 专用于**协调**，不做动手的编码/配置/测试工作。
  > 收到动手任务时先判断：能用几条消息搞定且不烧 context，还是需要组建 team。超过 1-2 个文件或需要并行调研的
  > 一律倾向于 `/spawn-team`。teammate 通过自己的 session 完成动手工作，你只看 summary + 决策。

- **Tracker 管理** — 需要持续监视长任务时，如何用内置 `/schedule` + `resources/agents/tracker.md` 模板启动 tracker，产出写到本 team 的 `roundtable/`

### 两种模式通用的工作笔记与任务跟踪

`notes.md` 初始内容：
```markdown
# <角色英文名> 工作笔记

(工作中积累的重要知识会记录在这里)
```

`TODO.md` / `ACTIVE_JOBS.md` / `COMPLETED_JOBS.md` 按标准模板创建（参考现有工位）。

## Step 4: 在成员表中注册

编辑 `_agent_team_work_zone/README.md`，在"项目组成员"表格中添加一行：

```
| <中文名> | <英文名> | `<目录名>/` | <flat 或 team> | <一句话职责> |
```

## Step 5: 读取相关通讯空间规则

- 所有 agent：读取 `_agent_team_work_zone/meeting_room/README.md` 了解顶层会议室规则
- Team lead 额外：读取新创建的 `<your_team>/roundtable/README.md` 了解部门内部通讯规则

## Step 6: 完成确认

所有步骤完成后，向用户汇报：
- 已创建的工位目录路径
- 工位模式（flat / team lead）
- 已创建的文件清单（扁平 5 个，team lead 更多）
- 已在成员表中注册
- 当前项目组共有多少名成员、其中 flat / team 各多少
- **若是 team lead**：提醒用户下一步可以用自然语言描述任务，lead 会主动建议调用 `/spawn-team`

## 注意事项

- `/onboard` **只会执行一次**——在对话开始时决定你的模式。之后不要重复运行
- 若用户一开始说要扁平工位，但后来发现任务太复杂，**不要**再调 `/onboard`，而是用 `/promote-to-team`
- 命名决策权在 agent，但用户有否决权——不要一意孤行
- 13 条工作守则**必须**完整复制到新工位的 README（守则 #6 角色持久化）
