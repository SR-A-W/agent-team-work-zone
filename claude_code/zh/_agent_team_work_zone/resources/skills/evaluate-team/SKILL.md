---
name: evaluate-team
description: >
  Team lead 评估当前 team 的效率和人员构成：谁在忙、谁闲、是否缺某种角色、是否有人可裁。
  产出一份结构化评估报告，辅助 lead 决定是否 /add-teammate 或 /remove-teammate。
  agent 可自主调用（用户自然语言同意后）。
disable-model-invocation: false
allowed-tools: Read Glob Grep Bash
---

# `/evaluate-team` — 团队效率与构成评估

## 身份前置检查

**先从对话 context 推断**：如果你已经清楚自己是 **team lead**（目录 `*_team/`、有 `roundtable/`），继续。

**无法推断时**才落地检查：
1. Glob `_agent_team_work_zone/*_team/README.md`
2. 定位当前对话对应的 team 工位
3. 若不是 team lead → 立即停止并警告：

   ```
   ⚠️ /evaluate-team 只在 team lead 上下文中有效。
   当前不是 team lead。若你需要组建 team 先升级，运行 /promote-to-team。
   ```

## Phase 1: 收集 team 当前状态

### 1a. 读 TEAMMATE_INFO.json（权威源）

**读 `_agent_team_work_zone/<SELF>_team/TEAMMATE_INFO.json`** — 这是 team 当前 roster 的**权威源**，`team_recipes/` 只是历史审计。

从中提取：
- `active_teammates`：每个条目的 `name` / `role_source` / `model` / `scope` / `plan_mode_gating` / `spawned_at` / `last_checkpoint_at` / `revived_count` / `status`
- `offboarded_teammates`：历史下岗记录（仅供参考）

**特别关注**：
- `last_checkpoint_at` 距今 > 24h 的 teammate → 标"checkpoint 过期"（可能失能或异常 idle）
- `status == "failed_to_reactivate"` 的 teammate → 上次 /reactivate-team spawn 失败，需要用户决定是手动修复还是 /remove-teammate
- `status == "benched"` 的 teammate → 临时下线（保留全量档案 + 工位），**不计入需要 reactivate**；列为"benched，按需唤回"，并显示 `bench_reason`（注意：benched 的 `last_checkpoint_at` 过期是预期的，不算异常）
- `revived_count > 3` 的 teammate → 反复恢复说明不稳定，可能 working-context.md 写得不好或任务本身不适合长跑

若 TEAMMATE_INFO.json 不存在或 `active_teammates` 为空 → team 当前没人，直接输出"空 team"报告，建议 `/spawn-team`。

Glob `_agent_team_work_zone/<SELF>_team/team_recipes/*.md` 作为**历史补充**：读最新 recipe 了解 team 是为什么任务组建的、最初设计意图是什么。

### 1b. 读 roundtable/

Glob `_agent_team_work_zone/<SELF>_team/roundtable/*.md`，读取 frontmatter 和内容摘要。

统计：
- **每个 teammate 近期的提交数**（按 `from` 字段聚合）
- **每个 teammate 的 OPEN/IN_PROGRESS 任务数**
- **每个 teammate 的最近活动时间**（最新文件的 date）

### 1c. 读 ACTIVE_JOBS.md

读 `_agent_team_work_zone/<SELF>_team/ACTIVE_JOBS.md`，了解正在运行的长任务（含 tracker cron trigger）。

## Phase 2: 效率分析

对每个 teammate 做以下判断：

| 维度 | 信号 | 判定 |
|---|---|---|
| **忙** | roundtable 里频繁有 TASK / DONE / ERR 提交（近 24h 或视 cron 而定），TODO 有多项 | 在忙 |
| **闲** | 近期无新产出 + 手头无 OPEN 任务 | 闲 |
| **卡** | 有 IN_PROGRESS 但没有后续更新，或者有 ERR 未处理 | 卡住了 |
| **重复** | 两个 teammate 职责重叠（spawn prompt 中的作用域相同或近似） | 冗余 |
| **缺口** | 任务分解里某类工作目前没人做（例如"需要做 smoke test"但没有负责测试的 teammate） | 缺角色 |

## Phase 3: 产出评估报告

```markdown
# Team Evaluation — <SELF> — YYYY-MM-DD HH:MM

## Team 当前构成
- 总人数: N
- 最近一次 /spawn-team: <timestamp>, recipe: <slug>

## 成员状态
| 昵称 | 角色来源 | 模型 | 状态 | Last Checkpoint | Revive | 近期产出 | 手头 OPEN | 备注 |
|---|---|---|---|---|---|---|---|---|
| Fixer | code-implementer | sonnet | 忙 | 10 min ago | 0 | 4 份 DONE (近 24h) | 2 项 | 主线工作 |
| Tracker | resources/agents/tracker.md | haiku | 闲 | 2h ago | 0 | 0 | 0 | 等待下次 cron |
| Reviewer | resources/agents/reviewer.md | sonnet | 卡 | ⚠️ 36h ago | 1 | 1 份 IN_PROGRESS | 1 项 | Checkpoint 过期 + 工作无更新 |
| DevilAdvocate | resources/agents/devil-advocate.md | sonnet | 闲 | 1h ago | 0 | 2 份挑战报告 | 0 | 初始批判已完成 |

## 发现的问题

### 🚨 需要立即处理
- Reviewer 卡了 36h，没看到进度更新 → 建议 lead 去它的 session 看看是不是阻塞了
- 没有 teammate 负责最终结果的 xlsx 表格产出 → 缺 result-reporter 角色

### ⚠️ 需要考虑
- DevilAdvocate 已经完成初始批判任务，近期没新产出 → 可以 /remove-teammate 释放资源
  （除非后续还需要它做 decision-time check）

### ✅ 运行良好
- Fixer 工作节奏稳定
- Tracker 按周期正常产出

## 建议操作

### 立即行动
1. 去 Reviewer session 确认卡点 (可能是技术阻塞或 context 污染)
2. /add-teammate 增加一个 result-reporter (从 resources/role_archetypes/analysis/result-reporter.md 起)

### 可选
- /remove-teammate DevilAdvocate (如果初始批判已吸收完毕)

## Token 成本估算
- 活跃 teammate 近 24h 消耗约 X tokens (基于 roundtable 文件大小估算)
- 如果继续当前节奏 1 周 → 约 X * 7 tokens
```

## Phase 4: 请求用户确认

**不自动执行**任何操作。将报告展示给用户，询问：

```
这份评估你有什么看法？需要我执行哪个建议？
（可以选：去看 Reviewer 的卡点 / 加 result-reporter / 移除 DevilAdvocate / 其他）
```

根据用户决定调用 `/add-teammate`、`/remove-teammate`，或者继续对话。

## 注意事项

- **只评估，不执行**：本 skill 的职责是诊断和建议，不直接改 team
- **量化不精确**：token 估算只是粗略感，不做严格统计
- **避免过度优化**：不要为了"让每个 teammate 都满载"而制造工作；team lead 的角色是让任务顺利，不是让 teammate 忙
- **时间窗口**：默认看近 24h 活动，视任务时长调整
