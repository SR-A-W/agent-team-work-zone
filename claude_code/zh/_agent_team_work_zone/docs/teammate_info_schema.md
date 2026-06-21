# TEAMMATE_INFO.json 结构说明

> 人类阅读文档。**不是** runtime 依赖——`/spawn-team`、`/reactivate-team` 等 skill 直接 inline 各自使用的 JSON 结构，不 Read 本文件。

本文件是 team lead 的**注册表**，记录 team 当前的成员构成和状态。每个 team 工位一份。

## 路径

```
_agent_team_work_zone/<team_name>/TEAMMATE_INFO.json
```

例如 `_agent_team_work_zone/architect_team/TEAMMATE_INFO.json`。

## 谁读谁写

| 操作 | 写 | 读 |
|---|---|---|
| `/spawn-team` | ✅ 初始化或覆写 `active_teammates` 数组 | - |
| `/add-teammate` | ✅ append 到 `active_teammates` | - |
| `/remove-teammate` | ✅ 把成员从 `active_teammates` 移到 `offboarded_teammates` | - |
| `/bench-teammate` | ✅ 把成员 `status` 置 `benched`、写 `benched_at`/`bench_reason`（**留在** `active_teammates`） | - |
| `/reactivate-team` | ✅ 更新 `revived_count`、`spawned_at`、`status`；`<name>` 唤回 benched 时清 `benched_at`/`bench_reason` | ✅ |
| `/checkpoint`（teammate 调用）| ✅ 只更新自己那条的 `last_checkpoint_at` | - |
| `/evaluate-team` | - | ✅ 权威源 |
| `/sync`（team lead 恢复路径）| - | ✅ 检测是否需要 reactivate |
| `/onboard` / `/promote-to-team` | ✅ 初始化为空结构 | - |

**Teammate 不得修改** `active_teammates` 数组的结构或其他成员的条目——只能更新自己那一条的 `last_checkpoint_at`。违反属 rule #1 低耦合问题。

## 完整 Schema（v1）

```json
{
  "schema_version": 1,
  "team_name": "architect_team",
  "lead_name": "Architect",
  "updated_at": "2026-04-18T22:30:00Z",
  "active_teammates": [
    {
      "name": "architect-fixer",
      "role_source": {
        "type": "archetype",
        "path": "resources/role_archetypes/coding/bash-scripter.md"
      },
      "model": "sonnet",
      "plan_mode_gating": false,
      "scope": "_agent_team_work_zone/training/*.sh",
      "spawned_at": "2026-04-18T22:00:00Z",
      "last_checkpoint_at": "2026-04-18T22:30:00Z",
      "revived_count": 0,
      "status": "active"
    }
  ],
  "offboarded_teammates": [
    {
      "name": "architect-oldtracker",
      "offboarded_at": "2026-04-17T10:00:00Z",
      "reason": "task completed"
    }
  ]
}
```

## 字段说明

### 顶层

| 字段 | 类型 | 含义 |
|---|---|---|
| `schema_version` | integer | 当前为 1。将来 schema 演化时递增 |
| `team_name` | string | Team 工位名（不带 `_team` 后缀？——**带**，例如 `architect_team`） |
| `lead_name` | string | Team lead 的角色英文名（例如 `Architect`） |
| `updated_at` | ISO8601 string | 本文件最后修改时间。每次写操作更新 |
| `active_teammates` | array | 当前活跃 teammate 数组 |
| `offboarded_teammates` | array | 已下岗 teammate 的历史记录 |

### `active_teammates[]` 条目

| 字段 | 类型 | 含义 |
|---|---|---|
| `name` | string | Teammate 的全局唯一名字，**必须形如 `<slug>-<role>`**：`slug` = team 工位名去 `_team`、单 token（无连字符），`role` 可含连字符。例 `architect-reviewer`、`architect-plan-a-author`。idle checkpoint hook 靠 `${name%%-*}_team` 从 name 反推工位，故 slug 必须无连字符。存量旧名（如 `Fixer`）容忍，新建一律用 `<slug>-<role>` |
| `role_source` | object | 角色定义来源，见下方 |
| `model` | string | 使用的模型：`sonnet` / `haiku` / `opus` 或具体 ID |
| `plan_mode_gating` | boolean | Spawn 时是否启用 plan-mode gating |
| `scope` | string | 作用域的简要描述（纯供人类参考，不是机器解析字段） |
| `spawned_at` | ISO8601 string | 最初 spawn 时间 |
| `last_checkpoint_at` | ISO8601 string\|null | 最后一次 /checkpoint 的时间。null = 从未 checkpoint 过 |
| `revived_count` | integer | 被 /reactivate-team 重建过的次数。首次 spawn 为 0 |
| `status` | string | 见下方状态枚举 |
| `benched_at` | ISO8601 string | **可选**，仅当 `status=benched` 时存在：被 /bench-teammate 临时下线的时间。唤回时删除 |
| `bench_reason` | string | **可选**，仅当 `status=benched` 时存在：下线原因（人类可读一句话）。唤回时删除 |

### `role_source` 对象

```json
{
  "type": "archetype" | "subagent" | "tier2" | "inline",
  "path": "resources/role_archetypes/...",   // archetype 和 tier2 用
  "subagent_name": "tracker",                // subagent 用
  "inline_description": "..."                 // inline 用
}
```

| `type` | 含义 | 其它字段 |
|---|---|---|
| `archetype` | 从 role_archetypes 填充 | `path`: 原型文件路径 |
| `subagent` | 引用 .claude/agents/ 下的通用 subagent | `subagent_name`: subagent 的 name |
| `tier2` | 本 team 自定义的 Tier 2 角色 | `path`: `<team>/teammates/<name>.md` |
| `inline` | 完全原创、spawn prompt 里定义 | `inline_description`: 简要描述 |

### `status` 枚举

| 值 | 含义 | 处理 |
|---|---|---|
| `active` | 期望在当前 team 里活跃 | /reactivate-team（无参）会重建它 |
| `idle` | 曾经活跃但当前无任务（但仍保留在 active_teammates 里） | 按 active 处理，重建后等 lead 分配任务 |
| `benched` | **临时下线**：保留全量档案 + 工位 + 文档，默认**不**被 /reactivate-team（无参）唤醒 | 留在 `active_teammates`（全量条目，附 `benched_at`/`bench_reason`）；仅 `/reactivate-team <name>` 单独唤回，唤回后转 `active` 并清 benched 字段 |
| `failed_to_reactivate` | /reactivate-team 时 spawn 失败 | 待用户决定是移除还是手动修复 |
| `offboarded` | 通过 /remove-teammate 已下岗 | **不应该在 active_teammates 里**——offboard 时应移到 offboarded_teammates |

**状态机**：`active` / `idle` ⇄ `benched`（`/bench-teammate` 下线、`/reactivate-team <name>` 唤回）；`active` / `idle` / `benched` → `offboarded`（`/remove-teammate`）。**benched vs offboarded**：benched 留在 `active_teammates`、全量档案、语义"还会回来"；offboarded 移入 `offboarded_teammates`、精简档案、语义"任务完成、不再回来"。是否唤回某个 benched 是 **team lead 的常驻管理判断**（见 README 工作守则），对用户黑箱——用户只在"提议—同意"的对话层面参与，不接触状态字段。

### `offboarded_teammates[]` 条目

| 字段 | 类型 | 含义 |
|---|---|---|
| `name` | string | 下岗时的名字 |
| `offboarded_at` | ISO8601 string | 下岗时间 |
| `reason` | string | 下岗原因（人类可读的一句话） |

**注**：offboarded 条目保留历史审计用。**名字可以在将来被新 teammate 复用**（同 team 重开同名 teammate 属正常）。

## 版本演化

Schema 变更规则：

- **Minor 变更**（新增可选字段、状态新值）：直接修改，`schema_version` 不升
- **Major 变更**（重命名字段、改变字段含义、移除字段）：`schema_version` 递增，同时在所有读写 skill 里加 migration 逻辑

## 关联文档

- 触发它的错误报告：`error_reports/2026-04-16_subagent_vs_teammate_confusion.md`（确认 Agent 工具支持 team_name + name，让本 schema 有意义）
- Rule 13（工作守则）：zh/en 两个 team 版 README 的 `### 13. Teammate 工位自维护 + checkpoint 义务`
