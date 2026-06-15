# Changelog — agent-team-work-zone（中文 Team 版）

所有重要变更都记录在此文件。格式遵循 [Keep a Changelog](https://keepachangelog.com/)，版本号遵循语义化版本 `vMAJOR.MINOR.PATCH`。

详细的版本管理 / Release commit / git tag / migration 脚本约定见 `docs/VERSIONING.md`。

---

## v0.1.0 (2026-06-12)

**首次公开发布**。基于内部开发版（`agent-team-work-zone-dev`）的 v0.5.0 切片。

### 内容

- 完整的多 agent 协作框架（基于文件、12 条工作守则、扁平 + team 混合架构）
- Skills、subagents、hooks、role archetypes、bootstrap 工具链
- 一键 `upgrade.sh` 升级（从 GitHub main 拉 latest）
- 友好 `install.sh` 首次安装入口
- `resources/scripts/release.sh` 发布纪律工具

### 备注

- 本 release repo 的版本号独立于内部 dev 版（dev v0.5.0 = release v0.1.0）
- 完整开发历史见 `github.com/SR-A-W/agent-team-work-zone-dev`
