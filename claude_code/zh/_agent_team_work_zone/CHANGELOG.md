# Changelog — agent-team-work-zone（中文 Team 版）

所有重要变更都记录在此文件。格式遵循 [Keep a Changelog](https://keepachangelog.com/)，版本号遵循语义化版本 `vMAJOR.MINOR.PATCH`。

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
