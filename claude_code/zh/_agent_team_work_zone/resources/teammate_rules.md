<!-- TEAMMATE_RULES:START -->
## Teammate 守则要点

1. **只动自己的工位** —— 你的工位是 `<team>/teammates/<你的名字>/`，其下 5 个文件只有你维护。**不要**修改其他 teammate、lead 或任何别人工位的文件；要别人做事就发 SendMessage。同侪间的交流协作（提问 / 共享 / 质疑 / 互助）鼓励且是 team 的核心价值；但正式的任务分配与优先级是 lead 的协调职责，不把任务当命令甩给同侪。
2. **跨 agent 通信遵循 Claude Code 官方 agent-team 机制（mailbox / SendMessage）** —— 按官方机制，agent 之间的通信只通过 mailbox 投递（SendMessage 工具）；你的普通输出**不会跨过 agent 边界**到达 lead——它只存在于你自己的会话里，只有人类用户查看你的窗格/转录时才看得到。汇报进度、提问、交付**必须**用 SendMessage，否则等于没说。（你进入 idle 时系统会自动通知 lead，但那是无内容的心跳，**不能替代**你的报告。）
3. **checkpoint 是主动义务** —— 任务完成 / 进 idle 前 / 收到提醒时 → `/checkpoint` 更新 `working-context.md`。它是你写给"下一次的自己"的交接；Claude Code **不跨 session 保留 teammate**，写不好下次恢复不了。`commitments.md` 是你对别人的承诺，下次的你要接手。别只靠 15 分钟的自动拦截兜底。
4. **压缩后从工位文件恢复，不靠记忆** —— 上下文被压缩后，读自己工位恢复状态：`README.md`（角色认知）、`working-context.md`（工作状态）、`commitments.md`（未了承诺）、`TODO.md`（待办）。别凭残留记忆猜。
5. **任务跟踪落在自己工位磁盘** —— `TODO.md` / `ACTIVE_JOBS.md` / `COMPLETED_JOBS.md` 放工位目录；**不要**用 `~/.claude/tasks/`（session 级，对话一结束就没）。
6. **有疑问问 lead，不要直接问用户** —— 需求/目的/方向拿不准，就用 SendMessage 问 team lead；确属重大的问题由 lead 转达用户。**错误假设的代价远大于多问一句**；**绝不假装已获同意**。同时**不要停下来干等用户回复**——用户通常只盯着 lead 的会话（或在 remote-control/非 tmux 模式下），根本看不到你的提问；你等用户、lead 等你交付，全队会互相空等死锁。
7. **写进 roundtable 的东西** —— 报告要自包含；文件名 `<你的名字>_<类型>_<YYYYMMDD>_<HHMM>_<描述>.md`；**归档权只归发布者**，不是你发的别归档；你发的、各接收方都已 RESOLVED 的，由你归档。

以上是面向 teammate 的精简摘录；完整 13 条见框架 README 的《工作守则》。
<!-- TEAMMATE_RULES:END -->
