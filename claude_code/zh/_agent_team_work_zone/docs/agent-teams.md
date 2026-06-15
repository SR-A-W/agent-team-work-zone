# Agent Teams Architecture — 新架构设计文档

> **Status**: ACTIVE
>
> 本文档替代 `design/hierarchy.md` 成为多 agent 层级化组织的官方设计。原 `hierarchy.md` 提出的四机制（`org_chart.yaml` / frontmatter `cc` field / `role_templates/` / `departments/` 子目录）随 Claude Code 内置 Agent Teams 特性的出现而过时。

## 背景

`agent-work-zone` 是一个多 agent 协作模板，源自 PL-MoE 研究项目的 `_agent_tasks/` 经验。早期版本是**扁平结构**：所有 agent 对等，通过一个共享的 `meeting_room/` 做异步文件通讯。

随着项目规模扩大，扁平结构暴露了三个问题：
1. **无上下级关系** — 无法表达"tracker 向 lead 汇报"
2. **角色不可复用** — 同类角色（多个 tracker）需要重复编写
3. **无交叉汇报** — 一个 agent 可能需要同时向部门和总负责人汇报

`design/hierarchy.md` 提出了**四机制渐进式方案**作为解决方向。

## Claude Code 内置 Agent Teams 特性

2025 年 Claude Code 引入了 **experimental Agent Teams** 特性（需要 v2.1.32+ 和 `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` env flag）。核心能力：

- **Team Lead / Teammate 模型**：一个 Claude Code session 作为 lead，可以 spawn 若干 teammate session
- **Teammate 是独立 Session**：每个 teammate 有自己的 context window，完整的 Claude Code 会话
- **Inter-teammate Mailbox**：teammate 之间可以直接通讯
- **Per-teammate Plan Mode Gating**：可以要求某些 teammate 先提方案待 lead 批准再实施
- **Display Modes**：支持 tmux split panes 或 in-process
- **Runtime 状态**：存放在 `~/.claude/teams/{team-name}/config.json`（**用户级**，自动生成，不可手编辑）

**关键约束**：
- **没有** project-level team config file（像 `.claude/teams/teams.json` 这种）
- Team 是 runtime 的：用自然语言 spawn，用完即散
- Custom subagents (`.claude/agents/*.md`) 可以作为 teammate 的 role template 使用
- `skills` 和 `mcpServers` frontmatter 字段**不会**传递给 teammate
- 推荐 team size：3~5 人，超过 5 人协调成本增加

## 为什么 hierarchy 四机制被 supersede

| 原机制 | 现状 |
|---|---|
| **A: `org_chart.yaml`** | **过时**。组织层级不再需要静态配置文件——team 是 runtime spawn 的，用一次销毁一次。静态 yaml 会立刻过时 |
| **B: frontmatter `cc` field** | **保留**。仍然有用——跨 team / 跨工位通讯的抄送功能，Claude Code 内置 mailbox 不提供这种"只读广播" |
| **C: `role_templates/`** | **重构**。原四机制的角色模板集中到 `resources/role_archetypes/`，但不再作为 `.claude/agents/` 的直接源。角色原型 + team lead 在 spawn 时具体化 = 两层模型 |
| **D: `departments/` 子目录** | **重构**。不再作为单独的子目录层级。改为**以 `_team` 后缀命名**的工位，各自持有 `roundtable/`、`archive/`、`team_recipes/`、`teammates/` 子结构。部门和扁平工位**同级**放置 |

## 新架构：扁平 / Team 混合

核心理念：**简单任务扁平，复杂任务 team**。

### 工位类型

```
_agent_team_work_zone/
├── secretary/                  # 扁平工位（无 _team 后缀）
├── git_keeper/                 # 扁平工位
├── architect_team/             # team 工位（以 _team 结尾）
│   ├── README.md               # team lead 角色定义 + rule 12
│   ├── notes.md / TODO.md / ...
│   ├── roundtable/             # 部门内部沟通
│   ├── archive/                # 部门内部归档
│   ├── team_recipes/           # /spawn-team 审计
│   └── teammates/              # Tier 2 自定义角色存档
└── planner_team/               # 另一 team 工位
```

**命名约定**是唯一的模式识别依据：
- `<name>/` → 扁平
- `<name>_team/` + 内含 `roundtable/` → team lead

### 两层通讯

| 层 | 位置 | 用途 | Frontmatter |
|---|---|---|---|
| **顶层** | `_agent_team_work_zone/meeting_room/` | 跨工位 / 跨 team 通讯 | `from: Architect` 首字母大写 |
| **部门内** | `<team>/roundtable/` | Team 内部通讯 | `from: architect_team/tracker` 小写斜杠 + `kind` 字段 |

`/check-inbox` 根据当前 agent 身份自动扫描对应层级——扁平只扫顶层，team lead 同时扫顶层和自己 team 的 roundtable。

### 工作流骨架

```
1. /onboard 创建扁平或 team lead 工位（只运行一次）
2. 扁平 agent 预见任务变复杂 → /promote-to-team（agent 自主调用）
3. Team lead 收到复杂任务 → /spawn-team（agent 自主调用）
4. /spawn-team 产出 natural-language spawn prompt，Claude Code 内置机制 spawn teammate
5. Team 工作期间：lead 用 /evaluate-team, /add-teammate, /remove-teammate 管理
6. 长跑任务：lead 用 /schedule 启动 tracker cron trigger
7. Teammate 完成工作 → 自然离场
8. /check-inbox + /sync 持续收集进度
```

## Skill 调用模型

每个 skill 的 `disable-model-invocation` 字段决定谁能调：

| 值 | 效果 |
|---|---|
| `true` | **只有用户**能输入 `/skill` 触发；agent 不能自主调用 |
| `false` | 用户和 agent 都能调；agent 在判断有必要时**自主**调起 |

### 对用户的黑盒原则

所有 **team 管理**和**定时任务**相关的操作对用户是黑盒——用户用自然语言交互，不记任何命令。

- `/spawn-team` 由 team lead agent 自主调起（用户自然语言同意后）
- `/promote-to-team` 由扁平 agent 自主调起（发现任务变复杂时）
- `/evaluate-team`、`/add-teammate`、`/remove-teammate` 由 team lead 自主调起
- `/schedule` 由 team lead 自主调起启动 tracker（默认 training 12h / eval 4h）

用户只需要手动调用基础操作：`/onboard`、`/sync`、`/check-inbox`（归档逻辑已内置于步骤 9，无需单独调用 `/archive-resolved`）。

## 两级身份检查

有身份约束的 skill（spawn-team、promote-to-team、evaluate-team、add-teammate、remove-teammate）都实现**两级身份检查**：

1. **先从对话 context 推断**（默认零 token 消耗）—— agent 通常已经知道自己是谁
2. **只有推断不出时**才读文件：Glob 所有工位 README，对比对话历史找到匹配

这避免了每次 skill 调用都做 file I/O。

## 三层角色定义存储

Team lead 在 `/spawn-team` 时创建的 teammate 定义，有三个存储级别：

| Tier | 位置 | 适用场景 | Naming |
|---|---|---|---|
| **1（默认）** | inline 在 spawn prompt + `<team>/team_recipes/<timestamp>.md` 审计 | 一次性任务 | 无前缀 |
| **2（偶尔）** | `<team>/teammates/<role>.md` | Team 内部跨任务复用 | 无前缀（目录隔离）|
| **3（罕见）** | `.claude/agents/<team>_<role>.md` | 希望 Claude Code 全局自动加载 | **必须带 team 前缀**避免跨 team 冲突 |

默认走 Tier 1。`.claude/agents/` 只保留 5 个项目全局通用的 subagent（`git-repo-manager`, `tracker`, `investigator`, `reviewer`, `devil-advocate`）。

## Rule 12：Team Lead 节省 Context

新增工作守则第 12 条：

> **Team lead 的 context window 专用于协调**：组建团队、读 teammate summary、向用户汇报、跨 team 路由。**不做**具体的编码/配置/测试等动手工作。超过 1-2 个文件或需要并行调研的任务一律倾向于组建 team。

扁平工位的补充：预见任务会变复杂时主动建议 `/promote-to-team`。

## Tracker 产品形态

Tracker 的物理存在是一个 subagent 定义（`resources/agents/tracker.md`），但它的**调用形态是 `/schedule`**：

- Team lead 调用 `/schedule` 创建 cron trigger
- 每次触发 Claude Code spawn 一个 fresh remote agent（以 tracker 为 role template）
- 远程 agent 读状态文件 → 写报告到 `<team>/roundtable/` → 退出
- 触发之间零 token 消耗
- **默认 cron**：训练 12h，eval 4h（可由 team lead 根据任务性质调整）

## 对 autonomous mode 的预留

`/spawn-team` 的 frontmatter 留有 `mode: interactive | autonomous` 字段，目前只实现 `interactive`。将来通过 `/loop` + hook 机制实现端到端自动化，届时在同一个 skill 里扩展。

详见 `roadmap/autonomous_team_mode.md`。

## 与 hierarchy.md 的关系

`design/hierarchy.md` 保留作为**历史推理过程**的记录。它的核心价值：
- 完整记录了扁平结构的局限和作者的思考
- 四机制方案虽然被 Claude Code 内置特性覆盖，但**思路**（渐进式、backward compatible、mechanism 可选）依然影响了新架构
- 新架构某些决策可以从 hierarchy 的开放问题中找到呼应（例如 cc 字段的保留）

在本文档发布后，`hierarchy.md` 的顶部会加 SUPERSEDED banner。

## 影响范围

本架构变更涉及：

- **新增**：`claude_code/zh/_agent_team_work_zone/` 整个目录（template source）
- **修改**：4 个已有 skill（onboard, sync, check-inbox, archive-resolved）
- **新增**：5 个新 skill（spawn-team, promote-to-team, evaluate-team, add-teammate, remove-teammate）
- **新增**：4 个新 subagent（tracker, investigator, reviewer, devil-advocate）；保留 1 个（git-repo-manager）
- **新增**：9 个角色原型
- **修改**：工作守则从 11 条增加到 12 条，rule 8 加 cc 语义
- **修改**：`install_skills.sh` 改为不删源，加入 agent 安装；新增 `bootstrap.sh`
- **创建**：`.claude/settings.json`（env flag）
- **重构**：live `_agent_team_work_zone/` 原地重构（Architect/Planner 升级为 `_team`）
- **Supersede**：`design/hierarchy.md`
- **不动**：`claude_code/zh/_agent_work_zone/` 和 `claude_code/en/_agent_work_zone/`（稳定扁平版模板）

## 参考资料

- Claude Code 官方文档：agent-teams
- Claude Code 官方文档：sub-agents
- `design/hierarchy.md`（历史参考）
- 本目录下的 `design_history.md`（本次重构的决策过程）
