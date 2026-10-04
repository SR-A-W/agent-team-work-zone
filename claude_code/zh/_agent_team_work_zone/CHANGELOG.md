# Changelog — agent-team-work-zone（中文 Team 版）

所有重要变更都记录在此文件。格式遵循 [Keep a Changelog](https://keepachangelog.com/)，版本号遵循语义化版本 `vMAJOR.MINOR.PATCH`。

---

## v0.4.0 (2026-10-04)

MINOR（向后兼容）：**checkpoint 安全——teammate 不再写共享注册表、注册表写入改为校验式、子代理不再被卷进 checkpoint 循环；以及升级刷新不再悄悄丢掉你的内容**。

### 变更
- teammate 不再写 `TEAMMATE_INFO.json`：`/checkpoint` 去掉了更新注册表的那一步，注册表只由 lead 写，消除了多个 teammate 同时 checkpoint 时互相覆盖的竞态。
- 注册表 `schema_version` 1 → 2：移除 `last_checkpoint_at` 字段；`/reactivate-team`、`/evaluate-team`、`/sync` 改从 teammate 的 `working-context.md` 文件 mtime 取"上次 checkpoint 时间"。仍带该字段的旧注册表照常可用（字段被忽略）。`/onboard`、`/promote-to-team` 新建注册表时写 `schema_version: 2`，`/spawn-team` 按 schema v2 初始化。
- `/reactivate-team` 的"Last checkpoint"改为显示 `working-context.md` 距今多久（以 mtime 为准），文件的 `_Last updated:` 行作为可读时间；回执为 "Resumed from checkpoint at <时间>. Ready."
- `/checkpoint` 的确认行带上写入者："Checkpoint written by <名字> to <路径>. Trigger: …"。
- SessionStart hook：检测到的 team 不是当前 agent 自己的工位时，提醒改为"对此保持沉默"（重启与上下文压缩两种情况都如此）；原来是"向用户简单提一下"。
- teammate 守则第 2 条（重发）：SendMessage 发送成功即已投递，静默 ≠ 丢失；只有 SendMessage 报错或对方明确说没收到才重发；给 lead 发消息时照抄其注册名。
- 升级时的守则区刷新：存量 README 还没有 RULES 标记时，守则块原先一直延伸到下一个 `## ` 标题，写在守则后面的笔记会被搬进 `.rules.bak`。现在守则块止于最后一行与框架守则相同的行，再延伸到最后一条编号守则（`### N.`）结束，遇到第一个分隔即停：`---`/`***`/`___`、不带编号的 `##`/`###` 标题、或 `<!--`。被并进块的行、留在块外的行都会计数并打 ⚠。标题同名但底下没有任何框架文字的（你自写的守则节）会被跳过。想让笔记留在受管块之外，请用 `---` 或一个不带编号的标题把它和守则隔开。

### 新增
- `/checkpoint` 身份核验（拿不准就不写）：写入前 teammate 先确认工位是自己的（依据自己的 spawn prompt，且工位里有写着自己名字的 `README.md`）；只收到一条点名别人工位的提醒的子代理会拒绝写入并回报。
- `/checkpoint` 在覆写 Part A 之前，先把旧的 Part A 原样存为一条 Part B 记录，误覆写可以恢复。
- `/reactivate-team` 在派生任何人之前先检查 `TEAMMATE_INFO.json` 能否解析（`jq empty`，或 PowerShell 等价命令）；失败则一个都不派生，并给出恢复命令（优先用 `TEAMMATE_INFO.json.bak`，否则从 git 恢复）。
- `/spawn-team`、`/add-teammate`、`/reactivate-team`、`/bench-teammate`、`/remove-teammate` 写注册表改为校验式写入：写临时文件 → `jq empty` 解析检查 → 备份为 `TEAMMATE_INFO.json.bak` → `mv`；任一步失败则不写。因此每次 lead 写注册表都会在旁边留下一份 `TEAMMATE_INFO.json.bak`。
- schema 文档：`scope` 等自由文本字段不得包含 ASCII 双引号（用「」/『』或弯引号），进度描述不要写进注册表。
- teammate README 的守则块（`TEAMMATE_RULES`）在升级替换前先备份：`<README>.teammate_rules.bak.<时间戳>`，并打 ⚠。原先内容有差异就直接替换、不备份。

### 修复
- idle checkpoint hook 不再把子代理逼进 checkpoint 循环：payload 带 `agent_id`（只在子代理调用中出现）时提前退出；提醒文字也告诉子代理或没有写文件工具的 agent 忽略本提醒并回报派生者。
- 从 v0.3.1 及更早版本升级时，写在 Troubleshooting 一节之后的用户内容（例如 `<!-- USER:* -->` 段）不再被覆盖：参考资料块止于最后一行与框架文字相同的行，而不是文件末尾。
- 升级写文件改为出错不中断、保留权限：备份写不进去时该块原样不动（打 ⚠ "NOT refreshed"），迁移继续；临时文件建在目标文件旁边，被改写的 README 保留原权限（原先会变成 600），新建的 `VERSION` 也用正常的默认权限。

### 已知问题
- 五个 skill 的校验式注册表写入仍使用固定的临时路径 `/tmp/info.json`，两个 lead 恰好同时写入时可能互相冲突；而且 `/tmp` 与项目不在同一文件系统时，最后那步 `mv` 不是原子操作。v0.5.0 修复。
- 如果你是从 v0.3.1 或更早版本升级到 v0.3.2 的，那次升级可能已经把你在顶层 README 的 Troubleshooting 之后自行添加的一节（例如 `<!-- USER:* -->` 段）覆盖掉了，且没有备份。v0.4.0 能防止以后再发生，但无法找回。请检查该 README，如有缺失，从 git 恢复（例如 `git log -p -- _agent_team_work_zone/README.md`）。
- `/add-teammate` 仍写着"按 schema v1 初始化"，而 `/spawn-team` 写的是 v2。无害（它只是追加一条记录），v0.5.0 修正。

### Migration（v0.3.2 → v0.4.0）
- **必做**：`bash _agent_team_work_zone/upgrade.sh` 覆盖框架文件，刷新顶层 README 的框架 / 守则 / 参考资料三块，刷新每个已有守则块的 lead/扁平工位 README，刷新每个已有 `TEAMMATE_RULES` 块的 teammate README（带备份），并写 VERSION。还没有该块的 teammate README 不动，等它下次被 spawn/reactivate 时自行补上。
- **每个已带该块的 teammate 工位都会留下一份 `.teammate_rules.bak.<时间戳>`**：本版改了 teammate 守则文字（第 2 条），所以这类块一定有差异，替换前都会先备份。完整守则文字本版没有变，所以 lead/扁平工位只有在你改过守则块、或它还没有标记时才会产生 `.rules.bak`。
- **无用户数据迁移**：已有的 `TEAMMATE_INFO.json` 不会被修改；`schema_version: 1` 且带 `last_checkpoint_at` 的注册表照常可用，该字段被忽略。
- **可能新出现的文件**：`TEAMMATE_INFO.json.bak`（每次 lead 写注册表后留下）、`*.rules.bak.<时间戳>` 与 `*.teammate_rules.bak.<时间戳>`（刷新时内容有差异才会留下）。它们不会被自动清理。
- **此前升级遗留的文件权限**：升级到 v0.3.2 时，被改写的 README 和 `VERSION` 可能变成了 `600` 权限。v0.4.0 会保留文件现有的权限，不会自动恢复；如果看到这些文件是 `600`，可用 `chmod 644 <文件>` 恢复。
- **请留意迁移打印的 ⚠ 行**："taken into" 守则块的文字在备份里；"kept outside" 块外的文字原样未动，可能是旧版框架文字，也可能是你自己的内容。

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
