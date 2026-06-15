# Role Archetypes Quick Reference

## What is a role archetype

Files in this directory are **templates that team leads consult during `/spawn-team`**. They are **not** Claude Code subagent definitions and are **not** loaded by `.claude/agents/`.

**Position in the three-tier storage strategy**:
- Role archetypes -> quick-reference templates, leads **copy and assemble** them into spawn prompts
- `.claude/agents/*.md` -> 5 project-global general-purpose subagents (tracker / investigator / reviewer / devil-advocate / git-repo-manager)
- `<team>/teammates/*.md` -> team-specific custom role archives (Tier 2)
- inline in spawn prompt -> one-off teammates (Tier 1 default)

## Two-layer model: generic template + task-level specialization

Each archetype describes **project-agnostic core responsibilities**. During `/spawn-team`, the team lead:

1. **Picks archetypes**: based on task decomposition, selects 1-N suitable archetypes
2. **Specializes**: **copies** the archetype's generic description into the spawn prompt, then **fills in project-specific details** (file paths, inputs/outputs, no-go zones, deliverables, etc.)
3. **Assembles the spawn prompt**: sends the specialized content together with the other teammates' descriptions to Claude Code's agent-team mechanism

## Why not make them subagent definitions

Not granular enough. For example, a name like "coder" is worthless in a real project — does it mean writing a PyTorch model architecture? Writing bash scripts? Writing YAML training configs? Each requires a completely different system prompt and tool constraints.

But **broad responsibility categories** are universal and can be templated at the level of "generic description + specialization guide". That is what these archetypes are for.

## Directory layout

```
role_archetypes/
├── README.md                    <- this file
├── coding/                      <- code-writing roles (split by language/responsibility)
│   ├── bash-scripter.md         generic bash scripts (including SLURM submit)
│   ├── model-architect.md       Transformers / PyTorch model architecture
│   └── dataset-specialist.md    data loading, preprocessing, augmentation
├── config/                      <- config-writing roles (split by responsibility, not file format)
│   ├── training-config-author.md  training configs (including LLaMA-Factory, VERL, etc. front ends)
│   └── eval-config-author.md      eval configs (including skythought, evalscope, etc. front ends)
├── infra/                       <- environment and infrastructure (with a prerequisite chain)
│   ├── env-configurator.md        conda / pip / dependencies (**first**)
│   └── container-builder.md       Singularity (HPC primary) + Docker (after)
└── analysis/                    <- analysis roles (read-only)
    ├── data-analyzer.md           routine extraction + summary across multiple data source types
    └── result-reporter.md         experiment results -> xlsx tables + visualizations
```

## How to use these archetypes

### As a team lead in `/spawn-team`

```
1. /spawn-team Phase 2 task decomposition -> identify the capabilities needed
2. /spawn-team Phase 3 lineup proposal -> for each teammate, pick an archetype from this directory (or pick a general-purpose subagent)
3. Copy the archetype file contents into the spawn prompt, and in the "**specialization**" section fill in:
   - project-specific file paths
   - what exactly to write/change
   - no-go list
   - expected output locations
4. Send the spawn prompt; Claude Code recognizes it and spawns the teammate
```

### Adding or modifying archetypes

When modifying the source, only edit the md files under `resources/role_archetypes/` — these are **not** synced to `.claude/` by bootstrap (because they are not auto-loaded Claude Code subagents). Changes take effect immediately; the next time a lead consults them in `/spawn-team`, they will see the new version.

## Important conventions

- Each archetype contains: **Responsibilities** / **Does not do** / **Typical workflow** / **Fields the lead must fill in during specialization**
- Archetype descriptions **do not contain** project-specific information (exceptions: notes about common front ends for the current project, such as LLaMA-Factory, are clearly flagged as "common front end for the current project" and can be overridden)
- Archetype naming: `<scope>-<action>er` (e.g. `bash-scripter`, `model-architect`)
- Archetype hierarchy: **no deeper than two levels** (coding/config/infra/analysis), to avoid over-classification
