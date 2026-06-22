# CLAUDE.md

- 本项目使用 **agent-team-work-zone** 作为 Claude Code agent 团队的运维层 —— 见下方
  **配合 agent-team-work-zone 工作**。
- 本项目的编码工程原则 —— 见下方 **Coding Engineering Principles**。

## 配合 agent-team-work-zone 工作

agent-team-work-zone 是一个基于文件的持久化与管理层，它**构建于并强化 Claude Code 的
Agent Teams 能力之上**：一支 agent 团队把工作状态保存在文件里，因而团队能跨 session、
跨 compaction、跨重启存续。

**它在哪里：** 项目根目录下的 `_agent_team_work_zone/` 目录 —— 它存放每个 agent 的
工位（角色文件、working-context / checkpoint、TODO、承诺），共享的 `meeting_room/`
和 `archive/`，以及每个团队的 `roundtable/`、`teammates/` 和 `TEAMMATE_INFO.json`
注册表。它的 skills（`/onboard`、`/spawn-team`、`/checkpoint`、`/reactivate-team`、
`/check-inbox`……）安装在 `.claude/` 下。

**原则：**
- **文件优先于上下文。** 角色、工作上下文、决策、任务清单、消息都存在磁盘上 —— 任何
  没写下来的东西都会在 session 结束或 compaction 时丢失。
- **管好自己的文件。** 每个 agent 只编辑自己的工位，绝不碰别人的。只通过 SendMessage
  协调 —— 纯文本输出永远不会越过 agent 边界。
- **存活是一张回执，不是一个文件。** 一个 teammate 只有在被当前、未中断的 lead session
  spawn 出来时才算活着；任何重启都会杀死所有 teammate。只有一条新鲜的 SendMessage
  回复才能证明它还活着。
- **保持 checkpoint 最新。** Teammate 写 working-context.md，以便未来的 spawn 能据此
  重新激活。
- **lead 协调，teammate 实现。** lead 把自己的上下文花在决策与评审上，而非实现。
- **从报告读 teammate 信号，别看心跳或文件。** 作为 lead，判断 teammate 的进度只认它的
  SendMessage 报告。`idle_notification` 是心跳、不是状态 —— 当 no-op，静等报告。绝不在
  teammate 干活途中轮询它的文件来判断"做完没/卡没卡"：改动是异步落盘的，你会读到旧快照
  而误判。要查就 ping（SendMessage）等回复；产物等报告到了再验。

## Coding Engineering Principles

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

### 1. Think Before Coding
**Don't assume. Don't hide confusion. Surface tradeoffs.**
Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

### 2. Simplicity First
**Minimum code that solves the problem. Nothing speculative.**
- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.
Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

### 3. Surgical Changes
**Touch only what you must. Clean up only your own mess.**
When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.
When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.
The test: Every changed line should trace directly to the user's request.

### 4. Goal-Driven Execution
**Define success criteria. Loop until verified.**
Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"
For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```
Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---
**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.
