---
name: remote-collab
description: >
  两名开发者各自的团队在不同机器上协作同一个项目：通过同一个 git 远端交换 meeting_room 文档。
  子命令 start / pull / push / stop / status。start 做前提检查、写配置、请用户在两种推送方式里选一种（默认每次批准），
  两种查看方式，start 时问用户：Haiku 查看成员每 30 分钟查看一次（默认），或后台脚本轮询（默认每 50 分钟，空闲时不花用量）；
  有发给本团队的新文档或变动才告诉 lead。
  pull 把远端合并进来，push 提交本团队的团队文件并推送；冲突一律退回并报告用户。
  只在 lead 会话（或扁平工位）里用；用户说"和另一台机器上的团队协作""看看对方有没有更新"时调用。
argument-hint: "start [间隔] | pull | push | stop | status"
disable-model-invocation: false
allowed-tools: Read Write Edit Glob Grep Bash Agent SendMessage Skill
---

# `/remote-collab` — 和另一台机器上的团队协作

两名开发者协作同一个项目，各自的团队在不同机器上，共用同一个 git 远端（例如 GitHub 上的同一个仓库）。两边通过 `meeting_room/` 里的文档交接任务。本技能负责把文档传过去、传回来：

- 两种查看方式，start 时问用户（默认第 1 种），都只 fetch、不动工作目录：
  - **查看成员方式**（第 1 种、默认）：一名常驻的 Haiku **查看成员**自己跑 `/loop`，默认每 30 分钟用脚本查看一次远端；有发给本团队的新文档时，在自己工位写一份摘要文件，再给 lead 发一条不超过 5 行的消息；只有其他变动时发一两行；没有更新不发。它只查看和整理，不合并、不派活。每查看 12 轮重新派生一次。
  - **后台脚本方式**（第 2 种）：没有常驻成员。lead 用 Bash 工具的后台运行方式启动脚本，脚本自己循环查看（默认每 50 分钟），有事才退出；进程退出时 Claude Code 唤起 lead，lead 再起一个一次性 Haiku 子代理写摘要。
- lead 要处理时运行 `/remote-collab pull` 把远端合并进来；写了给对方的文档、或做完对方在等的事之后，运行 `/remote-collab push` 推上去。
- 所有 git 命令都由脚本 `_agent_team_work_zone/resources/scripts/atwz_remote_collab.sh` 在本机 git 锁内执行。合并有冲突一律退回并报告用户，不自动解决，不 stash。

## 本技能用到的说法

- **团队目录**：`_agent_team_work_zone/<slug>_team/`（扁平工位时是 `_agent_team_work_zone/<工位目录>/`）。
- **查看成员**：`<slug>-remotewatch`，模型 `haiku`，按 `resources/agents/tracker.md` 的模式 B（盯守告警）工作。
- **摘要文件**：为一批远端提交写的一份结构化说明，每批一份：查看成员方式放在查看成员的工位里（`<团队目录>/teammates/<slug>-remotewatch/digests/`），后台脚本方式放在 `<团队目录>/digests/`。只在这批提交里有给本团队的文档（check 输出有 `doc` 行）时才写。格式见同目录的 `watcher_rules.md`。
- **配置**：`<团队目录>/remote_collab.json`，lead 写，入 git。
- **运行时状态**（不入 git）：查看成员自己工位里的 `remote_seen`（上次看到的远端提交、上次查看的时间和结果）、`loop_job`（定时任务 ID、创建时间和已查看的轮数，停止时按 ID 删、判断何时重新派生用）和 `digests/`（摘要文件）；lead 侧的 `<团队目录>/.remote_collab_state`（上次 pull / push 的时间和结果）；后台脚本方式下团队目录里的 `.remote_seen`、`.remote_collab_watch.pid`（后台 watch 的进程号）和 `digests/`。工作区 `.gitignore` 已排除这些文件。
- **脚本**：下文 `RC` 指 `bash _agent_team_work_zone/resources/scripts/atwz_remote_collab.sh`，`CFG` 指 `--config _agent_team_work_zone/<团队目录名>/remote_collab.json`。都在项目根目录（包含 `_agent_team_work_zone/` 的目录）下运行。

## 子命令

| 子命令 | 做什么 |
|---|---|
| `/remote-collab start [间隔]` | 前提检查 → 写配置 → 问用户查看方式和推送方式（一条消息，默认第 1 种和每次批准）→ 派生查看成员（已存在则只发"开始"消息）并确认第一次查看真的触发了，或启动后台查看。间隔默认第 1 种 `30m`、第 2 种 `50m` |
| `/remote-collab pull` | 把远端合并进本地 |
| `/remote-collab push` | 提交本团队的团队文件、合并远端、推送 |
| `/remote-collab stop` | 有未推送的团队文件先推一次，再让查看成员停止并下线，或停掉后台查看 |
| `/remote-collab status` | 显示配置、查看方式、上次查看的时间和结果、上次 pull / push 的结果 |

只由 lead 运行 pull 和 push；查看成员只运行 `check`，不合并。

**查看成员的空闲通知**：查看成员每次查看结束都会自动给你发一条空闲通知（idle_notification），这是 Claude Code 的固定行为，关不掉。收到它时什么都不做：不输出、不转给用户、不回复它（守则本来就把心跳当作空操作，这里再点名一次）。只有查看成员用 SendMessage 发来的 `[remote-collab]` 消息才处理：按你 README 里"### 远程协作：查看方式和消息"那一节做（start 时写入，见下文）。

---

## start

### 第 0 条：团队工位还是扁平工位

lead 的工位目录以 `_team` 结尾，且有 `roundtable/` 和 `TEAMMATE_INFO.json` → 团队工位，继续第 1 条。

否则是扁平工位。扁平工位不能派成员，也就没法派查看成员。配置里还没有 `watch_mode` 时，停下，这样问用户：

```
你现在的工位是单人工位，不能派成员。可以这样选：
(1) 先输入 /promote-to-team 升级为团队工位（原有文件都保留），升级后可以用 Haiku 查看成员定时查看（推荐）；
(2) 不升级，用后台脚本每 50 分钟查看一次，没有更新时不花用量，会话结束后要你说"接着远程协作"再启动；
(3) 不升级、不定时查看，只在你要的时候手动 pull / push。
```

- 选 1 → 运行 `/promote-to-team`；完成后从第 0 条重新开始 `start`（工位目录已改名为 `<名字>_team`，配置写在新目录里）。
- 选 2 → 照常做第 1–7 条，配置写 `"watcher": null`、`"mode": "auto"`、`"watch_mode": "script"`，只问推送方式（不问查看方式，也没有第三问），然后按"后台脚本方式"一节启动。
- 选 3 → 只提供手动的 pull、push、status，不做定时查看：照常做第 1–7 条，配置写 `"watcher": null`、`"mode": "manual"`，跳过"派生查看成员"，告诉用户"想看对方有没有更新，就让我运行 /remote-collab pull"。
- 不选或回答含糊 → 按选 3 处理，并告诉用户一句"按只手动记下了；随时可以再运行 /remote-collab start 选别的"。
- 扁平工位的名字写 `<工位目录>`（没有成员，不加 `/<成员>`），配置、`.remote_seen`、pid 文件、`digests/` 和其余运行时状态都放在该工位目录里。之后用户随时可以升级，再运行一次 `start`。

### 第 1–7 条：前提检查

逐条做，任何一条不过就停下，告诉用户怎么修。第 6、7 条只提醒，不阻止。

1. **在 git 工作树里**：`git rev-parse --is-inside-work-tree` 输出 `true`。
2. **工作区没被 git 忽略**：`git check-ignore -q _agent_team_work_zone/meeting_room/README.md` 和 `git check-ignore -q _agent_team_work_zone/<团队目录名>/` 都应以 1 退出（没被忽略）；以 0 退出就停下，说明"工作区被 .gitignore 排除了，两边的文档传不过去；要先把 `_agent_team_work_zone/` 纳入 git 管理"。
3. **有上游分支且能 fetch**：`git rev-parse --abbrev-ref --symbolic-full-name @{u}` 得到 `<远端>/<分支>`（例如 `origin/main`），记下远端名和分支名；再运行 `git fetch <远端> <分支>`。没有上游或 fetch 失败 → 停下，把 git 的报错原文给用户，说明要先能 `git push` / `git fetch` 到同一个远端。
4. **双方团队目录名不同**：运行 `git log --format=%h <远端>/<分支> ^HEAD -- _agent_team_work_zone/<团队目录名>/`。有输出，说明远端有别人改过同名的团队目录（团队目录只有本团队写）→ **同名，停下**，只检查、给出下面的改名步骤，不自动改名。两人对同一个项目各跑 `/quickstart` 时，团队名由项目名得出，几乎一定相同；团队目录、lead 名、成员名全会重，空闲时的 checkpoint 提醒会按名字找错工位，收件人也会混。
   - 改名步骤（由后开始协作的一方照做）：
     1. 请所有成员运行 /checkpoint，再逐个发关闭请求，等它们同意；
     2. 把团队目录改名为新名字（新的 slug 只含小写字母和数字，目录名 `<新 slug>_team`）；
     3. 改登记表 `TEAMMATE_INFO.json` 的 `team_name`、`lead_name` 和每个成员的 `name`（`<新 slug>-<角色>`），用带校验的 jq 写入；
     4. 把每个成员的工位目录改名为新名字，并改它 README 里的名字；
     5. 改 `_agent_team_work_zone/README.md` 项目组成员表里本团队那一行；
     6. 运行 `/reactivate-team`，按新名字重新派生成员；再运行一次 `/remote-collab start`。
5. **记下对方的团队目录名和 lead 名**：`git ls-tree -d --name-only <远端>/<分支> -- _agent_team_work_zone/` 列出远端的目录，取以 `_team` 结尾、且本地没有的那些。
   - 正好一个 → 就是对方：`git show <远端>/<分支>:./_agent_team_work_zone/<对方目录>/TEAMMATE_INFO.json | jq -r '.team_name, .lead_name'` 读出团队名和 lead 名。
   - 多个 → 列出来问用户哪个是对方。
   - 没有（对方还没推过）→ 配置里 `partner_team` 和 `partner_lead` 写 null；查看成员每次查看时会补查，发现后告诉你，你再用 jq 把它们写进配置。
6. **双方框架版本相同**：比较本地 `_agent_team_work_zone/VERSION` 与 `git show <远端>/<分支>:./_agent_team_work_zone/VERSION`。不同 → 提醒用户"两边的框架版本不同，合并时 `resources/`、`.claude/skills/` 等会大片冲突，建议先统一版本再开始"。不阻止。
7. **工作目录有未提交改动**（`git status --porcelain` 有输出）→ 提醒一句"之后合并时，如果这些改动正好落在要合并进来的文件上，合并会被挡住"。不阻止。

### 切换方式

`start` 时配置里 `stopped_at` 为 null、`watch_mode` 有值、且和这次要的方式不同（例如查看成员方式运行中，用户说"改用后台脚本查看"），先问用户一句："现在用的是<当前方式>。要先停止它、改用<新方式>吗？"

- 同意 → 先按 `stop` 做（推送未推的团队文件、停掉当前方式），再按新方式 `start`。
- 不同意 → 什么都不改。
- 同一方式重复 `start` → 按"重新 start"处理。

### 写配置

```bash
cfg=_agent_team_work_zone/<团队目录名>/remote_collab.json
ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
tmp="$(mktemp "$(dirname "$cfg")/.rc.XXXXXX")" \
  && jq -n --arg remote "<远端>" --arg branch "<分支>" --arg self "<团队目录名>" \
       --argjson partner '<"对方团队目录名" 或 null>' --argjson plead '<"对方 lead 名" 或 null>' \
       --argjson watcher '<"<slug>-remotewatch" 或 null>' --arg mode "<auto 或 manual>" \
       --arg interval "<第 1 种的间隔，默认 30m>" --arg sinterval "<第 2 种的间隔，默认 50m>" \
       --argjson wmode '<"teammate"、"script" 或 null（还没问）>' --arg ts "$ts" '
     {schema_version: 1, remote: $remote, branch: $branch, self_team: $self,
      partner_team: $partner, partner_lead: $plead, watcher: $watcher, mode: $mode,
      watch_mode: $wmode, interval: $interval, script_interval: $sinterval,
      push_permission: null, push_permission_granted_at: null,
      started_at: $ts, stopped_at: null}' > "$tmp" \
  && jq empty "$tmp" && mv "$tmp" "$cfg" && chmod 644 "$cfg" || rm -f "$tmp"
```

配置已存在（重新 start）时不重写，只用 jq 更新当前方式的间隔（`interval` 或 `script_interval`，命令里给了才改）、`watch_mode`（刚问过才写）、`stopped_at: null`、`started_at`，以及前提检查新得到的值。

兼容：旧配置没有 `watch_mode` → 按 `"teammate"` 处理，不改写；`schema_version` 仍为 1（只是新增字段）。`mode: "manual"` 时 `watch_mode` 不起作用。后台脚本方式下 `watcher: null`。

### 问查看方式和推送方式（只在 start 时问一次）

配置里还没有 `watch_mode`、或 `push_permission` 为 null 时，在写配置之后用**一条消息**问（只问还没定的那件；两件都定了就都不问）。用户在 start 之前或当时已经说清方式（"用后台脚本查看""不要常驻成员"）→ 方式不问。单人工位不问方式（见第 0 条）。问句原文（`<…>` 换成实际值）：

```
开始和另一台机器上的团队协作前，有几件事请你定（直接回答，例如"1，a，同意"或"第 2 种，5 分钟，b"）：

一、怎么查看对方的更新
(1) Haiku 查看成员：每 30 分钟查看一次，有给我们的文档时它先整理成摘要再告诉我（默认）。
(2) 后台脚本轮询：每 50 分钟查看一次，没有更新时不花任何用量；有更新才唤起我，并临时起一个 Haiku 子代理整理摘要。会话结束后要重新启动（团队工位运行 /reactivate-team 时会自动接上）。
间隔可以在回答里改。第 1 种推荐 30 分钟：
- 定时循环底层是 cron 表达式，只有能整除 60 的分钟数（15、20、30）或整点小时能均匀触发；50 分钟这类数会被改成每小时一次。
- 30 分钟在 1 小时的提示缓存内，每轮都命中（前提：我自己、分窗格显示的成员、或项目里设了 1 小时缓存的同进程成员，见第三问），命中部分按十分之一（Haiku）或二十分之一（Opus、Sonnet）计价。
- 可以更密（20 或 15 分钟），代价是我被唤醒的次数成比例增加。
- 不建议为了省用量拉到 60 分钟或更长：60 分钟正好卡在缓存到期的边上，常常错过；更长则每轮都要全价重算整个上下文，反而更费。真要省用量，选第 2 种，空闲时不花用量。

二、推送方式
推送会把本地分支上所有还没推的提交都推上去，包括成员和你自己的代码提交，不只是团队文件。
(a) 每次推送前，我把要推的提交列给你，你批准了我才推（默认）；
(b) 全自动：我在需要时直接推送，不再问你。

<只在需要时加第三问，条件见下>
三、（只在你选第 1 种时适用）查看成员的缓存设置
成员现在和我在同一个进程里显示（同进程方式）。这种方式下，成员的提示缓存默认只保留 5 分钟，查看成员每轮都不命中、整段按全价重写。可以由我在本机的项目设置 .claude/settings.local.json 里加一项 subagentPromptCacheTtl: "1h"，把缓存改成 1 小时。它只在这台机器上生效（不随 git 走），对本项目里所有子代理和成员都生效；写入缓存的单价会高一些（基价的 2 倍，原来是 1.25 倍），但命中后只按十分之一计价，长期常驻的成员会省很多。要我写吗？（同意 / 不用）

不选或说不清的，按 (1)、(a)，第三问按"不用"。
```

**查看方式**：
- 回答里明确选 2（"2""第 2 种""脚本""后台轮询"）→ `watch_mode: "script"`；否则（选 1、没选、含糊）→ `"teammate"`，并在回复里说一句"查看方式按 (1) 记下了"。
- 间隔：回答里带的间隔（"5 分钟""30m"）用于所选方式，第 1 种写进 `interval`，第 2 种写进 `script_interval`；回答没带、但命令里给了（`/remote-collab start 30m`）→ 用命令里的，同样按所选方式写入；都没有 → 第 1 种 `30m`，第 2 种 `50m`。第 2 种最短 `1m`，更短就按 `1m` 并告诉用户。
- 配置里已有 `watch_mode` 时不再问方式；重新 start 时，命令里给的间隔只更新当前方式的间隔。

**推送方式**：
- 用户明确选 (b)（例如回答"b"、"全自动"、"直接推"）→ 配置写 `push_permission: "once-at-start"`、`push_permission_granted_at: <当前时间>`。
- 选 (a)、没有选、或回答含糊（例如"嗯""都行""你看着办"）→ `push_permission: "ask-each-time"`，`push_permission_granted_at` 保持 null。
- 判断不出用户选了哪个时按 (a) 写，并告诉用户一句"按 (a) 记下了；要改成全自动，说'推送改成全自动'"。
- 重新 start 时 `push_permission` 已有值就不再问。
- 改选：用户之后说"推送改成全自动"或"推送每次问我"→ 用 jq 改 `push_permission`（改成 (b) 时同时写 `push_permission_granted_at: <当前时间>`，改成 (a) 时写 null），不用重新 start。

**第三问（同进程成员的缓存设置）**：订阅用户只有主会话默认 1 小时缓存；同进程显示的成员、子代理默认只有 5 分钟，所以同进程下查看成员每轮都不命中。Claude Code ≥ 2.1.242 可以用设置 `subagentPromptCacheTtl: "1h"`（或环境变量 `CLAUDE_CODE_SUBAGENT_PROMPT_CACHE_TTL=1h`）改成 1 小时。写问句前先判断，三条都满足才加第三问，否则不加、也不提：
1. 显示方式是同进程：读 `~/.claude/settings.json` 的 `teammateMode`。没写或为 `"in-process"` → 同进程，加第三问；`"tmux"` 或 `"iterm2"` → 分窗格，不加；`"auto"` → 你的环境里有 `TMUX` 变量、或 `TERM_PROGRAM` 为 `iTerm.app` 时算分窗格，不加，否则算同进程，加。只有 `"auto"` 时才看这两个环境变量：在 tmux 里运行、但 `teammateMode` 写的是 `"in-process"` 时，成员仍是同进程显示。
2. 版本：`claude --version` ≥ 2.1.242。低于这个版本设置无效：不加第三问；用户选第 1 种时，在结尾那句话里说明"成员缓存只有 5 分钟，每轮都不命中；可以改用分窗格显示，或选第 2 种"。
3. 还没设过：项目 `.claude/settings.local.json`、`.claude/settings.json` 都没有 `subagentPromptCacheTtl: "1h"`，环境里也没有那个变量。

用户选第 1 种、且第三问回答同意时，这样写：

```bash
f=.claude/settings.local.json
[ -f "$f" ] || echo '{}' > "$f"
cp -p "$f" "$f.bak.$(date -u +%Y%m%d%H%M%S)" \
  && tmp="$(mktemp "$(dirname "$f")/.settings.XXXXXX")" \
  && jq '.subagentPromptCacheTtl = "1h"' "$f" > "$tmp" \
  && jq empty "$tmp" && mv "$tmp" "$f" || rm -f "$tmp"
```

- 原文件 `jq empty` 不过（不是合法 JSON）→ 不写，告诉用户文件格式有问题、请先修。
- 写完告诉用户一句：已写入，对之后派生的成员和子代理生效（查看成员就是这次刚派生的）。
- 这个文件是本机的设置，不随 git 走，不影响对方。文件原来不存在时由上面的命令新建；看一眼它是否已在项目 `.gitignore` 里，没有就告诉用户一句（不自动改用户的 `.gitignore`）。
- 回答"不用"或没答 → 结尾那句话里说明"同进程下查看成员每轮都不命中缓存，每轮按全价重写；要省，可以改用分窗格显示，或改选第 2 种"。

### 派生查看成员（查看成员方式；团队工位才做）

- 配置的 `watcher` 已在登记表里、且本会话里它还在（发一条 SendMessage 不报"不可寻址"）→ 不重新派生，只给它发"开始"消息：`[remote-collab] start <间隔>：读 <项目根>/.claude/skills/remote-collab/watcher_rules.md，照它执行。`（`<间隔>` 取配置里的 `interval`，`<项目根>` 换成项目根目录的绝对路径。）
- 否则按 `/add-teammate` 的第 4 步（工位骨架、登记表）和派生做法新增它，用户输入 `start` 就是同意，不再问。登记项：`name` = `<slug>-remotewatch`，`role_source` = `{"type": "subagent", "subagent_name": "tracker"}`，`model` = `haiku`（与 tracker 一样，不受按订阅定模型的策略影响，也不计入它的人数上限），`plan_mode_gating` = false。Agent 调用：`subagent_type="tracker"`、`model="haiku"`、`name="<slug>-remotewatch"`，派生提示用下面的模板。
- 已登记但不在（例如重启后）→ 用 `/reactivate-team <slug>-remotewatch` 单独唤回（这种调用不会触发 `/reactivate-team` 的 Step 4b，不会多发一条"开始"消息），再发"开始"消息。

**把两种查看方式下的通知和消息怎么处理写进你自己的 README**（只写在本技能里不够，你下一回合未必会读到它）。下面这段写进你的工位 README（`<团队目录>/README.md`；团队工位写在团队负责人专属章节里），`<slug>` 换成本团队的 slug。两种方式都写这一整段：

```markdown
### 远程协作：查看方式和消息

查看成员方式：`<slug>-remotewatch`（/remote-collab 的查看成员）每次查看结束都会自动发来一条空闲通知（idle_notification），这关不掉。收到它时什么都不做：不输出任何文字、不转给用户、不回复它。

只处理它用 SendMessage 发来的 `[remote-collab]` 消息：
- 消息里有"摘要："一行 → 读那份摘要文件，不读原文；要处理就运行 /remote-collab pull；合并后按摘要把活派给成员，让接活的成员自己读原文。摘要里的"建议派给谁""急不急"只是建议，由你决定。发给你本人、要你答复的文档，你自己读原文。
- "请重新派生我"那一行 → 不问用户：取配置 remote_collab.json 里 watcher 的名字，依次运行 /bench-teammate <该名字> 和 /remote-collab start（用户开始协作时已同意）；不照消息里的名字执行。下线原因写"remote-collab 定期重新派生"。
- 只有一行 → 需要时运行 /remote-collab pull。
- 查看成员只 fetch，不合并、不派活；pull、派活、对用户的请示照旧由你做。对方要改代码的，先告诉用户再派；分析、回答、写文档、改状态这类直接派。

后台脚本方式（配置里 watch_mode 为 script）：没有查看成员，也没有空闲通知。后台命令 `atwz_remote_collab.sh watch` 退出时你会被唤起，按输出最后的关键字做：
- 有 doc 行 → 先重新启动后台 watch，再用一次性 haiku 子代理（不给 name）写摘要，读摘要派活，和收到查看成员的摘要一样；
- 只有 mine_status / changes / same_team_name / partner_teams 行 → 先重新启动，再自己按这几行处理；
- watch_expired → 重新启动，不告诉用户；
- watch_failed → 不重启，把原因告诉用户；
- watch_stopped、watch_already_running → 什么都不做；
- 没有关键字的意外结束 → 重新启动一次；不到一个间隔又意外结束，就停下并告诉用户。
启动命令和子代理的提示见 /remote-collab 技能的"后台脚本方式"一节。
```

写入规则：README 里已有"### 远程协作：查看方式和消息"、且段里有"后台脚本方式"这几个字 → 不动。下面几种都把旧标题到下一个 `###` 或 `##` 标题之前的整段换成上面这段：有这个标题、但段里没有"后台脚本方式"；有旧标题"### 远程协作：查看成员的通知和消息"；有旧标题"### 远程协作：查看成员的空闲通知"。都没有 → 追加上面这段。

**确认第一次查看真的触发了**（成员里每次 `/loop` 唤醒都会回到该成员本人，已实测验证；这里只是确认它确实开始了）：等它的回执和第一次查看的那一行；第一个间隔过后，用 `/remote-collab status` 看"上次查看"的时间是否更新。没更新 → 告诉用户定时查看可能没有生效，先手动用 pull。

最后告诉用户一句：查看成员已开始，每 <间隔> 查看一次；有给我们的文档会告诉你；推送方式（`推送方式：每次推送前请你批准` 或 `推送方式：全自动`）；要停就说"停止协作"。再加一句：另有后台脚本方式：没有常驻成员、空闲时不花费，但会话结束要重新启动；要换就说"改用后台脚本查看"。第三问的回答或版本要求另有说明时（见上一节），也写在这里。

### 后台脚本方式

配置里 `watch_mode` 为 `script` 时，不派生查看成员，跳过上面"派生查看成员"里的派生和"确认第一次查看"两步（写 README 那一段照做），改为下面的做法。单人工位也可以用这种方式。

启动后告诉用户一句：后台查看已启动，每 <间隔> 查看一次；有给我们的文档会告诉你；推送方式（同上）；会话结束后需要重新启动（团队工位重启后运行 /reactivate-team 会自动接上；单人工位要你说"接着远程协作"）；要停就说"停止协作"。

**启动一轮后台 watch**：用 Bash 工具、`run_in_background: true` 运行

```
cd "<项目根>" && bash _agent_team_work_zone/resources/scripts/atwz_remote_collab.sh watch-stop --config <CFG 里的路径>; bash _agent_team_work_zone/resources/scripts/atwz_remote_collab.sh watch --config <CFG 里的路径>
```

- 先 `watch-stop` 再 `watch`：清掉会话重启前可能残留的旧进程。`watch` 每 `script_interval` 查看一次，只有有事时才退出；最长运行 24 小时（`--max-hours`）后自己退出。
- Bash 工具返回的后台任务 ID 只记在你自己的上下文里，不写文件；持久的是 `<团队目录>/.remote_collab_watch.pid`。
- 不去读后台输出文件、不轮询：进程退出时你会被唤起。

**后台命令退出、你被唤起时**，按输出里的关键字：

1. 有 `doc` 行 → 先重新启动一轮（`.remote_seen` 已推进，不会重复报告；处理期间也在查看），再起一次性摘要子代理（见下），读它写的摘要文件，按 README 那一段派活、决定是否 pull，和收到查看成员的摘要时一样。
2. 只有 `mine_status`、`changes`、`same_team_name`、`partner_teams` 行 → 先重新启动一轮，再自己按这几行处理，不起子代理；处理方式同查看成员方式下对应的那一行消息（`watcher_rules.md` 第 5 节）。
3. `watch_expired` → 重新启动一轮，不告诉用户。
4. `watch_failed`（退出码 1）→ 不重启，把那 3 行失败原因告诉用户。
5. `watch_stopped`（stop 或 TaskStop 结束的）、`watch_already_running` → 什么都不做。
6. 没有上面任何关键字（例如被强杀）→ 重新启动一轮。距上一轮启动不到一个间隔就又这样结束 → 不再重启，告诉用户"后台查看两次意外结束，已停下；可以改用查看成员方式"。

**一次性摘要子代理**：Agent 工具调用，`model: "haiku"`、`subagent_type: "general-purpose"`，**不给 `name`**（这样它是你的一次性子代理，不是成员：不入登记表、没有工位、做完就结束）。提示原文（`<…>` 换成实际值）：

```
你是一次性的摘要子代理。读 <项目根>/.claude/skills/remote-collab/watcher_rules.md，只照其中"一次性摘要（后台脚本方式）"一节和它指向的"摘要文件"一节做，其余各节不用管。
本批 check 输出如下：
<把 watch 输出里的全部行原样贴上>
团队目录：<项目根>/_agent_team_work_zone/<团队目录名>/
写完后只回复两样：摘要文件的路径，以及按"给 lead 的消息"一节格式写的最多 5 行文字。
```

### 查看成员的派生提示（以 tracker 模式 B 模板为底）

`<…>` 换成实际值，`<项目根>` 换成项目根目录的绝对路径。检查规则不写在派生提示里，而写在同目录的 `watcher_rules.md`：这样会话重启后叫回的查看成员也能读到同一份最新的规则，而且不用读整份技能。

```
你是 <slug>-remotewatch，<团队目录名> 的 teammate，工作在模式 B（盯守告警）；按 <项目根>/_agent_team_work_zone/resources/agents/tracker.md 的模式 B 执行。你只负责查看另一台机器上的团队有没有推来新东西，并为 lead 整理成摘要；不做别的。

（这里照 /add-teammate 派生提示的写法，放第 0 步 .started、工位与持久化、规则变更、就绪回执几段；收件人写 team-lead。）

发出就绪回执后：间隔 <间隔>，读 <项目根>/.claude/skills/remote-collab/watcher_rules.md，照它执行。
```

## 查看成员的检查规则

查看成员的检查规则在同目录的 `watcher_rules.md`（安装后是 `.claude/skills/remote-collab/watcher_rules.md`）。改规则就改那个文件；派生提示和"开始"消息都指向它。

---

## pull

1. 运行 `RC pull CFG`。
2. 按输出：
   - `nothing to merge` → 告诉用户（或只记下）远端没有要合并的。
   - `merged <前>..<后> <方式>`，可能跟着 `doc` / `mine_status` 行 → 合并成功。对照输出的 `doc` 行和查看成员的摘要文件：
     - 摘要里有的文档：按摘要派活（SendMessage 给接活的成员：文档路径 + 摘要里那一节的要点 + "请先读原文再动手"）；是否采纳"建议派给谁"由你定。发给你本人、需要你自己答复的文档，你自己读原文。对方请求里要改代码的，按团队守则既有做法，先告诉用户再派；分析、回答、写文档、改状态这类直接派。
     - 输出里有、摘要里没有的文档（查看成员看过之后对方又推了新的）：运行 `/check-inbox`，照原流程处理，或等下一份摘要。
     - 对方改成 RESOLVED 的我方文档：照 `/check-inbox` 第 9 步归档。
     - 接活的成员在 pull 之后读原文，按原文做。
   - `conflict | <文件…>`（退出码 3）→ 脚本已 `git merge --abort` 退回，工作目录和合并前一样。告诉用户哪些文件冲突，请用户决定怎么处理；不自动解决。
   - `blocked_by_local_changes | <文件…>`（退出码 4）→ 本地这些文件有未提交的改动，正好落在要合并进来的文件上，git 拒绝合并，改动原样保留。告诉用户"先提交这些改动，或等成员做完再合并"。不 stash。只有这种挡住合并的情况才提示；不挡合并的未提交改动不提示。
   - `failed: …` → 把原因告诉用户。

## push

**时机**：你写了给对方的文档、或改了对方文档的状态之后；本团队完成了对方在等的事之后；`stop` 之前。不定时推送。

1. 运行 `RC push CFG --dry-run`，看 `would_commit`（要提交的团队文件：本团队目录下的改动，以及 meeting_room、archive 里由本团队发出或发给本团队的文件）和 `would_push`（要推送的提交）。
2. 推送方式：
   - `ask-each-time`（每次推送前批准）→ 把 `would_push` 的提交列给用户，等用户批准再做第 3 步；
   - `once-at-start`（全自动）→ 直接第 3 步；
   - `push_permission` 为 null（例如配置是手动写的、或缺这个字段）→ 按 `ask-each-time` 处理。
3. 运行 `RC push CFG --message "<一句提交说明>"`。脚本只按显式路径提交团队文件（代码由写代码的成员按守则第 10 条自己提交，lead 不替它们提交），再 fetch、快进或合并，然后推送；推送被拒（对方刚推过）时重来一次。
4. 按输出：`pushed <n>` 或 `nothing to push` → 完成；带 `merged` 和 `doc` 行时，同 pull 的第 2 步处理；`conflict`、`blocked_by_local_changes`、`failed` → 同 pull，什么都没推。

## stop

用户说"停止协作"时：

1. 运行 `RC push CFG --dry-run`；有 `would_commit` → 按 push 的步骤推一次。`ask-each-time` 时用户不批准 → 这次不推，继续下面几步。
2. 给查看成员发：`[remote-collab] stop`。等它回 `[remote-collab] stopped`。
3. 用 `/bench-teammate <slug>-remotewatch` 让它下线（保留工位，下次 `start` 时叫回）。

   后台脚本方式时，第 2、3 步换成运行 `RC watch-stop CFG`（本会话里记得后台任务 ID 的，也可以用 TaskStop 结束）。进程会打印 `watch_stopped`，你被唤起时什么都不做。输出 `watch_stop_failed pid=<n>` → 把进程号告诉用户，请用户决定是否手动结束。
4. 配置用 jq 写 `stopped_at: <当前时间>`。
5. 告诉用户一句：已停止定时查看，之后需要时可以手动 pull / push，或重新 start。第 1 步没有推送时再加一句：还有未推送的团队文件，需要时说"推送"。

## status

运行 `RC status CFG`，把结果用几句话告诉用户：当前是哪种查看方式（后台脚本方式时，后台查看是否在跑、从什么时候开始）、远端和分支、对方团队、上次查看的时间和结果、上次 pull / push 的时间和结果、未推送和未合并的提交数（这两个数按最近一次 fetch）。

---

## 重新派生与重启

- 定期重新派生（查看成员方式）：查看成员每查看 12 轮（默认 30 分钟间隔约 6 小时）会请你重新派生它：Haiku 的提示超过 10 万 token 后单价变为 5 倍，上下文按查看的轮数增长。收到这一行，取配置里 `watcher` 的名字，依次运行 `/bench-teammate <该名字>` 和 `/remote-collab start` 即可，不问用户。这样也没有哪个定时任务能活到 `/loop` 的 7 天到期。门槛是脚本 `check` 的 `--respawn-after` 参数（单位是轮，默认 12）；间隔改了不用调门槛。
- 会话重启：所有成员随 lead 会话结束而消失。重启后运行 `/reactivate-team`，它会自动叫回查看成员并接着定时查看（条件见 `/reactivate-team` 的 Step 4b）；查看成员处于临时下线、或 Step 4b 报告没接上时，再运行 `/remote-collab start`：配置和查看成员的登记都在，就跳过已通过的前提检查（第 3、4 条仍要做），只叫回查看成员并发"开始"消息。
- 后台脚本方式：会话结束时后台进程也就停了。重启后 `/reactivate-team` 按它的 Step 4b 重新启动一轮后台 watch；没有成员，也不涉及重新派生。单人工位不用 `/reactivate-team`：用户说"接着远程协作"时，按"后台脚本方式"一节重新启动。
- 连续 3 次 fetch 失败：查看成员自行停止并告诉你原因（后台脚本方式下是 watch 打印 `watch_failed` 退出）；你告诉用户。

## 跨机器的 meeting_room 约定

完整说明在 `_agent_team_work_zone/meeting_room/README.md` 的"另一台机器上的团队"一节。要点：

- 跨机器的文档里，`from:` / `to:` / `cc:` 一律写 `<团队目录>/<成员>`，lead 写 `<团队目录>/lead`，例如 `from: alice_team/lead`、`to: bob_team/lead`；`to: ALL` 指两边所有人。
- 同一时刻只有一方改一份文档：发布方发出后不再改正文，补充或更正写新文件；接收方只改 frontmatter 的 `status:` 一行；发布方在 pull 进来对方改成的 RESOLVED 之后才归档；回复写成新文件。

## 守则第 10 条的例外

pull（以及 push 里的合并）由脚本用 `git merge --no-edit <远端>/<分支>` 产生合并提交，这是守则第 10 条"不做非快进合并"的唯一例外；有冲突一律 `git merge --abort` 退回并报告用户，不自动解决冲突，不 stash。

## 费用（部分实测）

这一节的金额是按 API 牌价折算的估算值；标"实测"的 token 数是 reviewer 在测试里测得的。订阅用户不为这些调用另外付费，只计入用量额度；订阅额度和 token 的换算没有公开，所以折算值只用来比较各项之间的相对大小。

**两种方式的对比**（token 数为估算，标"实测"的除外）：

| | 查看成员方式（默认） | 后台脚本方式 |
|---|---|---|
| 没有更新时 | 查看成员每轮约 1 千（实测；同进程且没设 1 小时缓存时每轮全价重写，见"问查看方式和推送方式"一节的第三问）；每 12 轮查看重新派生一次（30 分钟间隔即 6 小时，一天约 4 次），每次起点约 7–8 万（首次派生约 7.1 万，重新派生后约 7.8–7.9 万，实测）；lead 每轮被空闲通知唤起一次，每条约 300–350（实测） | 0：脚本在后台 sleep，没有模型调用，lead 不被唤起 |
| 有给本团队的文档时 | 查看成员写摘要，一份约 0.8–1.5 万（实测）；lead 读摘要 | lead 被唤起一次；一次性 haiku 子代理：子代理起点 + 读规则约 3–4 千 + 一份摘要约 0.8–1.5 万；lead 读摘要 |
| 间隔 | 默认 30 分钟（整除 60 才能均匀触发）；间隔越短，空闲时的费用越高 | 默认 50 分钟（脚本自己 sleep，不受 cron 整除 60 的限制）；间隔长短不影响空闲时的费用 |
| 会话结束后 | 团队工位运行 /reactivate-team 时自动接上 | 同左；后台进程随会话结束，由 /reactivate-team 重新启动 |
| 还没验证的 | — | 后台进程的寿命上限（脚本每 24 小时自己退出、由 lead 重新启动，以免依赖它） |

对方推送不频繁、又希望及时知道时，后台脚本方式更合适；摘要由一次性子代理写，每次都要重新读规则，不像查看成员那样已经读过。

**查看成员方式**

下面标"实测"的是 2026-10 在 30 分钟间隔下测得的 token 数，其余是估算。

1. 这个设计做的事：把定时查看挪给 Haiku 查看成员，让每次检查的工具输出（fetch、脚本输出、文档全文）留在查看成员的上下文里，不进 lead 的上下文。lead 的费用不保证因此降低，取决于和什么比：和"lead 自己每隔一段时间查看"比，lead 的上下文进得少；和"完全不定时查看、想起来才手动 pull"比，lead 多出下面第 4、5 条。
2. 查看成员的上下文（实测）：派生后读完检查规则，起点约 7–8 万 token（首次派生约 7.1 万，重新派生后约 7.8–7.9 万）；没更新的一轮约增加 1.1 千；一份短文档的摘要约增加 8 千，300 行的长文档约 1.5 万。
3. 为什么定期重新派生：Haiku 的提示超过 10 万 token 后单价变为 5 倍，上下文按查看的轮数增长。按 7.9 万的起点算，12 轮内没有文档时约 9.2 万；12 轮内没有长文档时在 10 万以下（有一份短摘要约 10 万上下）；有一份 300 行的长摘要约 10.6–10.7 万。为此脚本还有一条规则：本轮有给本团队的文档（要写摘要）、且已查看到门槛的一半（默认 6 轮）时，也输出 `respawn_due`，查看成员写完摘要、发完摘要消息就请 lead 重新派生它，长摘要之后不再接着跑满 12 轮。一班里若遇到长文档的摘要，末尾一两轮可能略过 10 万，可接受；对方文档多时可把门槛调小（`--respawn-after`）。所以查看成员每查看 12 轮会请 lead 重新派生它，让它从起点重新开始；这一步是机械的，不问用户。30 分钟间隔下一天约 4 次，lead 每天多执行约 4 次这两条命令（/bench-teammate 和 /remote-collab start），每次重新派生本身相当于多一次起点的量。
4. lead 的调用费：即使没有更新，查看成员每轮结束的空闲通知也会唤醒 lead 一次。每次只是读一遍上下文（大部分命中缓存）；这个费用随 lead 上下文变长而变大。（估算：30 分钟间隔、lead 用 Opus，约每天 $1–1.5。）
5. lead 的上下文（实测）：一条空闲通知连同 lead 的回话约 300–350 token，30 分钟间隔一天 48 条，一周约 11 万 token，会让 lead 更早触发上下文压缩。lead 用 haiku 时，实测它会对空闲通知回一句话，做不到完全不输出，这部分量略多。
6. 间隔：默认 30 分钟，理由和问句里的四点相同：
   - 定时循环底层是 cron 表达式，只有能整除 60 的分钟数（15、20、30）或整点小时能均匀触发；50 分钟这类数会被改成每小时一次。
   - 提示缓存保留 1 小时的是 lead 自己、分窗格显示的成员、以及设了 1 小时的同进程成员；其余（同进程成员默认）只有 5 分钟，每轮都不命中。30 分钟在 1 小时缓存内，每轮都命中，命中部分按十分之一（Haiku）或二十分之一（Opus、Sonnet）计价；1 小时档的写入单价是基价的 2 倍（5 分钟档是 1.25 倍）。用 API key 时缓存只保留 5 分钟，每轮都不命中，间隔长短对这项费用没有影响。
   - 可以更密（20 或 15 分钟），代价是 lead 被唤醒的次数成比例增加。
   - 不建议为了省用量拉到 60 分钟或更长：60 分钟正好卡在缓存到期的边上，常常错过；更长则每轮都要全价重算整个上下文，反而更费。真要省用量，选后台脚本方式，空闲时不花用量。
   重新派生按轮数算，间隔只影响多久重新派生一次（30 分钟约 6 小时，20 分钟约 4 小时，60 分钟约 12 小时）。
7. 有更新时：lead 读摘要文件、派活的费用另算；接活成员读原文、做事的费用另算；都取决于对方推送的频率和文档长短。
8. lead 的会话必须一直开着，定时查看才会进行。
