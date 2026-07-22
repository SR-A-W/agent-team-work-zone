---
name: reactivate-team
description: >
  Team lead 在 session 重启后调用，读 TEAMMATE_INFO.json 重建 team：
  为每个 active teammate 用 Agent 工具 spawn 新 session（name 必须为 <slug>-<role>；权限模式继承 lead，不在 spawn 时单设），
  引导它读自己工位的 working-context.md（Part A 快照 + Part B 工作日志）恢复状态。
  无参调用只唤醒 active/idle，**跳过 benched**（临时下线）；`/reactivate-team <name>`
  单独唤回指定的（通常是 benched）teammate。这是"跨 session 团队恢复"的唯一方式——
  Claude Code 不会自动 respawn teammate。
disable-model-invocation: false
allowed-tools: Read Write Edit Glob Bash Agent
---

<!--
[KEEP IN SYNC WITH /checkpoint]
working-context.md 是两段式：Part A = 9 节当前态快照；Part B = 追加式工作日志。
此处引导新 teammate 读取的结构（Part A 9 节 + Part B 日志）必须与 /checkpoint 写出的
完全一致。改动任一 section 名称/编号/语义，或 Part B 的存在/读取方式，
也要同步更新 resources/skills/checkpoint/SKILL.md。
-->

# Reactivate Team — 重建 Team 并让每个 teammate 自恢复

## 身份前置检查

**必须在 team lead 上下文中调用**。判断：

1. 先从对话 context 推断——你是否已经清楚自己是 team lead？（工位目录以 `_team` 结尾且含 `roundtable/`、`TEAMMATE_INFO.json`）
2. 推断不出 → Glob `_agent_team_work_zone/*_team/README.md`，读 README 匹配对话历史
3. 如果**不是** team lead → **立即停止**并告知用户："此 skill 只能在 team lead 上下文中使用。当前是扁平工位/teammate。"

## 调用形态：无参全量恢复 vs 指定单个唤回

本 skill 有两种调用：

- **`/reactivate-team`（无参）**——session 重启后的常规全量恢复：唤醒所有 `status ∈ {active, idle}` 的 teammate，**跳过 `benched`**（临时下线的）。这是默认。
- **`/reactivate-team <name>`——单独唤回一个指定 teammate**（典型用于把一个 `benched` 的唤回，也可强制单独重建某个 active）：只 spawn 这一个 name（Step 3）。成功后若它原本是 `benched`，改回 `active` 并清掉 `benched_at` / `bench_reason`（详见 Step 4）。
  - **无 team 注册预处理（CC ≥2.1.178）**：直接 spawn 即可。会话级 team 由 Claude Code 自动管理，无需（也无法）`TeamCreate`/`TeamDelete`——单独唤回不会干扰本 session 里其他正活着的 teammate。

> **benched 由谁决定唤回**：是否唤回某个 benched teammate 是 **team lead 的常驻管理判断**（见 README 工作守则）——lead 在任何环节（尤其派活 / 开始某任务前）发现需要某 benched 专长，就向用户提议，经同意（或用户主动点名）后用 `/reactivate-team <name>` 执行。**无参调用绝不自动唤醒 benched，也不让用户在清单里勾选**——状态表对用户是黑箱。

## 前提：如何判断 teammate 是否存活

**核心规则（时序判断，不是查文件）**：

> 一个 teammate 存活，当且仅当它是**当前这条未中断的 lead session** spawn 的、且此后 session 没有重启过。任何 session 重启（SSH 断 / tmux 崩 / `/resume` / 进程退出）⇒ 该 team 所有 teammate 必然全部死亡，无例外。

把判断逻辑从"我去查文件看它活没活"扭转成一个时序问题：**这些 teammate 是我【这条命】里 spawn 的吗？不是 → 全死，必须 reactivate。** 永远不要靠查文件来判断存活。

### 四个"非证据"陷阱（逐条点名）

以下证据**全部无效**，不能用来推断 teammate 存活：

1. **`config.json` / 任何磁盘 team 文件里有该 member 条目** → ✗  
   磁盘上的 team 文件记录的是历史注册，不反映任何进程是否存活。（CC ≥2.1.178：会话级 team 由 Claude Code 自动建、自动清理，跨 session 不保留——但你仍**不能**靠任何磁盘文件推断存活，唯一权威信号是同 session 内的 SendMessage 回执。）

2. **inbox 里有它的消息（无论 read/unread）** → ✗  
   `inboxes/` 是磁盘残留文件，不随 session 清理，死团队的消息能留存数十天。读到旧消息**不代表对方刚回话**——这是最大的误判陷阱。

3. **`TEAMMATE_INFO.json` 里 `status:active`** → ✗（**最常见且最离谱的误判**）  
   `TEAMMATE_INFO.json` 是 lead 手动维护的静态文件，与任何运行时进程零关系。`status:active` 只是 lead 上次操作时的主观标记，和 teammate 是否真的活着毫无关联。

4. **teammate 有输出但未用 SendMessage** → ✗  
   Plain reply 跨不了 agent 边界——lead 根本看不到 teammate 的普通输出。输出只存在于 teammate 自己的 session 上下文里，对 lead 不可见。

### 唯一可靠的正向存活信号

**同 session 内收到该 teammate 的 SendMessage 回应。**  
主动 ping（SendMessage → 等对方 SendMessage 回执）是确认 teammate 当前存活的唯一可靠方法。没有回执 = 存活未知 = 视为死亡。

### 回执会过期；最常翻车的不是用户误调，而是 lead 自以为 teammate 还活着

实践中，几乎从不是"用户误调 `/reactivate-team`"，而是 **lead 没当场确认、却仍以为 teammate 活着**——拿几轮前的旧回执、或 `TEAMMATE_INFO.json` 的 `status:active` 当现状。守住两条：

- **回执是【时间点信号】、会过期**：几轮前活着 **不代表现在活着**，中间一次 teardown / 重启就全没了。**每次**要基于"活/死"下判断时（**包括"他们还活着、不用 reactivate"这种反向判断**），都必须**当场重新验证、绝不引用早先的回执**。
- **最快最硬的探活 = 扔一个 ping、直接读 `SendMessage` 的返回**（不用干等"窗口内无回复"那种慢判断）：
  - 返回 `success:true`（`Message sent to X's inbox`）→ 注册还在；但仍需等**回复**才算确认存活。
  - 返回 **`No agent named X is currently addressable`** → **注册已无 = 确定死亡**（即时、同步）。
  - **早先发送成功、现在发送失败** = 中间发生过 teardown，此前的"活着"已作废，必须 reactivate。

### Compaction ≠ 重启；怀疑已死，先 ping 再下结论

**context compaction（上下文压缩）发生在同一进程内，不杀 teammate**——压缩后早先 spawn 的 teammate 通常仍活着。所以"session 重启 ⇒ 全死"只适用于**真重启**（startup / resume / 进程退出），**不适用于压缩**。`SessionStart` hook 已按 `source` 区分文案（compact 时会提示"很可能仍活、先 ping"），但**无论 hook 说什么**：在向用户报告某 teammate 已死、或决定 reactivate 之前，**都要先 ping、等本 session 回执**——这是唯一权威判据。别把保守默认（"假定已死"）当成既成事实汇报。

---

## 流程

> **不再有 Step 0（CC ≥2.1.178）**：旧版需要先 `TeamDelete` → `TeamCreate` 重建 team 注册并清残留 ghost；这两个工具在 2.1.178 **已被删除**。新版每个 session 启动时**自动**创建唯一的会话级 team（名形如 `session-<id>`），teammate 退出时**自动清理**，磁盘不再累积死成员 ghost。因此 reactivate **直接从 Step 1 开始**——读 `TEAMMATE_INFO.json`、确认、逐个用 `Agent(...)` spawn 即可，无需任何 team 注册预处理。spawn 时**不传 `team_name`**（已被忽略），teammate 由 `Agent` 自动并入当前会话级 team。

### Step 1: 读 TEAMMATE_INFO.json

路径：`_agent_team_work_zone/<your_team>/TEAMMATE_INFO.json`

**无参调用**：从 `active_teammates` 里筛出**待唤醒集** = `status ∈ {active, idle}`（**排除 `benched`**；`failed_to_reactivate` 由用户决定是否重试，默认不自动纳入）：
- 文件不存在 → 告知用户"本 team 从未 spawn 过 teammate（TEAMMATE_INFO.json 不存在）"，退出
- 文件存在但待唤醒集为空 → 告知用户"没有需要恢复的 active teammate（可能都 offboarded 或 benched 了）"；若存在 benched，附一行只读 FYI（见 Step 2）后退出
- 待唤醒集非空 → 继续

**`/reactivate-team <name>` 指定调用**：直接在 `active_teammates` 里定位该 `<name>`（无论其 status 是 active / idle / benched / failed_to_reactivate）；找不到 → 告知用户该 name 不在 active_teammates（可能已 offboarded），退出。待唤醒集 = 仅这一个。

### Step 2: 向用户展示现状

列出每个 active teammate 的信息给用户看：

```
Team: <team_name>
需要恢复的 teammate（status ∈ active/idle）: N 个

1. <name>
   - 角色来源: <role_source.type> (<path or subagent_name>)
   - 模型: <model>
   - 最初 spawn 时间: <spawned_at>
   - 最后 checkpoint 时间: <last_checkpoint_at | "从未 checkpoint">
   - 之前被 revive 过: <revived_count> 次

2. <name>
   ...

[FYI — 仅当存在 benched 时显示，只读、不要求确认]
另有 K 个 benched teammate（临时下线，本次不唤醒）：[<benchedA>, <benchedB>]
如需唤回其中某个，请告知，我会用 /reactivate-team <name> 单独恢复。

确认开始 reactivate 吗？
（我将为每个待唤醒 teammate spawn 一个新 session，引导它读 working-context.md 自恢复。
如果某个 teammate 最后 checkpoint 时间距今很久，它可能无法完整恢复——请你决定是否仍要恢复它。）
```

> benched 的那行纯属告知——**不要**让用户在此勾选唤醒哪些，也**不要**把 benched 计入"确认 reactivate"的范围。

等待用户确认。**不要没经用户同意就开跑**——每次 Agent 工具调用都消耗 token。

### Step 3: 逐个 reactivate

对**待唤醒集**里的每个 teammate（Step 1 已按调用形态筛好——无参时即 `status ∈ {active, idle}` 按数组顺序，指定调用时即那一个）：

**3.1 准备 spawn prompt**（关键：引导 teammate 读自己工位自恢复）：

```
You are {name}, a teammate previously active on team '{team_name}'. Your previous
Claude Code session was terminated (not by shutdown_request — by session
interruption such as the team lead's session exiting). Claude Code does NOT
automatically preserve teammate state across sessions, so this is a fresh session
and you have no memory of your prior work.

Before doing anything else:

1. Read _agent_team_work_zone/{team_name}/teammates/{name}/README.md — your role definition
2. Read _agent_team_work_zone/{team_name}/teammates/{name}/working-context.md — your
   last checkpoint. It has TWO parts: Part A = a 9-section current-state snapshot (the
   authoritative "where things stand now"); Part B = an append-only work journal with
   recent conversation, verbatim key exchanges, and the last 3-4 dialogue turns. Read
   BOTH — Part A in full, plus the most recent Part B entries (and their verbatim tail)
   to recover recent context and conversation. (Older format with only 9 sections and no
   Part B is fine — just use the snapshot.) Trust this document — the previous spawn of
   you wrote it for you.
3. Read _agent_team_work_zone/{team_name}/teammates/{name}/commitments.md — outstanding
   promises you must honor.
4. Optionally read _agent_team_work_zone/{team_name}/teammates/{name}/TODO.md and
   completed.md for additional context if working-context points to them.
5. If your README.md has an old full rules section (heading matches `## Work Rules` or
   `## 工作守则`, and it is NOT inside a <!-- TEAMMATE_RULES:START --> block), replace that
   old section (from that heading through the next `## ` heading of the same level, or
   through end of file — heading included) with the content of
   _agent_team_work_zone/resources/teammate_rules.md; otherwise, if your README.md does NOT
   contain a <!-- TEAMMATE_RULES:START --> block, copy that block from the same file and
   append it to the end of your own README.md (you may only edit your own file).

If working-context.md looks corrupted, empty, or is missing sections, DO NOT
invent content — message the team lead via SendMessage asking for guidance
before starting work.

After reading, use the SendMessage tool to send the team lead exactly one line:
"Resumed from checkpoint at {last_checkpoint_at}. Ready."
(A plain reply will NOT reach the lead — you MUST use SendMessage.)

Do NOT start any new work until the team lead messages you with the next task.
```

**3.2 调用 Agent 工具** spawn：

```
Agent(
    description="Reactivate <name>",
    subagent_type="<根据 role_source 决定>",   # e.g., "general-purpose" / "tracker" / etc.
    model="<model from TEAMMATE_INFO.json>",
    name="<slug>-<role>",                       # 关键：它在 team 里的 name（沿用原 name，须为 <slug>-<role>）
    prompt="<上面的自恢复 spawn prompt>"
)
# 注意（CC ≥2.1.178）：不再传 team_name——已被忽略；teammate 由 Agent 自动并入当前会话级 team。
# 也不传 mode：teammate 权限模式无法在 spawn 时单设，继承 lead 当时的模式（要 auto 就让 lead 处于 auto / 设 permissions.defaultMode:"auto"）。
```

**subagent_type 选择规则**：
- `role_source.type == "subagent"` → `subagent_type: role_source.subagent_name`（引用通用 subagent）
- `role_source.type == "archetype"` 或 `"tier2"` 或 `"inline"` → `subagent_type: "general-purpose"`（通用 agent，具体角色靠 spawn prompt 注入）

**3.3 接收响应 + 记录结果**：

二元判定：
- **成功**：在本 session 收到该 teammate 的 SendMessage 回执（内容含 "Resumed from checkpoint at X. Ready."）→ 标记成功
- **失败/状态未知**：未收到 SendMessage 回执（含超时）→ 告警给用户，由用户决定（重试 spawn / 检查 working-context.md 是否损坏 / 或 /remove-teammate 移除）；**不假定成功**

> **重要**：磁盘 artifact（`working-context.md` / `last_checkpoint_at`）只能帮你了解 reactivate **之前**的状态，绝不能作为**本次 reactivate 是否成功**的判据——spawn 成功还是失败，这些静态文件都一样，不反映本次运行时事实。见本技能开头"前提"段。

### Step 4: 更新 TEAMMATE_INFO.json

对每个被唤醒的 teammate（无论成功失败）更新：

- 成功：
  - `spawned_at` 更新为当前时间
  - `revived_count` 加 1
  - `status` 置为 `active`（若原为 `benched` / `idle`，一并转正）
  - 若原为 `benched`：**删除** `benched_at` 和 `bench_reason` 字段
- 失败：
  - `status` 改为 `failed_to_reactivate`
  - 不更新 spawned_at（若原为 benched，benched 字段保留，便于稍后重试）

全局：
- `updated_at` 改为当前时间

用 jq 示例（对每个成功的 teammate，替换 N=name）：
```bash
jq --arg name "N" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   '.active_teammates |= map(if .name == $name then .spawned_at = $ts | .revived_count += 1 | .status = "active" | del(.benched_at, .bench_reason) else . end) | .updated_at = $ts' \
   "$info" > /tmp/info.json && mv /tmp/info.json "$info"
```

### Step 5: 汇报给用户

输出 summary：

```
Team <team_name> reactivated:

✅ Successfully resumed (N 个):
- <name1>: "Resumed from checkpoint at <ts>. Ready."
- <name2>: ...

❌ Failed to reactivate (M 个):
- <name3>: <reason>

Status updated in TEAMMATE_INFO.json.

Next steps:
- 如果有 failed teammate，请决定是：(a) 手动调试（检查 working-context.md 是否损坏），
  (b) /remove-teammate 移除它，(c) /add-teammate 重新招募
- 所有成功的 teammate 都已经 idle 等待你派发任务。你可以通过 SendMessage 给
  它们下一步指令，也可以先让它们 /check-inbox 看看有没有未处理工作
```

## 特殊情况处理

### Ghost collision（死成员名字残留）——CC ≥2.1.178 起不再发生

旧版（CC ≤2.1.177）：磁盘 `config.json` 的 `members` 数组会残留上次 session 的死 in-process 成员（ghost），用原名 spawn 会被自动加 `-2/-3` 后缀、导致名字漂移、`SendMessage` 找不到人——旧版靠 Step 0 的 `TeamDelete`→`TeamCreate` 清场根治。

**CC ≥2.1.178 已无此问题**：每个 session 的会话级 team 在退出时**自动清理**，磁盘不再累积 ghost；新 session 用原名 spawn 不会撞残留、不会被加后缀。因此本 skill **删掉了 Step 0**，正常流程下 spawn 直接拿回原名。

> 若仍偶遇名字被加后缀（极少见，例如同 session 内同名重复 spawn）→ 把该 teammate 标 `failed_to_reactivate` 告知用户；或接受新名字并**同步更新 TEAMMATE_INFO.json 里该成员的 name**（否则后续 `SendMessage` 找不到它）。

### 如果 working-context.md 损坏

Teammate spawn prompt 里已明确指示——如果文件损坏，teammate 会 SendMessage lead 请示，不盲目开工。

### 如果 TEAMMATE_INFO.json 格式坏了

停止 reactivate，告知用户"TEAMMATE_INFO.json 解析失败，请检查格式"。不要尝试自动修复——让用户介入。

### 终端 / tmux 相关（仅在 spawn 报 tmux 错、或想调显示/持久化方式时看）

> tmux **不是** agent team 的必需品——in-process 模式在任何终端都能跑完整 team 功能。本段仅在遇到下列报错、或你想改显示/持久化方式时才相关，正常流程**无需理会**。

**两个 tmux spawn 报错的含义**（硬性版本/环境检查由 `bootstrap.sh` 负责，本 skill **不**自己跑检查）：
- `Failed to create teammate pane: size invalid` → 你在 tmux 内、但 tmux 版本太老（< 3.0）。升级 tmux ≥ 3.0（3.6a 实测 OK），或退出 tmux 改用 in-process。
- `Could not determine current tmux pane/window` → PATH 里的 tmux 与当前 session（`$TMUX` socket）的 tmux 不是同一个（多版本共存）。让 PATH 指向启动当前 session 的那个 tmux。
- 这两个错 **bootstrap 会在你进 tmux 后预先拦截并诊断**——看到就**重跑 bootstrap**，按它的指引修。

**`teammateMode`（显示方式，settings.json 字段）**：

| 值 | 行为 |
|---|---|
| `in-process` | 所有 teammate 在主终端，↑↓ 选 + Enter 查看/发消息；任何终端可用。**默认（自 CC v2.1.179）** |
| `auto` | 在 tmux session 内**或** iTerm2 里 → 分面板；否则回落 in-process |
| `tmux` | 启用分面板，自动探测用 tmux 还是 iTerm2 |
| `iterm2`（CC v2.1.186+）| 显式用 iTerm2 原生分面板（需 `it2` CLI） |

- `teammateMode` 是**用户级**设置（`~/.claude/settings.json`）；也可 `--teammate-mode` 单会话覆盖；分面板需 tmux 或 iTerm2。**别手改 settings.json**——重跑 `bootstrap.sh` 的"显示模式选择"菜单（它写**全局** `~/.claude/settings.json`）。
- **强烈推荐把 Claude Code 跑在 tmux session 里**（即使显示用 in-process）：关终端 / SSH 断连时 tmux 保住进程、session 不中断，**直接少触发本 skill（`/reactivate-team`）**。装不装 tmux、跑不跑在 tmux 内都不影响 team 功能，但跑在 tmux 内能省去频繁重建 team。详见 `docs/user_manual.md` 的 tmux 部分。

## 不要做的事

- **不要**在 reactivate 过程中让老 teammate 和新 teammate 共存（会导致混乱）——reactivate 的前提是老 session 已经完全死掉
- **不要**修改 teammate 工位下的任何文件（rule #1，尤其是 working-context.md）——只有 teammate 自己能改
- **不要**一次 reactivate 非常多 teammate（>5 个）——每个都是独立 Agent 调用，token 消耗线性累加。如果 team 规模大，分批进行

## 为什么有这个 skill

Claude Code 的 agent-teams 特性**不保存 teammate 的 session**。当 lead session 崩溃或退出：
- `~/.claude/teams/<team>/config.json` 的 metadata 残留
- `~/.claude/teams/<team>/inboxes/` 的邮箱消息残留
- **但 teammate session 全部消失**

本 skill 通过"读 `TEAMMATE_INFO.json` + 用 Agent 工具重新 spawn + 引导 teammate 自恢复"这个 3 步链路，把"恢复 team"从 Claude Code 不可能的事变成可能。

配合：
- Rule 13（teammate 工位自维护 + checkpoint 义务）
- `/checkpoint` skill（teammate 写 working-context.md）
- `.claude/settings.json` 的 `SessionStart` hook（lead 一启动就被提醒运行 `/reactivate-team`）
- `docs/teammate_info_schema.md`（数据结构参考）
