---
name: broadcast-rule
description: >
  Team lead 把一条规则变更发给每个在线 teammate，记进本团队常设的 RULES_LEDGER.md，
  并跟踪确认（ACK）。只在 team lead 上下文有效。不修改 README 文本。
disable-model-invocation: false
allowed-tools: Read Write Edit Glob Grep Bash
---

# `/broadcast-rule` — 把规则变更发给全队

只改规则文件，到不了已经在运行的成员：teammate 的 spawn prompt 是固定的，没有任何机制让它重读 README。本 skill 把规则变更推送给每个在线 teammate，让每人记进自己的 README 并回复确认；同时留下常设记录，让下线（benched）、已死亡或尚未派生的 teammate 之后补上（它们的 spawn / reactivate prompt 会让它们去读这份记录）。

用户同意某条规则变更后调用（与 `/add-teammate` 的约定相同）。

## 身份前置检查

**必须在 team lead 上下文调用**：你的工位是 `_agent_team_work_zone/<name>_team/`（含 `TEAMMATE_INFO.json`）。若你是 teammate 或扁平工位 → 停下，告诉用户："本 skill 只有 team lead 能用。"

## Step 1：收集规则

发送任何消息之前，先收集：
- **规则原文**，按用户（或你）的措辞逐字照录；
- **一行标题**；
- **它修订的是什么**：`README 第 N 条` / `teammate_rules 第 N 条` / `新增`（仅作说明；本 skill 不修改 README 或 `teammate_rules.md` 的文本）；
- **谁批准的**：`user`（逐字引用用户的批准原话）或 `lead`。

原文有歧义就先问清楚再发。一条规则**只发一次，用最终措辞**：一条完整的消息，而不是一连串更正——teammate 在回合中收不到任何消息，接连发出的更正会在它回合结束时一起到达。

## Step 2：分配 id

`R-<UTC YYYYMMDD>-<n>`，其中 `n` = 1 + 记录里当天已有的条目数（记录文件还不存在时为 0）。下文的 `<id>` 指这整个 id（含前缀），例如 `R-20261004-1`。

## Step 3：确定接收人

读 `_agent_team_work_zone/<your_team>/TEAMMATE_INFO.json`。接收人 = `active_teammates` 中 `status ∈ {active, idle}` 的成员。benched、`failed_to_reactivate` 和已下岗的 teammate **不**发消息；在确认表里把它们列为"不在线"——它们在唤回时补上。

## Step 4：追加到记录文件

记录文件是 `_agent_team_work_zone/<your_team>/RULES_LEDGER.md`，与 `TEAMMATE_INFO.json` 并列。它**归 lead 所有**（rule 1）：只有 lead 写，teammate 只读。这是常设记录——不要归档。文件不存在时，用以下文件头新建：

```
# Rules ledger — <team>_team
Rule changes broadcast to this team's teammates with /broadcast-rule. Lead-owned; teammates read it, never edit it.
Spawn and reactivation prompts tell every teammate to read this file and acknowledge any rule it has not recorded yet.
```

然后追加一节（最新的在最下面；直接追加文件即可——记录文件是 Markdown，不是 JSON 注册表）：

```
## <id> — <一行标题>
- Issued: <UTC 时间> by <lead 名字>; approved by: <user | lead>（若来自用户，逐字引用批准原话）
- Amends: <README rule N / teammate_rules item N / new>   （仅作说明；本 skill 不改 README 文本）
- Text (verbatim, as sent):
  > <规则原文>
- Acknowledgements:
  | Teammate | Status at send | Sent (UTC) | ACK (UTC) | Note |
  |---|---|---|---|---|
  | <name> | active | <时间> | — | |
  | <name> | benched | — (not live) | — | gets it at reactivation |
```

## Step 5：给每个在线 teammate 各发一条消息

把 `<id>` 填成完整的 id（这样你要求的回复就是例如 `ACK R-20261004-1`）。对接收人逐个循环，**每人发一条 SendMessage**（不要用一条群发——确认表是逐人记录的）。消息原文如下：

```
[RULE <id>] 团队规则变更——本条取代此前在同一事项上的任何指示。
<规则原文>
现在请：(1) 把它记进你自己 README.md 的「## Team rule changes」一节——若没有这一节，就在 <!-- TEAMMATE_RULES:START --> 那一行的正上方新建（若你的 README 里没有这一行，就把这一节放在 README 末尾；不要写在该块里面或下面：升级时该块会被整体替换）；id 和原文照抄。(2) 用 SendMessage 工具给 lead 回复（普通回复到不了 lead），且只回复：ACK <id>
从现在起按此规则执行。
```

在 **Sent** 列填每次发送的时间。发送报错 `No agent named X is currently addressable` → Note 写 "dead at send; gets it at reactivation"。

## Step 6：结束本回合——不要在回合里等 ACK

teammate 的回复要等你的回合结束才送达，所以不要在本回合里等。用一行结束：

```
<id> sent to N live teammates; ACKs pending
```

## Step 7：ACK 到达时记录

之后的回合里，`ACK <id>` 到达时，在对应行的 **ACK** 列填上时间。`/spawn-team`、`/add-teammate`、`/reactivate-team` 的回执也可能带 `ACK <id>`（teammate 从记录文件补上的规则）——同样填进去。

某个 teammate 超出合理时间仍无回音 → 按 rule 13「teammate 沉默时怎么判断、怎么做」处理。**绝不循环重发。**

## 不在本 skill 范围内

- **跨团队广播**：用 `meeting_room/`，`to: ALL`。
- **修改 README 或 `teammate_rules.md` 的文本**：应当成为框架永久文本的规则，是另一项单独、审慎的改动。
