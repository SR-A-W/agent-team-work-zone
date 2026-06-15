---
name: add-teammate
description: >
  在现有 team 中增加一个 teammate：走简化版 spawn-team 流程（只处理单人）。
  Team lead 可自主调用（用户自然语言同意后）。只在 team lead 上下文有效。
disable-model-invocation: false
allowed-tools: Read Write Edit Glob Grep
---

# `/add-teammate` — 向现有 team 增加一个 teammate

## 身份前置检查

**先从对话 context 推断**：你应该已经知道自己是 team lead。**无法推断时**：
1. Glob `_agent_team_work_zone/*_team/`
2. 定位当前对话对应 team
3. 若不是 team lead → 立即停止警告

## Phase 1: 收集新 teammate 需求

向用户或从对话 context 收集：
- **为什么需要新 teammate**：现有 team 缺什么能力？
- **任务细节**：新 teammate 要做什么具体工作？
- **边界**：它可以碰什么、不可以碰什么？
- **与现有 teammate 的关系**：协作 / 接替 / 审阅？

## Phase 2: 选择角色来源

查阅：
- **通用 subagent** (`resources/agents/`)：tracker / investigator / reviewer / devil-advocate / git-repo-manager
- **角色原型** (`resources/role_archetypes/`)：9 个
- **本 team 的 Tier 2 存档** (`<SELF>_team/teammates/`)

**原则**：
- 优先用已有通用 subagent（不用定制，直接 spawn 时 by name 引用）
- 其次用角色原型（需填入项目特定细节）
- 最后才原创 inline persona 或新建 Tier 2

## Phase 3: 向用户展示提案

```
## 新 teammate 提案

- **昵称**: <name>
- **角色来源**: <subagent 名 / role_archetype 路径 / 原创>
- **模型**: <haiku / sonnet / opus>
- **Plan-mode gating**: <YES / NO>
- **作用域**: <具体可碰的文件/目录>
- **禁区**: <不能碰的>
- **交付物**: <产出什么>
- **与现有 team 的协作**: <谁给它派活、它的产出给谁>

你同意加入这个 teammate 吗？
```

等用户明确同意后进入 Phase 4。

## Phase 4: 创建 teammate 工位骨架 + 注册到 TEAMMATE_INFO.json

### 4a. 创建 teammate 工位目录 + 5 个骨架文件

路径：`_agent_team_work_zone/<SELF>_team/teammates/<teammate-name>/`

创建 5 个文件（Rule 13 规定的 teammate 自维护 5 文件）：

- **`README.md`** — 角色定义：写 Phase 3 里收集的昵称、模型、作用域、禁区、交付物、plan-mode gating 说明，以及（可选）一个空的 `## Checkpoint Instructions` 段位供后续定制
- **`working-context.md`** — 初始占位：
  ```markdown
  # Working Context — <teammate-name>
  _Initialized at spawn. Run /checkpoint to populate._
  ```
- **`completed.md`** — 空文件（append-only 日志，由 /checkpoint 的 task_completed trigger 追加）
- **`TODO.md`** — 空文件
- **`commitments.md`** — 空文件

### 4b. Append 到 TEAMMATE_INFO.json

在 `_agent_team_work_zone/<SELF>_team/TEAMMATE_INFO.json` 的 `active_teammates` 数组尾部追加一条（如果文件不存在，先按 schema v1 初始化 — 参见 `docs/teammate_info_schema.md`）：

```json
{
  "name": "<teammate-name>",
  "role_source": {
    "type": "archetype" | "subagent" | "tier2" | "inline",
    "path": "..." // 或 subagent_name 或 inline_description
  },
  "model": "<haiku|sonnet|opus>",
  "plan_mode_gating": <true|false>,
  "scope": "<作用域简述>",
  "spawned_at": "<ISO8601 当前时间>",
  "last_checkpoint_at": null,
  "revived_count": 0,
  "status": "active"
}
```

同时更新顶层 `updated_at` 为当前时间。

jq 示例（如果可用）：
```bash
jq --argjson entry '<json 对象>' --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   '.active_teammates += [$entry] | .updated_at = $ts' \
   _agent_team_work_zone/<SELF>_team/TEAMMATE_INFO.json > /tmp/info.json && \
   mv /tmp/info.json _agent_team_work_zone/<SELF>_team/TEAMMATE_INFO.json
```

## Phase 5: 生成 add-teammate spawn prompt

```
我要向现有的 <SELF> team 增加一个新的 teammate：

<昵称>（模型：<model>）
角色定义：<引用或填入内容>
任务：<细节>
Plan-mode gating: <YES/NO + 批准标准>

你的工位在 _agent_team_work_zone/<SELF>_team/teammates/<昵称>/（README/working-context/
completed/TODO/commitments 5 个文件已由 lead 初始化）。按 Rule 13 维护它：进入 idle 前、
收到 checkpoint 提醒时、任务完成后调用 /checkpoint 更新 working-context.md。

它的产出写到 _agent_team_work_zone/<SELF>_team/roundtable/，和其他 teammate 通过 mailbox 协作。

请 spawn 这个新 teammate 加入现有 team。
```

## Phase 6: 更新 team_recipes/

**不新建 recipe 文件**（那是 /spawn-team 的事）。而是：
- 找到最近的 recipe（`<SELF>_team/team_recipes/` 下按时间倒序第一个）
- 在其末尾追加一段 "Amendment"：

```markdown
---

## Amendment — YYYY-MM-DD HH:MM — add-teammate

### 新增 teammate
<Phase 3 的提案内容>

### 原因
<Phase 1 收集的需求>

### Spawn Prompt
<Phase 4 生成的 prompt>
```

这样后续 `/evaluate-team` 或下次 `/spawn-team` 能看到完整 team 演化历史。

## Phase 7: 发送 spawn prompt

在下一条消息把 Phase 5 的 prompt 发出，Claude Code 内置机制识别并 spawn。

```
✅ teammate 工位骨架已创建（5 文件）
✅ TEAMMATE_INFO.json 已追加新条目
✅ team_recipes/<latest>.md 已追加 Amendment
下一步发送 spawn prompt 给 Claude Code agent-team 机制
```

## 注意事项

- **不重复组建整个 team**：只加一个人，现有 team 保持
- **继承团队规范**：新 teammate 的 spawn prompt 里要明确写让它把产出写到 `<SELF>_team/roundtable/`
- **Amendment 不是新 recipe**：用追加而非新建，保持 team 演化历史清晰
- **最多控制在 5 人**：如果加上之后超过 5 人，先警告用户并问是否真的需要（或者是不是该移除某个冗余的）
