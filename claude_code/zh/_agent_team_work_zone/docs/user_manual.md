# 用户手册 — `_agent_team_work_zone/`

## 这是什么

`_agent_team_work_zone/` 是一套**多 agent 协作工作区模板**，专为 Claude Code 的 **Agent Teams 实验性特性**设计。它让你可以：

- 为简单任务用**单人扁平工位**（Secretary、GitKeeper 等）
- 为复杂任务用 **team lead + team 办公室**，由 lead 组建 3~5 人的 Claude Code agent team 并行工作
- 通过**文件系统驱动**的 meeting_room 和 roundtable 实现异步沟通和持久审计
- **对人类用户是黑盒**：你用自然语言交互，agent 自主决定何时升级、何时组建 team、何时调用定时 tracker

---

## 平台支持

| 平台 | 安装 / 升级 | 运行时持久化 | tracker 定时 |
|---|---|---|---|
| **Linux** | ✅ `npx agent-team-work-zone`（或 `install.sh` / `upgrade.sh`）| tmux + `/loop` | teammate + `/loop` |
| **macOS** | ✅ `npx agent-team-work-zone`（或 `install.sh` / `upgrade.sh`；与 Linux 同一脚本，已验证零阻断）| tmux / iTerm2 split-pane / in-process | Desktop Scheduled Tasks |
| **Windows**（原生）| ⏳ 下一个大版本 | in-process（弱持久）| Desktop Scheduled Tasks |
| **Windows + WSL** | ✅ 走 Linux 路径 | tmux 在 WSL 内 | teammate + `/loop` |

**为什么 macOS 同一套脚本就行**：所有 `.sh` 用 `#!/usr/bin/env bash`（自动选 Homebrew bash if 装了，否则降级 `/bin/bash 3.2` 也可），用户路径无 bash 4+ 特性。`stat -c %Y` 双写了 BSD 兜底 `|| stat -f %m`，无 `sed -i` / `date -d` / `grep -P` 等 GNU-only 构造。依赖（`curl` / `tar` / `git` / `bash`）macOS 自带。

**原生 Windows 推迟**的原因：3 个运行时 hook（`session_start_check.sh` / `teammate_idle_checkpoint.sh` / `session_end_final_checkpoint.sh`）必须 PowerShell 化，工作量大；下一个大版本（v2.x）做。**WSL 用户现在就能用**——把模板放在 WSL 内的项目里，按 Linux 路径走即可。

---

## 快速开始

### 1. 安装

**前提：** Node.js 18 或更高版本（只用来运行安装程序）；bash——Linux、macOS 或 Windows 上的 WSL（不支持原生 Windows）；`jq`（配置步骤用它把框架的 hook 写进 `.claude/settings.json`，没有它会停下）；Claude Code 2.1.178 或更高版本。

#### 用 npm 安装（推荐）

在你的项目目录下（目录须已存在）：

```bash
cd /path/to/your/project
npx agent-team-work-zone init --lang zh     # 英文版用 --lang en
```

- 它把 `_agent_team_work_zone/` 放进项目，并运行其中的配置脚本（`bootstrap.sh`，见下文）。也可以不进入项目目录、直接给出路径：`npx agent-team-work-zone init /path/to/your/project --lang zh`。
- 不给 `--lang` 时，在终端里运行会询问用哪种语言，否则使用英文版。
- 项目里已有 `_agent_team_work_zone/` 时它会停下，不覆盖。要更新已有的安装，见下文「升级」。
- 想用更短的命令：先 `npm i -g agent-team-work-zone` 装一次，之后用 `atwz init --lang zh`。不安装也可以用 `npx atwz init …`。全局只装 `agent-team-work-zone` 这一个包，不要再全局安装单独的 `atwz` 包：两者都提供 `atwz` 命令。
- **项目里已有 `.claude/` 目录时**，安装会直接合并进去，不询问。框架的 skill 和 agent 按名字新增或更新：你自己的 skill 和 agent，名字与框架不同的保留；与框架同名的（例如 `checkpoint`、`reviewer`）会被框架的版本替换，而且没有备份，安装前请先改名或自行备份。`.claude/settings.json` 会合并：在 `SessionStart`、`TeammateIdle`、`SessionEnd` 这三个 hook 事件上，框架的 hook 会替换你原有的；其他事件上的 hook 保留。如果你在这三个事件上原本有自己的 hook，合并前会先把 `settings.json` 复制为 `.claude/settings.json.bak.<UTC 时间>`，并打印这个路径。想继续用自己的 hook：从备份里把这三个事件上你自己的条目，加回新 `settings.json` 里同一事件的列表中。下一次升级会再次替换这三个列表（并另做一份备份），所以每次升级后都要重新加回。
- **安装中途停下时**（安装的配置步骤失败），`_agent_team_work_zone/` 会保留。按提示解决问题后，在项目目录下运行 `bash _agent_team_work_zone/resources/scripts/bootstrap.sh` 完成安装；再运行一次 `init` 会停下，因为工作区已经在了。常见的一种情况是没有装 `jq`：先装上（例如 `sudo apt install jq` 或 `brew install jq`），再运行上面那条命令。

#### 从源码安装（另一种方式）

```bash
# Clone 仓库
git clone <repo-url>
cd agent-team-work-zone

# 把中文 team 模板复制到你自己的项目根目录
cp -r claude_code/zh/_agent_team_work_zone /path/to/your/project/
cd /path/to/your/project

# 一键 bootstrap
bash _agent_team_work_zone/resources/scripts/bootstrap.sh
```

这里直接运行 `bootstrap.sh`，它合并进已有 `.claude/` 的方式与 npm 安装相同（见上文）。`bash _agent_team_work_zone/install.sh` 效果一样，但 `.claude/` 里已有内容时会先询问 `Install into the existing .claude/? [y/N]`；回答否或没有终端时，`.claude/` 保持不变，并打印日后完成安装用的 `bootstrap.sh` 命令。

> 英文版稍后由 Translator 生成。

> **⚠️ Claude Code 版本要求（本模板）**：本模板适配 **Claude Code 2.1.178** 的 agent-teams API（会话级自动 team、`TeamCreate`/`TeamDelete` 已删、`Agent` 的 `team_name` 被忽略），要求 **CC ≥ 2.1.178**。如果你的 Claude Code ≤ 2.1.177，请改用 **[release v0.1.0](https://github.com/SR-A-W/agent-team-work-zone/releases/tag/v0.1.0)**（针对旧 API）。

Bootstrap 会：
- 检查 Claude Code 版本 (>= v2.1.178)；不达标直接退出并指向 release v0.1.0
- 检查 tmux（**强烈推荐，非必需**——见下方说明；不装则用 in-process 兜底）
- 同步 skills + agents 到 `.claude/`
- 创建或合并 `.claude/settings.json` 启用 `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`
- 首次安装时检查 git：项目不在 git 仓库里，或在仓库里但不在仓库根目录，会提醒你。在仓库根目录时会询问是否用 git 跟踪 `_agent_team_work_zone/`（默认是，推荐）；选"否"会把 `/_agent_team_work_zone/` 加进项目的 `.gitignore`，以后改主意删掉这一行即可。没有终端时不询问，也不做任何改动。

> **💡 强烈推荐把 Claude Code 跑在 tmux 里**（不限 HPC，本地同样受益）：关终端 / SSH 断连时，tmux 保住 Claude Code 进程不被杀、session 不中断——**你回来 `tmux attach` 就接着干，省去频繁 `/reactivate-team`**。这是强烈推荐、但**非必需**：不装 tmux 也能用 in-process 模式跑完整 agent team 功能。想要"持久**又**不拆多余 pane"，可在 tmux 内启动 claude + 设 `teammateMode: "in-process"`（详见开发者手册"持久化来自 tmux"段）。

> **🍎 macOS 用户**：依赖（`curl` / `tar` / `git` / `bash`）macOS 自带，**直接运行 `npx agent-team-work-zone init`**（macOS 不自带 Node.js，需先安装，例如 `brew install node`）**，或从源码安装：`bash _agent_team_work_zone/install.sh`**。tmux 可 `brew install tmux`，或用 **iTerm2 split-pane**（reactivate-team skill 自动识别），或不装 tmux 用 in-process 兜底。bash 3.2（系统自带）也能跑——用户路径无 bash 4+ 特性。

> [!IMPORTANT]
> **`_agent_team_work_zone/` 必须放在项目目录里，并且永远在这个目录下启动 Claude Code**——也就是*包含* `_agent_team_work_zone/` 的那个目录。
>
> 常见错误：登录 HPC 集群（或任何服务器）后直接在 home 目录里启动 `claude`，而 work zone 却在某个项目文件夹里。这样会：
> - 项目 `.claude/` 里的 hooks 和设置不会生效，skills 在启动时也用不了；
> - 工位（每个 agent 在 work zone 里的目录）路径从项目根目录解析，checkpoint 和唤回（`/reactivate-team`）会去错的地方找；
> - teammate 从 lead 当前所在的目录启动——lead 在错的目录里运行（或它的 shell 切到了某个子目录），派生出的 teammate 也从那里启动，相对路径随之失效。
>
> 所以：先 `cd /path/to/your/project`，再运行 `claude`。把 home 目录本身当作项目也可以——只要 `_agent_team_work_zone/` 就在 home 目录下，并且在那里启动 Claude。但我们依然强烈推荐：在项目目录下使用该项目专有的 agent team work zone，并为它单独启动一个 Claude Code session。

#### 把 `_agent_team_work_zone/` 纳入 git 管理（强烈推荐）

把 `_agent_team_work_zone/` 和代码一起提交到项目的 git 仓库，不要把它加进 `.gitignore`。纳入 git 管理的，是 agent 最核心、最重要的工作记忆：角色定义、checkpoint、工作日志、讨论记录和团队登记表。运行期的临时文件由 work zone 自带的 `.gitignore` 排除。

- **agent 的工作记忆和日志也得到版本管理。** checkpoint、工作日志、讨论记录和决策，正逐渐成为项目开发记录的重要组成部分。用 git 跟踪它们，尤其是推送到 GitHub 之后，就等于用 git 管理了 agent 们的项目记忆：一方面记忆有了备份，丢失的风险大大降低；另一方面记忆可以回溯——当 agent 或项目走偏时，可以退回到之前的状态。
- **方便迁移到新机器。** 在另一台机器上 clone 项目，先在那里的项目目录下运行一次 `bash _agent_team_work_zone/resources/scripts/bootstrap.sh`（安装 skills、hooks 并配置 Claude Code；无论当初是用 npm 还是从源码安装的，都用这条命令），再在项目目录下启动 Claude，用 `/reactivate-team` 就能拉起一支角色相同、状态相同的 agent 团队。
- **多人协作。** 每位开发者可以在同一个项目里维护一支或多支 agent 团队；团队之间通过 work zone 了解彼此，并通过 `git push` / `git pull` 交流、互相留言（例如借助 `meeting_room/`）。

```bash
git add _agent_team_work_zone
git commit -m "Track the agent team work zone"
```

> [!CAUTION]
> 工位里可能有敏感内容（路径、主机名、数据或对话片段）。如果仓库是公开的，push 前先检查或清理，或者把 work zone 放在私有仓库里。

#### 升级

在项目目录下：

```bash
npx agent-team-work-zone@latest upgrade      # 或：npx agent-team-work-zone@latest upgrade /path/to/your/project
```

- 全局安装的：先 `npm i -g agent-team-work-zone@latest`，再 `atwz upgrade`。
- 从源码安装的：`bash _agent_team_work_zone/upgrade.sh` 仍然可用（它会从 GitHub 下载最新版本）。
- 只更新框架自身的文件，并刷新 `.claude/` 里的 skills 和 hooks。agent 的工作内容不受影响：它们的 checkpoint、工作日志和待办，meeting room 里的文档，团队登记表和 `settings.conf` 都保持原样。（框架在每个 agent 的 README 里维护的那段守则会更新。）
- 每次升级都会再合并一次 `.claude/settings.json`，规则与安装时相同：在 `SessionStart`、`TeammateIdle`、`SessionEnd` 上，框架的 hook 替换你原有的；你在这三个事件上有自己的 hook 时，会先把 `settings.json` 备份为 `.claude/settings.json.bak.<UTC 时间>`。
- 升级到新的大版本时会要求你确认。没有终端时加 `--yes`（用 `upgrade.sh` 时设置 `ATWZ_ASSUME_YES=1`）。
- 升级会重新运行安装脚本。在终端里，它可能再次询问两个写在 `~/.claude/settings.json` 里的全局 Claude Code 设置：成员显示方式和 Auto 权限模式。想保持原来的选择，显示模式选「不修改」，Auto 权限模式选「不启用（保持当前权限模式）」。
- **每次升级之后，都要重启 Claude Code 会话，并对每个正在运行的团队执行 `/reactivate-team`。** 已经在运行的会话和成员，可能仍在用启动时加载的旧版 skill：我们实际遇到过，升级之后正在运行的成员仍照旧版 `/checkpoint` 的步骤执行，直到重新启动才改过来。

#### 新版本提示

在项目里启动 Claude Code 会话时，如果已有更新的版本发布，会显示一条简短提示，附带升级命令。最新版本号在后台查询，每天最多一次，不会拖慢会话启动。查到新版本后，从下一次会话启动起开始提示，之后每次启动都会提示，直到你升级。查询失败（例如没有网络）时沿用上次查到的版本；如果从未查询成功过，就什么也不显示。要关闭这条提示：设置环境变量 `ATWZ_UPDATE_CHECK=0`，或创建文件 `_agent_team_work_zone/.no_update_check`（把这个文件提交进仓库，就对项目里所有人关闭）。

### 2. 为每个角色启动对话

```bash
claude -n "Secretary"
```

进入对话后运行 `/onboard`：

```
/onboard 协助项目主管管理项目和多 agent 协作
```

Skill 会先询问你要的是：
- **(1) 扁平工位** — 一人工位，简单任务
- **(2) Team Lead** — 带部门办公室，复杂任务

然后自动完成命名、建工位、注册成员表。

### 3. 日常工作流

#### 给 agent 分配任务

**用自然语言**，不需要记命令：

```
用户: Architect, 我要重构训练 pipeline 支持多机训练
Architect: 这个任务需要多种能力（模型架构、启动脚本、环境配置）。
          我建议组建一个 team 来做。可以吗？
用户: 好
[Architect 自主调用 /spawn-team，走 6 阶段组建阵容]
Architect: [展示阵容提案]
用户: [反馈调整]
Architect: [调整后发出 spawn prompt，Claude Code 实际 spawn team]
```

#### 跟进进度

```bash
claude --resume "Architect"
# 进入对话
/check-inbox
```

`/check-inbox` 会扫描：
- 顶层 `_agent_team_work_zone/meeting_room/`（跨 team 通讯）
- Architect 自己 team 的 `roundtable/`（team 内部通讯 + tracker 报告）

按时间顺序展示待处理项。

#### 长时间未操作后恢复

```
/sync
```

会：
- 恢复身份（两级识别：先从 context 推断，失败才读文件）
- 扫项目组成员变更
- 扫两层 meeting_room / roundtable
- 输出行动清单

#### 转交任务给其他 agent

当某个 agent 的职责发生变化、或者需要把手头的任务托付给其他人时，用 `/handoff`：

```
# 交出方（比如你不再负责 auth 模块了）
/handoff --give
[skill 通过对话收集任务清单 + 每个任务的 why + 进度 + 相关文件]
[生成 _agent_team_work_zone/meeting_room/<SELF>_HANDOFF_<date>_<slug>.md]

# 接收方（在接手者的 session 里）
/handoff --take
[skill 扫描 to: <SELF> 的 HANDOFF 文件]
[展示任务清单让用户确认]
[追加到自己的 TODO.md，把交接文档 status 改为 IN_PROGRESS]
```

`/handoff` 是**单一命令双模式** — 不带参数时它会问你是哪一方（`--give` / `--take` 是快捷参数）。把任务当成黑盒：本 skill 只负责把信息完整传过去，不假设接收方将如何完成任务（接收方完全可以再次转手、组建小组、或自己动手——那些都不在 handoff 的关心范围）。

典型场景：
- **职责变更**：原 agent 不再负责某领域
- **重构后迁移**：老工作流的 in-flight 任务转到新架构对应的 agent
- **临时回避**：交出方需要长期不在线，把任务暂时托付给他人

---

## 核心概念

### 扁平工位 vs Team 工位

| 类型 | 目录命名 | 何时用 |
|---|---|---|
| 扁平工位 | `<name>/` | 简单任务，单兵能完成（秘书、Git 管理、翻译等） |
| Team 工位 | `<name>_team/` | 复杂任务（涉及多种专业技能、需要并行工作、需要对抗性审视）|

扁平工位有 README、notes、TODO 等基本文件。
Team 工位额外有：
- `roundtable/` — 部门内部沟通
- `archive/` — 部门内部归档
- `team_recipes/` — `/spawn-team` 产出的审计记录
- `teammates/` — 团队自定义角色存档（可选）

### 升级路径：扁平 → team lead

一个扁平 agent 预见到任务会变复杂时，它会**主动**建议升级：

```
扁平 agent: 我看到这个任务会涉及多种能力和并行工作，建议把我升级为
          team lead。升级后目录从 architect/ 重命名为 architect_team/，
          工作历史完整保留。同意吗？
用户: 同意
[agent 自主调用 /promote-to-team]
```

**重要**：`/onboard` 只在对话开始时运行一次，不处理升级。升级用专门的 `/promote-to-team`。

### 两层通讯

| 层 | 用途 | Frontmatter |
|---|---|---|
| 顶层 `meeting_room/` | 跨工位 / 跨 team / 全局公告 | `from: Architect` (首字母大写) |
| 部门内 `<team>/roundtable/` | Team 内部 lead ↔ teammate、tracker 报告 | `from: architect_team/tracker` (小写斜杠) + `kind` 字段 |

### Tracker —— 定时监视长任务

当 team lead 需要盯一个长跑任务时，它会自己启动一个 tracker，基于 `resources/agents/tracker.md` 角色定义。**启动方式按平台分两路**：

- **HPC / Linux**：lead 通过 `/spawn-team` 把 tracker 作为 teammate 召唤进 team，tracker 在自己的 tmux pane 里运行 `/loop 12h <prompt>` 进入轮询模式。**SSH 断了不死**（前提是 lead 的 claude 启动在 tmux 内 + `teammateMode: "tmux"`）。详见下文「HPC 部署指南」。
- **macOS / Windows**：lead 在你的 Claude Code Desktop 里创建一个 Scheduled Task（Routines → New routine → Local 填表，或直接对 Desktop 说"create a scheduled task ..."）。每次到点 Desktop 启动一个新 session 跑 tracker prompt → 写报告 → 退出，触发之间零 token。**前提**：电脑开着不休眠，且首次手动 Run Now 时把弹窗都勾"always allow"（不然 cron 会被权限拦截）。完整字段（name / instructions / model / schedule / working folder / worktree / permission mode）和 tracker 的推荐值见 `resources/agents/tracker.md` 的「选项 2」；prompt 模板见 `resources/desktop_task_skill_template.md`。

通用约定：

- **训练任务**：默认 12 小时一次
- **Eval 任务**：默认 4 小时一次
- 报告写到 `<team>/roundtable/Tracker_REPORT_<timestamp>.md`
- **你不直接碰部署细节**——全由 team lead 代办，对你是黑盒
- 完整部署指南见 `resources/agents/tracker.md` 的「部署选项（按 OS 分）」段

### HPC 部署指南

HPC / Linux 上必须用 tmux 才能扛 SSH 断开，否则 tracker 等 teammate 会在 SSH SIGHUP 时全军覆没。完整启动流程：

#### 1. 安装 tmux ≥ 3.2

```bash
# Ubuntu / Debian
sudo apt install tmux

# RHEL / CentOS / Fedora
sudo yum install tmux  # 或 dnf

# 没有 sudo 权限的 HPC 用户
conda install -c conda-forge tmux
```

> **为什么版本下限是 3.0**（bootstrap 会在 tmux 内强制检查、不达标直接退出）：
> - tmux **≤ 2.7** 缺 Claude Code 需要的 pane-size 协议字段，在 tmux 内 spawn teammate 直接报 `Failed to create teammate pane: size invalid`——窗口开多大都没用，这是协议不兼容。**升级 tmux 是唯一解**（3.6a 实测 OK；3.2 已足够）。
> - **多版本 tmux 共存陷阱**：HPC 上常见 PATH 默认指向系统老 tmux、但 session 跑在 conda 新 tmux 里（或反之）。PATH 的 tmux 连不上当前 session 的 server → spawn 报 `Could not determine current tmux pane/window`。解决：让 PATH 指向**启动当前 session 的那个 tmux**（修好 PATH 后 `hash -r`），再重跑 bootstrap。
> - 这两个报错 bootstrap 都会在你进 tmux 后预先拦截并给出诊断，不用等到 spawn 时才撞见 cryptic message。

#### 2. 配置 `~/.claude/settings.json`

```json
{
  "teammateMode": "tmux"
}
```

或者用 `"auto"`——只要 lead 的 claude 启动时已经在 tmux 内即可。

#### 3. 一键启动 tmux + claude

```bash
bash _agent_team_work_zone/resources/scripts/start_hpc_session.sh
# 然后:
tmux attach -t claude_hpc
```

脚本会：检查 tmux 是否安装 → 检查当前是否已经在 tmux 内 → 不在就 `tmux new -s claude_hpc` 并在里面启动 `claude` → 打印 attach 指引。

#### 4. 在 tmux 里组队 + 召唤 tracker

```
你: /onboard
你: Architect, 我启动了一个 SFT 训练 (squeue id 12345)，watchlist:
   ./runs/sft/status, tail of logs/train.log，每 12h 监视一次
[Architect 通过 /spawn-team 把 tracker 加进 team，spawn prompt 包含
 "启动后立即执行 /loop 12h <监视任务 prompt>"]
[tracker teammate 在新 tmux pane 里启动 → 自己 issue /loop → 进入轮询]
```

#### 5. SSH 断开 / 重连

```bash
# SSH 断了？重连后:
tmux attach -t claude_hpc
# 看到 lead pane + tracker pane 都还在跑
```

只要 tmux session 活着，所有 pane 都活着；lead 和 tracker 的对话都不丢。

#### 6. 验证 teammate 真的是 tmux-backed

```bash
jq '.members[] | {name, tmuxPaneId, backendType}' \
   ~/.claude/teams/<team-name>/config.json
```

- `tmuxPaneId` 形如 `"%12"` → ✓ 正确，SSH 断开能扛
- `tmuxPaneId == "in-process"` → ✗ fallback 到了 in-process，必须用 tmux 重新启动 lead

#### 7. 7 天续期提醒

`/loop` 任务**自动 7 天过期**：第 7 天最后一次触发后 cron 任务删除，但 tracker session 本身仍然活着，只是停止轮询。处理：

- **短任务**：lead 在第 6 天通过 SendMessage 让 tracker 重新 issue `/loop`（推荐）
- **长任务（> 6 天）**：每个 epoch 重新 spawn 一个 tracker，不要试图无限续期
- **不要**写自动续期 daemon——手动可控比看不见的自动化安全

### 角色原型（`resources/role_archetypes/`）

Team lead 在 `/spawn-team` 时参考的**模板**，不是 subagent 定义。9 个：

- **coding/**: bash-scripter, model-architect, dataset-specialist
- **config/**: training-config-author (LLaMA-Factory, VERL), eval-config-author (skythought, evalscope)
- **infra/**: env-configurator → container-builder（前后依赖）
- **analysis/**: data-analyzer, result-reporter

### 通用 Subagents（`resources/agents/` → `.claude/agents/`）

5 个项目全局通用的 Claude Code subagent：

- **tracker** — 定时监视（haiku）
- **investigator** — 假设驱动的深度调研（**opus**，旗舰模型）
- **reviewer** — checklist 代码评审（sonnet）
- **devil-advocate** — 对抗性挑战（**opus**，旗舰模型，不 memory）
- **git-repo-manager** — Git 管理（sonnet）

### checkpoint 的 git 保存（可选）

每次 `/checkpoint` 还可以把 teammate 的工位文件存进 git，这样 checkpoint 经得起 `git stash`、一次合并出错或误覆盖。它**默认关闭**，按项目开启。

**两种模式：**
- **`snapshot`**（推荐）：工位文件保存到一个私有的 git 引用 `refs/atwz/checkpoints/<team>/<name>`。你的分支、`HEAD`、`git status` 和共享暂存区都不受影响，提交里不会出现任何东西。
- **`commit`**：工位文件以一次只含这些文件的提交，提交到当前分支（从工位里删掉的文件作为删除提交）。其他已暂存的内容保持暂存、不进这次提交。提交 hook 照常运行。

**开启或关闭**（在项目目录下运行）：
```bash
bash _agent_team_work_zone/resources/scripts/atwz_checkpoint_git.sh enable            # snapshot 模式
bash _agent_team_work_zone/resources/scripts/atwz_checkpoint_git.sh enable commit     # commit 模式
bash _agent_team_work_zone/resources/scripts/atwz_checkpoint_git.sh disable
bash _agent_team_work_zone/resources/scripts/atwz_checkpoint_git.sh status
```
设置保存在 `_agent_team_work_zone/settings.conf`（`checkpoint_git = off | snapshot | commit`），也可以手动编辑。请提交这个文件，让其他机器上的 teammate 用同一设置。`enable` 会立刻告诉你它在这里是否生效。

**什么时候不生效。** 每次保存都会重新检查；无法保存时，改为输出一行 `skipped: …`：
- work zone 不在 git 工作树里；
- 工位的 `working-context.md` 被 git 忽略（例如 `.gitignore` 里写了 `_agent_team_work_zone/`）；
- 自上次快照以来没有变化。

未跟踪但没被忽略的文件也会保存，否则 `git stash -u` 会把它们无声无息地拿走。被忽略的文件和运行期文件（`.started`、`.checkpoint_nudge_count`、`*.before-restore.*` 副本）从不保存。checkpoint 绝不会因为 git 而失败：结果作为一行附在 teammate 的 checkpoint 确认里。

**找回保存的版本：**
```bash
S=_agent_team_work_zone/resources/scripts/atwz_checkpoint_git.sh
bash $S list    /abs/path/to/_agent_team_work_zone/<team>/teammates/<name>                     # 历史
bash $S restore /abs/path/to/_agent_team_work_zone/<team>/teammates/<name>                     # 全部文件，最近一次保存
bash $S restore /abs/path/to/_agent_team_work_zone/<team>/teammates/<name> working-context.md --from <rev>
```
- 当前文件若与保存的版本不同，先另存为 `<文件>.before-restore.<UTC 时间>`；不再需要时删掉这些副本。
- `--from` 接受 `list` 列出的任何版本，例如 `refs/atwz/checkpoints/<team>/<name>~3`。
- 保存关闭时，`list` 和 `restore` 仍然读取快照引用。`restore` 要求工位目录存在；整个被删掉的工位它无法重建。
- 恢复由工位的主人（teammate，应 lead 的要求）或你来做——lead 不改 teammate 的文件。
- 不用脚本时：`git log refs/atwz/checkpoints/<team>/<name>` 查看历史，`git show refs/atwz/checkpoints/<team>/<name>:_agent_team_work_zone/<team>/teammates/<name>/working-context.md` 打印最近保存的版本（更早的用 `<ref>~N:`）。

**快照只留在你的机器上。** 框架从不 push 它们，普通的 `git push` 只发送分支，新的 `git clone` 也不会带上它们。只有 `git push --mirror` 或显式 push `'refs/*'` 才会发出去。删除它们：`git update-ref -d refs/atwz/checkpoints/<team>/<name>`，或一次全删：`git for-each-ref --format='%(refname)' refs/atwz | xargs -n1 git update-ref -d`。

**git 锁。** 项目里所有人共用一个 checkout 和一个暂存区，两次提交、合并或拉取同时发生会互相干扰。`atwz_git_lock.sh` 让所有 agent 的 git 命令一次只跑一个：
```bash
cd /path/to/your/project && bash _agent_team_work_zone/resources/scripts/atwz_git_lock.sh run -- git commit -m "…" -- <路径>
```
（在项目目录——也就是包含 `_agent_team_work_zone/` 的那个目录——下运行，这样项目只是某个更大仓库的子目录时也能用。）
别的 git 操作正在进行时它会等（从不删除 `.git/index.lock`），最多等 3 分钟，然后以退出码 75 放弃。commit 模式会自动使用这把锁。

**要求：**git 2.5 或更高版本。脚本按 bash 3.2（macOS）与 Linux 编写；macOS 兼容性是通过审读代码检查的，没有在 macOS 上实际运行过。

### 给运行中的团队改规则

只改规则文件，到不了已经在运行的 teammate：它们的指示在派生时就固定了。要给整个团队改一条规则，请 lead 用 **`/broadcast-rule`** 发出（在你同意这项变更之后）：
- 每个在线 teammate 收到一次、用最终措辞写成的规则，把它记进自己 README 的「## Team rule changes」一节，并回复 `ACK <id>`；
- lead 把规则和每一条确认记在本团队的 `RULES_LEDGER.md`（与 `TEAMMATE_INFO.json` 并列）；
- 不在线（benched）或尚未派生的 teammate，在被唤回或派生时读这份记录，并在回执里确认。

本 skill 不修改框架 README 或 `teammate_rules.md`。应当成为框架永久文本的规则，是另一项单独的改动。要通知其他团队，用 `meeting_room/`，`to: ALL`。

### 可选的 CLAUDE.md 段落

项目的 `CLAUDE.md` 可以加两个可选段落。首次安装时，若在终端里运行，`bootstrap.sh` 会逐个询问（默认 No）；升级时从不询问，之后想加请看下文。无论哪种情况，install/upgrade 从不修改或删除 CLAUDE.md 中已有的内容；它们只追加——缺少框架段落时追加框架段落，可选段落只在你回答 y 时追加。

- **给用户的消息（格式）**（`resources/claude_md_optional/user_message_format.md`）：不要用消息轰炸你；由 teammate 汇报触发的消息以 **队内简报：** 开头；需要你了解或裁定的内容以单独一行的一级标题 `# To Be Read By User` 开头，下面紧跟一行加粗的状态（**需裁定** / **进展** / **更正** / **静默轮**）。英文版的对应标签是 `Team brief` 与 `Decision needed / Progress / Correction / Quiet round`（标题仍是 `# To Be Read By User`）。
- **平实用语**（`resources/claude_md_optional/plain_vocabulary.md`）：用平实、严谨的词；不自造比喻性名词；少用简写。它的最后是一份**你否决过的词**，放在 `CLAUDE.md` 里面，所以始终会被加载。你每否决一个词，lead（或扁平工位）就把它加进这份清单；teammate 把要加的词发给自己的 lead。

之后想加某一段，在项目目录下手动追加（若 `CLAUDE.md` 里已有它的 `<!-- ATWZ-OPTIONAL:… -->` 标记就跳过）：
```bash
printf '\n' >> CLAUDE.md
cat _agent_team_work_zone/resources/claude_md_optional/user_message_format.md >> CLAUDE.md
printf '\n' >> CLAUDE.md
cat _agent_team_work_zone/resources/claude_md_optional/plain_vocabulary.md >> CLAUDE.md
```

---

## 典型用例

### 用例 1：长跑训练 + 主动 tracking

> **平台说明**：下面演示的是 **HPC / Linux** 路径（tmux + /loop teammate）。
> macOS / Windows 路径见 `resources/agents/tracker.md` 的「选项 2：macOS / Windows 本地 —— Desktop Scheduled Tasks」段。

```
用户: Architect, 我启动了一个长跑训练任务，想盯着点
Architect: 好。这是训练任务。我会通过 /spawn-team 把 tracker 加进 team，
          它会在自己的 tmux pane 里跑 /loop 12h，每 12 小时读一次状态写
          报告到 architect_team/roundtable/。你下次回来用 /check-inbox
          就能看到。有异常我会在报告里标高优先级。
          
          前提：你的 claude 已经在 tmux session 里启动（用过
          start_hpc_session.sh 的话就 OK），且 settings.json 里有
          teammateMode: "tmux"。
用户: 好
[Architect 通过 /spawn-team 把 tracker 加进 team，spawn prompt 含
 "启动后立即执行 /loop 12h <轮询任务>"]
[tracker teammate 在新 tmux pane 里启动 → 自己 issue /loop → 进入轮询]
Architect: 已 spawn tracker teammate（pane %12）。watchlist:
          squeue + ./runs/exp_42/status + train.log 尾部。
          7 天后 /loop 会自动过期，到时我会让它重新 issue。
          想停可以让我对它 SendMessage "/cron-list" + "/cron-delete <id>"。
```

12 小时后：

```
用户: /check-inbox
check-inbox: [TEAM] architect_team/roundtable/Tracker_REPORT_20260412_0300.md
             (from: architect_team/tracker, kind: TRACKER_REPORT, status: OPEN,
              priority: LOW, result: NORMAL)
             loss: 2.34 → 1.87, step 12000/100000, GPU util 98%, 预计 36h 完成
```

### 用例 2：复杂架构改造 + 组建 team

```
用户: Architect, 我要给训练代码加 flash-attn 3 支持
Architect: 这个改动涉及：
          - 改 model forward 引入 flash_attn_func
          - 改训练配置适配新的 attention backend
          - 环境里要装 flash-attn 3
          - 改完后需要 smoke test
          建议组建一个 4 人 team：
          - model-architect (sonnet, plan-mode): 改 forward
          - env-configurator (sonnet): 装 flash-attn 3
          - training-config-author (sonnet, plan-mode): 改训练配置
          - devil-advocate (opus): 质疑方案，找兼容性陷阱

          你同意吗？
用户: 同意，但 devil-advocate 去掉，先简单点
Architect: [调用 /spawn-team，6 阶段走完，emit spawn prompt]
[Claude Code agent-team 机制 spawn 3 个 teammate]
```

### 用例 3：调研结果反常

```
用户: Architect, 昨天的评测结果反常，GSM8K 比 baseline 低了 5 个点，
     代码没报错
Architect: 这是"跑通了但结果反常"的典型场景，需要 investigator 做假设
          驱动的深度调研。我 spawn 一个 investigator teammate：
          - investigator (opus): 读 eval log 和 checkpoint meta，
            列 ≥ 3 个 hypothesis，设计验证方案（不执行）

          你同意吗？
用户: 同意
[spawn investigator]
[investigator 产出 INVESTIGATION_REPORT 到 roundtable/]
```

---

## 已知局限

以下是框架目前**不处理**的运行环境问题。它们不是 bug，但会造成真实损失，请按各条的建议自行防范。

- **队友的消息只在回合结束后送达。** 一个 teammate 的回合不结束，队友发给它的消息就一直排队；长时间阻塞的工具调用（例如 shell 里的 `until … sleep` 循环）和一串短检查都会挡住消息，只有结束回合才能让消息进来。需要盯作业又要保持可达的 agent，用 `/loop` 排定唤醒，然后结束回合；只结束回合而不排定唤醒，作业就没人盯了。（在分屏模式、Claude Code 2.1.283 上观察到；同进程模式未测试。不同消息通道的送达时机不同：跨会话消息和子代理的回传可以在回合中途、工具调用之间送达。）**子代理（Agent 工具临时派出的 subagent）没有 `/loop` 所需的定时工具**（在 Claude Code 2.1.283 上对一个 Explore 子代理观察到：技能列表里有 `loop`，但无法运行；其他子代理类型未测试），长时间监控请交给 teammate。
- **整个团队可能被一次内存事故清空。** 两种情况：(a) 整个团队跑在同一个有内存上限的作业或容器里（例如一个 SLURM 分配），所有会话和它们启动的计算共享这个上限，一次内存溢出（OOM）被杀的可能是某个会话；(b) 同进程模式下，teammate 运行在 lead 的进程里，lead 崩溃则全员结束。大内存计算请放到独立的作业或容器里。工位文件不受影响，可用 `/reactivate-team` 恢复。（分屏模式下每个 teammate 是独立进程，普通桌面上一次 OOM 只杀一个进程。）
- **同一系统账号下的资源，框架看不到。** GPU 配额、conda 环境、磁盘配额、后台进程按系统账号共享，框架只隔离目录。同账号下的多个团队或项目可能互相影响，而工位里不会有任何记录。**不要按进程名杀进程**（`pkill -f`、`killall`、`kill $(pgrep …)`），可能杀掉别的 agent 的进程。请记录自己进程的进程号，只杀自己启动的。
- **跨仓库使用 `meeting_room/` 没有约定。** `meeting_room/` 是为同一个 work zone 内的团队设计的。别的仓库的团队往这里写文件可以工作，但谁有写权限、命名格式、谁负责归档，框架都没有规定，需要双方事先约定。
- **不支持每个 teammate 用独立的 git worktree。** skills、hooks 装在项目根目录的 `.claude/` 下，`/checkpoint`、`/reactivate-team` 读的也是项目根目录下的工位。把 teammate 搬进 worktree，持久化层会一分为二。所有 agent 共用一个 checkout 时的 git 纪律，见工作守则第 1 条"共享工作目录与暂存区"。

---

## 故障排查

### Claude Code 版本太旧

`bootstrap.sh` 会报错退出。升级到 v2.1.32 以上。

### Skill 修改后不生效

Claude Code 在 session 启动时加载 skills。修改源后：
1. `bash claude_code/zh/_agent_team_work_zone/resources/scripts/bootstrap.sh` 同步到 `.claude/`
2. 重启 Claude Code session 或用 `/agents` 命令刷新

### `/spawn-team` 说我不是 team lead

你当前是扁平工位。两种选择：
1. 让 agent 调 `/promote-to-team` 升级为 team lead（如果任务确实需要）
2. 保持扁平继续死扛

### Tracker teammate 不发报告 (HPC / Linux)

按以下顺序检查：

1. **验证 teammate 是真 tmux-backed**：
   ```bash
   jq '.members[] | {name, tmuxPaneId, backendType}' ~/.claude/teams/<team>/config.json
   ```
   `tmuxPaneId == "in-process"` → fallback 模式，SSH 断开会全死。需要按「HPC 部署指南」重启 lead。

2. **验证 spawn prompt 含 `/loop` 指令**：tracker 不会自己进入轮询，必须在 spawn prompt 里写明 *"启动后立即执行 `/loop 12h <prompt>`"*。打开 tracker 的 tmux pane（`tmux attach -t claude_hpc` 然后切到 tracker pane）确认。

3. **检查 7 天过期**：tracker 启动到现在超过 7 天？/loop 任务已过期，让 lead 通过 SendMessage 让 tracker 重新 issue `/loop`，或重新 spawn 一个 tracker。

### Tracker scheduled task 没触发 (macOS / Windows)

按以下顺序检查：

1. **任务确实存在并是 Active 状态**：在 Desktop 侧边栏 `Routines` 里找到 `tracker-<project>-...`，确认 Status 是 `Active` 而非 `Paused`。同时看 History 标签——如果有跑过但 status 是 `skipped (slept)`，说明电脑在该时间点休眠。

2. **首次 Run Now 已经做过权限预批**：第一次必须**手动**点 Run Now，把所有"Always allow"弹窗都勾上。如果跳过这一步，后台 cron 触发时会被权限弹窗阻塞且**不会**通知你。修复：手动 Run Now 一次，把所有弹窗都批掉。

3. **电脑没在该时间点休眠**：打开 `Settings → Desktop app → General → Keep computer awake`。错过的运行**不堆积补跑**——电脑唤醒后最多补最近一次（且在 7 天 lookback 内）；跨夜任务必须设永不休眠。

4. **Working folder 仍被 Desktop trust**：如果项目目录被 mv / 删除 / 权限变更过，Desktop 会拒绝在该目录运行任务。重新 trust 或修正路径。

5. **Schedule 字段确实是预期 cron**：GUI 预设只有 Manual / Hourly / Daily / Weekdays / Weekly。如果想要 `0 */12 * * *` 这种自定义 cron，必须在创建后用自然语言改（"change the schedule of tracker-... to every 12 hours"）；只看 GUI 预设可能误以为已经设置正确。

6. **prompt body 是否被改坏**：如果你直接编辑过 `~/.claude/scheduled-tasks/<task-name>/SKILL.md`，确认 frontmatter 完整（`name` + `description`）且正文未损坏。可重新从 `resources/desktop_task_skill_template.md` 拷贝覆盖。

### 团队 spawn 出问题

检查 `.claude/settings.json` 是否有 `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`。重新运行 bootstrap。

### 切勿直接编辑 `.claude/skills/` 或 `.claude/agents/`

那些是**运行时派生物**，下次 bootstrap 会被覆盖。源在 `claude_code/zh/_agent_team_work_zone/resources/`（或者 downstream 项目的 `_agent_team_work_zone/resources/`），**只编辑源**。

---

## 下一步阅读

- `agent-teams.md` — 新架构的设计文档（why & how）
