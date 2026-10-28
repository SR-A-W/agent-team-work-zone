---
name: onboard
description: >
  新 agent 入职: 先询问是扁平工位还是 team lead，然后创建对应目录结构、
  生成角色定义文件和任务跟踪文件、在成员表中注册。在新 agent 对话开始时使用。
  第一次使用建议用 /quickstart，它会一次建好 lead 工位和团队。
argument-hint: "<任务/角色描述>"
disable-model-invocation: true
allowed-tools: Read Write Edit Glob Bash
---

# Agent 入职流程（支持扁平工位和 Team Lead 两种模式）

你正在为一个新 agent 执行入职。请按以下步骤完成。

## 输入信息

用户通过 `$ARGUMENTS` 提供角色或任务描述。描述中可能已包含明确的命名，但**命名优先由你 agent 自行决定**，只有当用户主动提出偏好或拒绝你的命名时，才采用用户的指示。

## Step 0: 确认工位模式（扁平 or Team Lead）

在开始任何操作前，**先根据任务描述询问用户**：

```
我理解你需要的角色职责是：<从 $ARGUMENTS 中归纳的一句话>

请问这个角色应该是：
  (1) 扁平工位 — 一个人的工位，适合单人能完成的简单任务（如秘书、Git 管理、翻译等）
  (2) Team Lead — 带一个部门办公室，适合需要多人协作、并行工作流、对抗性调研的复杂任务
       （team lead 不做具体的编码/配置/测试，通过 /spawn-team 组建 team，由 teammate 完成动手工作）

你希望是哪种？
```

等用户明确回答后再进入对应分支。**不要自行猜测**——如果描述模糊，按守则 #11 主动提问。

> **升级**：如果将来发现扁平工位承担不了了，可以通过 `/promote-to-team` 升级。但 **`/onboard` 只在对话开始时执行一次**，这里决定的模式就定型了。

## Step 1: 阅读项目组总纲

读取 `_agent_team_work_zone/README.md`，了解：
- 项目组的工作流程
- 已有的成员列表
- 13 条工作守则
- 当前使用的模式（扁平/team 混合）

## Step 2: 确定角色名

**你需要自行确定以下三项**：
- **角色中文名** — 简短（2-4 字，如：秘书、架构师、规划师）
- **角色英文名** — 简短英文（如：Secretary、Architect、Planner）
- **一句话职责描述** — 概括核心职责

**命名原则**：
- 从用户的任务描述中提炼合适的命名
- 英文名用于目录命名时转为小写下划线格式
- 扁平工位目录：`<english_name>/`
- Team Lead 工位目录：`<english_name>_team/`（**必须以 `_team` 结尾**）
- 命名应简短、明确、易于区分
- 和别人在同一个项目协作（各自的团队在不同机器上，用 `/remote-collab`）时，两边的团队名要不同

**向用户确认命名**：

```
我建议这个角色叫：
  中文：<中文名>
  英文：<English Name>
  工位目录：_agent_team_work_zone/<english_name>[_team]/
  一句话职责：<描述>

你同意这个命名吗？如果不同意，请告诉我你的偏好。
```

若用户否决，按用户偏好重命名后再次确认。

## Step 3: 创建工位目录和基础文件

### 扁平工位分支

创建目录和 5 个文件：

```
_agent_team_work_zone/<english_name>/
├── README.md           ← 角色定义 + 13 条工作守则 + 扁平工位的升级提醒
├── notes.md            ← 工作笔记
├── TODO.md             ← 待办事项
├── ACTIVE_JOBS.md      ← 活跃任务
└── COMPLETED_JOBS.md   ← 已完成任务
```

README.md 必须包含以下章节：

1. **身份** — 角色名称 + 一句话职责描述
2. **职责范围** — 做什么 / 不做什么
3. **工作流程** — 典型工作步骤
4. **关键文件** — 经常需要访问的文件路径
5. **工作守则** — 从项目组总纲**完整复制** 13 条工作守则（防止上下文压缩后遗忘）
6. **工作笔记** — 说明本工位有 notes.md
7. **何时升级为 team lead** — 提醒自己：预见到任务会变复杂时主动建议用户 `/promote-to-team`（以下内容必须写入）：

   > **何时升级**：如果新分配的任务需要多种不同专业技能（例如既要改代码又要配环境又要写脚本）、
   > 会有多个可并行工作项、需要对抗性审阅或多角度调研、或单人完成会显著消耗 context window
   > （> 50% 用于执行细节而非决策），你应该**主动**建议项目主管运行 `/promote-to-team` 升级。
   > **原则：宁可提前升级，不要事后抢救**。一旦 context 已经被任务细节挤满再组建 team，lead 就无法有效指挥了。

8. **上下文恢复** — 压缩后怎么恢复（读 README + notes + 相关 meeting_room 文件）

### Team Lead 工位分支

创建目录、5 个文件 **+ team 特有子结构**：

```
_agent_team_work_zone/<english_name>_team/
├── README.md                ← 含 team lead 专属章节 + rule 12/13 + 13 条工作守则
├── notes.md
├── TODO.md / ACTIVE_JOBS.md / COMPLETED_JOBS.md
├── TEAMMATE_INFO.json       ← Team 注册表（初始空 active_teammates）
├── model_policy.json        ← 成员默认的模型、人数上限、给 lead 的建议（见下方"选定成员模型"）
├── roundtable/              ← 部门内部沟通
│   └── README.md            ← 从项目模板或 meeting_room README 派生
├── archive/                 ← 部门内部归档
│   └── .gitkeep
├── team_recipes/            ← /spawn-team 产出的审计记录
│   └── README.md            ← 说明 team_recipes 的用途
└── teammates/               ← 每 teammate 自己的工位 + Tier 2 存档
    └── README.md            ← 说明工位结构 + Tier 2 存档用途
```

**初始化 TEAMMATE_INFO.json**（team lead 新工位必建，为后续 `/spawn-team` / `/add-teammate` / `/reactivate-team` 读写做准备）：

> ⚠️ `<english_name>` 必须单 token（无连字符）——它是本 team 的 **slug**，日后 teammate 名 `<slug>-<role>` 与 idle hook 的 `${name%%-*}_team` 工位反推都依赖它无连字符。

```json
{
  "schema_version": 2,
  "team_name": "<english_name>_team",
  "lead_name": "<English Name>",
  "updated_at": "<ISO8601 当前时间>",
  "active_teammates": [],
  "offboarded_teammates": []
}
```

Schema 详见 `docs/teammate_info_schema.md`。Teammate **不写本文件的任何内容**（schema v2 起花名册 100% 由 team lead 写；teammate 的"最后 checkpoint"改由其工位 `working-context.md` 的 mtime 体现）。写入本文件时走带校验的原子写入：`jq` → `jq empty` 解析校验 → 备份 `.bak` → 原子 `mv`，不要手改 JSON。

**选定成员模型**（建好 `TEAMMATE_INFO.json` 之后做；快速模式跳过本步，由 /quickstart 自己做）：

成员用什么模型、能有几个人，按用户的订阅来定，免得一上来就把额度用光。成员的思考强度跟着 lead 这个会话（派生时没法单独设），所以思考强度只能作为对 lead 的建议。

1. 先从你自己的系统提示里读出你当前的模型，然后在 Bash 里运行 `bash _agent_team_work_zone/resources/scripts/atwz_detect_tier.sh --model "<当前模型>"`（读不到模型就不加 `--model`），取输出 JSON 里的 `tier` 和 `source`（Step 6 会带上 `--plan` 再运行一次，取给 lead 的建议句）。出错或解析不出 → `tier` 按 `unknown`。
2. 按 `tier` 查下面两张表。

   默认方案：

   | `tier` | 成员模型 | 成员人数上限 | 给 lead 的模型建议 | 给 lead 的思考强度建议 |
   |---|---|---|---|---|
   | `pro` | `haiku` | 2 | `sonnet` | `medium` |
   | `max_5x` | `sonnet` | 4 | `opus` | `medium` |
   | `max_20x` | `opus` | 5 | `opus` | `high` |
   | `team` | `sonnet` | 4 | `opus` | `medium` |
   | `api` / `unknown` | `sonnet` | 5 | 不建议 | 不建议 |

   保守方案（人数上限同默认方案）：

   | `tier` | 成员模型 | 给 lead 的模型建议 | 给 lead 的思考强度建议 |
   |---|---|---|---|
   | `pro` | `haiku` | `sonnet` | `low` |
   | `max_5x` | `haiku` | `sonnet` | `low` |
   | `max_20x` | `sonnet` | `opus` | `medium` |
   | `team` | `haiku` | `sonnet` | `low` |
   | `api` / `unknown` | `sonnet` | 不建议 | 不建议 |

3. 向用户展示并请用户选。档位名：`pro` 写 Pro，`max_5x` 写 Max 5x，`max_20x` 写 Max 20x，`team` 写 Team / Enterprise；思考强度：`low` 写"低"，`medium` 写"中等"，`high` 写"较高"。例如 Max 5x：

   ```
   我看到你的订阅是 Max 5x。用哪一套？
     1. 默认：成员用 sonnet，最多 4 名成员；你这个会话（团队负责人）建议用 opus、中等思考强度（之后派生或重新派生的成员会用同样的思考强度）。
     2. 保守，更省额度：成员用 haiku；你用 sonnet、低思考强度。
     3. 自己指定。
   ```

   Max 20x 时，默认一项里把"建议用 opus"写成"建议用 opus（额度足够，想要更强的规划判断也可以用 fable）"，和 Step 6 的说法一致。

   Pro 的保守方案只降思考强度、不降模型，第 2 项写成："保守，更省额度：模型不变；你的思考强度降到低。"

   `api` 和 `unknown` 两种没有保守方案，这样问：

   ```
   <api：你用的是按用量计费的登录方式 | unknown：我没能判断你的订阅档位>。建议成员默认用 sonnet 模型，最多 5 名成员。用这一套，还是自己指定？（默认 / 自己指定）
   ```

   - 选"自己指定"：再问成员模型（`haiku` / `sonnet` / `opus`）和人数上限；给 lead 的建议沿用默认方案。用户想让所有成员都用 `fable` 时，说明：成员会话用 Fable 可能要按量付费，那时会弹同意提示，5 分钟无人应答这一回合就作废，成员会卡住，所以默认值里不放 `fable`；需要时可以在派生某个成员时点名用 `fable`。
   - 用户不选或说"随便" → 用默认方案。
4. 把结果写进 `_agent_team_work_zone/<english_name>_team/model_policy.json`（字段见 `docs/model_policy_schema.md`），带校验写入，不手改 JSON（任一步失败都删掉临时文件）：

   ```bash
   policy=_agent_team_work_zone/<english_name>_team/model_policy.json
   ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
   tmp="$(mktemp "$(dirname "$policy")/.policy.XXXXXX")" \
     && jq -n --arg tier "<tier>" --arg src "<source>" --arg choice "<default|conservative|custom>" \
          --arg mm "<成员模型>" --argjson max <人数上限> \
          --argjson lm '<"sonnet" / "opus" 或 null>' --argjson le '<"low" / "medium" / "high" 或 null>' --arg ts "$ts" '
        {schema_version: 1, tier: $tier, tier_source: $src, choice: $choice,
         member_model: $mm, max_members: $max,
         lead_model_suggested: $lm, lead_effort_suggested: $le,
         decided_by: "onboard (user confirmed)", detected_at: $ts, updated_at: $ts}' > "$tmp" \
     && jq empty "$tmp" && mv "$tmp" "$policy" && chmod 644 "$policy" || rm -f "$tmp"
   ```

   `source` 只含字段名和取值；不要把 `claude auth status` 的原始输出写进任何文件或消息。之后 `/spawn-team` 的阵容提案按这个文件填默认模型，用户在阵容确认那一步还能改。

README.md 必须包含 Flat 版所有章节 **+** 以下 team lead 专属章节：

- **Team 职责范围** — 这个 team 负责什么领域 / 典型任务类型 / 边界
- **团队管理** — 使用 `/spawn-team`、`/evaluate-team`、`/add-teammate`、`/remove-teammate` 的指南；写明派生成员前读本团队的 `model_policy.json`，按里面的成员模型和人数上限提阵容
- **给成员换模型或思考强度** — 原文照写本文"快速模式"一节末尾的"给成员换模型或思考强度"一段（普通流程和快速模式都写）
- **Context 保留原则**（即 rule 12）：

  > **重要 — Rule 12**：作为 team lead，你的 context window 专用于**协调**，不做动手的编码/配置/测试工作。
  > 收到动手任务时先判断：能用几条消息搞定且不烧 context，还是需要组建 team。超过 1-2 个文件或需要并行调研的
  > 一律倾向于 `/spawn-team`。teammate 通过自己的 session 完成动手工作，你只看 summary + 决策。

- **Tracker 管理** — 需要持续监视长任务时，如何用内置 `/schedule` + `resources/agents/tracker.md` 模板启动 tracker，产出写到本 team 的 `roundtable/`

### 两种模式通用的工作笔记与任务跟踪

`notes.md` 初始内容：
```markdown
# <角色英文名> 工作笔记

(工作中积累的重要知识会记录在这里)
```

`TODO.md` / `ACTIVE_JOBS.md` / `COMPLETED_JOBS.md` 按标准模板创建（参考现有工位）。

## Step 4: 在成员表中注册

编辑 `_agent_team_work_zone/README.md`，在"项目组成员"表格中添加一行：

```
| <中文名> | <英文名> | `<目录名>/` | <flat 或 team> | <一句话职责> |
```

## Step 5: 读取相关通讯空间规则

- 所有 agent：读取 `_agent_team_work_zone/meeting_room/README.md` 了解顶层会议室规则
- Team lead 额外：读取新创建的 `<your_team>/roundtable/README.md` 了解部门内部通讯规则

## Step 6: 完成确认

所有步骤完成后，向用户汇报：
- 已创建的工位目录路径
- 工位模式（flat / team lead）
- 已创建的文件清单（扁平 5 个，team lead 更多）
- 已在成员表中注册
- 当前项目组共有多少名成员、其中 flat / team 各多少
- **若是 team lead**：提醒用户下一步可以用自然语言描述任务，lead 会主动建议调用 `/spawn-team`
- **若是 team lead**，再交代模型（合计不超过两行）：
  1. 一句成员模型："成员默认用 <模型>，最多 <n> 名成员；想换，跟我说一句。"
  2. 给 lead 的建议：再运行一次 `bash _agent_team_work_zone/resources/scripts/atwz_detect_tier.sh --model "<当前模型>" --plan <default 或 conservative>`（用户选保守方案时用 `conservative`，其余用 `default`），把输出的 `lead_advice` 原样写上；为空就不写。不要改写，也不要自己另拼。

## 快速模式（只由 /quickstart 使用）

/quickstart 不用技能工具调用本技能（本技能只允许用户直接调用），而是读本文件、照本节执行。用户直接输入 `/onboard` 时，不走本节。

**/quickstart 交过来的答案**：
- slug（只含小写字母和数字，已按 /quickstart 的规则得出）；
- 英文名 `<Slug> Lead`、中文名"项目主管"、一句话职责；
- 未完成标记 `.quickstart_incomplete` 的全文。

缺任何一项 → 不向用户补问，停下，退回 /quickstart，由它报告失败。

**先做这一条检查**（本技能其余部分没有这条规则，只在快速模式下做）：`_agent_team_work_zone/<slug>_team/` 已存在时——
- 里面**没有** `.quickstart_incomplete` → 停下，不覆盖任何文件，退回 /quickstart 报告"同名目录已存在"；
- 里面**有** `.quickstart_incomplete` → 下面各步只补缺的文件，不重写已有的。

**各步怎么做**：

| 本技能的步骤 | 快速模式下 |
|---|---|
| `## Step 0: 确认工位模式（扁平 or Team Lead）` | 跳过，固定为 Team Lead |
| `## Step 1: 阅读项目组总纲` | 照做 |
| `## Step 2: 确定角色名` | 跳过向用户确认，用传入的名字。**目录名不按本步的"转小写下划线"规则得出**，直接用 `<slug>_team` |
| `## Step 3: 创建工位目录和基础文件` 下的 `### Team Lead 工位分支` | **照做，不能跳过。** 本节"`<english_name>` 必须单 token"的警告在这里指 slug，照样检查。建好目录后**第一个**写 `.quickstart_incomplete`（内容用传入的全文），然后才写其他文件。`TEAMMATE_INFO.json` 的 `team_name` 写 `<slug>_team`，`lead_name` 写 `<Slug> Lead`。其中的"选定成员模型"一步**跳过**，由 /quickstart 自己判断档位、写 `model_policy.json`。README 的团队负责人专属章节照常写，包括下面的"给成员换模型或思考强度"一段 |
| `## Step 3` 下的 `### 两种模式通用的工作笔记与任务跟踪` | **照做，不能跳过** |
| `## Step 4: 在成员表中注册` | **照做，不能跳过**。按本步的格式写一行：中文名"项目主管"、英文名 `<Slug> Lead`、目录 `<slug>_team/`、模式 team、一句话职责；成员表里已有这个目录的行就不再加 |
| `## Step 5: 读取相关通讯空间规则` | 照做 |
| `## Step 6: 完成确认` | 跳过，不向用户汇报，回到 /quickstart，由它的结束消息汇报 |

**"给成员换模型或思考强度"一段**（写进 lead 工位 README 的团队负责人专属章节，普通流程和快速模式都写；原文照写，只把 `<slug>` 换成本团队的 slug）：

````markdown
### 给成员换模型或思考强度

用户说"把 <成员名> 换成 <模型>"（例如 opus），就视为已经确认，不再问用户：

- 只针对某个成员 → 按下面五步做，不改 `model_policy.json`；
- 针对"以后的成员"或"所有成员" → 先改 `model_policy.json`（见五步之后），再对已有成员逐个走五步。

成员默认不用 `fable`：成员会话用 Fable 可能要按量付费，那时会弹同意提示，5 分钟无人应答这一回合就作废，成员会卡住。用户点名要某个成员用 `fable` 时照做，但先提醒一句这个风险；`model_policy.json` 的成员模型不写 `fable`。

1. 请该成员运行 /checkpoint，等它确认。
2. 用 SendMessage 给它发关闭请求（`{"type": "shutdown_request"}`），等它同意。登记表里它的状态保持 `active`，不改成 `benched`。
3. 把登记表里它的 `model` 改为目标模型（带校验的原子写入）：
   ```bash
   name="<成员名>"
   model="opus"
   ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
   info=_agent_team_work_zone/<slug>_team/TEAMMATE_INFO.json
   tmp="$(mktemp "$(dirname "$info")/.info.XXXXXX")" && cp -p "$info" "$tmp" \
     && jq --arg n "$name" --arg m "$model" --arg ts "$ts" '
     .active_teammates |= map(if .name == $n then .model = $m else . end) | .updated_at = $ts
   ' "$info" > "$tmp" \
     && jq empty "$tmp" \
     && cp "$info" "$info.bak" \
     && mv "$tmp" "$info" || rm -f "$tmp"
   ```
4. 运行 `/reactivate-team <成员名>`，它按登记表里的新模型派生。它的步骤里会问"确认开始 reactivate 吗？"——用户已经提出换模型，按已确认继续，不再问用户一次。
5. 核对回执里的模型 ID（应含新模型名，例如 opus）。预期会出现一行"模型不一致……README 写的是 <旧模型>"：/reactivate-team 会把回执与成员 README 的模型行比对，而 README 是成员自己的文件，lead 不改。这一行是预期内的，不是错误；请该成员在下次 checkpoint 时自己把 README 的模型行改成新模型。

针对"以后的成员"或"所有成员"时，先改 `model_policy.json`（文件不存在就跳过这一步，只走五步）：
```bash
model="<新模型>"
ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
policy=_agent_team_work_zone/<slug>_team/model_policy.json
tmp="$(mktemp "$(dirname "$policy")/.policy.XXXXXX")" && cp -p "$policy" "$tmp" \
  && jq --arg m "$model" --arg ts "$ts" '
  .member_model = $m | .choice = "custom" | .decided_by = "user request" | .updated_at = $ts
' "$policy" > "$tmp" \
  && jq empty "$tmp" \
  && mv "$tmp" "$policy" || rm -f "$tmp"
```

用户说"思考强度调到 <强度>"（不论说的是成员还是你）：成员的思考强度跟着你这个会话，派生时没法单独设。所以告诉用户输入 `/effort <强度>`（这也会成为以后会话的默认；`max` 除外，它只对当前会话有效），并把 `model_policy.json` 的 `lead_effort_suggested` 改为这个强度（同上的写法，把 `.member_model = $m` 换成 `.lead_effort_suggested = $m`，`model` 填强度）。不要说"成员已经改了"，而是告诉用户：之后派生或重新派生的成员会用同样的思考强度（同进程显示时已在工作的成员也会跟着变，分窗格显示时要重新派生才变）。
````

## 注意事项

- `/onboard` **只会执行一次**——在对话开始时决定你的模式。之后不要重复运行
- 若用户一开始说要扁平工位，但后来发现任务太复杂，**不要**再调 `/onboard`，而是用 `/promote-to-team`
- 命名决策权在 agent，但用户有否决权——不要一意孤行
- 13 条工作守则**必须**完整复制到新工位的 README（守则 #6 角色持久化）
