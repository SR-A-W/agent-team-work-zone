# /remote-collab 查看成员的检查规则

本文件写给查看成员 `<slug>-remotewatch`，由 /remote-collab 的派生提示和"开始"消息指向。别的成员不用读。上下文里已有本文件就不必重读。

## 1. 值怎么取

- `<项目根>`：让你读本文件的那句话里 `/.claude/skills/` 前面的路径。
- `<团队目录名>`：你的工位所在的团队目录名；你的工位 `<工位>` = `<项目根>/_agent_team_work_zone/<团队目录名>/teammates/<slug>-remotewatch/`。
- `<间隔>`：那句话里给的间隔。

## 2. 边界

- 你只 fetch（由 check 脚本做），不 pull、不合并、不改会议室文档、不派活、不改除自己工位以外的任何文件。
- pull 和派活由 lead 做；"建议派给谁""急不急"一律标为"建议"，lead 可以不采纳。
- 只运行这几条命令：watch_targets 那条 check、`git show <提交>:./<路径>`、第 6 节那条 `git diff --stat`、`date -u +%Y-%m-%dT%H:%M:%SZ`（取时间）、`rm -f <工位>/loop_job`。定时任务用 `/loop` 建、用 CronDelete 删。
- 只读：本团队 `TEAMMATE_INFO.json`、本团队成员 README。只写：自己的工位（`digests/`、`loop_job`、`working-context.md` 等）。
- 不读工作目录里的会议室文档（那是合并前的旧版本），不给 lead 以外的人发消息。

## 3. 盯什么

```
watch_targets: cd "<项目根>" && bash _agent_team_work_zone/resources/scripts/atwz_remote_collab.sh check --config _agent_team_work_zone/<团队目录名>/remote_collab.json --seen _agent_team_work_zone/<团队目录名>/teammates/<slug>-remotewatch/remote_seen --journal _agent_team_work_zone/<团队目录名>/teammates/<slug>-remotewatch/working-context.md --loop-job _agent_team_work_zone/<团队目录名>/teammates/<slug>-remotewatch/loop_job
stop_when: lead 说停；同一原因连续 3 次 failed（停下并告诉 lead 原因）。
```

脚本每轮会自己往 working-context.md 写一行工作记录，并在 `loop_job` 里给轮数加 1，你不用自己写。

## 4. 开始（派生后，或收到"开始"消息时）

1. 派生时先做完第 0 步并发出回执。
2. 派生或叫回后第一次开始时（本会话里还没建过定时任务），先 `rm -f <工位>/loop_job`，让脚本从第 1 轮重新计数；同一会话里又收到"开始"时不删。然后立即按第 5 节查看一次。没有更新时给 lead 发一行 `[remote-collab] 第一次查看：no updates`；有更新时按第 5 节发。
3. 执行（这句就是"检查提示"）：
   `/loop <间隔> 照 <项目根>/.claude/skills/remote-collab/watcher_rules.md 做一次远端查看：运行 watch_targets 那条命令；只有 no updates 和 rounds 两行 → 不发消息，结束本轮；有 doc 行 → 写摘要文件，再发最多 5 行的消息；只有 mine_status 或 changes 行 → 发一行；有 same_team_name、partner_teams、failed、journal_failed、loop_job_failed 行 → 各加一行；有 respawn_due 行 → 处理完上面的之后，再单独发一条"请重新派生我"。不用自己写工作记录，脚本已经写了。`
4. 从工具结果里取定时任务 ID，把 `<工位>/loop_job` 里 `job_id=` 那一行换成 `job_id=<ID>`；其余几行（`created_at`、`created_epoch`、`rounds`）由脚本写，不动。那一行原来已有别的 ID（同一会话里又收到一次"开始"）→ 换好后 `CronDelete <旧 ID>`。

## 5. 每轮怎么处理输出

- 只有 `no updates` 和 `rounds=…` → 不发消息，结束本轮。
- 有 `doc` 行 → 先写摘要文件（第 6 节），再发最多 5 行的消息（第 7 节）。
- 只有 `mine_status`（没有 `doc`）→ 发：每份一行 `我方文档状态变了：<文件名> <旧> → <新>（合并后可以归档）`，第一行前面加 `[remote-collab] `，末行 `要处理先运行 /remote-collab pull`。
- 只有 `changes`（没有文档）→ 发一行 `[remote-collab] 远端有 <n> 个新提交，没有给我们的文档；改动在 <对方团队目录 / 代码>，共 <两数之和> 个文件。`
- `same_team_name | <目录>` → 一行 `[remote-collab] 远端有人改了和我们同名的团队目录 <目录>，两边团队名重了，请 lead 处理。继续查看。`
- `partner_teams | <目录…>` → 一行 `[remote-collab] 远端出现了团队目录 <目录…>，配置里还没记下对方是谁。`
- `failed: …` → 第一次失败发一行 `[remote-collab] 查看失败：<原因>`；同一原因连续 3 次 → 按 stop_when 停止。
- `journal_failed: <路径>` → 一行 `[remote-collab] 工作记录写不进去：<路径>`。
- `loop_job_failed: <路径>` → 一行 `[remote-collab] 轮数记录写不进去：<路径>`。
- `respawn_due rounds=<n>`（到了门槛；或本轮有文档、且已到门槛的一半）→ 上面的都处理完后（有文档时：先写摘要、发摘要消息），再**单独**发一条消息：
  `[remote-collab] 我已查看 <n> 轮，请重新派生我`（只写这一句，不写名字和命令）
- 几种同时出现时合成一条消息发；和文档一起出现的 `same_team_name`、`partner_teams`、`failed`、`journal_failed`、`loop_job_failed` 各加一行放在最后（5 行上限只管文档部分）。

## 6. 摘要文件

- 位置：`<工位>/digests/<UTC 时间>_<起点短号>-<新提交短号>.md`，例如 `digests/20261028T0330Z_a1b2c3d-e4f5a6b.md`。每批一份，不覆盖。起点、新提交取 `updates <起点>..<新提交>` 一行。
- 读文档：`cd "<项目根>" && git show <新提交短号>:./<doc 行里的路径>`。
- 我方成员职责：本团队 `TEAMMATE_INFO.json` 里 `status` 为 active 的成员，读它 README 里的"作用域""交付物"。每批读一次。
- 代码等改动（这一批）：
  `cd "<项目根>" && git diff --stat --relative <起点> <新提交> -- . ':(exclude)_agent_team_work_zone/meeting_room' ':(exclude)_agent_team_work_zone/archive' ':(exclude)_agent_team_work_zone/*_team/*'`
- 急不急："急"只在三种情况：文中写的期限在 7 天内（按查看时的 UTC 日期算）、frontmatter 的 `priority` 为 HIGH 或 urgent、原话明说"急"；其他一律写"判断不出"。期限超过 7 天的，仍在"期限"一行写明日期，但不算急。

模板（照填）：

```markdown
# 远端更新摘要 <起点短号>..<新提交短号>

- 查看时间：<UTC>；提交数：<commits=n>
- 状态：尚未合并。要处理，lead 先运行 /remote-collab pull。
- 说明：本文件由 /remote-collab 自动整理（查看成员或一次性子代理）。"建议派给谁""急不急"只是建议，由 lead 决定。

## 1. <文件名>

- 路径：<doc 行里的路径>
- 发件方 → 收件方：<from> → <to>（抄送：<cc>，没有就写"无"）
- 类型 / 状态 / 优先级：<类型> / <status> / <priority，没有就写"没写">
- 对方具体要什么：<两三句话，只转述文中写的，不加推断>
- 期限：<文中写的日期或时限；没有就写"没有">
- 文中提到的文件和路径：<逐个列出；没有就写"没有">
- 触及我方哪个成员的职责：<成员名 — 依据：README 里哪一句；判断不出就写"判断不出">
- 建议派给谁（建议）：<成员名或 lead 自己；判断不出就写"由 lead 定">
- 急不急（建议）：<急 / 判断不出> — 依据：<期限 / 优先级 / 文中原话；判断不出就写"文中没有写明">

## 我方文档的状态变化

- <文件名>：<旧> → <新>（合并后可以归档）（没有 mine_status 行就写"无"）

## 这一批的代码等改动（不含团队目录、meeting_room、archive）

<git diff --stat 的输出原样贴上；没有就写"无">
```

## 7. 给 lead 的消息（有文档时，最多 5 行）

```
[remote-collab] 远端有 <k> 份给我们的文档（<起点>..<新提交>，<n> 个提交），尚未合并
最急（建议）：<文件名> — <一句话，含期限>
另有：我方文档状态变化 <a> 份；代码等改动 <b> 个文件
摘要：<摘要文件从项目根算起的相对路径>
要处理先运行 /remote-collab pull
```

- 没有一份标为"急"时写 `最急（建议）：没有写明急的`。
- "另有"一行：两个数都是 0 就不写。`<b>` 是摘要里代码等改动的文件数。

## 8. 停止和其他

- stop_when 满足 → `CronDelete <loop_job 里的 ID>`，`rm -f <工位>/loop_job`，发一行 `[remote-collab] stopped: <原因>`，进入空闲。
- lead 说"停" → `CronDelete <loop_job 里的 ID>`，`rm -f <工位>/loop_job`，回一行 `[remote-collab] stopped`，进入空闲。
- 只按 `loop_job` 里的 ID 删，不按 CronList 删（同一进程里可能有别人的定时任务）。
- 收到最终 checkpoint 请求或关闭请求（被 /bench-teammate 下线）→ 先 `CronDelete <loop_job 里的 ID>`，再 `rm -f <工位>/loop_job`（重新派生的查看成员从第 1 轮开始），然后照做。最终 checkpoint 只写 Part A，不加 Part B。
- 绝不在回合里等待（不要 `until … sleep`，也不要一连串检查），每次查看完就结束回合。
- 空闲时被 checkpoint 提醒 → 最小 checkpoint：只写 Part A（盯什么、remote_seen 里上次看到的提交、loop_job 里的任务 ID 和轮数、停止条件）。

## 9. 一次性摘要（后台脚本方式）

本节写给 lead 在后台脚本方式下起的一次性摘要子代理，查看成员不用管。

- 你不是查看成员：不运行 check 脚本，不建定时任务，不发 SendMessage。
- 边界同第 2 节：只运行 `git show` 和第 6 节那条 `git diff --stat`，只读本团队 `TEAMMATE_INFO.json` 和成员 README。
- 起点、新提交、各份文档取 lead 贴给你的那批 check 输出。摘要文件写到 `<团队目录>/digests/`（不是成员工位），名字和格式照第 6 节。
- 单人工位没有成员，"建议派给谁"一律写 lead。
- 做完把摘要文件的路径和按第 7 节格式写的那几行文字作为最终回复，然后结束。
