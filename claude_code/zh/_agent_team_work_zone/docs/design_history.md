# Design History — Agent Teams 重构

> 本文档记录 2026-04 期间 `_agent_team_work_zone/` 重构的设计决策过程，作为历史参考。最终架构见 `agent-teams.md`。

## 时间线

- **2026-04-08**：Secretary 在 meeting_room 提交 `Secretary_TASK_20260408_1600_experimental_hierarchical_zh_template.md`，提议在一个实验性中文子目录中落地原层级化方案（四机制）。
- **2026-04-09**：Architect 入职（`/onboard`），读取 Secretary 任务和 `design/hierarchy.md`。
- **2026-04-09 ~ 2026-04-11**：Architect 与项目主管进行多轮讨论，逐步确认新架构方向。
- **2026-04-11**：最终计划敲定并通过 plan mode 审批，进入实施阶段。

## 关键决策点及其理由

### 1. 为什么取消原层级化四机制

原 `design/hierarchy.md` 提出四机制（`org_chart.yaml` / `cc` field / `role_templates/` / `departments/` 子目录）作为渐进式启用的层级化方案。

**决策**：取消 A（org_chart.yaml）和部分 D（departments/ 作为独立子目录层），保留 B（cc field）和 C 的**思想**（重构为 role archetypes + custom subagents）。

**理由**：
- Claude Code 内置 Agent Teams 特性直接覆盖了"层级组织"需求——team 是 runtime spawn 的，静态 yaml 会立刻过时
- 原方案是"为完全没有 team 机制的 Claude Code 设计的 workaround"，现在不必要了
- 但 cc field 依然有用（跨 team 通讯场景），dept 子结构的**思路**保留（以 `_team` 后缀命名而不是单独目录层）

### 2. 为什么要"扁平 + team 混合"而不是全部 team 化

**讨论过**：是否把所有 agent 都升级为 team lead？

**决策**：**不**全部 team 化。Secretary、GitKeeper、Translator 等简单任务保持扁平。

**理由**：
- Team 每个 teammate 占一个独立 session，**token 消耗显著增加**
- 对于"协调类"、"单线任务"、"单文件修改"这类任务，单兵作战更高效
- 只有复杂任务（多种专业技能、并行工作流、对抗性调研）才值得 team 的协调开销
- 用户明确偏好：不要为了用 team 而用 team

### 3. 为什么 spawn-team 等管理 skill 改为 agent 可自主调用

**讨论过**：原设计 `/spawn-team` 是 `disable-model-invocation: true`，用户手动触发。

**决策**：改为 `disable-model-invocation: false`，agent 自主调用（用户自然语言同意后）。

**理由**：
- 用户反馈："人类用户应该用自然语言对话，不应该记命令"
- Team lead agent 最了解任务是否需要 team、需要什么角色、什么时机组建
- 对用户的理想体验：描述任务 → agent 提议组建 team → 用户同意 → agent 自主执行
- 对用户是**黑盒**：`/spawn-team`、`/promote-to-team`、`/schedule`（for tracker）等全由 agent 代办

**保留手动触发的 skill**：`/onboard`、`/sync`、`/check-inbox`、`/archive-resolved`。这些是项目主管在"检视项目状态"时会主动运行的，保持用户控制。

### 4. 为什么 tracker 走 `/schedule` 而不是 `/loop` + team lead 长会话

**讨论过**两种轮询机制：

#### Pattern A: `/loop` + team lead 长会话
- Team lead 挂 `/loop`，每隔一段时间自动检查进度和决策下一步
- **优点**：端到端全自动
- **缺点**：(1) Token 消耗极大；(2) lead 可能在错误方向上越走越远

#### Pattern B: `/schedule` + 定时 tracker
- Tracker 作为独立的 scheduled remote agent，每次触发启动 fresh session，读状态写报告，退出
- **优点**：成本低、会话无需常驻、现在就能落地
- **缺点**：不是端到端自动（用户下次回来时读报告 + 决策）

**决策**：Pattern B 作为主线落地；Pattern A 作为 "terminal form" 预留（`mode: autonomous` 字段）等将来高阶模型就绪再实现。

### 5. 为什么 `/onboard` 只运行一次不处理升级

**讨论过**：是否让 `/onboard` 同时处理首次入职和后续升级。

**决策**：`/onboard` 只在对话开始时运行一次；升级用专门的 `/promote-to-team`。

**理由**：
- `/onboard` 是对话建立时的一次性操作
- 升级是运行中的动态变更，需要保留原有工作历史（notes、TODO 等）
- 分两个 skill 职责更清晰

### 6. 为什么部门内部沟通叫 `roundtable` 而不是 `meeting_room`

**讨论过的候选**：`roundtable`、`huddle`、`war_room`、`workshop`、`briefing`、`squad_room`。

**决策**：`roundtable`。

**理由**：
- 和顶层 `meeting_room` 形成清晰层级对比（大房间 vs 圆桌小团）
- 中性好用、语义正面、可中英互译
- 用户最初就是这个提议

### 7. 为什么叫 `resources/` 而不是 `commons/` 或 `lib/`

**讨论过的候选**：`resources`、`commons`、`library`、`toolbox`、`depot`、`armory`。

**决策**：`resources`（暂定，将来可能调整）。

**理由**：
- 最直白，开发者一眼知道用途
- 没有特定技术栈关联
- 后续可以在 developer_manual 中注明"未来版本可能重命名"

### 8. 为什么 team 工位用 `_team` 后缀而不是 `departments/<name>/`

**讨论过**：是否把 team 工位全部放在 `departments/` 子目录下作为独立层。

**决策**：取消 `departments/` 层，所有工位（扁平和 team）在 `_agent_team_work_zone/` 下**同级**放置，用命名约定 `_team` 后缀区分。

**理由**：
- 减少目录深度
- 扁平和 team 一眼就能看到全部，不用切换目录
- 命名约定足以表达类型
- 升级路径简单：`mv architect architect_team && mkdir roundtable archive ...`

### 9. 为什么三层角色定义存储（Tier 1/2/3）

**讨论过**：用户担心两个 team 有同名角色（都有 eval-config-author）时命名冲突。

**决策**：三层策略：
- Tier 1 (默认)：inline 在 spawn prompt + `<team>/team_recipes/` 审计
- Tier 2 (偶尔)：`<team>/teammates/<role>.md` 存档，目录隔离无冲突
- Tier 3 (罕见)：`.claude/agents/<team>_<role>.md`，**必须带 team 前缀**避免冲突

**理由**：
- 默认 Tier 1 保持 `.claude/agents/` 干净，只有 5 个项目全局 subagent
- Tier 3 的 team 前缀规则完全消除冲突
- 层级递进，多数场景用 Tier 1 足够

### 10. 为什么角色原型不作为 subagent 定义

**讨论过**：是否把 "tracker"、"bash-scripter" 这类都做成 Claude Code 自动加载的 subagent。

**决策**：只有**精确界定**的角色做成 subagent（5 个：tracker, investigator, reviewer, devil-advocate, git-repo-manager）。"bash-scripter"、"coder" 这类**粒度不够**的做成**角色原型**模板（9 个）。

**理由**：
- 用户反馈："coder 这种命名太泛，写训练配置 vs 写 PyTorch vs 写 bash 需要完全不同的 system prompt"
- 角色原型作为**通用模板 + 任务级具体化**的两层模型：layer 1 是项目无关的职责描述，layer 2 是 team lead 在 spawn 时填入的项目细节
- 精确界定的 subagent（tracker、reviewer、investigator、devil-advocate）基本只做**只读 / 观察 / 批评**类工作，这些职责天然可以精确定义
- 实现层面的 coder 工作交给 team lead 按项目定制

### 11. 为什么 result-reporter 要专门产出 xlsx 表格

**讨论过**：result-reporter 的核心产出形态。

**决策**：专门强调 xlsx 表格 + 可视化图表。

**理由**：
- 用户反馈："汇报是给**人**看的，不是给 agent 看的，xlsx 表格是人类最高效吸收数据的方式"
- 特别是 eval 结果，"给人类主管一眼能看懂"
- 区分 data-analyzer（给 agent 看的事实提取）和 result-reporter（给人看的呈现）

### 12. 为什么 env-configurator 和 container-builder 有前后依赖

**讨论过**：infra 类角色的职责划分。

**决策**：两个独立角色，env-configurator **先**，container-builder **后**；container-builder **假设 env 已通**，遇到 pip 问题必须召回 env-configurator 而不是自己解决。

**理由**：
- 用户反馈："配环境的 agent 不应该负责写 SLURM 脚本，反而 SLURM 脚本更像 bash 脚本"——暗含 infra 角色的职责要清晰
- 进一步反馈："container-builder 专注于镜像本身，遇到 pip 问题应该召回 env-configurator"
- 前后依赖写进两个原型的顶部，避免 team lead 在 `/spawn-team` 时错配角色

### 13. 为什么保留 live `_agent_team_work_zone/` 并 gitignore 它

**讨论过**：是否把 live 工作区也纳入 git 跟踪。

**决策**：`_agent_team_work_zone/` 保留在 `.gitignore` 中，作为开发者的个人 dogfood 场，不作为模板发布。

**理由**：
- Live 工作区包含每个开发者的个人对话状态（notes、TODO、team_recipes 等），不适合共享
- 模板发布源在 `claude_code/zh/_agent_team_work_zone/`，clean 且可复制
- Live 的存在让 dev repo 自己也能用模板工作（dogfood），是一个特殊的约定

### 14. 为什么两级身份检查（context 优先，文件兜底）

**讨论过**：skill 如何知道当前 agent 的身份和模式。

**决策**：两级检查——先从对话 context 推断（零 I/O），失败才读文件（Glob + 对比）。

**理由**：
- 用户反馈："agent 通常已经知道自己是谁，不需要每次都读文件，会消耗 token"
- 但为了 robust，context 不可靠时（上下文被压缩过）需要文件兜底
- 两级策略同时满足常规效率和边界安全

### 15. 为什么 tracker 的默认 cron 是 12h / 4h 而不是 30 分钟

**讨论过的候选**：30 分钟（激进）vs 12 小时（保守）。

**决策**：training 12h，eval 4h（用户选择）。

**理由**：
- 用户反馈："30 分钟太频繁，我的 token 会被用爆"
- 12h/4h 足够抓住异常信号（训练几天 / eval 几小时的尺度）
- Team lead 可以按任务性质调整，但默认值以 token 预算为先

## 未决和推迟

### 推迟实现
- **Terminal form (Pattern A) 的 autonomous mode** — 等待更高阶模型 + 预算充裕
- **英文版** (`claude_code/en/_agent_team_work_zone/`) — zh 稳定后由 Translator 生成
- **ML-specific 角色原型** — 如 slurm-submitter、vllm-compat-specialist，待项目实际需要时增加

### 需要验证
- `bootstrap.sh` 在下游用户真实项目中的可用性（当前只在 dev repo 自己 dogfood 验证）
- `/spawn-team` emit 的 natural-language prompt 能否稳定被 Claude Code agent-team 机制识别
- Tracker 在 HPC SLURM 环境下实际运行的稳定性

## 参与者

- **项目主管** — 所有架构决策的最终决策者
- **Architect (team lead, 自己)** — 研究、提案、落地实施
- **Secretary** — 提出原 TASK，协调任务分发
- **SkillSmith** — 独立完成 `/handoff` skill（任务交接工具）的设计与实现
- 其他 agent 在本次重构中没有直接参与（部分将通过 `/sync` 被动同步到新架构）

---

## 后续记录（使用过程中的补丁）

### 2026-04-12: 首次 `/spawn-team` dogfood 与补丁

重构完成后进行了**首次真实 `/spawn-team` 端到端测试**——任务是把 `claude_code/zh/_agent_team_work_zone/` 翻译为 `claude_code/en/_agent_team_work_zone/`（35 个 markdown + 2 个 bash 脚本），用 4 人 agent team 并行完成。

**结果**：翻译成功，en 版本 bootstrap 可独立运行。但暴露出几个重要问题。

#### 发现 1: Rule #1 "低耦合" 不够具体，需补条款

**事件**：在 Phase 6 live 工作区重构时，Architect 代 Planner 执行了 `mv planner planner_team` + 新建 team 子目录 + 重写 README 为 team lead 版——**违反了 Planner 对其工位的所有权**。

**根因**：原 Rule #1 只说"不越界"，没明确"**不要修改其他 agent 的工位目录**"。`/promote-to-team` skill 虽然设计上只能由工位自己调用，但 rule 没说"不准绕过 skill 手动做同样的事"。

**补丁**（本次补）：Rule #1 扩展为 5 条子规则：
- 工位归属（不改别人的工位）
- Team 边界（不改别人 team 的 roundtable）
- 升级和迁移（只能自己 `/promote-to-team`）
- 帮忙也不行（通过 TASK 派发，不直接动手）
- 违反代价（被动方在 /sync 时发现工位被改却不知谁动了）

改动范围：`claude_code/zh/_agent_team_work_zone/README.md` + `claude_code/en/_agent_team_work_zone/README.md` 的 rule 1。

#### 发现 2: `run_in_background: true` + 会话中断 = agent 死掉

**事件**：首次 spawn 4 个 translator 时用了 `run_in_background: true`（期待并行跑、lead 干别的）。结果父会话中断后，4 个 agent 全部被杀，它们的临时 output 文件被清理，已写出的文件为零。

**根因**：Claude Code 后台 agent 是父会话的子任务，父会话中断时它们也死。

**教训**：
- 对于"我必须等结果才能继续"的工作（翻译就是），用**前台并行**——多个 Agent 调用放同一条消息，它们并行执行，父一直阻塞到所有都完成
- 后台模式更适合"启动后我去干别的事"，且要考虑会话中断风险

**补丁**：暂不改 skill 文档（这是 Claude Code 的通用行为，不是项目特定）。但在新建的 `notes/` field notes 里永久记录此经验。

#### 发现 3: `/spawn-team` 的 Phase 6a prompt 模板对 Unicode 符号没提示

**事件**：Translator-Mech（sonnet）在翻译 bash 脚本时，把 echo 字符串里的 `✓`/`✗`/`⚠`/`↻` 替换成了 ASCII 的 `OK`/`x`/`!`/`~`——因为它误把这些当作"emoji"，按通用 "don't use emoji" 规则清除了。但这些是脚本用户体验的一部分，zh 源里有的。

**根因**：spawn prompt 没有明确说"代码字符串里的 unicode 符号保留不动"。Agent 的默认习惯压过了项目特定需求。

**教训**：Team lead 在 `/spawn-team` 时给 translator 类 teammate 的 prompt，要**显式说**："unicode 符号（如 ✓/✗/⚠）在代码字符串里属于功能字符，不是装饰 emoji，原样保留。"

**补丁**：未来给翻译任务写 spawn prompt 时记得加这一条。但不改 `/spawn-team` skill 本体（翻译是众多任务类型之一，skill 不应该堆砌每种任务的专门规则）。

#### 发现 4: ~~Agent 工具 schema 没有 `team_name` 参数~~ **【2026-04-16 勘误】**

> **⚠ 此条结论已被证伪。** 详见 [`error_reports/2026-04-16_subagent_vs_teammate_confusion.md`](../../../error_reports/2026-04-16_subagent_vs_teammate_confusion.md)
>
> **真相**：Agent 工具的显示 schema 虽然没列出 `team_name` 和 `name`，但 **runtime 实际接受**这两个参数。**原问题是我误读 schema，而不是 Claude Code 的 bug**。2026-04-12 翻译任务中所谓的 4 个 translator "teammate" 实际是 subagent——我从未真正启动过 team。
>
> 2026-04-16 用 test-teammate 重新验证，确认：传入 `team_name` + `name` 后 runtime 成功 spawn 真 teammate、加入 team config members 数组、SendMessage 按 name 路由到 mailbox、响应格式是 `<teammate-message>` 不是 subagent `<task-notification>`。
>
> **2026-04-12 的翻译产出仍然有效**（subagent 能完成的机械工作没问题），但所谓"首次真 team dogfood"的描述不准确——真正的 team dogfood 推迟到后续 TODO #16 执行。

#### 发现 5: `/spawn-team` 的 Phase 3 阵容提案应鼓励"何时跳过 teammate 通讯"

**事件**：本次翻译任务 teammate 之间**没有通讯**——因为 lead 判断是独立并行任务，给每个 teammate 的 prompt 都是"各自跑自己的批次，不用沟通"。结果是对的，但也暴露出 Phase 3 没有显式引导 lead 考虑"是否需要 teammate 间通讯"。

**补丁**（可选）：以后如果在 `/spawn-team` Phase 3 加一个子 step "通讯模式决定：全独立 / 部分依赖 / 紧密协作"，更好。本次不做，记在 notes 里等下次用到时再迭代。

#### 发现 6: Agent tool subagent 是一次性的，不留历史

**事件**：4 个 translator 完成后自动释放，对话历史不保存，`architect_team/teammates/` 目录还是空的。

**澄清**：这是**预期行为**——`architect_team/teammates/` 是 Tier 2 **自定义角色模板**存放地，不是 runtime teammate session 的坟场。一次性 translator 不属于 Tier 2。**审计证据在 `team_recipes/`**——那里有 `20260412_0105_translate_en_team_template.md` 完整记录了阵容。

**教训**：文档里 Tier 1/2/3 分层说得对，但用户初次使用可能会误期望 `teammates/` 里能看到本次 team 的成员。需要在 user_manual 里更明确地澄清。

**补丁**（延后）：后续版本在 user_manual 里加一段"team 完成后会发生什么 & 去哪找 team 的历史证据"。本次不做。

---

### 小结

首次 dogfood 暴露了 1 个必须立即修的规则漏洞（rule #1 补条款），3 个需要长期跟踪的经验（background agent、unicode、team_name schema），2 个可选的未来优化。**核心架构没问题**——翻译任务圆满完成，35 个文件并行产出，en 版 bootstrap 可独立跑。
