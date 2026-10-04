[English](README.md) | **中文**

# Agent Team Work Zone

[![arXiv](https://img.shields.io/badge/arXiv-2607.22917-b31b1b.svg)](https://arxiv.org/abs/2607.22917)
[![License](https://img.shields.io/badge/License-see%20LICENSE-lightgrey.svg)](./LICENSE)
[![Developed with](https://img.shields.io/badge/Developed%20with-AT%20WorkZone-6f42c1.svg)](https://github.com/SR-A-W/agent-team-work-zone)

> 面向 Claude Code 及其 Agent Teams 的持久化管理层。

**太长不看?** 👉 [直接跳到 Quick Start](#quick-start) 开始用。

> 📄 **设计手册。** ATWZ 附有一份面向开发者的详细设计手册——阐述其设计与理念、场景演示,以及对失败模式与局限的分析。**[在 arXiv 上阅读](https://arxiv.org/abs/2607.22917)**。

Claude Code 让启动强大的 agent 变得很容易。但当工作的规模和周期超出单个对话能承载的范围，几个现实问题就会浮现——其中最致命的一条，Claude Code 原生完全无解：**teammate 一旦随进程消失，就再也找不回来**。**Agent Team Work Zone 正是为此而生：它把分散、易断的 agent 工作，组织成一个持久、可恢复、可审计的团队。** 它要消除的痛点：

- **Claude Code Agent Team 模式下的 teammate agent，其 session 跨不过进程重启、且原生无法恢复。** Claude Code 的 Agent Teams 不持久化 teammate 的 session：当 Claude Code 进程停止时(比如经常发生的 SSH 断连、或运行它的终端被关闭)，**整个团队连同各自积累的工作状态一起消失，原生没有任何办法找回**;你只能从零重新组队、重新交代。
- **`/compact` 之后，细节会流失。** 压缩把对话浓缩成摘要，agent 对"自己是谁、在干什么、欠了什么"的把握**可能**随之变模糊。
- **随手堆叠 agent 对话，会积累看不见的"agentic 技术债"。** 一开始能跑，但久了：决策被困在压缩掉的旧对话里、改动归属不清、任务被遗弃、agent 之间重复劳动、没有"当初为什么这么做"的审计轨迹——项目越往后越难维护和复盘。
- **跨对话接力的任务，委派要反复手写长 prompt。** 当一个任务需要在多个对话之间传递时，你每次都得把背景、目标、约束重新交代一遍。

**Agent Team Work Zone** 在 Claude Code 原生 Agent Teams 外围加了一层**基于文件系统的操作层**，把上面这些痛点逐一接住：每个 teammate 持续把状态落盘成**检查点**，团队中断后一条命令即可从断点**重新激活**——**让"长期常驻、跨越数天乃至数周的 agent team"终于变得实际可用**;角色、笔记、待办与往来都成了文件，既不随 `/compact` 流失，也为每个决定留下审计轨迹，把"agentic 技术债"压到最低;跨对话的协作走结构化的交接与报告包，不必每次重写长 prompt。它把零散、易断的 agent 对话，变成一个**持久、可恢复、可审计**的项目团队;而你始终**在环中**参与分工与文档化。

> 逐条对照(短板 → 我们如何补足)见下方[《它补足了 Claude Code 的哪些短板》](#它补足了-claude-code-的哪些短板)。

---

## 它补足了 Claude Code 的哪些短板

直接用 Claude Code，会在下面这些地方力不从心;Agent Team Work Zone 逐一补足：

| 直接用 Claude Code 的不足 | Agent Team Work Zone 如何补足 |
|---|---|
| Agent Team 模式下的 teammate session 跨进程重启不持久，断了就全没 | 持久化的 team 工位 + teammate 工位，可从检查点逐个重建 |
| `/compact` 压缩后细节流失，agent 的角色与状态只剩摘要 | 角色定义、笔记、检查点、TODO 都落盘成文件，不随压缩丢失 |
| 普通对话之间无法互发消息(只能手动复制);团队内消息也不留存 | Meeting room 异步文件协议 + roundtable 记录，跨工位 / 跨 session / 跨 team 留痕沟通 |
| 任务状态只活在单个 session 里 | 跨 session 的 TODO / ACTIVE / COMPLETED 文件 |
| 跨对话接力的委派只能每次重新手写长 prompt，无结构 | 结构化的交接和报告包 |
| Agent 做过什么不留痕、决策淹没在旧对话里(agentic 技术债) | 审计轨迹 + 文件化的待办/进行中/已完成;加上你在环中参与分工与文档化，债务持续可控 |

---

## 核心想法：把 agent 当真实员工来组织

没有这一层时，大多数人要么把所有任务都堆在同一个对话里，要么开了一堆 agent 对话却分工不细、各自为战、难以管理。

Agent Team Work Zone 把这些 agent 当作**真实的员工**来对待。在这一层之下，Claude Code 的 agent session 被组织成两种形态：

### 🧑‍💼 普通员工(扁平工位)
一个被"员工化"的普通 Claude Code 对话 session = 一名员工：有明确**角色**、独占一个**个人工位**(一个持久目录，作为它的外部工作笔记)。它就是日常和你对话的那个 agent，只是多了一块属于自己的持久工作区。普通对话之间无法互发消息，所以扁平员工之间靠 **meeting room** 做[异步协作](#6-用-meeting-room-让两个-agent-协作)。

### 👥 员工团队(Agent Team 模式)— **强烈推荐**
对稍有复杂度的项目，我们**强烈建议用 team 模式**。一个团队 = 一个 **team lead** + 若干 **teammate**：

> **一个 team 对应一个复杂任务，一个项目可以有多个 team。** 通常用**一个 agent team 去啃项目里某一个较复杂的任务或功能**，而不是指望一个 team 包打整个项目;一个项目可以并行存在**多个 agent team**，不同 team 之间同样通过 meeting room 做[异步协作](#6-用-meeting-room-让两个-agent-协作)。

- **Team lead** 是一个**启用了 Claude Code 内置 Agent Team 功能**的 agent session，负责协调——拆解任务、路由、review、综合汇报，而**不是**把自己的 context window 烧在具体实现上。它拥有一个**团队工位**(`*_team/`)。
- **Teammate** 是由该 Agent Team 功能**自动生成**的专门 worker，各有自己的个人工位，**无需你手动创建或管理**。原生 Claude Code 里，这些 teammate 会随 team lead 的进程终止而**全部消失**;本操作层用检查点解决了这个痛点，**让"长期存续的 team"真正可用**。
- 团队模式下，**lead 和 teammate、teammate 与 teammate 之间可以实时对话**——不依赖隐藏的聊天记忆。**Roundtable** 是这些沟通的**文档化记录与补强**(便于审计与恢复)，而不是唯一的沟通渠道。
- 团队模式才解锁的能力：
  - **检查点(Checkpoint)** — 每个 teammate 定期把工作状态落盘，让未来任何一次 spawn 都能从上次停下的地方继续(团队中断后能恢复，全靠它)。
  - **重新激活(Reactivate)** — 一条命令从检查点重建整个团队。
  - **团队注册表 + 交接 + 归档** — 谁在岗、任务交给谁、做完归到哪，全程留痕。

> 个人有个人工位，团队有团队工位。已完成的工作会被**归档**以供审计。

---

## 关键原语

**工位(Workstation)** — 任何一个"员工化"的 agent 独占的持久目录，是它的外部工作笔记：角色定义、笔记、任务列表、当前工作上下文、已完成历史。下面两类角色各有自己的工位。

**普通员工(扁平工位)** — 一个被员工化的**普通 Claude Code 对话 session**：有角色、有个人工位，就是日常和你对话的那个 agent，只是多了块持久工作区。它**没有**启用 Agent Team 功能，因此靠 meeting room 与他人异步协作。

**Team Lead** — 一个**启用了 Claude Code 内置 Agent Team 功能**的 agent session，拥有 `*_team/` 团队工位。负责拆解任务、生成(spawn)teammate、协调 roundtable、向你汇报，自己不做实现。**这通常就是你正在对话的主 session**。

**Teammate** — 由 Claude Code 内置 Agent Team 功能**自动生成**的专门 worker，工位在 `<team>_team/teammates/<name>/`，**无需你手动创建或管理**。维护自己的检查点、TODO、承诺和已完成日志，通常由 team lead 指挥(你也可以直接和它对话)。

**Meeting Room** — 顶层异步沟通空间，供所有扁平员工和 team lead 使用。注意它**不会自动同步、是纯异步的**：消息不会自己送达——你需要**指定 A agent 把文档留给 B agent**，再**让 B agent 调用 `/check-inbox`** 去读取留给它的文档。

**Roundtable** — team 内部沟通空间，仅供 team lead 和它的 teammates 使用(实时对话的文档化补强，非唯一渠道)。

**Checkpoint(检查点)** — 每个 teammate 写下的结构化状态快照，让未来 spawn 的实例能恢复"上个 session 知道的事"和"还欠的事"。

**Team Registry** — 由 team lead 维护的 `TEAMMATE_INFO.json`，驱动 reactivation 流程。

---

## Quick Start

> **Claude Code 版本**：Agent Team Work Zone 要求 **Claude Code ≥ 2.1.178**——它适配 2.1.178 的 agent-teams API(自动会话级 team;`TeamCreate`/`TeamDelete` 已移除)。若你的 Claude Code **≤ 2.1.177**，请改用 **[release v0.1.0](https://github.com/SR-A-W/agent-team-work-zone/releases/tag/v0.1.0)**(针对旧 agent-teams API)。安装脚本也会强制这条下限。

> **平台支持**：目前支持 **Linux** 和 **macOS**。安装/升级脚本和运行时 hook 基于 bash;**Windows 暂不支持**(原生 Windows 无 bash，原生化在 roadmap 上、计划于下一个大版本提供)。Windows 用户当前可借助 WSL 运行。

### 1. 前提

- **Node.js 18 或更高版本**（只用来运行安装程序）
- **bash**：Linux、macOS 或 Windows 上的 WSL（不支持原生 Windows）
- **jq**（配置步骤用它把框架的 hook 写进 `.claude/settings.json`，没有它会停下）
- **Claude Code 2.1.178 或更高版本**

### 2. 安装到你的项目

在你的项目目录下（目录须已存在）：

```bash
cd /path/to/your/project
npx agent-team-work-zone init --lang zh     # 英文版用 --lang en
```

- 它把 `_agent_team_work_zone/` 放进你的项目，并运行其中的安装脚本。也可以不进入项目目录、直接给出路径：`npx agent-team-work-zone init /path/to/your/project --lang zh`。
- 不给 `--lang` 时，在终端里会弹出语言菜单，否则使用英文版。
- 项目里已有 `_agent_team_work_zone/` 时它会停下，不覆盖。要更新已有的安装，见下文「把框架升级到最新版」。
- 项目里已有 `.claude/` 目录时，安装会合并进去：你自己的 skill 和 agent，名字与框架不同的保留；与框架同名的会被框架的版本替换，而且没有备份，请先改名或自行备份。其他事件上的 hook 保留，但在 `SessionStart`、`TeammateIdle`、`SessionEnd` 三个 hook 事件上，框架的 hook 会替换你原有的（替换前先备份 `settings.json`）。怎么把自己的 hook 加回去，见[用户手册](claude_code/zh/_agent_team_work_zone/docs/user_manual.md)。
- 偶尔用一次，就用 `npx agent-team-work-zone <命令>`；经常用的话，先 `npm i -g agent-team-work-zone` 装一次，之后用更短的 `atwz <命令>`（例如 `atwz init --lang zh`）。

> [!IMPORTANT]
> **`_agent_team_work_zone/` 必须放在项目目录里，并且永远在这个目录下启动 Claude Code**——也就是*包含* `_agent_team_work_zone/` 的那个目录。
>
> 常见错误：登录 HPC 集群（或任何服务器）后直接在 home 目录里启动 `claude`，而 work zone 却在某个项目文件夹里。这样会：
> - 项目 `.claude/` 里的 hooks 和设置不会生效，skills 在启动时也用不了；
> - 工位（每个 agent 在 work zone 里的目录）路径从项目根目录解析，checkpoint 和唤回（`/reactivate-team`）会去错的地方找；
> - teammate 从 lead 当前所在的目录启动——lead 在错的目录里运行（或它的 shell 切到了某个子目录），派生出的 teammate 也从那里启动，相对路径随之失效。
>
> 所以：先 `cd /path/to/your/project`，再运行 `claude`。把 home 目录本身当作项目也可以——只要 `_agent_team_work_zone/` 就在 home 目录下，并且在那里启动 Claude。但我们依然强烈推荐：在项目目录下使用该项目专有的 agent team work zone，并为它单独启动一个 Claude Code session。

#### 从源码安装（另一种方式，不需要 Node.js）

```bash
git clone https://github.com/SR-A-W/agent-team-work-zone.git
cp -r agent-team-work-zone/claude_code/zh/_agent_team_work_zone /path/to/your/project/   # 英文版用 claude_code/en/
cd /path/to/your/project
bash _agent_team_work_zone/install.sh
```

> **复制这一步不想用命令行？** 直接在文件管理器（Finder / Nautilus 等）里操作：进入 clone 下来的仓库，把 `claude_code/zh/_agent_team_work_zone`（或 `en/` 版）整个文件夹**复制**，**粘贴**到你的项目根目录下，再运行上面 `install.sh` 那一行。

### 3. 安装程序做了什么

安装程序把 skills 和 agent definitions 装进 `.claude/`，并启用所需的 Claude Code 设置。首次安装时它还会检查 git：项目不在 git 仓库里，或在仓库里但不在仓库根目录，会提醒你；在仓库根目录时会询问是否用 git 跟踪 `_agent_team_work_zone/`（默认是，推荐）。选"否"会把 `/_agent_team_work_zone/` 加进项目的 `.gitignore`，以后改主意删掉这一行即可。它还会提供两个可选的 `CLAUDE.md` 段落：给你的消息格式，以及平实用语规则；默认都会加入。所有提问都是菜单（方向键加回车）；没有终端时不提问。

#### 把 `_agent_team_work_zone/` 纳入 git 管理（强烈推荐）

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

### 4. 启动一个 agent 并让它入职

在你的项目目录里直接进入 Claude Code：

```bash
claude
```

然后让 agent 入职：

```
/onboard 帮我复现这个 github repo 中的实验
```

> `/onboard` 后面跟的是一句**你这个项目要干什么**的描述——上面只是个例子，按你的真实需求写即可。Skill 会先问你该建成扁平工位还是 team lead，然后自动创建正确结构。**对有复杂度的项目，在这一步选择/让它组建 team**。

### 5. 让团队开干(检查点全自动)

通常在 `/onboard` 过程中，team lead 就会按你的决定把团队组建好。让它开始干活即可——lead 会拆解任务、提出 teammates、保存 recipe 并 spawn workers。

> **极少数情况**：如果 `/onboard` 没建 team，你只要对 team lead 说一句"建个团队来做 X"，它就会调用 `/spawn-team`(你也可以自己调，但一般不需要)。

> **省心提示**：在 agent team 模式下，建议把 Claude Code 切到 **"auto mode"(自动批准)** 运行——teammate 干活会频繁触发逐条 permission 确认，auto mode 能免去这一大堆批准。安装脚本会问你是否把它设为默认(`permissions.defaultMode:"auto"`，默认开、强烈推荐);你也可随时用 `Shift+Tab` 切换。

**关于检查点——你不用管。** teammate 不需要你手动操作落盘：本操作层用 hook 保证**每个 teammate 在进入 idle 前自动写检查点**(默认间隔 15 分钟)。检查点记录的是这个 teammate 的"当前态快照 + 近期工作日志"——它在做什么、做到哪、和谁达成了什么、还欠什么。**正是这些自动落盘的检查点，让团队在 session 中断后还能被恢复。**

### 6. 用 meeting room 让两个 agent 协作

当两个**分属不同对话**的 agent 需要协作时(例如两个 team lead)，走 meeting room 这条异步通道。**它不会自动同步**，要你手动撮合：

1. **让发送方留文档**——在 agent A 的对话里说，例如："把这个结论写成一份文档放到 meeting room，留给 B。" A 会在 `_agent_team_work_zone/meeting_room/` 下生成一份标了 `to: B` 的 markdown。
2. **让接收方收取**——切到 agent B 的对话，运行 `/check-inbox`。B 会扫描 meeting room、挑出 `to: B` 的文档逐条处理，完成后把文档状态标为 `RESOLVED`。
3. **让发起方归档**——`/check-inbox` 还负责归档：回到**发起方 A** 的对话再调一次 `/check-inbox`，A 作为该文档的发起者，会把已 `RESOLVED` 的文档归档，保持 meeting room 干净。

> team lead 调 `/check-inbox` 时还会额外扫自己 team 的 roundtable;扁平 agent 只扫顶层 meeting room。

### 7. Resume 并重新激活 team

下次回来，正常进入 Claude Code 的 resume 流程后，在对话里：

```
/reactivate-team
```

Lead 会用团队注册表和各 teammate 的检查点，把团队恢复到上次的操作状态。

### 把框架升级到最新版

在你的项目目录下：

```bash
npx agent-team-work-zone@latest upgrade
```

- 全局安装的：先 `npm i -g agent-team-work-zone@latest`，再 `atwz upgrade`。
- 从源码安装的：`bash _agent_team_work_zone/upgrade.sh` 仍然可用（它会从 GitHub 下载最新版本）。
- 只更新框架自身的文件，并刷新 `.claude/` 里的 skills 和 hooks。agent 的工作内容不受影响：它们的 checkpoint、工作日志和待办，meeting room 里的文档，团队登记表和 `settings.conf` 都保持原样。（框架在每个 agent 的 README 里维护的那段守则会更新。）
- 升级到新的大版本时会要求你确认。没有终端时加 `--yes`（用 `upgrade.sh` 时设置 `ATWZ_ASSUME_YES=1`）。
- 升级不会再问安装时的那些问题：成员显示方式和 Auto 权限模式保持现有设置，也不会追加可选的 `CLAUDE.md` 段落。
- **每次升级之后，都要重启 Claude Code 会话，并对每个正在运行的团队执行 `/reactivate-team`。** 已经在运行的会话和成员，可能仍在用启动时加载的旧版 skill：我们实际遇到过，升级之后正在运行的成员仍照旧版 `/checkpoint` 的步骤执行，直到重新启动才改过来。

在你的项目里启动 Claude Code 会话时，如果已有更新的版本发布，会显示一条简短提示，附带上面的命令。版本查询在后台进行，每天最多一次，不会拖慢会话启动。查到新版本后，从下一次会话启动起开始提示，之后每次启动都会提示，直到你升级。查询失败时沿用上次查到的版本；如果从未查询成功过，就什么也不显示。要关闭这条提示：设置 `ATWZ_UPDATE_CHECK=0`，或创建文件 `_agent_team_work_zone/.no_update_check`（把它提交进仓库，就对项目里所有人关闭）。

#### 之后修改设置

想改掉之前的选择、把项目搬到另一台机器之后，或补上当初跳过的可选 `CLAUDE.md` 段落，在项目目录下运行：

```bash
npx agent-team-work-zone reconfigure        # 全局安装的也可以用：atwz reconfigure
```

它在你已经安装的版本上重新询问安装时的问题，不升级、也不重装。细节（包括从源码安装时用的命令）见[用户手册](claude_code/zh/_agent_team_work_zone/docs/user_manual.md)。

---

## 预置 Skills

### 用户主动调用的 Skills(按通常使用频率排序)

| Skill | 用途 |
|---|---|
| `/reactivate-team` | 在 resume 后从检查点恢复整个团队 |
| `/check-inbox` | 处理发给该 agent 的 meeting room / roundtable 消息 |
| `/onboard` | 为新 agent 创建扁平工位或 team lead 工位 |
| `/sync` | 压缩后恢复角色上下文并检查 inbox |
| `/handoff` | 把任务上下文从一个 agent 转交给另一个 |
| `/promote-to-team` | 把扁平工位升级为 team lead |

### Agent 自动调用的 Skills(你通常不需要主动调用)

| Skill | 用途 |
|---|---|
| `/checkpoint` | (由 hook 自动触发)更新 teammate 的可恢复工作上下文 |
| `/spawn-team` | 结构化 6 阶段流程组建 teammate 群组 |
| `/add-teammate` | 给现有 team 添加新 teammate |
| `/remove-teammate` | 用交接和归档纪律退役一个 teammate |
| `/bench-teammate` | 把某 teammate 临时下线以腾出在线名额，日后可唤回 |

---

## 什么时候用它：越复杂、越长期的项目越值得

**最适合高复杂度的项目。** 项目越大、越长、角色越多、越需要可追溯，这一层的价值越高。具体来说，适合：

- 跨多个 session 的持续项目
- 有多个专门角色的 agents
- 你关心谁做了什么、为什么做
- Context 压缩曾造成工作丢失
- 任务需要交接、跟踪或定期状态报告

---

## 设计原则

**专属化的笔记与记忆，胜过泛泛的聊天上下文。** Claude Code 自带记忆系统，但聊天上下文往往不够具体、不够 specific。把"未来的 agent 需要知道的事"明确写进工位文件，比依赖泛化的对话记忆更可靠、更精准。

**工位即工作笔记。** 工位文件是 agent 的外部工作本：当前理解、局部知识、踩过的坑、未完成的承诺和恢复入口。

**自动落盘，不靠自觉。** teammate 的工作状态由 hook 定期**自动** checkpoint(默认进入 idle 前、约每 15 分钟一次)，不依赖任何人记得手动保存——这正是团队能在意外中断后被恢复的底层保证。

**人在环中(human-in-the-loop)，技术债更轻。** 角色定义与分工由你和 agent 一起敲定，因此不只是 agent 之间职责清晰，你对它们各自在做什么也心里有数;跨 session 的 meeting room 异步协作也由你主持——你指派谁给谁留文档、让谁就某个项目问题落一份说明——这些人工介入进一步压低了 agentic 技术债。

**低耦合。** 每个 agent 只拥有自己的工位。永远不直接编辑别人的文件——跨工位协作通过 meeting room 或 roundtable 进行。

**报告即 prompt。** 一份好的 agent-to-agent 报告本质上就是一个高质量 prompt packet：发生了什么、试过什么、什么失败了、改了什么、接下来需要什么、相关文件在哪里。

**Team lead 负责协调。** Context window 应该用于任务拆解、路由、review 和综合汇报——而不是实现工作。

---

## 文档

- [用户手册](claude_code/zh/_agent_team_work_zone/docs/user_manual.md) — 入门指南、skills 参考、工作流模式
- 技术报告 — *(规划中，敬请期待)*

---

## 一句话总结

**Agent Team Work Zone 是面向 Claude Code 及其 Agent Teams 的持久化管理层：它给 AI agents 提供角色、工位、工作笔记、报告、交接、检查点和审计轨迹，让项目中的 multi-agent 工作流在 compact、session 中断和 resume 之后仍能重建知识并继续推进工作。**

## 致谢

`CLAUDE.md` 的 **Coding Engineering Principles** 一节，在 MIT License 下逐字引用了 [multica-ai/andrej-karpathy-skills](https://github.com/multica-ai/andrej-karpathy-skills) 的编码准则（基于 Andrej Karpathy 对 LLM 编码陷阱的观察）。
