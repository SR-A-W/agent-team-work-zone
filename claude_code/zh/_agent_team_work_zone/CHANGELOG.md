# Changelog — agent-team-work-zone（中文 Team 版）

所有重要变更都记录在此文件。格式遵循 [Keep a Changelog](https://keepachangelog.com/)，版本号遵循语义化版本 `vMAJOR.MINOR.PATCH`。

---

## v0.5.0 (2026-10-04)

MINOR（向后兼容）：**能区分"根本没启动"的 teammate 并让它保持可达、共享工作目录的守则、可选的 checkpoint git 保存与 git 锁、广播规则变更的 skill、可选的 CLAUDE.md 段落，以及不碰你自己文件的升级**。

要求：可选的 git 锁需要 git 2.5 或更高版本；其他功能不需要。

### 变更
- TeammateIdle checkpoint hook：计时起点改为 `working-context.md` mtime 与 `.started` 中较晚的一个，刚唤回的 teammate 第一次空闲时不再被要求 checkpoint；提醒文字仍报告距上次保存的时间；没有 `.started` 时行为不变。
- spawn / reactivate prompt 里的守则自愈：替换 teammate README 中旧的完整守则段之前，先把它原样备份到 `README.md.teammate_rules.bak.<UTC 时间戳>`，并在回执里报告；lead 转告用户。
- spawn / add / reactivate prompt 改用绝对路径 `<project_root>`：teammate 的工作目录不一定是项目根，其 Bash 里也没有 `CLAUDE_PROJECT_DIR`。
- `CLAUDE.md.template`（仅新安装）："从报告读 teammate 信号"原则加入：消息可能晚到数小时、`[to X]` 心跳摘要不是报告、约定截止已过且 ping 无回音时可以查已落地的状态（`git log`、已完成的产物）、不对用户说未经核实的沉默原因。
- `/checkpoint` 新增最后一步：项目开启时执行 git 保存，确认行里带上结果；确认步骤变为 Step 6。
- `/spawn-team`、`/add-teammate`、`/reactivate-team` 的 prompt 让 teammate 读本团队的 `RULES_LEDGER.md`、记下尚未记录的规则并在回执里确认；lead 据回执填写账本。
- README skills 表：`loop` 一行改为"监控时定时唤醒（见第 13 条）"，新增 `/broadcast-rule` 一行，"仅限 team lead"的说明也包含它。
- 模板 `.gitignore` 还忽略 teammate 启动标记、hook 日志、idle hook 的计数器、注册表备份，以及写入中断时可能留下的临时文件；守则备份仍纳入管理，因为其中可能有用户内容。
- `bootstrap.sh`：git 低于 2.5 时打印警告（只有可选的 git 锁需要它），没装 git 时提示一行。

### 新增
- 派生和唤回 prompt 新增第 0 步：teammate 在读任何文件之前先写 `teammates/<名字>/.started`（当前 UTC 时间），让 lead 能区分"根本没启动"和"在忙"。
- Ready / Resumed 回执末尾加 `Model: <名称>, ID: <ID>`（照抄 teammate 自己的系统提示，没有则写 `Model: not stated`）；lead 把 ID 记入注册表新增的可选字段 `model_resolved`，与申请的模型或 teammate README 不一致时标出，但两边都不改。`schema_version` 仍为 2；没有该字段的注册表照常可用。
- `/spawn-team`、`/add-teammate`、`/reactivate-team` 新增"无回执"处理：约 10 分钟无回执时，lead 先尽力读 tmux 面板，再拿 `.started` 与派生时间比对，然后把可能原因告诉用户；绝不自动重派。
- tracker agent 新增"盯守告警"模式（模式 B）：低成本的 Haiku teammate 用 `/loop` 等一个结果，检查之间空闲，只在出结果、出异常或停止时给 lead 发消息，必须给出 `stop_when`。
- 工作守则（README 守则块）：
  - 第 1 条：共享工作目录与暂存区纪律——按显式路径提交；禁用 `git add -A` / `commit -a` / `stash` / `pull --rebase` / 非快进合并；用 `pull --ff-only`；不删除已存在的 `.git/index.lock`（一直不消失就告诉 lead）；共享 checkout 里提交、合并、拉取时使用 git 锁；
  - 第 7 条：决策来源（谁提议、谁批准、引原话；成员之间的约定在 lead 裁定前只是提议），以及裁定要写明作废哪些工作；
  - 第 13 条 teammate 部分：保持可达（盯作业就用 `/loop` 排定唤醒再结束回合——队友消息只在回合结束时送达），以及 `.started` 与模型 ID 回执义务；
  - 第 13 条 lead 部分：成员沉默时（消息可能晚到数小时；截止已过且 ping 无回音时只查已落地状态；`[to X]` 心跳摘要不是报告；不自动重派，向用户列出可能原因；用 `/loop` 等待；派生后核对 `.started` 与模型 ID），以及给正在干活的成员发更正时合并成一条完整消息。
- teammate 守则（`teammate_rules.md`，会进每个 teammate 的 README）：加入"本块由框架维护、升级时整体替换、旧块备份为 `README.md.teammate_rules.bak.<时间戳>`"的说明；新增第 8 条（用 `/loop` 保持可达）、第 9 条（决策来源）、第 10 条（共享工作目录与暂存区，以及 git 锁）。
- README 新增「开始之前」一节，用户手册的「快速开始」部分也加入同样的说明：`_agent_team_work_zone/` 要放在项目目录里，并且总在这个目录下启动 Claude Code（常见错误是在 HPC 登录节点的 home 目录里直接启动 `claude`；把 home 目录本身当作项目仍然可以）；强烈推荐把 `_agent_team_work_zone/` 纳入 git（agent 的项目记忆得到备份、可以回滚；可以在另一台机器上拉起同一支团队；多位开发者的团队可以通过 `git push` / `git pull` 协调），并提醒公开仓库注意敏感内容。
- 用户手册新增"已知局限"一节：队友消息只在回合结束时送达；子代理无法运行 `/loop`（Explore 上观察到）；一次内存事故可清空全队（同一受限作业，或同进程模式）；同一系统账号的资源框架看不到，不要按进程名杀进程；跨仓库使用 `meeting_room/` 没有约定；不支持每个 teammate 独立的 git worktree。
- checkpoint 的 git 保存（可选，默认关闭）。每个项目单独开启：`bash _agent_team_work_zone/resources/scripts/atwz_checkpoint_git.sh enable`。之后每次 `/checkpoint` 还会把 teammate 的工位文件存进 git，checkpoint 不会因 `git stash`、一次坏的合并或误覆盖而丢失。
  - `snapshot` 模式（默认）：文件存到私有引用 `refs/atwz/checkpoints/<team>/<name>`；你的分支、`HEAD`、`git status` 和共享暂存区都不受影响，提交历史里看不到它。
  - `commit` 模式：把工位文件提交到当前分支，这个提交只包含这些文件（删除也会提交）；暂存区里的其他内容保持原样；提交钩子照常运行。
  - 设置存在 `_agent_team_work_zone/settings.conf`（`checkpoint_git = off | snapshot | commit`），把它提交进仓库，其他机器就共用同一设置；命令有 `enable` / `disable` / `status`，`enable` 会立刻告诉你在这里是否生效。
  - 每次保存都会重新检查能否保存，并在 checkpoint 确认里给出一行 `saved …` 或 `skipped: …`；checkpoint 不会因为 git 而失败。
  - `list` / `restore` 找回已保存的版本；与之不同的当前文件会先另存为 `<文件>.before-restore.<UTC 时间>`。
  - 快照只留在本机：框架从不 push 它们，普通 `git push` 只推分支，新 clone 也不会取到。
- 共享 checkout 的 git 锁：`cd <项目根目录> && bash _agent_team_work_zone/resources/scripts/atwz_git_lock.sh run -- git …` 让所有 agent 的 git 命令一次只跑一个：别的 git 操作在进行时就等待（从不删除 `.git/index.lock`），最多等 3 分钟，超时以退出码 75 放弃；同一台机器上已存在超过 10 分钟、且持有它的进程已经退出的锁会被清除。commit 模式自动使用这把锁。
- `/broadcast-rule`（team lead 用）：把一条规则变更以一条完整消息发给每个在线 teammate；teammate 把它记进自己 README 的「## Team rule changes」一节并回复 `ACK` 加该规则的编号（例如 `ACK R-20261004-1`）；lead 在 `TEAMMATE_INFO.json` 旁维护一份常设的 `RULES_LEDGER.md`；不在线或尚未派生的 teammate 在派生或唤回时读账本，并在回执里确认。
- 可选的 `CLAUDE.md` 段落，在 `resources/claude_md_optional/`：「给用户的消息（格式）」（由 teammate 汇报触发的消息以**队内简报**开头；需要用户读的内容以 **To Be Read By User** 加一行状态开头：需裁定 / 进展 / 更正 / 静默轮）与「平实用语」（平实的词、不自造名词、少用简写，并附一份写在其中的用户禁用词清单）。首次安装时 `bootstrap.sh` 逐段询问（`[y/N]`，默认不加；没有终端时跳过）；回答 y 才追加，且只追加一次——`CLAUDE.md` 里已有该段的 `<!-- ATWZ-OPTIONAL:<id> -->` 标记就跳过。install/upgrade 从不修改或删除 CLAUDE.md 中已有的内容；它们只追加——缺少框架段落时追加框架段落，可选段落只在你回答 y 时追加。

### 修复
- 注册表写入（`/spawn-team`、`/add-teammate`、`/reactivate-team`、`/bench-teammate`、`/remove-teammate`）：临时文件改为在注册表旁用 `mktemp` 创建（原为共用的 `/tmp/info.json`，两个写入方可能互相覆盖，`/tmp` 与项目不在同一文件系统时最后的移动也不是原子的）；用 `cp -p` 预填，注册表保留原有权限；失败时删除临时文件。
- `/add-teammate`：注册表不存在时按 schema v2 初始化（原文写的是 v1）。
- `/add-teammate` 创建新 teammate 的 README 时就写入 teammate 守则块（带标记），与 `/spawn-team` 一致——之后的升级才能刷新它。
- `/reactivate-team` 第 4 步：jq 示例补上 `info=…` 定义（原来未定义就使用，配合 `mktemp` 会把临时文件建在当前目录）。

### 已知问题
- 两个新脚本对 macOS（bash 3.2 与 BSD 工具）的兼容性只做了代码阅读，还没有在 Mac 上实际运行过。
- git 锁只协调经由它运行的命令，不经过它直接运行的 `git` 命令不会被拦住。另一台机器留下的锁从不自动清除：那台机器崩溃后需要手动删除（在此之前，等待者会以退出码 75 放弃）。同一台机器上的过期锁要过 10 分钟才会被清除。
- checkpoint 快照只在本机（不 push、不随 clone 带走），换一台机器时帮不上忙；把 `_agent_team_work_zone/` 纳入 git 才行。`restore` 无法重建被整个删掉的工位目录。`git push --mirror` 或显式推送 `refs/*` 会把快照推出去。
- `.before-restore.*` 副本会一直留在工位里，直到你自己删除。

### Migration（v0.4.0 → v0.5.0）
- **必做**：`bash _agent_team_work_zone/upgrade.sh`。它覆盖框架文件（`resources/`、`docs/`、`CHANGELOG.md`），刷新顶层 README 的框架 / 守则 / 参考资料三块，刷新每个带守则块的 lead / 扁平工位 README 的守则块，以及每个已有 `TEAMMATE_RULES` 块的 teammate README 的该块（都带备份），追加新的 `.gitignore` 规则，写 VERSION，并重新运行 `bootstrap.sh`（它会装上新的 `/broadcast-rule` skill）。没有该块的 teammate README 不动，下次派生或唤回时补上；块上方的内容从不改动。
- **会留下备份**：本版守则正文和 teammate 守则正文都有改动，所以每个被刷新的 README 旁边都会多一份备份——`README.md.rules.bak.<时间戳>`（顶层 README 与 lead / 扁平工位）或 `README.md.teammate_rules.bak.<时间戳>`（teammate）。它们不会被自动清理。
- **`.gitignore`**：在 `_agent_team_work_zone/.gitignore` 里只追加以下规则，且只追加缺少的，放在一行注释下面：`*_team/teammates/*/.started`、`.hook_logs/`、`*_team/teammates/*/.checkpoint_nudge_count`、`*_team/TEAMMATE_INFO.json.bak`、`*_team/.info.??????`、`**/.README.md.??????`、`/.VERSION.??????`、`/settings.conf.??????`。你自己的行不会被改写、重排或删除。安装里没有 `.gitignore` 时不新建，升级会打印模板版在哪里以及它会忽略哪些文件。
- **不会碰**：升级从不创建、修改或删除 `_agent_team_work_zone/settings.conf`、任何 `<team>_team/RULES_LEDGER.md` 或任何 `TEAMMATE_INFO.json`，也从不修改 `CLAUDE.md` 中已有的内容（只在缺少框架段落时追加）。无用户数据迁移：没有 `model_resolved` 字段的注册表照常可用。
- **可选的 CLAUDE.md 段落在升级时不询问。** 要加的话：`printf '\n' >> CLAUDE.md && cat _agent_team_work_zone/resources/claude_md_optional/<文件>.md >> CLAUDE.md`（文件：`user_message_format.md`、`plain_vocabulary.md`）。
- **git**：可选的 git 锁需要 git 2.5 或更高版本，版本更低时 `bootstrap.sh` 会提示。checkpoint 的 git 保存保持关闭，直到你运行 `atwz_checkpoint_git.sh enable`。

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
