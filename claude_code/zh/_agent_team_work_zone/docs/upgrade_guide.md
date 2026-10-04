# 升级指南

本指南说明如何把已安装在项目中的 `_agent_team_work_zone/` 升级到 `agent-team-work-zone` repo 的新版本。

> **快速版**：在你的项目根目录下跑 `bash _agent_team_work_zone/upgrade.sh`——一条命令搞定。
> 详细说明见下文。

## 检查当前版本

```bash
cat _agent_team_work_zone/VERSION
```

版本号遵循语义化规则 `vMAJOR.MINOR.PATCH`：

- **MAJOR (X)**：破坏性变更，或安装与升级方式的重大变化（升级时会要求确认）
- **MINOR (Y)**：新增功能（新 skill / agent / hook），向后兼容
- **PATCH (Z)**：文档修订、bug 修复，完全向后兼容

升级前对照 `CHANGELOG.md` 了解本次改动范围。

## 框架文件所有权清单

升级时，以下文件属于**框架所有**（由升级脚本自动覆盖）：

```
_agent_team_work_zone/
├── upgrade.sh                 ← 框架所有（一键脚本入口）
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

**例外：守则区。** `<!-- RULES:START --> … <!-- RULES:END -->` 是嵌在用户区内的**第二个框架管理子块**（v0.3.2 起）：升级时会与新模板**比对**，仅在内容有差异时先把旧块备份为 `README.md.rules.bak.<时间戳>` 再替换；块外其它用户内容（成员表、自定义章节）仍然一律不碰。若你的 README 还没有这对标记，迁移会按守则区标题自动定位并注入（找不到则跳过）：START 放在标题前；END 不是放在下一个 `## ` 标题前，而是放在**该标题下最后一行框架守则原文之后**（逐行比对新模板）；若守则区有编号小节（`### N.`），END 再延伸到**最后一条编号守则的末尾**——遇到下一个不带编号的 `### ` 标题、`---`/`***`/`___` 分隔线或 `<!--` 为止，这样手抄时被改写过措辞的守则也会随旧块进 `.rules.bak`，不会与新守则并存。**要让你的笔记留在块外，请用 `---`（或 `***`、`___`）或一个不带编号的 `##`/`###` 标题把它和守则隔开**（`####` 子标题、以及带编号的 `### N.` 标题不算分隔——它们会被视为最后一条守则的一部分、并进块，打 ⚠ 并随旧块进 `.rules.bak`）：这样它原样保留，迁移会打印 `⚠ … kept outside the managed block` 提示行数；紧贴在最后一条守则后面、中间没有上述分隔的文字会被并进块、随旧块进 `.rules.bak`（可恢复），迁移会打印 `⚠ … taken into the managed block` 提示行数。另两点须知：① 你夹在守则**中间**插入的内容会被划进块内，刷新时随旧块进 `.rules.bak`；② 仍留在块外的行既可能是你的内容，也可能是认不出的旧框架文字，请按提示核对。标题下若没有任何一行与模板守则相同（例如你自写的 `## Work Rules for my team`），视为你自己的章节，跳过不动。

**teammate 工位的精简守则块** `<!-- TEAMMATE_RULES:START --> … <!-- TEAMMATE_RULES:END -->` 同样处理：有差异时先把旧块备份为 `README.md.teammate_rules.bak.<时间戳>` 再替换。顶层 README 的 `<!-- REFERENCE:START --> … <!-- REFERENCE:END -->`（预置 Skills 至 Troubleshooting）是纯框架内容，每次升级直接覆盖、不备份；自愈注入标记时 END 同样只落在框架原文最后一行之后，你追加在 Troubleshooting 之后的内容留在块外。上述 `.bak` 文件写在对应 README 旁边，升级不会自动清理，核对后可自行删除。

## 如何升级

### 推荐方式：一键脚本

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

### 用 npm

框架也以 npm 包 `agent-team-work-zone` 发布（需要 Node.js 18 或更高版本和 `bash`；不支持原生 Windows）。用 `npx agent-team-work-zone <命令>` 运行；或者用 `npm i -g agent-team-work-zone` 装一次，之后用短名 `atwz <命令>`：

```bash
npx agent-team-work-zone init [项目目录] --lang zh   # 新项目：铺好 _agent_team_work_zone/ 并运行 bootstrap
npx agent-team-work-zone upgrade [项目目录]          # 已有安装：升级到包里自带的版本
npx agent-team-work-zone reconfigure [项目目录]      # 已有安装：重新询问安装时的问题
npx agent-team-work-zone --version                   # 包版本及其自带的框架版本
```

`[项目目录]` 是项目根目录；省略时用当前目录，支持 `~` 和相对路径，目录必须已经存在。

偶尔用一次就用 `npx agent-team-work-zone <命令>`；常用的话用 `npm i -g agent-team-work-zone` 装一次，之后也可以用短命令 `atwz <命令>`。

`upgrade` 使用包内自带的模板（不联网下载），然后跑与一键脚本相同的迁移链和 `bootstrap.sh`。它从 `_agent_team_work_zone/upgrade.sh` 判断安装的语言；判断不出来时，在终端里会让你选择，没有终端时会停下并要求加 `--lang zh|en`。当前目录已有 `_agent_team_work_zone/` 时 `init` 会拒绝运行。

升级不会询问安装时的问题（可选 `CLAUDE.md` 段落、git 纳入、teammate 显示模式、auto 权限模式），沿用你现有的选择。要修改，请运行 `npx agent-team-work-zone reconfigure`（源码安装：`bash _agent_team_work_zone/resources/scripts/bootstrap.sh --reconfigure`）。它以重新设置模式再次运行已安装的 `bootstrap.sh`——不重装、不下载、不升级——也不改动 `_agent_team_work_zone/` 里的任何内容。这个命令出现之前的安装需要先升级：对更老的安装，`npx agent-team-work-zone reconfigure` 会拒绝并说明原因，而源码命令 `bootstrap.sh --reconfigure` 会悄悄忽略这个选项，只按普通方式重跑一遍设置、不提任何问题。

### 从本地目录升级

`bash _agent_team_work_zone/upgrade.sh` 也可以不下载，直接使用一个已解开的新版模板目录：

```bash
UPGRADE_SOURCE_DIR=/path/to/claude_code/zh/_agent_team_work_zone bash _agent_team_work_zone/upgrade.sh
```

### 主版本升级

升级跨过主版本（例如 v1.x → v2.x）时，调度脚本会先打印这一版改了什么，再请你确认（默认 No）：

- 升级会覆盖框架文件（`resources/`、`docs/`、`README.md` 的框架段、`CHANGELOG.md`、`upgrade.sh`）。你在工位和 `meeting_room/` 里写的内容、注册表（`TEAMMATE_INFO.json`）、`settings.conf` 不受影响；各 README 里由框架维护的守则段会被刷新（旧块有备份）；`.claude/settings.json` 会重新合并：框架在 `SessionStart`、`TeammateIdle`、`SessionEnd` 上的 hook 会替换你在这三个事件上的 hook（你有自己的 hook 时，会先把 `settings.json` 备份为 `settings.json.bak.<时间戳>`）。
- **升级本身不做备份。** 升级前先把 `_agent_team_work_zone/` 提交到 git，需要时就能回滚（见"如何回滚"）。
- 没有终端时升级会被取消（退出码 3），除非你用 `ATWZ_ASSUME_YES=1` 确认（npm 方式：`upgrade --yes`）。

### 升级之后

升级完成后请重启 Claude Code 会话，并对正在运行的团队执行 `/reactivate-team`——已在运行的会话和成员可能仍在用旧版 skill。

### 新版本提示

每次 Claude Code 会话开始时，`resources/scripts/check_update.sh`（由 `bootstrap.sh` 安装的 SessionStart hook）会把已安装的 `VERSION` 与 npm 包 `agent-team-work-zone` 的最新版本比较，落后时打印一段简短提示。它只提示，从不自动升级。它最多 24 小时联网查一次，而且在后台进行，会话启动不用等它；结果缓存在 `_agent_team_work_zone/.upgrade/update_check`。没有网络或没有 `curl` 时保持静默。关闭方法：设置 `ATWZ_UPDATE_CHECK=0`，或创建文件 `_agent_team_work_zone/.no_update_check`（把它提交进仓库，就对项目里所有人关闭）。

### Fork 用户

如果你跑的是 `agent-team-work-zone` 的 fork，可以通过环境变量覆盖下载来源：

```bash
export UPGRADE_REPO_URL="https://github.com/<your-fork>/agent-team-work-zone/archive/refs/heads/main.tar.gz"
bash _agent_team_work_zone/upgrade.sh
```

### 旧 4 步流程（已废弃但仍可用）

**手动 4 步流程不推荐**。但 `resources/scripts/upgrade.sh`（migration chain dispatcher）继续保留，新一键脚本只是它的自动化包装层。如果你出于调试或定制需求需要手动跑：

```bash
# 1. 在本地 clone 一份 agent-team-work-zone repo
git clone https://github.com/SR-A-W/agent-team-work-zone.git /tmp/agent-team-work-zone

# 2. 把模板内容 cp 到你项目的 .upgrade/ 暂存区
cp -r /tmp/agent-team-work-zone/claude_code/zh/_agent_team_work_zone/. \
      _agent_team_work_zone/.upgrade/

# 3. 跑 dispatcher（和一键脚本调用的是同一个 dispatcher）
bash _agent_team_work_zone/.upgrade/resources/scripts/upgrade.sh

# 4. 暂存区会被 dispatcher 自动清理（保留 .upgrade/README.md）
```

普通用户不再需要走这条路径——一键脚本完全等价。

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

历史发布有 annotated git tag（v0.1.0 起），可以用 `git checkout v0.2.0` 跳到那个发布点查看当时的内容。

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

