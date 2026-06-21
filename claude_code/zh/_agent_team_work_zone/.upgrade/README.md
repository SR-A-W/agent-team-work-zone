# `.upgrade/` — 升级暂存区

本目录是**升级流程专用的暂存区**。正常情况下它应当为空；只有在执行框架升级时才会临时填充内容。

## 用途

当你要把 `_agent_team_work_zone/` 升级到 `agent-team-work-zone` repo 的新版本时：

1. 从 `agent-team-work-zone` repo `git pull` 到目标版本
2. 把该 repo 的 `claude_code/zh/_agent_team_work_zone/` **整个目录的内容**复制到本目录下：
   ```bash
   # 在用户项目根目录执行，假设 agent-team-work-zone 已在 ~/Projects/agent-team-work-zone
   cp -r ~/Projects/agent-team-work-zone/claude_code/zh/_agent_team_work_zone/. \
         _agent_team_work_zone/.upgrade/
   ```
   复制后本目录应该长这样：
   ```
   .upgrade/
   ├── VERSION
   ├── CHANGELOG.md
   ├── README.md
   ├── docs/
   ├── resources/
   │   └── scripts/
   │       ├── upgrade.sh              ← 新版调度器
   │       └── migrations/             ← 按版本递增的迁移脚本链
   │           ├── common.sh
   │           ├── v0.0.0_to_v0.1.0.sh
   │           └── ...
   └── ...
   ```
3. 运行新版调度器：
   ```bash
   bash _agent_team_work_zone/.upgrade/resources/scripts/upgrade.sh
   ```
   脚本会自行判断当前版本、挑选需要执行的迁移链、依次跑完，最后重跑 `bootstrap.sh`。
4. 升级完成后可以清空本目录（保留目录和本 README）：
   ```bash
   find _agent_team_work_zone/.upgrade/ -mindepth 1 ! -name README.md -exec rm -rf {} +
   ```
   （或直接 `rm -rf .upgrade/` 再由下次升级重建——内容都会由 repo 提供。）

## 为什么不直接从 `agent-team-work-zone` repo 运行？

把新版暂存在项目本地的 `.upgrade/` 里有几个好处：

- **迁移脚本跟它所属的版本走**：`v0.0.9 → v0.1.0` 的迁移脚本就在 `.upgrade/resources/scripts/migrations/` 里，由新版自带；如果用户本地 repo 落后，迁移链依然完整。
- **路径自描述**：调度器通过 `$0` 向上推导出 `.upgrade/` 和 `_agent_team_work_zone/`，用户无需传参，也不会搞错目标项目。
- **断点可重试**：一次失败后，`.upgrade/` 还在，修好问题再跑一次即可；无需重新 pull repo。

## 注意事项

- 本目录应被 Git 忽略（见上一级 `.gitignore`），以免用户项目提交时带上升级残留。
- 升级完成后内容可留可删；留着下次升级可跳过 copy 步骤，但需要你自行确保内容是最新的。
