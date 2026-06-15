# 升级指南

本指南说明如何把已安装在项目中的 `_agent_team_work_zone/` 升级到 `agent-work-zone` repo 的新版本。

> **快速版**：在你的项目根目录下跑 `bash _agent_team_work_zone/upgrade.sh`——一条命令搞定。
> 详细说明见下文。

## 检查当前版本

```bash
cat _agent_team_work_zone/VERSION
```

版本号遵循语义化规则 `vMAJOR.MINOR.PATCH`：

- **MAJOR (X)**：破坏性架构变更
- **MINOR (Y)**：新增功能（新 skill / agent / hook），向后兼容
- **PATCH (Z)**：文档修订、bug 修复，完全向后兼容

升级前对照 `CHANGELOG.md` 了解本次改动范围。详细的版本管理约定见 `VERSIONING.md`。

## 框架文件所有权清单

升级时，以下文件属于**框架所有**（由升级脚本自动覆盖）：

```
_agent_team_work_zone/
├── upgrade.sh                 ← 框架所有（v0.5.0 起的一键脚本入口）
├── VERSION                    ← 框架所有
├── CHANGELOG.md               ← 框架所有
├── README.md                  ← 部分更新（仅 FRAMEWORK:START~END 之间）
├── meeting_room/
│   └── README.md              ← 框架所有
├── docs/                      ← 框架所有，整目录覆盖
└── resources/                 ← 框架所有，整目录覆盖
    ├── skills/
    ├── agents/
    ├── role_archetypes/
    ├── scripts/
    ├── hooks/
    └── settings_hooks_template.json
```

以下文件属于**用户所有**（升级脚本严禁触碰）：

```
_agent_team_work_zone/
├── meeting_room/
│   └── *.md（除 README.md 外）  ← 用户消息
├── archive/                     ← 归档消息
├── <任何工位目录>/                ← 所有工位（flat 或 _team）
│   例如 secretary/、architect_team/ 等
│   含其中的 TEAMMATE_INFO.json、teammates/、roundtable/、team_recipes/
└── README.md 的"项目组成员"段     ← 用户维护的成员表（FRAMEWORK:END 之后）
```

### README.md 的特殊处理

`README.md` 同时包含框架内容（守则、skill 列表等）和用户内容（项目组成员表）。框架内容用 HTML 注释标记划定边界：

```
<!-- FRAMEWORK:START -->
（框架内容，升级脚本自动替换）
<!-- FRAMEWORK:END -->

## 项目组成员
（用户内容，升级脚本严禁触碰）
```

升级脚本只替换 `FRAMEWORK:START` 到 `FRAMEWORK:END` 之间的内容，成员表及之后的内容完全保留。如果你的 `README.md` 因故丢失了这两个标记，升级脚本会打印警告并**跳过** README 替换。

## 如何升级

### 推荐方式（v0.5.0 起）：一键脚本

在你的项目根目录（含 `_agent_team_work_zone/` 那一级）跑：

```bash
bash _agent_team_work_zone/upgrade.sh
```

脚本会：
1. 从 GitHub 下载最新 main 分支的 framework tarball 到临时目录
2. 解压、把模板拷到 `_agent_team_work_zone/.upgrade/` 暂存区
3. 调用 migration chain dispatcher 跑所有需要的迁移脚本（增量升级，链路可断点续跑）
4. 自动重跑 `bootstrap.sh`，刷新 `.claude/skills` / `.claude/agents` / `.claude/settings.json` 的 hooks
5. 清理暂存区（保留 `.upgrade/README.md` 作为目录占位）

**全程无参数、无配置文件、无残留。** 失败时退出非零并保留暂存区供调试，临时下载目录由 EXIT trap 自动清理。

### Fork 用户

如果你跑的是 `agent-work-zone` 的 fork，可以通过环境变量覆盖下载来源：

```bash
export UPGRADE_REPO_URL="https://github.com/<your-fork>/agent-work-zone/archive/refs/heads/main.tar.gz"
bash _agent_team_work_zone/upgrade.sh
```

### 旧 4 步流程（已废弃但仍可用）

v0.5.0 起，**手动 4 步流程不再推荐**。但 `resources/scripts/upgrade.sh`（migration chain dispatcher）继续保留，新一键脚本只是它的自动化包装层。如果你出于调试或定制需求需要手动跑：

```bash
# 1. 在本地 clone 一份 agent-work-zone repo
git clone https://github.com/SR-A-W/agent-work-zone.git /tmp/agent-work-zone

# 2. 把模板内容 cp 到你项目的 .upgrade/ 暂存区
cp -r /tmp/agent-work-zone/claude_code/zh/_agent_team_work_zone/. \
      _agent_team_work_zone/.upgrade/

# 3. 跑 dispatcher（和一键脚本调用的是同一个 dispatcher）
bash _agent_team_work_zone/.upgrade/resources/scripts/upgrade.sh

# 4. 暂存区会被 dispatcher 自动清理（保留 .upgrade/README.md）
```

普通用户不再需要走这条路径——一键脚本完全等价。

### 给 v0.5.0 之前版本（v0.0.0 .. v0.4.0）的存量用户

新一键脚本 `_agent_team_work_zone/upgrade.sh` 是 v0.5.0 才引入的。如果你的项目在 v0.5.0 之前，得先用旧 4 步流程升到 v0.4.0+ 再用新法。或者直接对照本文档"旧 4 步流程"段一次跑通到 latest：dispatcher 会自动识别当前版本并跑链上所有的 migration。

升级到 v0.5.0+ 之后，后续就只需要 `bash _agent_team_work_zone/upgrade.sh` 一条命令。

## 如何回滚

升级本质上是文件覆盖。如需回滚，通过 Git 恢复：

```bash
cd /path/to/your/project
git diff _agent_team_work_zone/                              # 查看升级改动了什么
git checkout HEAD -- _agent_team_work_zone/resources/        # 回滚 resources/
git checkout HEAD -- _agent_team_work_zone/docs/             # 回滚 docs/
git checkout HEAD -- _agent_team_work_zone/README.md         # 回滚 README 框架段
git checkout HEAD -- _agent_team_work_zone/VERSION _agent_team_work_zone/CHANGELOG.md
# 或者整体回滚（连同你自己改的内容，慎用）：
git checkout HEAD -- _agent_team_work_zone/
```

回滚后，如果 `.claude/settings.json` 中的 hooks 需要同步回旧版本，重跑旧版 `bootstrap.sh` 即可。

历史发布有 annotated git tag（v0.1.0 起），可以用 `git checkout v0.4.0` 跳到那个发布点查看当时的内容。

## 升级失败的常见处理

| 现象 | 原因 | 处理 |
|---|---|---|
| `curl: (6) Could not resolve host github.com` | 网络问题 | 检查网络后重跑 |
| `✗ Extracted archive does not contain expected VERSION file.` | tarball 损坏或 URL 不对 | 检查 GitHub repo URL，重跑 |
| `dispatcher` 中途 fail | migration 脚本错误 | 暂存区已保留，可手动调试或 git 恢复后重跑 |
| `bootstrap.sh exited non-zero` | `.claude/` 同步失败 | 跟随错误提示手动重跑 bootstrap |
| `## v0.X.Y` 已经在 VERSION 文件里 | 已是最新 | 退出，无操作 |

## CHANGELOG 格式说明

每个版本发布都在 `CHANGELOG.md` 顶部新增 `## vX.Y.Z (YYYY-MM-DD)` 章节：

```markdown
## vX.Y.Z (YYYY-MM-DD)

发布一句话总结。

### 修复 / 变更 / 新增 / 文档
- ...

### Migration (vPREV → vX.Y.Z)
**必做**：（升级时你需要做的）
**行为变更须知**：（向后兼容但要知晓的）
```

完整的版本管理 / Release commit / git tag / migration 脚本约定见 `VERSIONING.md`。
