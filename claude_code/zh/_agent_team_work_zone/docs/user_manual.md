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
| **Linux** | ✅ `install.sh` / `upgrade.sh` | tmux + `/loop` | teammate + `/loop` |
| **macOS** | ✅ `install.sh` / `upgrade.sh`（与 Linux 同一脚本，已验证零阻断）| tmux / iTerm2 split-pane / in-process | Desktop Scheduled Tasks |
| **Windows**（原生）| ⏳ 下一个大版本 | in-process（弱持久）| Desktop Scheduled Tasks |
| **Windows + WSL** | ✅ 走 Linux 路径 | tmux 在 WSL 内 | teammate + `/loop` |

**为什么 macOS 同一套脚本就行**：所有 `.sh` 用 `#!/usr/bin/env bash`（自动选 Homebrew bash if 装了，否则降级 `/bin/bash 3.2` 也可），用户路径无 bash 4+ 特性。`stat -c %Y` 双写了 BSD 兜底 `|| stat -f %m`，无 `sed -i` / `date -d` / `grep -P` 等 GNU-only 构造。依赖（`curl` / `tar` / `git` / `bash`）macOS 自带。

**原生 Windows 推迟**的原因：3 个运行时 hook（`session_start_check.sh` / `teammate_idle_checkpoint.sh` / `session_end_final_checkpoint.sh`）必须 PowerShell 化，工作量大；下一个大版本（v2.x）做。**WSL 用户现在就能用**——把模板放在 WSL 内的项目里，按 Linux 路径走即可。

---

## 快速开始

### 1. Clone 和部署模板

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

> 英文版稍后由 Translator 生成。

> **⚠️ Claude Code 版本要求（本模板）**：本模板适配 **Claude Code 2.1.178** 的 agent-teams API（会话级自动 team、`TeamCreate`/`TeamDelete` 已删、`Agent` 的 `team_name` 被忽略），要求 **CC ≥ 2.1.178**。如果你的 Claude Code ≤ 2.1.177，请改用 **[release v0.1.0](https://github.com/SR-A-W/agent-team-work-zone/releases/tag/v0.1.0)**（针对旧 API）。

Bootstrap 会：
- 检查 Claude Code 版本 (>= v2.1.178)；不达标直接退出并指向 release v0.1.0
- 检查 tmux（**强烈推荐，非必需**——见下方说明；不装则用 in-process 兜底）
- 同步 skills + agents 到 `.claude/`
- 创建或合并 `.claude/settings.json` 启用 `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`

> **💡 强烈推荐把 Claude Code 跑在 tmux 里**（不限 HPC，本地同样受益）：关终端 / SSH 断连时，tmux 保住 Claude Code 进程不被杀、session 不中断——**你回来 `tmux attach` 就接着干，省去频繁 `/reactivate-team`**。这是强烈推荐、但**非必需**：不装 tmux 也能用 in-process 模式跑完整 agent team 功能。想要"持久**又**不拆多余 pane"，可在 tmux 内启动 claude + 设 `teammateMode: "in-process"`（详见开发者手册"持久化来自 tmux"段）。

> **🍎 macOS 用户**：依赖（`curl` / `tar` / `git` / `bash`）macOS 自带，**直接 `bash install.sh` 即可**。tmux 可 `brew install tmux`，或用 **iTerm2 split-pane**（reactivate-team skill 自动识别），或不装 tmux 用 in-process 兜底。bash 3.2（系统自带）也能跑——用户路径无 bash 4+ 特性。

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
