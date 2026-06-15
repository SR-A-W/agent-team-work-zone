# 角色原型速查（Role Archetypes）

## 什么是角色原型

本目录里的文件是**给 team lead 在 `/spawn-team` 时参考的模板**。它们**不是** Claude Code 的 subagent 定义，**不由** `.claude/agents/` 加载。

**三层存储策略中的位置**：
- 角色原型 → 速查模板，lead 在 spawn prompt 里**复制拼装**使用
- `.claude/agents/*.md` → 项目全局通用的 5 个 subagent（tracker / investigator / reviewer / devil-advocate / git-repo-manager）
- `<team>/teammates/*.md` → 团队自定义角色存档（Tier 2）
- inline 在 spawn prompt → 一次性 teammate（Tier 1 默认）

## 两层模型：通用模板 + 任务级具体化

每个原型描述的是**项目无关的基本职责**。team lead 在 `/spawn-team` 时：

1. **选原型**：根据任务分解选 1~N 个合适的原型
2. **具体化**：把原型的通用描述**拷贝**到 spawn prompt，然后**填入项目特定细节**（文件路径、输入输出、禁区、交付物等）
3. **组装 spawn prompt**：把具体化后的内容和其他 teammate 的描述一起发给 Claude Code agent-team 机制

## 为什么不做 subagent 定义

细粒度不够。例如 "coder" 这种命名在实际项目中毫无价值——到底是写 PyTorch 模型架构？写 bash 脚本？写 YAML 训练配置？每种需要完全不同的 system prompt 和工具约束。

但**职责大类**是普遍存在的，可以模板化到"通用描述 + 具体化指南"的程度。这就是原型的定位。

## 目录组织

```
role_archetypes/
├── README.md                    ← 本文件
├── coding/                      ← 写代码类（按语言/职责区分）
│   ├── bash-scripter.md         通用 bash 脚本（含 SLURM submit）
│   ├── model-architect.md       Transformers / PyTorch 模型架构
│   └── dataset-specialist.md    数据加载、预处理、augmentation
├── config/                      ← 写配置类（按职责区分，而非文件格式）
│   ├── training-config-author.md  训练配置（含 LLaMA-Factory、VERL 等前端）
│   └── eval-config-author.md      评测配置（含 skythought、evalscope 等前端）
├── infra/                       ← 环境与基础设施（有前后依赖）
│   ├── env-configurator.md        conda / pip / 依赖（**先**）
│   └── container-builder.md       Singularity（HPC 主）+ Docker（后）
└── analysis/                    ← 分析类（只读）
    ├── data-analyzer.md           多类数据源的常规提取 + summary
    └── result-reporter.md         实验结果 → xlsx 表格 + 可视化
```

## 如何使用这些原型

### 作为 team lead 在 `/spawn-team` 中

```
1. /spawn-team 的 Phase 2 任务分解 → 识别需要什么能力
2. /spawn-team 的 Phase 3 阵容提案 → 对每个 teammate，从本目录选一个原型（或选通用 subagent）
3. 把原型文件内容拷贝到 spawn prompt，在"**具体化**"部分补入：
   - 项目特定的文件路径
   - 具体要写/改什么
   - 禁区清单
   - 期望的产出位置
4. 发送 spawn prompt，Claude Code 识别并 spawn teammate
```

### 新增或修改原型

修改源文件时只编辑 `resources/role_archetypes/` 下的 md——这些**不会**被 bootstrap 同步到 `.claude/`（因为它们不是 Claude Code 自动加载的 subagent）。修改后直接生效，下次 lead 在 `/spawn-team` 里查阅时会读到新版本。

## 重要约定

- 每个原型都包含：**职责** / **不做** / **典型工作流** / **lead 在具体化时要补的字段**
- 原型描述**不含**项目特定信息（LLaMA-Factory 等属于当前项目常用前端的提示除外，会在明显位置标注"当前项目常用前端"可被覆盖）
- 原型命名规则：`<scope>-<action>er`（如 `bash-scripter`、`model-architect`）
- 原型层级：**不超过二级**（coding/config/infra/analysis），避免过度分类
