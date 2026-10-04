<!-- FRAMEWORK:START -->
# _agent_team_work_zone/ — 多 Agent 协作工作区（Team 版）

> 本目录是一套**支持 Claude Code 内置 Agent Teams 特性**的多 agent 协作模板。每个 Claude Code 对话承担一个特定角色；简单任务用扁平工位单兵作战，复杂任务用 **team lead + team 办公室** 的组织结构，借助 Claude Code 的 agent-team spawn 等内置能力完成端到端协作。

> **本模板适配 Claude Code 2.1.178**（会话级自动 team、`TeamCreate`/`TeamDelete` 已删、`Agent` 的 `team_name` 被忽略），要求 **CC ≥ 2.1.178**。如果你的 Claude Code ≤ 2.1.177，请改用 **[release v0.1.0](https://github.com/SR-A-W/agent-team-work-zone/releases/tag/v0.1.0)**（针对旧 API）。

## 环境要求

- **Claude Code** ≥ v2.1.178（适配 2.1.178 agent-teams API；旧版用 release v0.1.0）
- **tmux** ≥ 3.2（强烈推荐：split-pane 显示 + 抗 SSH 断连；非必需，不装则 in-process 兜底）
- **jq**（必需：bootstrap 用它把框架的 hook 写进 `.claude/settings.json`，没有它会停下）

---

## 开始之前

> [!IMPORTANT]
> **`_agent_team_work_zone/` 必须放在项目目录里，并且永远在这个目录下启动 Claude Code**——也就是*包含* `_agent_team_work_zone/` 的那个目录。
>
> 常见错误：登录 HPC 集群（或任何服务器）后直接在 home 目录里启动 `claude`，而 work zone 却在某个项目文件夹里。这样会：
> - 项目 `.claude/` 里的 hooks 和设置不会生效，skills 在启动时也用不了；
> - 工位（每个 agent 在 work zone 里的目录）路径从项目根目录解析，checkpoint 和唤回（`/reactivate-team`）会去错的地方找；
> - teammate 从 lead 当前所在的目录启动——lead 在错的目录里运行（或它的 shell 切到了某个子目录），派生出的 teammate 也从那里启动，相对路径随之失效。
>
> 所以：先 `cd /path/to/your/project`，再运行 `claude`。把 home 目录本身当作项目也可以——只要 `_agent_team_work_zone/` 就在 home 目录下，并且在那里启动 Claude。但我们依然强烈推荐：在项目目录下使用该项目专有的 agent team work zone，并为它单独启动一个 Claude Code session。

### 把 `_agent_team_work_zone/` 纳入 git 管理（强烈推荐）

把 `_agent_team_work_zone/` 和代码一起提交到项目的 git 仓库，不要把它加进 `.gitignore`。纳入 git 管理的，是 agent 最核心、最重要的工作记忆：角色定义、checkpoint、工作日志、讨论记录和团队登记表。运行期的临时文件由 work zone 自带的 `.gitignore` 排除。

- **agent 的工作记忆和日志也得到版本管理。** checkpoint、工作日志、讨论记录和决策，正逐渐成为项目开发记录的重要组成部分。用 git 跟踪它们，尤其是推送到 GitHub 之后，就等于用 git 管理了 agent 们的项目记忆：一方面记忆有了备份，丢失的风险大大降低；另一方面记忆可以回溯——当 agent 或项目走偏时，可以退回到之前的状态。
- **方便迁移到新机器。** 在另一台机器上 clone 项目，先在那里的项目目录下运行一次 `npx agent-team-work-zone reconfigure`（从源码安装的：`bash _agent_team_work_zone/resources/scripts/bootstrap.sh --reconfigure`），它会安装 skills、hooks 并配置 Claude Code，并重新询问安装时的问题，包括每台机器各自设置的成员显示方式和 Auto 权限模式，再在项目目录下启动 Claude，用 `/reactivate-team` 就能拉起一支角色相同、状态相同的 agent 团队。
- **多人协作。** 每位开发者可以在同一个项目里维护一支或多支 agent 团队；团队之间通过 work zone 了解彼此，并通过 `git push` / `git pull` 交流、互相留言（例如借助 `meeting_room/`）。

```bash
git add _agent_team_work_zone
git commit -m "Track the agent team work zone"
```

> [!CAUTION]
> 工位里可能有敏感内容（路径、主机名、数据或对话片段）。如果仓库是公开的，push 前先检查或清理，或者把 work zone 放在私有仓库里。

---

## 初始配置

### 1. 一键 bootstrap

```bash
npx agent-team-work-zone init --lang zh     # 推荐（需 Node.js 18+）；在你的项目目录下运行
# 或者，如果你是自己把 _agent_team_work_zone/ 复制进项目的：
bash _agent_team_work_zone/install.sh
```

脚本会：
- 检查 Claude Code 版本
- 安装 `resources/skills/` 和 `resources/agents/` 到 `.claude/` 下
- 创建或合并 `.claude/settings.json` 启用 experimental agent teams 特性
- 不删除源目录（与旧版 install_skills.sh 的破坏性行为不同）
- 首次安装时检查 git：项目不在 git 仓库里，或在仓库里但不在仓库根目录，会提醒你。在仓库根目录时会询问是否用 git 跟踪 `_agent_team_work_zone/`（默认是，推荐）；选"否"会把 `/_agent_team_work_zone/` 加进项目的 `.gitignore`，以后改主意删掉这一行即可。没有终端时不询问，也不做任何改动。

### 2. 为每个角色启动交互式对话并完成入职

```bash
claude -n "Architect"
```

在对话中运行 onboard skill（agent 会先询问招募的是扁平工位还是 team lead）：

```
/onboard 负责项目架构设计与实验性改造
```

### 3. 恢复对话

```bash
claude --resume "Architect"
```

### 4. 同步状态

长时间未操作后，在对话中执行 `/sync` 即可扫描工作区变更、必要时恢复身份、检查新消息。

### 5. Display mode（可选，用户级）

Team spawn 的展示模式需要在 `~/.claude.json` 或 CLI flag 设置（不能固定在项目级）：

```json
{ "teammateMode": "auto" }
```

或启动时指定：`claude --teammate-mode tmux`。详见 Claude Code 官方文档。

---

## 目录结构

```
_agent_team_work_zone/
├── README.md                  ← 你正在读的文件 (项目组总纲)
├── meeting_room/              ← 顶层会议室: 跨工位 / 跨 team 的全局沟通
│   ├── README.md
│   └── <Agent>_<类型>_<YYYYMMDD>_<HHMM>_<描述>.md
├── archive/                   ← 顶层归档
├── <agent_name>/              ← 扁平工位（无 _team 后缀）
│   ├── README.md              ← 角色定义
│   ├── notes.md / TODO.md / ACTIVE_JOBS.md / COMPLETED_JOBS.md
├── <agent_name>_team/         ← team 工位（以 _team 结尾）
│   ├── README.md              ← team lead 的角色定义
│   ├── notes.md / TODO.md / ACTIVE_JOBS.md / COMPLETED_JOBS.md
│   ├── TEAMMATE_INFO.json     ← ★ team 活跃成员注册表（lead 维护，见 docs/teammate_info_schema.md）
│   ├── roundtable/            ← 部门内部沟通（team 内 lead↔teammate、tracker 报告等）
│   │   └── README.md
│   ├── archive/               ← 部门内部归档
│   ├── team_recipes/          ← /spawn-team 产出的历史记录
│   └── teammates/             ← 每 teammate 一个子目录（持久化工位，重启时 /reactivate-team 依据它恢复）
│       └── <teammate_name>/
│           ├── README.md              ← 该 teammate 的角色定义（可含 ## Checkpoint Instructions 段）
│           ├── working-context.md     ← Part A 当前态快照(覆写) + Part B 工作日志(追加)（由 /checkpoint 写，rule 13）
│           ├── completed.md           ← append-only 产出日志
│           ├── TODO.md                ← 该 teammate 自己的待办
│           └── commitments.md         ← 对 lead/peer 的承诺
│
├── resources/                 ← 所有非成员资源
│   ├── README.md
│   ├── skills/                ← Skills 权威源（由 bootstrap 同步到 .claude/skills/）
│   │   ├── onboard/SKILL.md
│   │   ├── sync/SKILL.md
│   │   ├── check-inbox/SKILL.md
│   │   ├── archive-resolved/SKILL.md
│   │   ├── handoff/SKILL.md
│   │   ├── spawn-team/SKILL.md
│   │   ├── promote-to-team/SKILL.md
│   │   ├── evaluate-team/SKILL.md
│   │   ├── add-teammate/SKILL.md
│   │   ├── remove-teammate/SKILL.md
│   │   └── bench-teammate/SKILL.md
│   ├── agents/                ← 通用 subagent 权威源（由 bootstrap 同步到 .claude/agents/）
│   │   ├── git-repo-manager.md
│   │   ├── tracker.md
│   │   ├── investigator.md
│   │   ├── reviewer.md
│   │   └── devil-advocate.md
│   ├── role_archetypes/       ← 角色原型速查（不由 Claude Code 自动加载）
│   │   ├── README.md
│   │   ├── coding/   (bash-scripter / model-architect / dataset-specialist)
│   │   ├── config/   (training-config-author / eval-config-author)
│   │   ├── infra/    (env-configurator / container-builder)
│   │   └── analysis/ (data-analyzer / result-reporter)
│   ├── scripts/
│   │   ├── bootstrap.sh
│   │   └── install_skills.sh
│   └── hooks/                 ← 预留，供 terminal-form 自动化模式启用
│
└── docs/                      ← 文档
    ├── user_manual.md
    ├── agent-teams.md         ← 新架构设计文档
    ├── teammate_info_schema.md
    └── upgrade_guide.md
```

### 工位命名约定

| 类型 | 约定 | 示例 |
|---|---|---|
| 扁平工位 | `<role_name>/`（**无** `_team` 后缀） | `secretary/`、`git_keeper/` |
| Team 工位 | `<role_name>_team/`（**以** `_team` 结尾） | `architect_team/`、`planner_team/` |
| 部门内部沟通 | 工位下的 `roundtable/` | `architect_team/roundtable/` |
| 部门内部归档 | 工位下的 `archive/` | `architect_team/archive/` |
| 团队审计 | `team_recipes/` | `architect_team/team_recipes/` |
| 团队自定义角色 (Tier 2) | `teammates/` | `architect_team/teammates/pytorch_patcher.md` |

**关键识别**：skill 判断一个对话当前属于扁平还是 team lead，只需检查工位目录是否以 `_team` 结尾且存在 `roundtable/` 子目录。

---

<!-- FRAMEWORK:END -->

## 项目组成员

| 角色名 | 英文名 | 工位目录 | 模式 | 职责简述 |
|--------|--------|----------|------|----------|

> **新 agent 入职后，必须在此表格中添加自己的信息**。`模式` 列填 `flat` 或 `team`。

---

## 新 Agent 入职指南

当用户在一个新的 Claude Code 对话中给你分配了一个角色，请按以下步骤操作：

### 推荐方式：使用 `/onboard` skill

```
/onboard <任务/角色描述>
```

Skill 会先询问你是**扁平工位**还是 **team lead**（根据任务性质），然后自动完成：
- 角色名提炼（agent 自主决定）
- 工位目录创建（根据 flat/team 选择创建 `<name>/` 或 `<name>_team/` 并补齐 team 特有子结构）
- README、notes、TODO/ACTIVE_JOBS/COMPLETED_JOBS 生成
- 成员表注册

### 手动入职（了解内部流程用）

1. 阅读本文件（项目组总纲）
2. 判断你是扁平工位还是 team lead（flat / team）
3. 创建工位目录：
   - Flat: `_agent_team_work_zone/<name>/`
   - Team: `_agent_team_work_zone/<name>_team/` + 下面的 `roundtable/`、`archive/`、`team_recipes/`、`teammates/` 子目录
4. 写 README.md（含完整 13 条工作守则，作为上下文恢复锚点）
5. 写 notes.md（工作笔记，按主题组织）
6. 写 TODO.md / ACTIVE_JOBS.md / COMPLETED_JOBS.md
7. 在上面的项目组成员表中注册自己
8. 阅读 `meeting_room/README.md` 和（若是 team lead）`<你的工位>/roundtable/README.md`

---

## 会议室与 Roundtable

本项目有**两个层级**的沟通空间：

### 顶层 `meeting_room/`

跨工位、跨 team 的全局沟通。所有扁平工位和 team lead 都要扫这里。适合：
- 跨 team 任务交接
- 全局公告
- 扁平工位之间的通讯

### 各 team 工位下的 `roundtable/`

team 内部沟通。**只有对应 team 的 lead 和内部成员**能看到和修改。适合：
- team lead 给 teammate 派发任务
- teammate 之间的协作
- tracker 的周期性状态报告
- team 内部完成通知

### Frontmatter 区分

**顶层 meeting_room**（不变）：
```yaml
---
status: OPEN | IN_PROGRESS | RESOLVED
from: Architect              # 首字母大写的 agent 英文名
to: Secretary                 # 或 ALL
date: 2026-04-11 15:30
priority: HIGH | MEDIUM | LOW
cc: [Planner, SkillSmith]    # 可选，抄送（只读不改）
---
```

**部门内 roundtable**（新增 `kind` 字段，`from`/`to` 用 `<team>/<role>` 小写斜杠）：
```yaml
---
kind: TRACKER_REPORT | TASK | DONE | ERR | STATUS
status: OPEN | IN_PROGRESS | RESOLVED
from: architect_team/tracker  # 小写，带 team 前缀
to: architect_team/lead
date: 2026-04-11 15:30
priority: HIGH | MEDIUM | LOW
---
```

详见 `meeting_room/README.md` 和各 team 工位下的 `roundtable/README.md`。

---

<!-- RULES:START -->
## 工作守则（13 条）

> **本守则由框架维护，随升级刷新。** 扁平工位与 team lead 在自己的工位 README 中带全套守则（升级会就地刷新）；teammate 带的是精简子集（见 `resources/teammate_rules.md`），由 `/spawn-team` 在建工位时写入。**请勿手改本区块——改动会在下次升级被覆盖；要定制，改标记块之外的用户区。**

### 1. 低耦合
每个 agent 只做自己职责内的事，不越界。**具体含义**：

- **工位归属**：每个工位目录（`<name>/` 或 `<name>_team/`）及其所有内容**归属于对应的 agent**。不属于你的工位**不要修改**——包括 README、notes、TODO、roundtable 等所有文件
- **Team 边界**：如果你不是某个 team 的 lead 或 teammate，**不要写入该 team 的 roundtable / archive / team_recipes / teammates**
- **升级和迁移**：扁平工位升级为 team lead **只能由该工位自己**调用 `/promote-to-team`——team lead **不得代劳**为其他 agent 升级工位
- **帮忙也不行**：即使你觉得对方需要帮助，**也要通过 meeting_room 发 TASK** 让对方自己执行，不要直接动手改
- **共享工作目录与暂存区**：所有 agent 共用同一个 git checkout——同一个工作目录、同一个暂存区。暂存区里不是你放的东西别动、也别带进你的提交：
  - 提交前先看 `git diff --cached --stat`；提交一律按显式路径：`git commit -m "…" -- <路径>…`
  - 禁用 `git add -A` / `git add .` / `git commit -a`（会把别人的改动带进你的提交）
  - 禁用 `git stash`、`git pull --rebase`、非快进 merge（stash 会收起别人未提交的文件；rebase 或合并失败后的中止、重置会把它们回退）；拉取用 `git pull --ff-only`
  - 不删除真实存在的 `.git/index.lock`（那是别人的 git 操作正在进行）；若它一直不消失、且没有 git 进程在运行，告诉 lead，不要自己删
  - 在共享 checkout 里提交、合并、拉取时，优先用 `cd "<项目根目录>" && bash _agent_team_work_zone/resources/scripts/atwz_git_lock.sh run -- git …`，其中 `<项目根目录>` 是包含 `_agent_team_work_zone/` 的那个目录的绝对路径（你的 spawn prompt 里给了）；这样在任何工作目录下都能用，项目只是某个更大仓库的子目录时也不例外
- **违反此条的代价**：被动对象在下次 `/sync` 时会发现自己的工位被改动过却不知道是谁、为什么——这会破坏工作连续性和信任

### 2. 充分信息
提交到 meeting_room / roundtable 的报告必须自包含——读者不需要额外调查就能理解。

### 3. 不重复劳动
在开始工作前，先检查 meeting_room（以及你所在 team 的 roundtable）里是否已有相关信息。

### 4. 文件命名必须带 agent 名和精确时间戳
所有提交到 meeting_room / roundtable 的文件，命名格式为:
```
<Agent英文名>_<类型>_<YYYYMMDD>_<HHMM>_<简要描述>.md
```
时间戳必须精确到分钟 (HHMM)。

frontmatter 中的 `date` 字段也必须包含时间:
```yaml
date: 2026-04-11 15:30
```

### 5. Meeting room / Roundtable 保持干净
- `meeting_room/` 和各 `*_team/roundtable/` 中只保留 `OPEN` 和 `IN_PROGRESS` 状态的文件
- 任务变为 `RESOLVED` 后，由处理该任务的 agent 将文件移到对应层级的 `archive/` 目录（顶层文件→顶层 archive，部门文件→部门 archive）
- `archive/` 是历史记录，不删除，但不需要日常关注

### 6. 角色持久化
每个 agent 的 `README.md` 是角色记忆的锚点。上下文压缩后，通过读取它恢复角色认知。

### 7. 用户是项目负责人
任务分配和优先级由用户决定，agent 之间不直接指派任务（team lead 对自己 team 内 teammate 除外）。

- **记录决策来源**：把裁定或约定写进文件时，写明谁提议、谁批准；"谁决定的"引用原话，不转述。teammate 之间就契约、接口、字段达成的一致，在 lead 裁定前只是**提议**，记录时标为"提议（待 lead 裁定）"，不写成"X 已裁定"。
- **裁定改变前提时，说明哪些工作因此作废**：发出裁定的同一条消息里，写明因此不必再做的工作和受影响的人。

### 8. Meeting room / Roundtable 文件权限
- **归档权唯一归 issuer（`from`）**：只有文件的发布者（`from` 是你）才能将文件移至 archive。其他任何 agent 均**无归档权**，无论 `to` 是否指向自己。
- `to` 字段**明确指向你**的文件：你有权修改其 `status`（如改为 RESOLVED），但**不可归档**（由 issuer 归档）。
- `to: ALL` 的状态报告属于发布者，其他 agent 只读不改、不归档。
- 你自己提交的报告（`from` 是你），你可以自行管理（包括归档）。确认所有接收方均已标 RESOLVED 后才归档。
- **`cc` 字段**：若你在 `cc`（不在 `to`），该文件只供你知晓——**只读、不改 status、不归档**。
- **部门内 roundtable** 的文件权限同理，但 `from`/`to` 解析为 `<team>/<role>` 格式。
- **Team lead 的 roundtable 归档协调**：lead 是唯一会扫自己 roundtable 的角色（teammate 的 `/check-inbox` 不扫 roundtable），所以对**已完成却未归档**的 roundtable 文档——若 issuer 是在岗 teammate，lead **有权立刻通知该 issuer 去归档**（归档动作仍由 issuer 执行，权责不变）；若 issuer 已遣散，lead **核实状况后自行归档或转移文档所有权**。
- **违反此规则可能导致其他 agent 的工作状态丢失**

### 9. 任务跟踪 (TODO.md / ACTIVE_JOBS.md / COMPLETED_JOBS.md)

每个 agent 在**自己的工位目录下**维护三个任务跟踪文件：

- **`TODO.md`**: 待办事项
- **`ACTIVE_JOBS.md`**: 正在运行的任务（SLURM job、定时 tracker trigger 等）
- **`COMPLETED_JOBS.md`**: 已完成或已取消的任务历史记录

**⚠ 必须放在工位目录，不能放在 `~/.claude/tasks/` 下**：

- ✅ 正确路径：`_agent_team_work_zone/<你的工位>/TODO.md`（本地磁盘，持久化，跨 session 存活）
- ❌ 错误路径：`~/.claude/tasks/<session-id>/...`（Claude Code 的 **session-scoped** task list 存储——**当前对话一结束就消失**，长期 TODO 会彻底丢失）

**Claude Code 内置 `TaskCreate` / `TaskList` 能不能用**？能，但它只是**当前会话内的临时追踪**（例如"这一轮对话里顺序做的几件小事"），**不是**持久 TODO 的替代品。任何"跨 session 还要记得"的事，都**必须**落到工位的 `TODO.md` / `ACTIVE_JOBS.md` / `COMPLETED_JOBS.md` 里——只有工位目录下的 markdown 文件才有本地磁盘持久化。

**工作流**：TODO → 开始执行 → ACTIVE_JOBS → 完成/取消 → COMPLETED_JOBS

### 10. 积累工作笔记 (notes.md)
每个 agent 在自己的工位目录下维护一个 `notes.md` 文件，记录工作中积累的**重要且会重复使用的知识**：
- 项目目录结构的理解
- 常用的命令、路径、文件格式
- 踩过的坑和解决方式
- 对特定工作流程的经验总结

**怎么做**:
- 随时追加，按主题组织（非时间流水）
- 保持精简，只记录真正重复使用的知识
- 在自己的 README.md 的"上下文恢复"章节中，引导自己读取 notes.md

### 11. 善于提问
对于项目核心需求、目的、方向等非技术层面的问题，**鼓励主动提问**。错误的假设比多问一个问题代价大得多。

### 12. Team lead 节省 context window
如果你是 **team lead**（工位目录以 `_team` 结尾，含 `roundtable/`），你的 context window 专用于**协调**——组建团队、读 teammate summary、向用户汇报、跨 team 路由。你**不做**具体的编码/配置/测试等动手工作，那些交给 `/spawn-team` 产出的 teammate。

收到需要动手的任务时先判断：
- 能用几条消息搞定且不烧 context → 自己处理
- 超过 1-2 个文件或需要并行调研 → 组建 team

**原则**：宁可提前组建 team，不要等 context 爆了再抢救。

**对扁平工位**：rule 12 同样提醒你——如果你预见到一个任务会变复杂（需要多种专业技能、并行工作流、对抗性调研），**主动建议项目主管运行 `/promote-to-team`** 把你升级为 team lead，不要死扛。

### 13. Teammate 工位自维护 + checkpoint 义务

**如果你是 teammate**（工位在 `<team>/teammates/<你的名字>/`）：

- 你的工位下 5 个文件（`README.md` / `working-context.md` / `completed.md` / `TODO.md` / `commitments.md`）**只有你自己维护**。Lead 只读不改（rule #1）
- 每次任务完成、每次进入 idle 前、收到"run /checkpoint"提醒时、或 lead 要求时，必须调用 `/checkpoint` 更新 `working-context.md`
- **自动提醒（v0.2.3 起对 in-process 也生效）**：你距上次落盘超过 15 分钟还想 idle 时，`TeammateIdle` hook 会用 `exit 2` 拦住你、把"先跑 /checkpoint"的提醒直接喂给你，逼你落盘后再 idle。这条路绕开了旧链路认不出 in-process 身份的死结，所以**对 in-process 和 tmux 模式都有效**
- ⚠️ 但**别把自动提醒当唯一保险**：它最多每 15 分钟拦你一次，意外退出仍可能丢最多 ~15 分钟的活。checkpoint 仍是你的**主动义务**——重要进展做完就自觉写，别只等被拦
- `working-context.md` 是你**对未来自己（下一次 spawn 的你）**的交接文档。写得不好 → 下次的你恢复不了状态
- `commitments.md` 是你对别人的承诺。这里未完成的事，哪怕 `/checkpoint` 没写到 working-context，下一次的你也要看这个文件接手
- **保持可达**：队友的消息只在你的回合结束后送达。要盯作业时，用 `/loop` 排定唤醒，然后结束回合；不要在回合里等（shell `until … sleep` 循环，或一长串检查调用）——长时间阻塞的调用和一串短检查都会挡住消息，只有结束回合才能让消息进来。只结束回合、不排定唤醒，作业就没人盯了；用不了 `/loop` 时，结束回合前给 lead 发一句简短状态，由 lead 再 ping 你继续
- **派生/唤回时**：第一步先写 `teammates/<你的名字>/.started`（内容为当前时间），再读任何文件；回执（`Resumed…` / `Ready`）末尾加 `Model: <名称>, ID: <ID>`，照抄你系统提示里写的，没写就写 `Model: not stated`，不要猜

**如果你是 team lead**：

- `TEAMMATE_INFO.json`（在你工位根下）是你的**注册表**。`/spawn-team` / `/add-teammate` / `/remove-teammate` / `/bench-teammate` / `/reactivate-team` 会自动更新它，**你不要手改**
- Session 每次重启时（`claude --resume`）注意 `SessionStart` hook 的提醒——如果有 teammate，**立刻运行 `/reactivate-team`**（无参，只恢复 active/idle；benched 临时下线的会被跳过），不要假设它们自己回来了（**Claude Code 不会自动 respawn teammate**）
- **怀疑 teammate 已死时，先 ping 再下结论（实践中最常翻车的点）**：真实失败几乎从不是"用户误调 `/reactivate-team`"，而是 **lead 没当场确认、却以为 teammate 还活着**。任何静态信号——`SessionStart` hook 文案、`TEAMMATE_INFO` 的 `status:active`、inbox 旧消息、`config.json`——对"活/死"**都不是证据**；**几轮前的旧回执也不算**（回执是时间点信号、会过期，中间一次 teardown 就全废）。所以**每次**基于"活/死"做判断时（**包括"他们还活着、不用 reactivate"这种反向判断**），都要**当场重新 ping、绝不引用旧回执**：`SendMessage` 报 **`No agent named X addressable` = 确定死亡**（最快最硬的判据），成功进 inbox 但无回复 = 未知。**另注：context compaction ≠ session 重启**——压缩同进程、teammate 通常仍活，别被"Session restarted"骗（hook 已按 `source` 分文案，但仍以 ping 为准）
- **teammate 沉默时怎么判断、怎么做**：
  - **消息可能晚到数小时**（对方在一个长回合里、在等确认或权限提示等），没收到报告 ≠ 没干活。截止前只认报告，要问就 ping；截止已过且 ping 无回音，可查**已落地的状态**（`git log`、已完成的产物），**不读它正在写的工作文件**
  - **形如 `[to X] …` 的心跳摘要不是给你的报告**：那是它发给 X 的一条消息的摘要（lead 在自己收到的心跳里观察到过），不引用、不据此行动、不据此记录结论或推断原因；需要其中的信息就向它要原文
  - **不自动重派沉默的 teammate**：ping 成功进 inbox 却迟迟无回复 = 状态未知，可能是 (a) 在等一个确认或权限提示（分屏模式下可能是它面板里的启动确认界面；工具权限提示会出现在你（lead）的会话里，容易漏看），(b) 在一个长回合里（队友消息要等回合结束才送达），(c) 已死亡。先告诉用户并列出这三种可能，由用户确认后再处理；未经核实，不对用户断言是哪一种。（ping 报 `No agent named X addressable` 则按上一条，确定死亡）
  - **你自己要等时用 `/loop`**，不在自己的回合里等待——你的回合不结束，teammate 发来的消息同样排队
  - **派生/唤回后核对两样东西**：teammate 第一步写的 `teammates/<名字>/.started`，以及回执末尾的 `Model: <名称>, ID: <ID>`（用法见 `/spawn-team`、`/reactivate-team`）
- **给正在干活的成员发更正，合并成一条完整消息**：成员在回合中收不到任何消息——你连发的几条更正会在它回合结束时一起到达，那时它已经按旧指示做完了。更正要自成一体，写明"以本条为准"，等到它的回执再发下一条
- **临时下线（benched）与按需唤回**：在线 teammate 数量受 Claude Code 上限约束。某 teammate 阶段性用不上、或要腾在线名额时，用 `/bench-teammate` 把它临时下线（保留全量档案 + 工位，`status=benched`，**不**被无参 `/reactivate-team` 唤醒）。反过来，**在任何环节——尤其派活 / 开始某任务前——一旦你判断需要某个 benched 成员的专长，应当即向用户提议唤回**，经用户同意（或用户主动点名）后用 `/reactivate-team <name>` 单独唤回。状态表（active / idle / benched / offboarded）由你维护、**对用户是黑箱**——用户只在"提议—同意"层面参与，不接触状态字段、也不在任何清单里勾选
- **危险操作前主动让 teammate checkpoint**：自动提醒（`TeammateIdle` + exit 2）只在 teammate **自己即将 idle** 且距上次落盘 > 15 分钟时才触发，且最多挡住 ~15 分钟的丢失窗口。所以重启/关机/长时间挂起前，仍由你 `SendMessage` 逐个让 active teammate 跑 `/checkpoint` 并确认落盘——把自动提醒当兜底、不当唯一保险
- 不要修改任何 teammate 的工位文件（rule #1）。想让 teammate 做事 → `SendMessage`，不直接改文件

**为什么这条必须存在**：Claude Code 的 agent-teams 特性 **不跨 session 持久化 teammate 状态**。lead 重启后 teammate session 全部消失，只有靠 teammate 自己的 `working-context.md` + lead 的 `TEAMMATE_INFO.json` + `/reactivate-team` 三件套才能让 team 恢复。

**违反本条的代价**：teammate 状态丢失、lead 产生幻觉误以为 teammate 还在、team 协作彻底崩溃。

---
<!-- RULES:END -->

<!-- REFERENCE:START -->
## 预置 Skills

安装后可通过 `/skill名` 在对话中触发。部分 skill 允许 agent 自主调用（`disable-model-invocation: false`），部分只能由用户手动触发。

### 仅用户手动触发（`disable-model-invocation: true`）

| Skill | 命令 | 功能 |
|-------|------|------|
| onboard | `/onboard <描述>` | 新 agent 入职：开头询问扁平 or team lead，自动完成命名、建工位、注册成员表 |
| sync | `/sync` | 同步工作区变更 + 上下文压缩后的角色恢复 |
| check-inbox | `/check-inbox` | 检查顶层 meeting_room（所有人）+ 所在 team 的 roundtable（team lead），按时间顺序处理 |
| archive-resolved | `/archive-resolved` | 按守则 #8 将 RESOLVED 的 meeting_room / roundtable 文件移至对应 archive |
| handoff | `/handoff [--give\|--take]` | 任务交接：单 skill 双模式，交出方生成交接文档（含 why / 进度 / 上下文），接收方读取并吸收到自己的 TODO。把任务当成黑箱 |

### Agent 可自主调用（`disable-model-invocation: false`）

| Skill | 命令 | 触发方 | 功能 |
|-------|------|--------|------|
| promote-to-team | `/promote-to-team` | 扁平 agent 自主 | 扁平工位升级为 team lead：重命名目录、补齐 team 子结构、README 加 rule 12 和 lead 章节 |
| spawn-team | `/spawn-team` | team lead 自主 / 任何 agent（若是 flat 会先触发 promote） | 6 阶段结构化组建 team：任务分解、阵容提案、plan-mode gating、对抗性检查、用户确认、输出 spawn prompt + 保存 recipe |
| evaluate-team | `/evaluate-team` | team lead 自主 | 分析现有 team 效率：哪些 teammate 在忙、闲、缺角色、冗余 |
| add-teammate | `/add-teammate` | team lead 自主 | 在现有 team 中增加一个 teammate |
| remove-teammate | `/remove-teammate` | team lead 自主 | 让某个 teammate 下岗：优雅交接 + 归档产出 |
| bench-teammate | `/bench-teammate <name>` | team lead 自主 | 把某个 teammate 临时下线（benched）：最终 checkpoint + 关 session 腾名额，保留全量档案；日后 `/reactivate-team <name>` 唤回 |
| broadcast-rule | `/broadcast-rule` | team lead 自主（用户同意该规则变更后） | 把一条规则变更发给每个在线 teammate，记进本团队常设的 `RULES_LEDGER.md` 并跟踪确认；不在线的 teammate 在被唤回时补上 |

**重要**：`/evaluate-team`、`/add-teammate`、`/remove-teammate`、`/bench-teammate`、`/broadcast-rule` 只在 **team lead 上下文**中有效。若当前是扁平工位误调用，skill 会立即报警并拒绝执行。

### Claude Code 内置 skills（直接使用）

| Skill | 命令 | 用途 |
|-------|------|------|
| schedule | `/schedule ...` | 创建定时 remote agent（cron trigger），常用于 team lead 启动 tracker |
| loop | `/loop <interval> <prompt>` | 在当前 session 内按间隔重复跑一个 prompt（监控时定时唤醒，让 agent 在两次检查之间保持可达——见第 13 条） |

---

## 通用 Custom Subagents

位于 `.claude/agents/`（由 bootstrap 从 `resources/agents/` 同步而来）。这些是**项目全局通用**的 subagent，所有工位都能通过 `Agent` 工具或 team spawn 机制引用。

| Subagent | 模型 | 职责 |
|----------|------|------|
| git-repo-manager | sonnet | Git 仓库管理：分支、合并冲突、历史回顾、清理、tag |
| tracker | haiku | 按 cron 周期读取任务状态并写快照报告。**默认间隔：training 12h / eval 4h**。由 team lead 通过 `/schedule` 启动 |
| investigator | **opus**（别名，自动跟进最新旗舰版）| **针对"跑通了但结果反常"的深度假设驱动调研**（不是 runtime error debug）。只读。用旗舰模型因为需要深度推理 |
| reviewer | sonnet | 按 checklist 评审 diff/文件，分级输出（blocker/suggestion/nit）。只读 |
| devil-advocate | **opus**（别名，自动跟进最新旗舰版）| 对抗性挑战一份计划：找反例、质疑假设、列失败路径。每次 fresh（不积累 memory）。用旗舰模型因为需要最强批判性思维 |

---

## 角色原型速查

位于 `resources/role_archetypes/`。这些是 **team lead 在 `/spawn-team` 时参考的模板**——**不由 Claude Code 自动加载**，**不是 subagent 定义**。粒度介于"通用 subagent"和"项目特定 teammate"之间，帮助 team lead 快速起草 spawn prompt。

详见 `resources/role_archetypes/README.md`。

---

## 团队创建的角色定义存储（三层）

当 team lead 用角色原型组建 team 时，生成的具体 teammate 定义有三种存放方式：

| Tier | 位置 | 何时用 | 命名 |
|---|---|---|---|
| **1（默认）** | inline 在 spawn prompt 里 + `<team>/team_recipes/<timestamp>_<slug>.md` 审计 | 一次性任务，不跨任务复用 | 无前缀 |
| **2（偶尔）** | `<team>/teammates/<role>.md` | 团队内多次复用同一定制角色 | 无前缀（目录隔离） |
| **3（罕见）** | `.claude/agents/<team>_<role>.md` | 希望 Claude Code 自动加载，可全局引用 | **必须带 team 前缀** 以避免跨 team 冲突 |

默认路径是 Tier 1——这样 `.claude/agents/` 始终干净，只包含全局通用的 5 个 subagent。Tier 3 只在极少数跨 team 引用场景使用。

---

## Troubleshooting

- **Claude Code 版本太旧**：`bootstrap.sh` 会报错退出。升级到 ≥ v2.1.178，然后在项目目录下运行 `bash _agent_team_work_zone/resources/scripts/bootstrap.sh`（`npx agent-team-work-zone init` 不会再次运行，因为 `_agent_team_work_zone/` 已经在了）；或改用 [release v0.1.0](https://github.com/SR-A-W/agent-team-work-zone/releases/tag/v0.1.0)
- **`.claude/skills/` 下找不到某个 skill**：在项目目录下重新运行 `bash _agent_team_work_zone/resources/scripts/bootstrap.sh`；确认源文件在 `resources/skills/<name>/SKILL.md`
- **skill 修改后不生效**：Claude Code 在 session 启动时加载 skills。重启 session 或用 `/agents` 命令刷新
- **切勿直接编辑 `.claude/skills/` 或 `.claude/agents/`**：这些是运行时派生物，下次 bootstrap 会被覆盖。**源在 `resources/`，只编辑源**
<!-- REFERENCE:END -->
