# Changelog — agent-team-work-zone（中文 Team 版）

所有重要变更都记录在此文件。格式遵循 [Keep a Changelog](https://keepachangelog.com/)，版本号遵循语义化版本 `vMAJOR.MINOR.PATCH`。

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
