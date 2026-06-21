# resources/ — 非成员资源

本目录存放**不属于任何具体 agent 工位**的共享资源——skills、通用 custom subagents、角色原型速查、安装脚本、预留 hooks 等。

## 为什么叫 `resources/` 而不是混在工位里

- 和扁平工位 / team 工位**平级**存放，物理隔离避免概念混淆
- 所有需要被 `bootstrap.sh` 安装到 `.claude/` 下的源都在 `skills/` 和 `agents/` 子目录里
- 权威源规则：**只编辑 `resources/` 下的源**，`.claude/` 下的是派生物，禁止手编

## 子目录

```
resources/
├── skills/              ← Skills 权威源（bootstrap 同步到 .claude/skills/）
│   ├── onboard/SKILL.md
│   ├── sync/SKILL.md
│   ├── check-inbox/SKILL.md
│   ├── archive-resolved/SKILL.md
│   ├── spawn-team/SKILL.md
│   ├── promote-to-team/SKILL.md
│   ├── evaluate-team/SKILL.md
│   ├── add-teammate/SKILL.md
│   └── remove-teammate/SKILL.md
│
├── agents/              ← 项目全局通用 subagent 权威源（bootstrap 同步到 .claude/agents/）
│   ├── git-repo-manager.md
│   ├── tracker.md
│   ├── investigator.md
│   ├── reviewer.md
│   └── devil-advocate.md
│
├── role_archetypes/     ← 角色原型速查（不由 Claude Code 自动加载）
│   ├── README.md
│   ├── coding/          (bash-scripter / model-architect / dataset-specialist)
│   ├── config/          (training-config-author / eval-config-author)
│   ├── infra/           (env-configurator / container-builder)
│   └── analysis/        (data-analyzer / result-reporter)
│
├── scripts/
│   ├── bootstrap.sh     ← 一键安装 skills + agents + settings.json + 环境检查
│   └── install_skills.sh (保留，内部被 bootstrap 调用)
│
└── hooks/               ← 预留，供 terminal-form (autonomous mode) 启用
```

## 权威源规则

- **源**：`resources/{skills, agents, role_archetypes, scripts, hooks}/`
- **运行时**：`.claude/skills/` 和 `.claude/agents/`（由 bootstrap 同步）
- **禁止**直接编辑 `.claude/skills/*` 或 `.claude/agents/*`
- 英文版 `claude_code/en/_agent_team_work_zone/` 在 zh 稳定后由 Translator 从 zh 生成，不作为独立源

## 开发工作流

1. 编辑 `resources/skills/<name>/SKILL.md`（或 `resources/agents/<name>.md`）
2. 运行 `bash resources/scripts/bootstrap.sh` 同步到 `.claude/`
3. 重启 Claude Code session 或用 `/agents` 刷新让它加载新版本
4. 测试

