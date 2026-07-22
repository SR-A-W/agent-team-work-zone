# Changelog — agent-team-work-zone（中文 Team 版）

所有重要变更都记录在此文件。格式遵循 [Keep a Changelog](https://keepachangelog.com/)，版本号遵循语义化版本 `vMAJOR.MINOR.PATCH`。

---

## v0.3.2 (2026-07-21)

PATCH（Bug 修复，完全向后兼容）：**工作守则 + 五节框架参考资料现能随升级实际刷新到存量安装，teammate 精简守则改为自愈替换（消除双套并存）**。

### 修复
- **守则随升级刷新**：此前"工作守则"章节在 README 的 `FRAMEWORK:START/END` 标记之外，任何一次 `upgrade.sh` 升级都刷不到它——存量安装的守则永久停留在初装版本。新增独立的 `<!-- RULES:START/END -->` 标记 + `common.sh` 三个新函数：`replace_marked_section`（通用 marker 区块替换器）、`ensure_rules_markers`（存量自愈：条数不敏感、双语标题都认，缺标记时自动定位守则区并注入）、`refresh_rules_section`（编排：自愈 → 与源比对 → 仅在有实质差异时先备份旧块再替换）。迁移脚本现在会遍历**所有工位 README**（扁平工位 + `<team>_team/` lead 工位），按需刷新守则区。
- **参考资料随升级刷新**：README 里"预置 Skills / 通用 Custom Subagents / 角色原型速查 / 团队创建的角色定义存储 / Troubleshooting"这五节此前也在标记之外——装机后**永不更新**，用户查到的命令/技能表可能早已过时。新增 `<!-- REFERENCE:START/END -->` 标记 + `common.sh` 两个新函数：`ensure_reference_markers`（存量自愈：按"预置 Skills"标题定位，注入标记，止于文件末——五节合计一个区块）、`refresh_reference_section`（编排：自愈 → **直接覆盖**，不比对不备份，因为这五节是纯框架内容，没有可保留的用户定制）。迁移脚本对顶层 README 新增一次调用；工位 README 从不含这五节，不进工位遍历。
- **README 守则区开头句改写**：原"每个 agent 必须将以下守则完整复制到自己工位的 README"与新的非对称分发机制矛盾（teammate 实际带的是精简子集，不是全套）。改为"本守则由框架维护，随升级刷新；扁平工位与 team lead 带全套（就地刷新），teammate 带精简子集（`resources/teammate_rules.md`，由 `/spawn-team` 写入）；请勿手改本区块——改动会在下次升级被覆盖，要定制请改标记块之外的用户区"。

### 新增
- **teammate 精简守则分发 + 自愈替换**：新增 `resources/teammate_rules.md`（7 条摘录，`<!-- TEAMMATE_RULES:START/END -->` 标记包裹，内容独立于 13 条完整守则）。`/spawn-team` 建 teammate 工位骨架时即写入该文件内容；`/spawn-team` 与 `/reactivate-team` 的 spawn prompt 都新增一句自愈指令——若 teammate 的 README 里还留着旧的完整守则区（标题匹配"工作守则"且不在 `TEAMMATE_RULES` 标记内），**用精简块替换掉它**（消除新旧两套并存）；若没有旧守则区、也没有 `TEAMMATE_RULES` 块，则追加。迁移脚本对已有 `TEAMMATE_RULES` 区块的 teammate README 按差异刷新（无备份）；尚无该区块的存量 teammate 工位，迁移不动它，留给下次 spawn/reactivate 时自然补齐。
- **teammate 守则补充两条**：第 1 条补充"同侪间的交流协作（提问/共享/质疑/互助）鼓励且是 team 的核心价值，但正式任务分配与优先级是 lead 的协调职责"；第 7 条补充"你发的、各接收方都已 RESOLVED 的报告，由你自行归档"。

### Migration（v0.3.1 → v0.3.2）
- **必做**：`bash _agent_team_work_zone/upgrade.sh` 自动覆盖框架文件 + 刷新守则区 + 刷新参考资料区 + 写 VERSION。
- **无用户数据迁移**：`TEAMMATE_INFO.json` `schema_version` 仍为 1，无字段改名。完全向后兼容。
- **存量 teammate 工位**：若已有 `TEAMMATE_RULES` 区块且内容有差异，会被自动刷新；若尚无该区块（含仍留着旧完整守则区的情形），迁移不动它——下次该 teammate 被 spawn/reactivate 时，由 teammate 自己按自愈指令替换或追加。

---

## v0.3.1 (2026-06-22)

PATCH（Bug 修复 + 体验改进，完全向后兼容）。

### 修复
- **`bootstrap.sh` §6/§7 设置写入目标修正**：显示模式（`teammateMode`）和权限模式（`permissions.defaultMode:"auto"`）现恒写入**全局 `~/.claude/settings.json`**。此前默认写项目级 `.claude/settings.json`——但 `permissions.defaultMode` 项目级被 Claude Code 明确忽略（只有全局生效），`teammateMode` 亦为用户级设置，项目级无效。

### 改进
- **`bootstrap.sh` §6 重做为"显示模式选择"**：新增可启用分面板（`auto`）的选项（此前仅能切 `in-process` 隐藏面板）；更新过期文案（CC v2.1.179 起默认 `in-process`）；默认高亮"不修改"（第 3 项）。

### 体验
- **`bootstrap.sh` §6/§7 + `upgrade.sh` 主版本确认门**改为上下箭头选择菜单（新增可复用 `choose_option` 函数），取代原 `y/n` 文字输入。

### 文档
- 更正 `reactivate-team/SKILL.md` 和 `spawn-team/SKILL.md` 的 `teammateMode` 取值表：`in-process` 为默认（自 CC v2.1.179）；新增 `tmux` 和 `iterm2`（CC v2.1.186+）；移除非法值 `split-pane`；补充用户级/单会话覆盖说明。

### Migration（v0.3.0 → v0.3.1）
- **必做**：`bash _agent_team_work_zone/upgrade.sh` 自动覆盖框架文件 + 写 VERSION。
- **无用户数据迁移**：`TEAMMATE_INFO.json` `schema_version` 仍为 1，无字段改名。完全向后兼容。
- **建议升级后**：重新运行 `bootstrap.sh`，重选显示模式 / 权限模式（此前在项目级设置的偏好对 CC 无效，需在全局重设）。

---

## v0.3.0 (2026-06-22)

MINOR（新增功能，向后兼容）：**新增 `CLAUDE.md`（always-loaded 操作指令）**。无破坏性变更。

### 新增
- **`CLAUDE.md`**：面向「使用本框架的项目」的常驻操作指令——含操作层精华原则（文件优先、管好自己的文件、判活、checkpoint、lead 协调/teammate 实现、teammate 信号判读）+ **Coding Engineering Principles**（在 MIT License 下逐字引用 [multica-ai/andrej-karpathy-skills](https://github.com/multica-ai/andrej-karpathy-skills)，基于 Andrej Karpathy 对 LLM 编码陷阱的观察，见仓库根 README 致谢）。
- **bootstrap 装 CLAUDE.md 进项目根**：无 CLAUDE.md 则创建；已有则把上述两节追加（不覆盖你的内容），幂等。

### Migration（v0.2.0 → v0.3.0）
- **必做**：`bash _agent_team_work_zone/upgrade.sh` 自动从 v0.2.0 升到 v0.3.0，并在重跑 bootstrap 时把 CLAUDE.md 装进项目根。
- **无用户数据迁移**：`TEAMMATE_INFO.json` `schema_version` 仍为 1。向后兼容。

### 备注
- zh + en 双语对称。

---

## v0.2.0 (2026-06-20)

适配 **Claude Code 2.1.178** 的 agent-teams API。**要求 Claude Code ≥ 2.1.178。** 本版无新增功能——是必要的 Claude Code 适配。

### 适配 2.1.178 API 变更
- **`/reactivate-team` 删除 Step 0**：`TeamCreate`/`TeamDelete` 工具已被 2.1.178 移除。每个 session 自动创建唯一会话级 team（`session-<id>`）、teammate 退出自动清理、磁盘不再累积 ghost——reactivate 直接 `Agent(...)` 重 spawn 即可。
- **`Agent(...)` spawn 调整**：不再传 `team_name`（已被忽略）；**不设 `mode`**——teammate 权限模式无法在 spawn 时单设，**继承 lead 当时的模式**。要 teammate 起手即 auto，设 `permissions.defaultMode:"auto"` 或先把 lead 切 auto；`bootstrap.sh` 新增交互询问（默认开、强烈推荐）。
- **idle hook 三级工位定址**（`teammate_idle_checkpoint.sh`）：T1 payload team_name（旧版兼容）→ T2 由 name 派生 `${name%%-*}_team`（主路径）→ T3 glob 兜底（命中 >1 → exit 0 不猜）。根治跨 team 同名 teammate 误判。
- **`<slug>-<role>` 命名约定**：新 teammate 名须为 `<slug>-<role>`（slug = 工位名去 `_team`、单 token 无连字符），使 hook 能从 name 反推工位。存量旧名靠 T3 兜底，不强制改名。
- **bootstrap CC 下限**抬到 `2.1.178`，不达标硬退出。

### Migration（v0.1.0 → v0.2.0）
- **必做**：`bash _agent_team_work_zone/upgrade.sh` 自动从 v0.1.0 升到 v0.2.0（覆盖框架文件 + 写 VERSION + 打印破坏性告知）。
- **无用户数据迁移**：`TEAMMATE_INFO.json` `schema_version` 仍为 1、无字段改名。
- **升级前确认 Claude Code ≥ 2.1.178**。CC ≤ 2.1.177 请留在 v0.1.0。

### 备注
- zh + en 双语对称。
- 本版为 **team-only**：会话级 team 由 Claude Code 自动建/清。

---

## v0.1.0 (2026-06-12)

**首次公开发布**——完整的多 agent 协作框架。

### 内容

- 完整的多 agent 协作框架（基于文件、12 条工作守则、扁平 + team 混合架构）
- Skills、subagents、hooks、role archetypes、bootstrap 工具链
- 一键 `upgrade.sh` 升级（从 GitHub main 拉 latest）
- 友好 `install.sh` 首次安装入口
