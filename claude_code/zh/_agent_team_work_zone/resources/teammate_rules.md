<!-- TEAMMATE_RULES:START -->
## Teammate 守则要点

> 本块由框架维护，升级时会整体替换，你的本地修改会被覆盖（旧块会备份为 `README.md.teammate_rules.bak.<时间戳>`）。

1. **只动自己的工位** —— 你的工位是 `<team>/teammates/<你的名字>/`，其下 5 个文件只有你维护。**不要**修改其他 teammate、lead 或任何别人工位的文件；要别人做事就发 SendMessage。同侪间的交流协作（提问 / 共享 / 质疑 / 互助）鼓励且是 team 的核心价值；但正式的任务分配与优先级是 lead 的协调职责，不把任务当命令甩给同侪。
2. **跨 agent 通信遵循 Claude Code 官方 agent-team 机制（mailbox / SendMessage）** —— 按官方机制，agent 之间的通信只通过 mailbox 投递（SendMessage 工具）；你的普通输出**不会跨过 agent 边界**到达 lead——它只存在于你自己的会话里，只有人类用户查看你的窗格/转录时才看得到。汇报进度、提问、交付**必须**用 SendMessage，否则等于没说。（你进入 idle 时系统会自动通知 lead，但那是无内容的心跳，**不能替代**你的报告。）**发送成功即已投递；静默 ≠ 丢失，不要因为没立刻收到回复就重发**——SendMessage 返回 `success:true`（`Message sent to X's inbox`）就代表消息已进对方 mailbox；对方没马上回，通常是它在忙 / 还没轮到读它，而不是消息丢了。**只有两种情况才该重发**：(i) SendMessage 本身**报错**（例如 `No agent named X is currently addressable`）；(ii) 对方**明确告诉你没收到**。除此之外不要重复轰炸同一条消息。给 lead 发消息时，`to:` 用 lead 的**注册名**（你的 spawn / reactivation prompt 里出现的那个，通常是 `team-lead`），**逐字照抄、不要臆造地址**。
3. **checkpoint 是主动义务** —— 任务完成 / 进 idle 前 / 收到提醒时 → `/checkpoint` 更新 `working-context.md`。它是你写给"下一次的自己"的交接；Claude Code **不跨 session 保留 teammate**，写不好下次恢复不了。`commitments.md` 是你对别人的承诺，下次的你要接手。别只靠 15 分钟的自动拦截兜底。
4. **压缩后从工位文件恢复，不靠记忆** —— 上下文被压缩后，读自己工位恢复状态：`README.md`（角色认知）、`working-context.md`（工作状态）、`commitments.md`（未了承诺）、`TODO.md`（待办）。别凭残留记忆猜。
5. **任务跟踪落在自己工位磁盘** —— `TODO.md` / `ACTIVE_JOBS.md` / `COMPLETED_JOBS.md` 放工位目录；**不要**用 `~/.claude/tasks/`（session 级，对话一结束就没）。
6. **有疑问问 lead，不要直接问用户** —— 需求/目的/方向拿不准，就用 SendMessage 问 team lead；确属重大的问题由 lead 转达用户。**错误假设的代价远大于多问一句**；**绝不假装已获同意**。同时**不要停下来干等用户回复**——用户通常只盯着 lead 的会话（或在 remote-control/非 tmux 模式下），根本看不到你的提问；你等用户、lead 等你交付，全队会互相空等死锁。
7. **写进 roundtable 的东西** —— 报告要自包含；文件名 `<你的名字>_<类型>_<YYYYMMDD>_<HHMM>_<描述>.md`；**归档权只归发布者**，不是你发的别归档；你发的、各接收方都已 RESOLVED 的，由你归档。
8. **要盯作业又要保持可达，就用 `/loop` 排定唤醒，然后结束回合** —— 队友发来的消息要等你的回合结束才送达。不要在回合里等作业（shell `until … sleep` 循环，或一长串检查调用）：长时间阻塞的调用和一串短检查都会挡住消息，只有结束回合才能让消息进来。只结束回合、不排定唤醒，作业就没人盯了；确实用不了 `/loop` 时，结束回合前给 lead 发一句简短状态，由 lead 再 ping 你继续。
9. **记录决策来源** —— 记下裁定或约定时写明谁提议、谁批准，"谁决定的"引原话。你和同侪就契约、接口、字段达成的一致，在 lead 裁定前只是提议，记为"提议（待 lead 裁定）"。
10. **工作目录和暂存区是全队共用的** —— 提交前先看 `git diff --cached --stat`，只按显式路径提交（`git commit -m "…" -- <路径>`）；禁用 `git add -A` / `add .` / `commit -a`、`git stash`、`pull --rebase`、非快进 merge；不删除存在的 `.git/index.lock`（一直不消失且无 git 进程时告诉 lead）。在共享 checkout 里提交、合并、拉取时，优先用 `cd "<项目根目录>" && bash _agent_team_work_zone/resources/scripts/atwz_git_lock.sh run -- git …`，其中 `<项目根目录>` 是包含 `_agent_team_work_zone/` 的那个目录的绝对路径（你的 spawn prompt 里给了）；这样在任何工作目录下都能用，项目只是某个更大仓库的子目录时也不例外。

以上是面向 teammate 的精简摘录；完整 13 条见框架 README 的《工作守则》。
<!-- TEAMMATE_RULES:END -->
