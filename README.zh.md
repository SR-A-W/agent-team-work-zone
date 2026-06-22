[English](README.md) | **中文**

# Agent Team Work Zone

> 面向 Claude Code 及其 Agent Teams 的持久化管理层。

**太长不看?** 👉 [直接跳到 Quick Start](#quick-start) 开始用。

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

> **Claude Code 版本**：本发行版(**v0.2.0**)要求 **Claude Code ≥ 2.1.178**——它适配 2.1.178 的 agent-teams API(自动会话级 team;`TeamCreate`/`TeamDelete` 已移除)。若你的 Claude Code **≤ 2.1.177**，请改用 **[release v0.1.0](https://github.com/SR-A-W/agent-team-work-zone/releases/tag/v0.1.0)**(针对旧 agent-teams API)。安装脚本也会强制这条下限。

> **平台支持**：目前支持 **Linux** 和 **macOS**。安装/升级脚本和运行时 hook 基于 bash;**Windows 暂不支持**(原生 Windows 无 bash，原生化在 roadmap 上、计划于下一个大版本提供)。Windows 用户当前可借助 WSL 运行。

### 1. 获取模板

```bash
git clone https://github.com/SR-A-W/agent-team-work-zone.git
```

### 2. 复制到你的项目

把模板目录复制进你的项目根目录即可：

```bash
cp -r claude_code/zh/_agent_team_work_zone /path/to/your/project/   # 中文版——跑这一行
# 想用英文版的话，改跑这一行：
# cp -r claude_code/en/_agent_team_work_zone /path/to/your/project/
```

> **不想用命令行?** 直接在文件管理器(Finder / Nautilus 等)里操作：进入 clone 下来的仓库，把 `claude_code/zh/_agent_team_work_zone`(或 `en/` 版)整个文件夹**复制**，**粘贴**到你的目标项目根目录下，效果完全一样。

### 3. 安装

```bash
cd /path/to/your/project
bash _agent_team_work_zone/install.sh
```

脚本会把 skills 和 agent definitions 安装到 `.claude/` 目录，并启用所需的 Claude Code 设置。

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

想把 Agent Team Work Zone **框架本身**升级到最新版(拉取最新的 skills / hooks / 文档，并自动过一遍迁移)时，在项目根目录运行：

```bash
bash _agent_team_work_zone/upgrade.sh
```

它只更新框架文件，**不会动你 agent 工位里的工作内容**。

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
