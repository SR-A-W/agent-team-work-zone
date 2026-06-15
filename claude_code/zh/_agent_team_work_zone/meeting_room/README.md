# Meeting Room — 顶层跨工位会议室

> 这是所有 agent 之间**跨工位 / 跨 team** 异步沟通的中心。
>
> **注意**：部门内部沟通请使用各 team 工位下的 `roundtable/`，不要放到顶层 meeting_room。顶层只处理跨工位、跨 team 的全局事务。

## 顶层 vs 部门内 Roundtable

| 场景 | 应该放哪里 |
|---|---|
| 扁平工位之间的通讯（Secretary ↔ GitKeeper） | 顶层 meeting_room |
| 扁平工位 ↔ team lead 的任务交接 | 顶层 meeting_room |
| Team lead 之间的通讯 | 顶层 meeting_room |
| 全局公告（项目主管的广播） | 顶层 meeting_room，`to: ALL` |
| Team 内部：lead ↔ teammate 派发 | **对应 team 的 `<team>/roundtable/`** |
| Team 内部：tracker 周期报告 | **对应 team 的 `<team>/roundtable/`** |
| Team 内部：teammate 之间协作 | **对应 team 的 `<team>/roundtable/`** |

---

## 提交报告

将需要其他工位知道的信息以 markdown 文件形式放在本目录下。

**文件命名规范**（必须带 agent 名 + 精确到分钟的时间戳）：
```
<Agent英文名>_<类型>_<YYYYMMDD>_<HHMM>_<简要描述>.md
```

类型前缀：
- `ERR` — 错误报告（发现问题，需要其他 agent 修复）
- `PROJECT_STATUS` — 项目进度快照
- `TASK` — 任务交接（需要特定 agent 接手执行）
- `DONE` — 完成通知（某项工作已完成，相关 agent 可继续后续步骤）
- `STATUS` — 其他状态更新

示例：
- `Architect_ERR_20260411_1530_vllm_compat_issue.md`
- `Planner_DONE_20260411_0930_refactor_plan_ready.md`
- `Secretary_PROJECT_STATUS_20260411_1800_weekly_update.md`

**文件头部必须包含 frontmatter**：
```yaml
---
status: OPEN | IN_PROGRESS | RESOLVED
from: <发送者 Agent 英文名>        # 首字母大写
to: <目标 Agent 英文名> 或 ALL    # 首字母大写
date: YYYY-MM-DD HH:MM             # 必须包含时间
priority: HIGH | MEDIUM | LOW
cc: [Agent1, Agent2]               # 可选，抄送；cc'd 方只读不改
---
```

---

## 读取报告

- 开始工作前，检查本目录中是否有 `to` 字段指向你的 / `to: ALL` 的文件
- 如果你是 **team lead**，还要检查自己 team 下的 `roundtable/`（`/check-inbox` 会同时扫两个位置）
- 特别关注 `status: OPEN` 且与你职责相关的报告
- 接手任务后，将 status 更新为 `IN_PROGRESS`
- 完成后将 status 更新为 `RESOLVED`，简要说明处理结果（归档由 issuer 在下次 `/check-inbox` 时执行）

## 归档规则

- RESOLVED 的文件必须从本目录移至 `../archive/`
- **归档权唯一归 issuer（`from`）**：只有文件的发布者才能执行移动
- 接收方（`to`）：完成任务后将 status 改为 RESOLVED，**不执行归档**
- `/check-inbox` 在步骤 9 中会自动扫描 issuer 已完成的文档并提示归档
- 本目录保持干净，只有待处理和处理中的任务
- `../archive/` 是历史记录，保留不删除
- **守则 #8**：`to: ALL` 和 `cc` 中的文件只读不改不归档

## 多接收方文件模板

当一份任务需要多个 agent 共同完成时，推荐在文件末尾加 **Completion Checklist**，供各接收方逐一勾选：

```yaml
---
status: OPEN
from: Issuer
to: [A, B, C]
date: 2026-06-11 09:00
priority: HIGH
---

...任务正文...

## Completion Checklist
- [ ] A: (待完成)
- [ ] B: (待完成)
- [ ] C: (待完成)
```

各接收方接手任务后，将 `status` 改为 `IN_PROGRESS`（或在自己的 checklist 行加 "started: YYYY-MM-DD HH:MM" 注记），表示已认领。完成自己那部分后勾选对应行并追加时间戳 + 摘要。最后完成的那方将 `status` 改为 `RESOLVED`。Issuer 在下次 `/check-inbox` 时看到 `status: RESOLVED` 或 checklist 全勾，即执行归档。

## 注意事项

- 报告必须自包含：读者不需要去翻日志或读其他文件就能理解
- 如果涉及具体文件，给出完整路径
- 如果涉及报错，贴出关键错误信息
- `cc` 字段仅用于通知，不能用来绕过 `to` 权限
