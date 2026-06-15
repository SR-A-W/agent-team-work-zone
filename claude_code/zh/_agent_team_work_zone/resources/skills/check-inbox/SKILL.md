---
name: check-inbox
description: >
  检查顶层 meeting_room（所有 agent）+ 自己 team 的 roundtable（仅 team lead）中
  指向自己的任务，按时间顺序处理：读取内容、更新工位文件、执行任务、更新状态。
  同时作为 issuer 扫描自己发出的已完成文档并归档（步骤 9）。
  严格遵守工作守则第 8 条（含 cc 字段语义）。归档权威实现；/archive-resolved 已 deprecated。
disable-model-invocation: true
allowed-tools: Read Glob Grep Bash Edit Write
---

# 检查收件箱并处理任务

扫描 `_agent_team_work_zone/meeting_room/`（所有 agent）以及 `_agent_team_work_zone/<your_team>/roundtable/`（仅 team lead），找出**所有指向当前 agent**的任务，按时间顺序逐一处理。

> **重要 — 工作守则第 8 条（Meeting room / Roundtable 权限）**：
> - **归档权唯一归 issuer（`from`）**：只有 `from` 是你的文件你才能归档
> - `to` 字段**明确指向你**的文件：你有权修改 `status`，但**不可归档**（由 issuer 归档）
> - `to: ALL` 的状态报告属于发布者，其他 agent **只读不改、不归档**
> - 自己提交的报告 (`from` 是你) 可自行管理（包括在步骤 9 归档）
> - **`cc` 字段**：若你在 `cc`（不在 `to`），该文件只供你知晓——**只读、不改 status、不归档**
> - **违反此规则可能导致其他 agent 的工作状态丢失**

## 执行步骤

### 1. 身份检查（两级）

**先尝试从对话 context 推断**：如果你清楚自己的角色和工位，跳到下一步。记为 `<SELF>`（英文名），并记下自己是 **flat** 还是 **team_lead** 以及对应的 `<workstation>` 路径。

**只有 context 无法确定时**，才执行落地检查：
1. Glob `_agent_team_work_zone/*/README.md` 和 `_agent_team_work_zone/*_team/README.md`
2. 逐个检查 README，找到和当前对话匹配的工位
3. 如果工位目录以 `_team` 结尾且含 `roundtable/` → `team_lead` 模式
4. 否则 → `flat` 模式
5. 若仍无法确定，**立即停止并向用户提问**，不要猜测

### 2. 扫描收件箱（分两层，按模式分叉）

#### 所有 agent：扫描顶层 meeting_room
使用 Glob 列出 `_agent_team_work_zone/meeting_room/*.md`（排除 `README.md`）。

#### 仅 team lead：额外扫描自己的 roundtable
使用 Glob 列出 `_agent_team_work_zone/<SELF>_team/roundtable/*.md`（排除 `README.md`）。

对每个文件读取 frontmatter 提取 `status`、`from`、`to`、`cc`（若有）、`kind`（若有）、`date`、`priority`。

### 3. 按权限规则过滤

对每个文件判断归属：

| status | to 字段 | cc 字段 | 归属 |
|---|---|---|---|
| OPEN 或 IN_PROGRESS | `<SELF>` 或列表含 `<SELF>` | - | ✅ 收件箱 — 需要我处理 |
| OPEN 或 IN_PROGRESS | `ALL` | - | 📢 广播 — 作为信息参考，不主动执行 |
| OPEN 或 IN_PROGRESS | 其他 | `<SELF>` | 👁️ 抄送 — **只读**，不改 status、不归档 |
| 任意 | 其他 agent（不含 `<SELF>`）| 不含 `<SELF>` | ❌ 无关，跳过 |
| RESOLVED | from=`<SELF>` | 任意 | ➡️ 进入步骤 9（issuer 归档队列）|
| RESOLVED | from=他人 | 任意 | 📋 已完成，等 issuer 归档——只读，不归档 |

**团队版特殊**：对 roundtable 文件，`from` 和 `to` 是 `<team>/<role>` 格式（例如 `architect_team/tracker`）；其中 `architect_team/lead` 等价于 `<SELF>` 当 `<SELF>` 是该 team 的 lead 时。

### 4. 按时间顺序排序

对"收件箱" + "抄送"文件按 `date` 字段**升序排序**（最早的先处理）。

时间顺序很重要：后发的任务可能依赖前面任务的结果。

### 5. 逐个读取完整内容

按时间顺序对每个文件使用 Read 读取**完整内容**，理解任务要求：
- **新任务 (OPEN)**：任务描述、输入文件、期望输出、截止时间、优先级
- **老任务 (IN_PROGRESS)**：已完成部分、卡点、是否有其他 agent 回复了进度更新

对 IN_PROGRESS 老任务，额外搜索一次 meeting_room、roundtable 和 archive 中是否有相关的后续报告，判断老任务是否可以进入下一步。

### 6. 输出待处理清单，请求用户确认

在开始执行前，向用户输出一份"待处理清单"，请用户确认：

```
当前 agent: <SELF> (模式: flat/team_lead)

📬 收件箱 — 按时间顺序 (共 N 项):

🆕 新任务 (OPEN):
1. [TOP][HIGH] file1.md (from: X, date: 2026-04-11 10:00) — 标题/目的
2. [TEAM][MED] roundtable/file2.md (from: architect_team/tracker, kind: TRACKER_REPORT, date: 2026-04-11 14:30) — 摘要

⏳ 老任务 (IN_PROGRESS):
3. [TOP][HIGH] file3.md (from: Z, date: 2026-04-10 09:15) — 已完成 X，待处理 Y

👁️ 抄送给我 (只读):
4. [TOP] file4.md (from: W, to: V, cc: <SELF>, date: 2026-04-11 08:00) — 摘要

📢 广播 (to: ALL):
5. [TOP][LOW] file5.md (from: Secretary, date: 2026-04-11 08:00) — 项目公告

📁 我发出的已完成文档 (将在步骤 9 归档):
- [TOP] fileA.md (to: X, status: RESOLVED) — 将归档
- [TOP] fileB.md (to: [A,B,C], Completion Checklist: all done) — 将归档

是否按此顺序处理? 若需调整，请告知。
```

> 标记说明：`[TOP]` = 顶层 meeting_room；`[TEAM]` = 自己 team 的 roundtable

### 7. 更新工位文件

用户确认后，**在执行任务前**先同步工位跟踪文件：

- **`TODO.md`**：将新任务作为待办项追加（若尚未存在）
- **`ACTIVE_JOBS.md`**：对已开始执行的长任务登记
- **`notes.md`**：如任务涉及的路径/命令/配置有长期复用价值，追加（守则 #10）

### 8. 按顺序执行任务

对每个待处理任务（**抄送项跳过——只读**）：

1. **开始前**：将对应文件的 `status` 从 `OPEN` 更新为 `IN_PROGRESS`（仅当 `to` 明确指向 `<SELF>` 时）
2. **执行任务**
3. **遇到阻碍**：
   - 技术问题可自行排查
   - 涉及需求、优先级、方向 → 按守则 #11 主动向用户提问
   - 依赖其他 agent → 在对应层级（顶层或 team roundtable）新建 ERR/TASK 文件
4. **任务完成后**：
   - 在 TODO.md 中勾选
   - 从 ACTIVE_JOBS.md 移到 COMPLETED_JOBS.md
   - 在任务文件末尾追加处理结果备注（时间 + 执行人 + 结果摘要 + 产物路径）
   - 将 `status` 更新为 `RESOLVED`
   - **不执行归档**（由 issuer 在下次 `/check-inbox` 步骤 9 时归档）

### 9. 作为 issuer：归档自己已完成的文档

扫描 `_agent_team_work_zone/meeting_room/`（以及 `_agent_team_work_zone/<SELF>_team/roundtable/`，若为 team lead）中 `from: <SELF>` 的文件，过滤出**已完成**的：

**完成判定（两者任一满足即触发归档）**：
- `status: RESOLVED`
- 或文件内 Completion Checklist 全勾（所有条目均为 `- [x]`，无剩余 `- [ ]`）

**Roundtable 已完成文档的归档协调（仅 team lead）**：lead 扫自己的 roundtable 时，若发现 issuer（`from`）是**当前 active teammate**、已完成（`status: RESOLVED` 或 checklist 全勾）、但尚未归档的文档——**lead 不直接归档**（归档权属 issuer），而是**有权立刻 `SendMessage` 通知该 issuer teammate 去归档**，并给出**确切路径**："你在 roundtable 的 `<path>` 已 RESOLVED，请归档（`mv` 到 `<SELF>_team/archive/`）"。teammate 是 issuer、有归档权；lead 已给确切路径，它无需自己扫 roundtable（teammate 的 `/check-inbox` 本就**不扫** roundtable，所以靠它自己永远发现不了——必须 lead 来推）。
> **为什么由 lead 发起**：用户通常只和 team lead 对话、在 lead 的 session 里调 `/check-inbox`，所以 lead 是唯一会扫到 roundtable、发现"已完成却没归档"堆积的人；但归档**动作**仍由 issuer 执行，issuer-only 的权责不变。
> **issuer 已遣散时**：若该 active teammate 其实已 offboard（不在 `active_teammates`）→ 落到下面的「缺席兜底」：lead **核实状况后**视情况 (a) 自行归档，或 (b) 把该文档的**责任/所有权转移**给某个在岗 agent，由其后续处理。

**缺席兜底（仅 team lead）**：额外列出 `from` 字段所指 agent 已不在 `TEAMMATE_INFO.json` 的 `active_teammates` 中的 RESOLVED 文件（issuer 已 offboard），标注"（缺席兜底，需确认）"，由 team lead **核实后**手动归档**或转移所有权**。**扁平工位无 TEAMMATE_INFO.json，缺席兜底扫描静默跳过。**

**可归档列表示例**：
```
📁 作为 issuer — 可归档 (共 N 个):
[TOP]
- fileA.md (to: X, status: RESOLVED) — X 已完成
- fileB.md (to: [A,B,C], checklist: all done) — 所有人已完成
[TEAM] <SELF>_team/roundtable/
- fileC.md (from: <SELF>, status: RESOLVED) — 我发的，直接归档

📨 通知 issuer 归档 (active teammate 发到 roundtable 的已完成文档，归档权属它们):
- roundtable/fileE.md (from: drafter — active, RESOLVED) → SendMessage drafter 去归档

[缺席兜底 / 转移所有权]
- roundtable/fileD.md (from: OldAgent — 已不在注册表) → lead 核实后自行归档或转移所有权

确认：归档"可归档"N 个 + 通知 M 个 issuer 归档？
```

用户确认后执行移动（原位置决定归档位置）：
```bash
mv _agent_team_work_zone/meeting_room/<文件名> _agent_team_work_zone/archive/
mv _agent_team_work_zone/<SELF>_team/roundtable/<文件名> _agent_team_work_zone/<SELF>_team/archive/
```

若本次扫描无可归档文件，静默跳过（不输出空列表）。

### 10. 汇报结果

```
收件箱处理完成 (执行人: <SELF>, 时间: YYYY-MM-DD HH:MM):

✅ 已完成 (status → RESOLVED):
- [TOP] file1.md — 结果摘要（归档由 issuer 执行）
- [TEAM] roundtable/file2.md — 结果摘要（归档由 issuer 执行）

📁 已归档（作为 issuer）:
- [TOP] fileA.md — to: X, 已完成
- [TEAM] roundtable/fileC.md — from: <SELF>, 已完成

📨 已通知 issuer 归档（active teammate 的 roundtable 已完成文档）:
- roundtable/fileE.md → 已 SendMessage drafter 去归档

🔄 进行中 (status: IN_PROGRESS):
- file3.md — 已推进至 X，下一步 Y

⏸️ 已暂停 (阻塞):
- file_stuck.md — 阻塞原因: ...，已提交 ERR

👁️ 已阅（抄送，未执行）:
- file4.md

📢 广播已阅:
- file5.md

工位文件更新: TODO.md (+N), ACTIVE_JOBS.md (+K)
```

## 注意事项

- **顺序敏感**：严格按 `date` 升序处理
- **权限边界**：`to: ALL` / `cc 含 <SELF>` 的文件绝不改 status、绝不归档（违者参见守则 #8）
- **两层扫描**：team lead 一定要同时扫顶层 + 自己的 roundtable，不要漏
- **老任务回访**：IN_PROGRESS 老任务主动查 archive/ 中的后续进度
- **避免重复登记**：追加到 TODO.md 前先检查是否已存在
