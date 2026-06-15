# Roadmap: Autonomous Team Mode (Terminal Form)

> **Status**: RESERVED — 预留接入点，未实施
>
> **激活条件**：
> - 更高阶的 Claude 模型可用（例如 Mythos 及后续模型）
> - Token 预算允许长跑 team lead 会话
> - 通过 Pattern B（当前 interactive mode）验证过至少若干实际任务，积累了可靠的失败模式库

## 目标

让一个 team lead 对话能**端到端自动完成**一个复杂任务：

1. 收到任务描述后自主组建 team（`/spawn-team`）
2. Spawn teammate 后**持续循环**（`/loop`）：
   - 周期性读 tracker 产出和 teammate 进度
   - 发现问题时召回 investigator 或其他调试角色
   - 前一阶段完成后，分派下一阶段任务
   - 根据 teammate 反馈调整策略
3. 全程无需用户干预，用户偶尔回来查看 `/check-inbox` 即可
4. 任务最终完成后，自动写 DONE 报告到顶层 meeting_room 给用户

## 与 Pattern B (当前 interactive mode) 的对比

| | Pattern B (interactive) | Pattern A (autonomous) |
|---|---|---|
| 驱动 | 用户对话推动 | Lead 自主 `/loop` 推动 |
| Lead 会话 | 短期，用完退出 | 长期持续运行 |
| Token 成本 | 低（按需消耗） | 高（持续消耗） |
| 自动化程度 | 半自动（用户参与决策） | 全自动（lead 自主决策）|
| 风险 | 低（用户可及时纠偏） | 高（lead 可能在错方向越走越远） |
| 适用任务 | 绝大多数 | 需要长期无人值守的端到端任务 |
| 实施时间 | 已落地 | 预留接入点，将来实施 |

## 预留的接入点

### 1. `/spawn-team` skill frontmatter

```yaml
---
name: spawn-team
mode: interactive      # 当前只支持 interactive
---
```

`mode` 字段已在 frontmatter 中预留。将来实现 `autonomous` 时会添加 Phase 7「启动自主循环」。

### 2. team lead README 的 "Autonomous mode" 章节

每个 team lead 工位的 README 会有一个 "Autonomous mode" 章节（当前标注 "Not enabled"），将来启用时在这里描述行为变化。

### 3. `resources/hooks/` 目录

预留给将来 autonomous mode 需要的 hook 配置。当前为空。

### 4. `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` 已开启

因为 interactive mode 也需要 agent-team 支持，这个 env flag 在 `.claude/settings.json` 已经开启。autonomous mode 启用时不需要额外 env flag（除非 Claude Code 将来引入新 flag）。

## 实施计划（当触发激活条件时）

### Phase 0: 前置准备
- [ ] 确认 Mythos 或同级模型可用
- [ ] 确认预算能承受长跑 team lead 会话
- [ ] 至少 5 个 Pattern B 任务的失败案例研究
- [ ] 积累常见"走偏"模式的清单

### Phase 1: 设计 autonomous loop 机制
- [ ] 设计 `/loop` 的具体触发节奏（每 30 分钟？每小时？按 tracker 触发？）
- [ ] 设计 hook 机制：teammate 完成 → 通知 lead（避免 lead 每次 loop 都主动轮询 teammate）
- [ ] 设计**最大循环次数**安全闸（防无限跑）
- [ ] 设计**成本上限**安全闸（总 token 花费达到阈值停止）
- [ ] 设计**停止条件检测**：任务完成、陷入死循环、严重错误等

### Phase 2: `/spawn-team` 扩展
- [ ] 添加 Phase 7：启动自主循环
- [ ] 在 spawn prompt 中加入 rule "进入 autonomous mode 后 lead 不再等用户确认"
- [ ] 添加 `/loop` 启动指令（由 spawn-team 的输出触发）

### Phase 3: `/promote-to-team` 扩展
- [ ] 在升级时询问用户是否启用 autonomous mode
- [ ] 如果是，更新 team lead README 的 "Autonomous mode" 章节为 "Enabled"

### Phase 4: 新 skill `/pause-autonomous`
- [ ] 紧急暂停 autonomous loop
- [ ] 让 lead 恢复到 interactive mode 等待用户
- [ ] 用户手动触发

### Phase 5: Hook 集成
- [ ] 配置 `resources/hooks/`，包括：
  - `PostToolUse` hook: 监听 teammate 的工具调用
  - `SubagentStop` hook: teammate 完成时通知 lead
  - `PreToolUse` hook: 对高风险工具调用（例如 `rm`, `git push --force`）要求人工确认
- [ ] 在 bootstrap 中安装 hooks

### Phase 6: 试点
- [ ] 选择一个低风险任务（例如 benchmark 评测）做试点
- [ ] 记录每次循环的决策和输出
- [ ] 统计 token 消耗
- [ ] 分析失败案例

### Phase 7: 失败案例库
- [ ] 建立 `docs/autonomous_failures/` 目录记录所有试点失败案例
- [ ] 每个失败案例记录：任务描述、走偏点、根因、缓解建议
- [ ] 这些案例反馈到 `/spawn-team` 的 Phase 2 任务分解，提前避开

### Phase 8: 推广
- [ ] 确认稳定后在 README 中标注 autonomous mode 为 "Available"
- [ ] 更新 user_manual 添加"何时使用 autonomous mode"

## 风险和缓解

| 风险 | 缓解 |
|---|---|
| Lead 在错方向越走越远 | 最大循环次数、成本上限、失败案例库前置警告 |
| Token 成本失控 | 硬上限 + 监控 + 用户可随时 `/pause-autonomous` |
| 高风险操作被 autonomous 触发（`rm -rf`、`git push --force`）| `PreToolUse` hook 强制人工确认，即使 autonomous mode 也不例外 |
| Teammate 之间的协作死锁 | 超时机制 + 定期 teammate status 汇总 |
| Lead 和用户期望脱节 | 每完成一个 phase 主动向用户发 STATUS 报告到顶层 meeting_room |

## 不在本阶段要做的事

- **不**把 autonomous mode 作为默认行为——它是 opt-in 的
- **不**替代 interactive mode——两者共存
- **不**为简单任务启用——只在复杂长跑任务用
- **不**允许 autonomous mode 跨越多个 team 协作——每个 autonomous lead 只管自己的 team

## 备注

本 roadmap 当前是**占位**，不作为可行性承诺。具体实施时需要根据 Claude Code 特性的发展（包括 hooks 机制的成熟度、模型能力）重新评估和调整。

参考 `agent-teams.md` 对本架构的设计原则。
