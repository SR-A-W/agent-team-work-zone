---
name: archive-resolved
description: >
  扫描顶层 meeting_room（所有 agent）+ 自己 team 的 roundtable（仅 team lead）中
  已完成 (RESOLVED) 的文件，按权限规则只归档当前 agent 有权处理的文件，
  分别移动到对应层级的 archive。严格遵守工作守则第 8 条（含 cc 字段）。
  （v0.3.0 起建议用 /check-inbox 代替，详见 DEPRECATED NOTICE）
disable-model-invocation: true
allowed-tools: Read Glob Grep Bash
---

> **注意（v0.3.0 起）**：归档权威逻辑已并入 `/check-inbox`（步骤 9：issuer 归档）。
> 推荐用 `/check-inbox` 代替本 skill。本文件保留作向后兼容参考；
> 如需独立触发归档扫描，本 skill 的逻辑仍然有效，但以 `/check-inbox` 中的规则为准。

# 归档已完成任务（按权限过滤，支持顶层 + 部门双层）

扫描 `_agent_team_work_zone/meeting_room/`（所有 agent）+ `_agent_team_work_zone/<your_team>/roundtable/`（仅 team lead），将当前 agent 有权归档且 `status: RESOLVED` 的文件移动到对应的 archive。

> **重要 — 工作守则第 8 条**：
> - 只有 `to` 字段**明确指向你**的文件，你才能修改 `status` 或归档
> - `to: ALL` 的状态报告属于发布者，其他 agent **只读不改、不归档**
> - 你自己提交的报告 (`from` 是你) 可自行管理
> - **`cc` 字段**：若你在 `cc`（不在 `to`），该文件只读、**绝不**归档
> - **违反此规则可能导致其他 agent 的工作状态丢失**

## 执行步骤

### 1. 身份检查（两级）

**先从对话 context 推断**：如果你清楚自己的角色和工位模式，直接用。记为 `<SELF>`，记下 `<mode>` (flat / team_lead)。

**无法推断时**才落地检查：
1. Glob `_agent_team_work_zone/*/README.md` 和 `_agent_team_work_zone/*_team/README.md`
2. 对比对话历史找到匹配工位
3. 判断 mode（是否以 `_team` 结尾 + 含 `roundtable/`）
4. 无法确定时立即停止并提问

### 2. 扫描两层收件箱

#### 所有 agent：扫顶层
Glob `_agent_team_work_zone/meeting_room/*.md`（排除 `README.md`）。

#### 仅 team lead：额外扫自己的 roundtable
Glob `_agent_team_work_zone/<SELF>_team/roundtable/*.md`（排除 `README.md`）。

对每个文件读取 frontmatter 提取 `status`、`from`、`to`、`cc`（若有）。

### 3. 按权限规则过滤

| status | from | to | cc | `<SELF>` 可归档？ |
|---|---|---|---|---|
| RESOLVED | `<SELF>` | 任意 | 任意 | ✅ 可归档（自己发布的） |
| RESOLVED | 他人 | `<SELF>`（单一）| 任意 | ❌ **不归档** — 由 issuer 归档 |
| RESOLVED | 他人 | 列表含 `<SELF>` + 其他 | 任意 | ⚠️ **不归档** — 等最后收件人 |
| RESOLVED | 他人 | `ALL` | 任意 | ❌ **绝不归档**（属于发布者）|
| RESOLVED | 他人 | 其他 agent（不含 `<SELF>`）| `<SELF>` | ❌ **绝不归档**（抄送只读）|
| RESOLVED | 他人 | 其他 agent | 不含 `<SELF>` | ❌ 不归档（与你无关）|
| 非 RESOLVED | 任意 | 任意 | 任意 | ❌ 不归档 |

将文件分为：
- **可归档**
- **跳过 (无权 — ALL / cc / 多收件人 / 与你无关)**
- **跳过 (未完成)**

### 4. 向用户确认

```
当前 agent: <SELF> (模式: flat/team_lead)

✅ 可归档 (你有权处理):
[TOP]
- file1.md  (from: <SELF>, to: X)
[TEAM] <SELF>_team/roundtable/
- file3.md  (from: teammate_Z, to: <SELF>_team/lead)

⏭️ 跳过 — 你无权归档:
- file2.md  (from: Y, to: <SELF>)        ← 由 issuer 归档
- file4.md  (from: A, to: ALL)          ← 属于发布者 A
- file5.md  (from: B, to: C, cc: <SELF>) ← 抄送只读
- file6.md  (from: D, to: <SELF>, E)     ← 多收件人

⏳ 跳过 — 未完成:
- file7.md  (status: OPEN)

确认归档"可归档"清单中的 N 个文件？
```

### 5. 执行移动

用户确认后，**按原文件位置分类归档**：

- 顶层文件 → `_agent_team_work_zone/archive/`
- 部门文件 → `_agent_team_work_zone/<SELF>_team/archive/`

```bash
mv _agent_team_work_zone/meeting_room/<文件名> _agent_team_work_zone/archive/
mv _agent_team_work_zone/<SELF>_team/roundtable/<文件名> _agent_team_work_zone/<SELF>_team/archive/
```

> 严禁移动"跳过"清单中的任何文件。

### 6. 汇报结果

```
归档完成 (执行人: <SELF>):
- ✅ 顶层归档: N 个 → _agent_team_work_zone/archive/
- ✅ 部门归档: M 个 → _agent_team_work_zone/<SELF>_team/archive/
- ⏭️ 跳过 K 个 RESOLVED (无权: ALL / cc / 多收件人 / 无关)
- ⏳ 会议室中剩余活跃: X 个 (OPEN/IN_PROGRESS)
- ⏳ 部门 roundtable 中剩余活跃: Y 个
```

## 注意事项

- 不要移动 `README.md`
- 不要移动子目录
- 当 `to` 字段是列表但还有其他收件人时，**保守**——不归档
- 当 `to: ALL` 时，**只有 `from` 是 `<SELF>` 的情况下才可归档**
- **cc 字段**是绝对的只读权限，**永远不归档**
- 对归属有任何疑问，宁可跳过也不要错误归档
- Team lead 不要把顶层文件归档到部门 archive，也不要反过来——**原位置决定归档位置**
- 新规则（v0.3.0 起）：接收方（`to` 是你）不再有归档权，即使是单一收件人也不例外。归档权属于 issuer（`from`）。
