# model_policy.json 结构说明

> 人类阅读文档。**不是** runtime 依赖——`/quickstart`、`/onboard`、`/spawn-team`、`/add-teammate` 直接 inline 各自使用的 JSON 结构，不 Read 本文件。末尾"给 lead 的建议怎么写"一节的规则由 `resources/scripts/atwz_detect_tier.sh` 实现；改规则要同时改脚本。

本文件记录一个团队的成员**默认**用什么模型、最多几名成员，以及给 lead 的模型和思考强度建议。它按用户的订阅档位定下来，免得一上来就把额度用光。每个 team 工位一份。

成员的思考强度跟着 lead 当前的会话：Agent 工具的 `effort` 参数对团队成员不起作用（同进程和分窗格都一样），所以本文件不记成员的思考强度，只记对 lead 的建议。

## 路径

```
_agent_team_work_zone/<team_name>/model_policy.json
```

和 `TEAMMATE_INFO.json` 放在一起，纳入 git。

## 谁读谁写

| 操作 | 写 | 读 |
|---|---|---|
| `/quickstart` | ✅ 建团队时判断订阅档位，按默认方案写入（不问用户） | ✅ 续做时读 |
| `/onboard`（Team Lead 工位） | ✅ 判断订阅档位，向用户展示默认 / 保守 / 自己指定三种，按用户的选择写入 | - |
| `/spawn-team`、`/add-teammate` | - | ✅ 阵容提案里成员模型的默认值，以及人数上限 |
| `/reactivate-team` | - | **不读**：重新派生只按登记表 |
| lead（用户要求"以后的成员 / 所有成员换成 …"或"思考强度调到 …"时） | ✅ 改 `member_model` 或 `lead_effort_suggested`，`choice` 改为 `custom` | - |
| teammate | **不写** | - |

档位由 `resources/scripts/atwz_detect_tier.sh` 判断。它只读 `claude auth status` 的登录方式和订阅类型；订阅是 Max 时，再读一个档位字段来分 Max 5x 和 Max 20x（这是 Claude Code 没有文档的内部字段，以后可能改名；读不到就按 Max 5x）。没登录时判为 `unknown`。

## 完整 Schema（v1）

```json
{
  "schema_version": 1,
  "tier": "max_20x",
  "tier_source": "subscriptionType=max; organizationRateLimitTier=default_claude_max_20x",
  "choice": "default",
  "member_model": "opus",
  "max_members": 5,
  "lead_model_suggested": "opus",
  "lead_effort_suggested": "high",
  "decided_by": "quickstart (automatic)",
  "detected_at": "2026-10-25T03:14:00Z",
  "updated_at": "2026-10-25T03:14:00Z"
}
```

## 字段说明

| 字段 | 类型 | 含义 |
|---|---|---|
| `schema_version` | integer | 当前为 1 |
| `tier` | string | `pro` / `max_5x` / `max_20x` / `team`（含 Enterprise）/ `api`（API key、云厂商、`ANTHROPIC_BASE_URL` 指向别处）/ `unknown`（判断不出，含没登录） |
| `tier_source` | string | 判断所依据的字段名和取值。**不写**邮箱、组织名、账户编号、令牌 |
| `choice` | string | `default` / `conservative` / `custom` |
| `member_model` | string | `haiku` / `sonnet` / `opus`。**不允许 `fable`**：成员会话用 Fable 可能要按量付费，那时会弹同意提示，5 分钟无人应答这一回合就作废，成员会卡住。用户点名要某个成员用 `fable` 时照做，但只写进该成员的登记项，不写进这里 |
| `max_members` | integer | 建议的成员人数上限。超过时向用户说明并请用户确认，不硬性拒绝。`/remote-collab` 的查看成员（`<slug>-remotewatch`，固定用 haiku）不计入 |
| `lead_model_suggested` | string 或 null | 给 lead（用户当前会话）的模型建议。技能改不了 lead 的模型，只能在结束消息里建议；null 表示不建议。Max 20x 时结束消息按 `fable` 比较（额度足够，推荐 Fable） |
| `lead_effort_suggested` | string 或 null | 给 lead 的思考强度建议：`low` / `medium` / `high`；之后派生或重新派生的成员会用 lead 当时的思考强度。null 表示不建议 |
| `decided_by` | string | `quickstart (automatic)` / `onboard (user confirmed)` / `user request` |
| `detected_at` | ISO8601 string | 判断档位的时间 |
| `updated_at` | ISO8601 string | 本文件最后修改时间 |

## 各档位的取值

默认方案：

| `tier` | `member_model` | `max_members` | `lead_model_suggested` | `lead_effort_suggested` |
|---|---|---|---|---|
| `pro` | `haiku` | 2 | `sonnet` | `medium` |
| `max_5x` | `sonnet` | 4 | `opus` | `medium` |
| `max_20x` | `opus` | 5 | `opus` | `high` |
| `team` | `sonnet` | 4 | `opus` | `medium` |
| `api` | `sonnet` | 5 | null | null |
| `unknown` | `sonnet` | 5 | null | null |

保守方案（只在 `/onboard` 里给；人数上限同默认方案）：

| `tier` | `member_model` | `lead_model_suggested` | `lead_effort_suggested` |
|---|---|---|---|
| `pro` | `haiku` | `sonnet` | `low` |
| `max_5x` | `haiku` | `sonnet` | `low` |
| `max_20x` | `sonnet` | `opus` | `medium` |
| `team` | `haiku` | `sonnet` | `low` |
| `api` / `unknown` | `sonnet` | null | null |

框架自带的 tracker（定时盯守）仍按它自己的规定用 haiku，不受本文件影响。

## 派生时成员模型的优先顺序

按下面的顺序取第一个有的：

1. 用户在对话里点名的（"这个成员用 opus"）——永远优先；
2. 重新派生（`/reactivate-team`）时：登记表里该成员已有的 `model`。**不读本文件**，已有成员不会因为本文件改了而被换掉；
3. 本文件的 `member_model`；
4. 没有本文件（老团队）：`sonnet`。

派生时不传 `effort`，登记表也不记思考强度。

## 给 lead 的建议怎么写

**由脚本实现**：`resources/scripts/atwz_detect_tier.sh --model "<lead 当前模型>" [--plan default|conservative]` 按本节规则拼好整句，输出在 JSON 的 `lead_advice` 里（无建议时为空字符串）。/quickstart 的结束消息和 /onboard 的完成确认原样使用它，不由模型现场拼。本节是规则说明；改规则要同时改脚本。

- 建议值：按档位和方案（`--plan`，默认 `default`；/onboard 选保守方案时传 `conservative`）取本文件"各档位的取值"两张表里的 `lead_model_suggested`、`lead_effort_suggested`。Max 20x 的默认方案，模型按 `fable` 比较（额度足够，推荐 Fable）。`api`、`unknown` 没有建议值，不出建议。
- 当前值：模型是 `--model` 给的（认得出 haiku / sonnet / opus / fable 才比较，认不出就不出建议）；思考强度是脚本读出的 `lead_effort_current`。
- 按等级比较：模型 `haiku` < `sonnet` < `opus` < `fable`；思考强度 `low` < `medium` < `high` < `xhigh` < `max`。每一项：相同 → 不提；当前高于建议 → 归入"该降的"；当前低于建议 → 归入"该升的"。两组都空 → 不出建议。
- 每组里 Pro 先思考强度后模型，其他档先模型后思考强度。各项写成"输入 /model <建议模型>"（建议是 fable 时加"（Fable 最多占每周额度的一半）"）、"输入 /effort <建议思考强度>（之后派生或重新派生的成员会用同样的思考强度）"；一组有两项时写成"先 <第一项>，再考虑<第二项>"。
- 按顺序拼成一句：
  1. 有"该降的"：写"你现在<用的是 <当前模型> / 思考强度是 <当前思考强度>（只写该降的项，两项用"、"连接）>，<档位名> 的额度会消耗得很快[Pro 且当前模型是 fable 时加：，而且 Fable 在 Pro 上要按量付费]；建议<该降的项>"。
  2. 有"该升的"：
     - Max 20x 且没有第 1 部分："你的 Max 20x 额度足够，想要更强的规划判断，可以<该升的项>"。"额度足够"只用于 Max 20x。
     - Pro：有第 1 部分时"；想要更强的规划判断，也可以提高到 <建议值，用"、"连接>（<该升的项>），Pro 下留意额度"，没有时把"也可以"换成"可以"、去掉开头的"；"。
     - 其他：有第 1 部分时"；想要更强的规划判断，也可以<该升的项>"，没有时"想要更强的规划判断，可以<该升的项>"。
  3. 句末加："。这也会成为你以后会话的默认，随时可以再改。"
- 下文 <档位名>：`pro` 写 Pro，`max_5x` 写 Max 5x，`max_20x` 写 Max 20x，`team` 写 Team / Enterprise。
- 例（脚本实际输出）：
  - Pro、当前 opus、思考强度 high →"你现在用的是 opus、思考强度是 high，Pro 的额度会消耗得很快；建议先输入 /effort medium（之后派生或重新派生的成员会用同样的思考强度），再考虑输入 /model sonnet。这也会成为你以后会话的默认，随时可以再改。"
  - Pro、当前 haiku、思考强度 medium →"想要更强的规划判断，可以提高到 sonnet（输入 /model sonnet），Pro 下留意额度。这也会成为你以后会话的默认，随时可以再改。"
  - Max 20x、当前 opus、思考强度 medium →"你的 Max 20x 额度足够，想要更强的规划判断，可以先输入 /model fable（Fable 最多占每周额度的一半），再考虑输入 /effort high（之后派生或重新派生的成员会用同样的思考强度）。这也会成为你以后会话的默认，随时可以再改。"
