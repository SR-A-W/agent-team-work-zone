# 版本与发布约定（VERSIONING）

本文档规定 `_agent_team_work_zone` 框架的版本号规则、发布流程和发布工件（commit、tag、CHANGELOG、migration 脚本）的格式约定。

> **本文档面向**：框架维护者（决定何时 bump 版本、写 release）。普通用户只看 `upgrade_guide.md` 即可。

## 1. SemVer 规则（v0.x 阶段）

版本号格式：`vMAJOR.MINOR.PATCH`，例如 `v0.4.0`、`v0.5.0`、`v0.5.1`。

### MAJOR（X）— 破坏性架构变更

- 工位/目录结构的破坏性重命名（例如 v0.3.0 时 `_agent_work_zone/` → `_agent_team_work_zone/`）
- skill 接口的破坏性变更（移除 skill、改 skill 必填参数）
- `TEAMMATE_INFO.json` schema 的破坏性变更（删字段、改字段语义）
- migration 脚本机制本身的不兼容变更（如 dispatcher 入参变了）

**v0.x 阶段宽松条款**：v0.x 之间允许 MINOR 级别 bump 来携带"可控的破坏性变更"——只要：
- migration 脚本能自动处理 / 自动迁移用户数据
- CHANGELOG 的 Migration 段落明确告知行为变更

v1.0.0 之后这个宽松条款失效，任何破坏性变更必须 MAJOR。

### MINOR（Y）— 新增功能 / 可控破坏性变更

- 新增 skill / agent / hook / role archetype
- 现有 skill 加可选参数
- 新增文档章节
- v0.x 阶段：可控的、有 migration 脚本兜底的破坏性变更（例如重命名某个工位目录）

### PATCH（Z）— 修复 / 文档 / 微调

- bug 修复
- 文档措辞调整
- 规则文本微调（不改语义）
- 风格 polish（OK→✓、加注释日期等）

### 决策快速参考

| 看到这个改动 | 该 bump 哪档 |
|---|---|
| 加了一个新 skill | MINOR |
| 改了某个 skill 的必填参数 | MAJOR |
| 改了某个 skill 的措辞，行为没变 | PATCH |
| 加了一个 hook | MINOR |
| 重命名了一个目录（带 migration 脚本）| v0.x 时 MINOR，v1.0.0 后 MAJOR |
| 修复了一个 bug | PATCH |
| 给 README 加一段说明 | PATCH |
| 引入新的 `_agent_team_work_zone/<新顶层文件>` | MINOR |

---

## 2. Release commit 约定

发布是**单独的 commit**，不和功能 commit 合并。commit 标题必须以 `Release vX.Y.Z` 开头：

```
Release v0.5.0: stable major + one-button upgrade
Release v0.5.1: fix curl pipe error swallow in upgrade.sh
Release v0.6.0: add /handoff skill + autonomous mode toggle
```

### 该 commit 包含且仅包含

- `claude_code/zh/_agent_team_work_zone/VERSION` 改成新版本号
- `claude_code/en/_agent_team_work_zone/VERSION` 改成新版本号
- `claude_code/zh/_agent_team_work_zone/CHANGELOG.md` 新增 `## vX.Y.Z` 条目
- `claude_code/en/_agent_team_work_zone/CHANGELOG.md` 新增 `## vX.Y.Z` 条目
- `claude_code/zh/_agent_team_work_zone/resources/scripts/migrations/v<PREV>_to_vX.Y.Z.sh` 新增

**不许包含**：本次版本承载的功能改动（那些应该在更早的功能 commit 里）。Release commit 是"贴标签的动作"，不是"做新东西的动作"。

### 为什么这条约定重要

- `git log --grep="^Release v"` 一行命令列出所有发布点
- 回溯"v0.5.0 做了什么 / 影响什么"只看一个 commit
- migration 脚本审计与功能改动解耦：升级机制只关心"发布做了什么"，不关心实现细节
- 工具支持：`release.sh` 强制检查 HEAD commit 标题以 `Release vX.Y.Z` 开头

---

## 3. Git tag 约定

每次发布**必须**打 annotated tag（不是 lightweight tag）：

```bash
git tag -a v0.5.0 -m "Release v0.5.0"
```

标签**打在 Release commit 上**（不是任何功能 commit）。

### Annotated vs Lightweight

- Annotated（推荐）：tag 自己有 commit 对象、有作者、有日期、有消息——是"独立的发布记录"
- Lightweight：tag 只是个指针、不带元数据——不要用

### Tag push 时机

Release commit + tag 一起 push：`git push --follow-tags`（让 git 自动把对应 tag 也 push 上去）。

### v0.x 历史 tag

v0.1.0 .. v0.4.0 是回填的（v0.5.0 sprint 时补的），按 CHANGELOG 日期反查对应 release commit 后打 tag。从 v0.5.0 起强制由 `release.sh` 把关。

---

## 4. CHANGELOG 约定

格式遵循 [Keep a Changelog](https://keepachangelog.com/)，每个发布在 `CHANGELOG.md` 顶部新增 `## vX.Y.Z (YYYY-MM-DD)` 章节。

### 必填段落

```markdown
## v0.5.0 (2026-06-12)

发布一句话总结。

### 修复 / Fixed
- ...

### 变更 / Changed
- ...

### 新增 / Added
- ...

### 文档 / Documentation
- ...

### Migration (vPREV → v0.5.0)
**必做**：（向用户提示升级所需的动作）
**行为变更须知**：（向后兼容但维护者要知道的）
（如果是 PATCH 且无行为变化可省略 Migration 段）

### 备注
- ...
```

任意一段没有内容可以省略，但**完全空的 CHANGELOG 条目不允许**（`release.sh` 会拒绝）。

### 双语对称

每次发布的 zh 和 en CHANGELOG 必须**对称**——同样的章节、同样的条目、措辞翻译过去。

---

## 5. Migration 脚本约定

每次 bump 版本号都**必须**有对应 migration 脚本：

```
claude_code/zh/_agent_team_work_zone/resources/scripts/migrations/v<PREV>_to_v<NEW>.sh
```

### 标准模板（PATCH / MINOR 通用）

照搬 `v0.0.0_to_v0.1.0.sh` pattern：
- `cp_framework_files` for `resources/` 和 `docs/`
- 必要时覆盖 `meeting_room/README.md`、`CHANGELOG.md`、`README.md`（FRAMEWORK 段替换）
- 末尾 `write_version "$TARGET_DIR/VERSION" "v<NEW>"`

### MAJOR 升级特例

MAJOR 涉及破坏性变更，migration 脚本可以包含结构性操作（mkdir / mv / 跨目录移动），但**严禁碰用户工位内的文件**。具体规则见 `upgrade_guide.md` 的"框架文件 vs 用户文件"清单。

### 为什么这条约定重要

历史教训：v0.2.0 / v0.2.1 发布时忘了写 migration 脚本，导致 v0.x → v0.4.0 chain 中途断裂。现在 `release.sh` 强制检查 migration 脚本存在，杜绝再犯。

---

## 6. Release 工作流（v0.5.0 起）

发布动作的标准流程（**所有命令在 repo 根目录跑**）：

```bash
# 0. 进入 repo 根
cd /path/to/agent-work-zone

# 1. 在干净的 main 分支上，确认所有要进 v0.5.0 的功能 commit 已合并
git checkout main
git log --oneline -10

# 2. Lead 写 release 资料（双语对称）
#    - 改 VERSION (zh + en)
#    - 写 CHANGELOG v0.5.0 条目 (zh + en)
#    - 写 v0.4.0_to_v0.5.0.sh
git add \
  claude_code/zh/_agent_team_work_zone/VERSION \
  claude_code/en/_agent_team_work_zone/VERSION \
  claude_code/zh/_agent_team_work_zone/CHANGELOG.md \
  claude_code/en/_agent_team_work_zone/CHANGELOG.md \
  claude_code/zh/_agent_team_work_zone/resources/scripts/migrations/v0.4.0_to_v0.5.0.sh

# 3. Release commit
git commit -m "Release v0.5.0: <一句话总结>

<更详细的描述>
"

# 4. 跑 release.sh 强制检查 + 打 tag
bash claude_code/zh/_agent_team_work_zone/resources/scripts/release.sh v0.5.0
# 或先 dry-run：
bash claude_code/zh/_agent_team_work_zone/resources/scripts/release.sh --dry-run v0.5.0

# 5. Push
git push --follow-tags
```

`release.sh` 会强制检查 5 条：VERSION 一致 / CHANGELOG 有条目 / migration 脚本存在 / 工作树 clean / HEAD commit 标题以 `Release v0.5.0` 开头。任一失败直接 exit 1，不打 tag。

---

## 7. v1.0.0 路线占位

v1.0.0 是承诺级别的版本，目前未规划。计划方向：**作为可独立分发的 package 发布**（不再要求用户 clone 整个 agent-work-zone repo，而是通过 brew tap / curl install / 或类似机制安装）。

v1.0.0 之后的承诺：
- 不再有破坏性 MINOR——所有破坏性变更走 MAJOR
- skill 接口、`TEAMMATE_INFO.json` schema、framework 文件清单都视为**公开 API**
- 任何破坏性变更需要 deprecation period（先 deprecation warning、下个 MAJOR 再删）

v0.x 阶段不受这些约束，但维护者**应该向这个方向靠拢**——每次 bump 时心里想一下"如果这是 v1.0.0 之后，能 PATCH 吗 / MINOR 吗 / 必须 MAJOR 吗"。这是 v1.0.0 提前演练。

---

## 8. 旧 4 步升级流程的废弃声明

v0.5.0 起，**手动 4 步流程**（`git pull → cp -r → bash dispatcher → 清理`）**正式废弃**。

`upgrade_guide.md` 从 v0.5.0 起只描述新一键脚本 `bash _agent_team_work_zone/upgrade.sh`。

### 给存量 v0.x 用户的迁移路径

如果你的项目还在 v0.x 旧版本（v0.0.0 .. v0.4.0）：
1. **先用旧法升到 v0.4.0**——按 `upgrade_guide.md` 的旧版本说明（可以从 `git checkout v0.4.0` 拿回那个版本的文档）
2. **然后用新法**：从 v0.4.0 起，`bash _agent_team_work_zone/upgrade.sh` 直接升到 latest

### 旧 dispatcher 仍然在

`resources/scripts/upgrade.sh`（migration chain dispatcher）**继续保留**——新一键脚本只是它的自动化包装层，不是替代它。所以升级机制内部依然走 migration chain，只是用户不再需要手动 cp。

---

## 9. 历史决策参考

详细的版本设计决策、踩过的坑见：
- `notes/` 顶层目录：过往 sprint 的设计笔记
- `docs/design_history.md`：早期架构决策记录
- `_agent_team_work_zone/upgrader_team/notes.md`（live dogfood）：维护者的工作笔记
- 各个版本的 CHANGELOG 条目本身：包含触发因素和影响范围

如本文档与代码行为冲突，**以代码（特别是 `release.sh`）为准**——它是强制执行约定的工具，文档是约定的人类可读版本。

---

## 10. Dev / Release 双仓库版本映射 + v1.0.x 演进方案

本框架以**两个仓库**演进：

| 仓库 | 可见性 | README 面向 | 角色 |
|---|---|---|---|
| **dev**（即本仓库 `agent-work-zone`）| 私有 | **开发者**（框架维护者）| 真源：zh 源 + en 镜像、live dogfood、迁移脚本、release.sh、设计笔记全在此 |
| **release**（未来 public 仓库）| 公开 | **用户** | 由 dev 裁剪、对外分发的发行版；剥离 `release.sh` / migrations / dogfood / 设计笔记 |

### 版本映射规则

> **release MAJOR = dev MAJOR − 1；MINOR 与 PATCH 同步。**

例：dev `v1.1.0` ↔ release `v0.1.0`（首个对外发行版）；dev `v1.2.3` ↔ release `v0.2.3`；将来 dev `v2.0.0` ↔ release `v1.0.0`（即 §7 所述"作为可独立分发 package 的承诺级 v1.0.0"——那是**发行版**的 v1.0.0，对应 dev 的 v2.0.0）。

这样 dev 始终领先 release 一个大版本：dev 内部已经"成熟到 1.x"，但对外仍在 0.x 的"公开 API 尚可演进"阶段——与 §7 的承诺不冲突，反而把它落到了**发行版**这一侧。

### 为什么 dev 从 v0.5.0 直接跳到 v1.0.1（跳过 v1.0.0）

`v0.5.0` 是一个**象征性的成熟度基线**——它带来了一键 `upgrade.sh` + 发布纪律 `release.sh` + 版本约定，框架自此"够格称 1.0"。与其回溯性地把 v0.5.0 改名成 v1.0.0，不如**就地认定 v0.5.0 ≙ 象征性 v1.0.0**，dev 后续从 `v1.0.1` 继续。

- dev 的 VERSION 文件内容仍以**链式前驱**为准：迁移脚本名为 `v0.5.0_to_v1.0.1.sh`（用户磁盘上的 VERSION 内容是 `v0.5.0`，迁移链按它匹配，与任何 tag 别名无关）。
- GitKeeper / Upgrader 另行补一个 `v1.0.0` annotated tag，**别名指向 v0.5.0 的 release commit**（纯 tag 操作，不改 VERSION 文件、不进迁移链）。

### "重大独立修复值得单独版本号"约定

并非每个修复都要单独版本号——绝大多数打磨**统一并入一个 PATCH**（如 v1.0.1 收编了 checkpoint 窗口、liveness 加固、计数订正等一批小改动）。但**严重、独立、值得单独追踪**的修复**单独占一个版本号**，便于审计与回溯。

例：teammate idle hook 的**跨 team 同名 teammate 工位误判** bug（glob `*_team/` 取字母序首个 → 读错 team 的 mtime → 误 nudge）是严重的隐性正确性 bug，单独占 `v1.0.2`，与 v1.0.1 的常规打磨分开。

### 收尾后的目标态

当本轮所有收尾完成、框架达到首个"可对外"状态时：dev 打 `v1.1.0`，裁剪出 release 仓库的 `v0.1.0` 作为**首个公开发行版**。
