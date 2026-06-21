---
name: promote-to-team
description: >
  把扁平工位升级为 team lead：重命名目录为 <name>_team/、补齐 roundtable/archive/
  team_recipes/teammates/ 子结构、改 README 加 rule 12 和 lead 专属章节。
  agent 可自主调用——当扁平 agent 预见任务将变复杂时主动向用户建议。
disable-model-invocation: false
allowed-tools: Read Write Edit Glob Bash
---

# `/promote-to-team` — 扁平工位升级为 Team Lead

## 身份前置检查

**先从对话 context 推断**：如果你已经清楚自己是 **扁平工位**（目录无 `_team` 后缀、无 `roundtable/`），直接进入下一步。

**无法推断时**才落地检查：
1. Glob `_agent_team_work_zone/*/README.md` 和 `_agent_team_work_zone/*_team/README.md`
2. 找到对应当前对话的工位
3. 如果是 `*_team/` 且含 `roundtable/` → **当前已经是 team lead**，立即停止并警告：

   ```
   ⚠️ 你当前已经是 team lead（工位在 <path>）。
   /promote-to-team 仅对扁平工位有效。
   若你需要管理现有 team，试试 /evaluate-team、/add-teammate、/remove-teammate。
   ```

4. 如果是扁平工位 → 继续

## Phase 1: 向用户确认升级

Agent 在对话中用自然语言说明升级原因，请用户确认：

```
我预见到当前任务会变复杂（<原因列表，例如：需要并行调研多个假设 / 需要多种专业技能 /
单人完成会显著消耗 context >），建议我从扁平工位升级为 team lead 来处理。

升级后：
- 我的工位目录会从 _agent_team_work_zone/<english_name>/ 重命名为 _agent_team_work_zone/<english_name>_team/
- 我会获得 roundtable/、archive/、team_recipes/、teammates/ 这些 team 特有的子目录
- 我的 README 会加上 rule 12 (team lead 保留 context) 和 team 管理相关章节
- 我的 notes.md / TODO.md / ACTIVE_JOBS.md / COMPLETED_JOBS.md 完整保留，不丢任何工作历史
- 升级后我会用 /spawn-team 组建 team 来完成手头的复杂任务

你同意升级吗？
```

**等用户明确同意后**再进入 Phase 2。如果用户拒绝，就保持扁平继续死扛，但要在 notes.md 里记录一下用户的决定（以便未来复盘）。

## Phase 2: 重命名工位目录

> ⚠️ **`<english_name>` 必须是单 token（无连字符、无下划线）**——它将成为本 team 的 **slug**（工位名去 `_team` 即得）。日后 spawn 的 teammate 名为 `<slug>-<role>`，idle hook 靠 `${name%%-*}_team` 反推工位；slug 若含连字符，hook 会切错。如当前扁平工位名带连字符，借本次重命名一并改为单 token。

使用 `git mv`（若在 git repo 中）或 `mv`：

```bash
git mv _agent_team_work_zone/<english_name> _agent_team_work_zone/<english_name>_team
# 若不在 git 中：
mv _agent_team_work_zone/<english_name> _agent_team_work_zone/<english_name>_team
```

此时：
- `README.md`、`notes.md`、`TODO.md`、`ACTIVE_JOBS.md`、`COMPLETED_JOBS.md` 都保留，只是换了父目录
- 没有丢任何文件

## Phase 3: 补齐 team 特有子结构

在新的 `_agent_team_work_zone/<english_name>_team/` 下创建：

```
roundtable/
  README.md       ← 部门内部沟通规则（参考顶层 meeting_room README 模板 + 说明部门隔离）
archive/
  .gitkeep
team_recipes/
  README.md       ← 说明 team_recipes 是 /spawn-team 产出的审计记录，可复用
teammates/
  README.md       ← 说明每 teammate 的工位结构 + Tier 2 存档用途
TEAMMATE_INFO.json ← Team 注册表（初始空 active_teammates，详见下方）
```

### TEAMMATE_INFO.json 初始化

在 team 工位根目录创建空的注册表：

```json
{
  "schema_version": 1,
  "team_name": "<english_name>_team",
  "lead_name": "<English Name>",
  "updated_at": "<ISO8601 当前时间>",
  "active_teammates": [],
  "offboarded_teammates": []
}
```

这是 Rule 13 规定的 team 注册表，后续 `/spawn-team` / `/add-teammate` / `/reactivate-team` 会读写它，`/checkpoint` 会更新 teammate 自己那条的 `last_checkpoint_at`。Schema 详见 `docs/teammate_info_schema.md`。

### roundtable/README.md 内容

```markdown
# <English Name> Team — 部门内部会议室（Roundtable）

> 本目录是 **<English Name> team 内部**的沟通空间。只有本 team 的 lead 和 teammate 能在此发文。
> 跨 team / 跨工位通讯请发到 `../../meeting_room/`。

## Frontmatter 规范

部门内部文件使用 `<team>/<role>` 小写斜杠格式：

\`\`\`yaml
---
kind: TRACKER_REPORT | TASK | DONE | ERR | STATUS
status: OPEN | IN_PROGRESS | RESOLVED
from: <english_name>_team/<role>   # 例如 architect_team/tracker
to: <english_name>_team/lead       # 或其他 teammate
date: YYYY-MM-DD HH:MM
priority: HIGH | MEDIUM | LOW
---
\`\`\`

## 归档

部门内部 RESOLVED 文件归档到 `../archive/`（而非顶层 archive）。
遵守守则 #8：**归档权唯一归 issuer（`from`）**；`to` 指向你的文件只能改 status，不可归档。
```

### team_recipes/README.md 内容

```markdown
# Team Recipes — 团队组建审计记录

本目录保存 `/spawn-team` 产出的 team 组建 prompt 和任务上下文，作为：
- 审计记录（这个 team 是什么时候、为什么、怎么组建的）
- 可复用素材（下次遇到类似任务时，可以先查这里找参考）

每个 recipe 是一份 markdown，命名格式：`<YYYYMMDD_HHMM>_<slug>.md`。

详见 `/spawn-team` skill 的 Phase 6b。
```

### teammates/README.md 内容

```markdown
# Teammates — 团队自定义角色存档（Tier 2）

本目录存放**跨任务复用**的团队自定义 teammate 定义。

对照三层存储策略：

| Tier | 位置 | 场景 |
|---|---|---|
| 1 (默认) | inline 在 spawn prompt + team_recipes/ 审计 | 一次性任务 |
| **2 (本目录)** | `teammates/<role>.md` | 团队内多次复用同一自定义角色 |
| 3 (罕见) | `.claude/agents/<team>_<role>.md` 带 team 前缀 | 希望 Claude Code 全局自动加载 |

默认走 Tier 1。只有当 lead 发现自己反复用同一个定制 teammate 时，才把它固化到 Tier 2。
Tier 3 极少使用——需要全局引用时再考虑，并且**必须**用 team 前缀防冲突。
```

## Phase 4: 更新工位 README

编辑 `_agent_team_work_zone/<english_name>_team/README.md`：

### 4a. 在身份章节补注模式

把原来的
> ## 身份
> - Architect
> - 负责项目架构设计与实验性改造...

改为
> ## 身份
> - Architect (Team Lead)
> - 负责项目架构设计与实验性改造...
> - 模式：**team lead**（工位在 `architect_team/`，有 `roundtable/` 等 team 特有子结构）

### 4b. 在工作守则章节补入 rule 12

如果原 README 只有 11 条守则，**必须加上第 12 条**（从 `_agent_team_work_zone/README.md` 复制）：

> ### 12. Team lead 节省 context window
> 如果你是 team lead，你的 context window 专用于协调——组建团队、读 teammate summary、
> 向用户汇报、跨 team 路由。你**不做**具体的编码/配置/测试等动手工作，那些交给
> `/spawn-team` 产出的 teammate。收到动手任务时先判断：能用几条消息搞定且不烧 context，
> 还是需要组建 team。超过 1-2 个文件或需要并行调研的任务一律倾向于组建 team。
> **原则**：宁可提前组建 team，不要事后抢救。

### 4c. 新增 "Team Management" 章节

在工作守则之后加：

```markdown
## Team Management

作为 team lead，我使用以下 skill 管理我的 team：

- `/spawn-team` — 为新的复杂任务组建 3~5 人 team（我自主调用，用户自然语言同意后）
- `/evaluate-team` — 定期评估现有 team：谁在忙、谁闲、缺不缺角色、有没有冗余
- `/add-teammate` — 向现有 team 增加一个 teammate
- `/remove-teammate` — 让某个 teammate 下岗（交接后归档产出）

对持续监视长任务，我用 Claude Code 内置的 `/schedule` 启动 tracker（基于 `resources/agents/tracker.md`）：
- training 任务默认 12 小时一次
- eval 任务默认 4 小时一次
- 报告自动写到我 team 的 `roundtable/`

## 部门内部通讯

我的 team 内部沟通走 `architect_team/roundtable/`（参见该目录 README）。
跨 team 和跨工位的通讯走顶层 `_agent_team_work_zone/meeting_room/`。
`/check-inbox` 会同时扫两处。

## Context 保留原则（重申 Rule 12）

- 手头任务能一两条消息搞定 → 自己处理
- 超过 1-2 个文件或需要并行工作 → 组建 team
- 已经感觉 context 紧张 → 立刻把剩余工作打包给 teammate，不要死扛
```

### 4d. 替换扁平工位的"何时升级"章节

扁平工位 README 里的"何时升级为 team lead"章节现在**不再适用**（你已经是 team lead 了），删掉或替换为一句简短说明：

> ~~## 何时升级为 team lead~~
>
> **已升级** — 当前为 team lead 模式，详见上方 "Team Management"。

## Phase 5: 更新成员表

编辑 `_agent_team_work_zone/README.md` 中的成员表，把对应行的 `工位目录` 列从 `<name>/` 改为 `<name>_team/`，把 `模式` 列从 `flat` 改为 `team`。

## Phase 6: 汇报完成

```
✅ 升级完成

工位: _agent_team_work_zone/<english_name>/ → _agent_team_work_zone/<english_name>_team/

新增子目录:
- roundtable/       (部门内部沟通)
- archive/          (部门内部归档)
- team_recipes/     (团队组建审计)
- teammates/        (Tier 2 自定义角色)

README 更新:
- 身份章节标注 "Team Lead" 模式
- 新增 rule 12 (如果之前缺失)
- 新增 "Team Management" 章节
- 移除扁平工位的"何时升级"章节

保留不动:
- notes.md
- TODO.md / ACTIVE_JOBS.md / COMPLETED_JOBS.md

成员表已更新：<english_name> 的模式列从 flat 改为 team

下一步：
你可以直接用自然语言描述需要这个 team 处理的任务，我会主动调用 /spawn-team
组建团队。
```

## 注意事项

- **只在扁平工位触发**：前置检查阻止 team lead 误调用
- **保留工作历史**：notes / TODO / ACTIVE_JOBS / COMPLETED_JOBS 完整保留
- **git mv 优先**：如果在 git repo 中用 `git mv` 保证历史
- **用户明确同意后再执行**：不要自作主张升级
- **13 条工作守则必须完整**：检查 README 中是否真的有 rule 12；若原扁平工位 README 只有 11 条（旧版），务必补齐
