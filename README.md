**English** | [中文](README.zh.md)

# Agent Team Work Zone

> A persistence and management layer for Claude Code and its Agent Teams.

**TL;DR?** 👉 [Jump straight to Quick Start](#quick-start).

Claude Code makes it easy to spin up powerful agents. But once the scale and lifespan of your work outgrow what a single conversation can hold, a few real problems surface — and the most damaging one has no native fix in Claude Code: **once a teammate vanishes with its process, it's gone for good**. **Agent Team Work Zone exists for exactly this: it organizes scattered, interruptible agent work into a persistent, recoverable, auditable team.** Here is the pain it removes:

- **A teammate agent in Claude Code's Agent Team mode can't survive a process restart, and Claude Code can't recover it.** Claude Code's Agent Teams do not persist teammate sessions: when the Claude Code process stops (say the SSH connection drops, as it often does, or the terminal running it is closed), **the entire team, along with all the working state each member built up, is gone, with no native way to get it back**; you're left rebuilding the team from scratch and re-explaining everything.
- **After `/compact`, detail is lost.** Compaction condenses the conversation into a summary, so an agent's grip on "who am I, what am I doing, what do I owe" **may** get fuzzy.
- **Pile up ad-hoc agent conversations and invisible "agentic technical debt" accumulates.** It works at first, but over time: decisions get trapped in compacted old chats, change ownership blurs, tasks get abandoned, agents duplicate each other's work, and there's no audit trail of "why this was done" — the project gets harder and harder to maintain and review.
- **Hand-off tasks make you rewrite long delegation prompts.** When a task has to pass between conversations, you re-type the background, the goal, and the constraints every time.

**Agent Team Work Zone** adds a **filesystem-based operations layer** around Claude Code's native Agent Teams that catches each of these pains: every teammate continuously persists its state as a **checkpoint**, so after an interruption one command brings each member back from where it left off — **making a long-running agent team that spans days or even weeks finally practical**; roles, notes, TODOs, and exchanges all become files that survive `/compact` and leave an audit trail for every decision, keeping "agentic technical debt" to a minimum; and cross-conversation work flows through structured handoffs and report packets instead of re-typed prompts. It turns scattered, interruptible agent conversations into a **persistent, recoverable, auditable** project team, with you always **in the loop** on the division of labor and documentation.

> For a point-by-point breakdown (gap → how we fill it), see [What Gaps in Claude Code It Fills](#what-gaps-in-claude-code-it-fills) below.

---

## What Gaps in Claude Code It Fills

Used on its own, Claude Code falls short in the places below; Agent Team Work Zone fills each one:

| Where raw Claude Code falls short | How Agent Team Work Zone fills it |
|---|---|
| Teammate sessions in Agent Team mode don't survive a process restart — once interrupted, they're gone | Persistent team + teammate workstations, rebuildable one by one from checkpoints |
| After `/compact`, detail is lost and an agent's role and state are reduced to a summary | Role definitions, notes, checkpoints, and TODOs all persisted as files, untouched by compaction |
| Plain conversations can't message each other (only manual copy-paste); in-team messages aren't retained either | Meeting room async file protocol + roundtable records — traceable communication across workstations, sessions, and teams |
| Task state lives only inside a single session | Cross-session TODO / ACTIVE / COMPLETED files |
| Hand-off delegation means rewriting long ad-hoc prompts, with no structure | Structured handoffs and report packets |
| What an agent did leaves no trace, and decisions get buried in old chats (agentic technical debt) | An audit trail + file-based TODO/in-progress/done; plus you in the loop on the labor split and documentation keeps the debt in check |

---

## Core Idea: Organize Agents Like Real Employees

Without this layer, most people either cram every task into a single conversation, or open a pile of conversations with no clear division of labor — and it quickly becomes unmanageable.

Agent Team Work Zone treats these agents as **real employees**. Under this layer, Claude Code's agent sessions are organized into two forms:

### 🧑‍💼 Solo employee (flat workstation)
An "employee-ified" plain Claude Code conversation session = one employee: a clear **role** and its own **personal workstation** (a persistent directory that serves as its external working notes). It's the same agent you talk to day to day, just with a persistent work area of its own. Plain conversations can't message one another, so flat employees coordinate through the **meeting room** via [async collaboration](#6-make-two-agents-collaborate-via-the-meeting-room).

### 👥 Employee team (Agent Team mode) — **strongly recommended**
For any project with real complexity, we **strongly recommend team mode**. A team = one **team lead** + several **teammates**:

> **One team per complex task; a project can have several teams.** Typically you point **one agent team at a single, sufficiently complex task or feature** — not one team for the whole project. A project can run **several agent teams** in parallel, and different teams likewise coordinate through the meeting room via [async collaboration](#6-make-two-agents-collaborate-via-the-meeting-room).

- The **team lead** is an agent session **with Claude Code's built-in Agent Team feature enabled**. It coordinates — decomposing tasks, routing, reviewing, summarizing — rather than burning its own context window on implementation. It owns a **team workstation** (`*_team/`).
- **Teammates** are specialized workers **auto-created by that Agent Team feature**, each with its own personal workstation — **you don't create or manage them by hand**. In raw Claude Code, these teammates **all vanish when the team lead's process ends**; this ops layer fixes that with checkpoints, **making a long-lived team actually usable**.
- In team mode, **lead↔teammate and teammate↔teammate can talk in real time** — no reliance on hidden chat memory. The **roundtable** is the **documented record and reinforcement** of those exchanges (for audit and recovery), not the only channel.
- Capabilities unlocked by team mode:
  - **Checkpoints** — each teammate periodically persists its working state, so any future spawn can pick up where it left off (this is exactly what lets an interrupted team recover).
  - **Reactivation** — one command rebuilds the entire team from checkpoints.
  - **Team registry + handoffs + archival** — who's on duty, who a task went to, where finished work landed — all traceable.

> Individuals have personal workstations; teams have team workstations. Completed work is **archived** for audit.

---

## Key Primitives

**Workstation** — a persistent directory owned exclusively by any "employee-ified" agent; its external working notebook: role definition, notes, task lists, current working context, and completed-work history. The two role types below each own a workstation.

**Solo employee (flat workstation)** — an employee-ified **plain Claude Code conversation session**: a role and a personal workstation, the same agent you talk to day to day, just with a persistent work area. It does **not** enable the Agent Team feature, so it coordinates with others asynchronously through the meeting room.

**Team Lead** — an agent session **with Claude Code's built-in Agent Team feature enabled**, owning a `*_team/` team workstation. It decomposes tasks, spawns teammates, coordinates the roundtable, and reports to you; it does no implementation. **This is usually the main session you're talking in.**

**Teammate** — a specialized worker **auto-created by Claude Code's built-in Agent Team feature**, with a workstation at `<team>_team/teammates/<name>/` — **you don't create or manage it by hand**. It maintains its own checkpoints, TODOs, commitments, and completed-work log, usually directed by the team lead (you can also talk to it directly).

**Meeting Room** — a top-level async communication space for all flat employees and team leads. Note it **does not sync automatically — it is purely async**: messages don't deliver themselves — you direct **agent A to leave a document for agent B**, then have **agent B run `/check-inbox`** to read what was left for it.

**Roundtable** — a team-internal communication space, used only by a team lead and its teammates (the documented reinforcement of real-time talk, not the sole channel).

**Checkpoint** — a structured state snapshot each teammate writes, letting a future spawned instance recover both "what the previous session knew" and "what it still owes."

**Team Registry** — the `TEAMMATE_INFO.json` maintained by the team lead, which drives the reactivation flow.

---

## Quick Start

> **Claude Code version**: this release (**v0.2.0**) requires **Claude Code ≥ 2.1.178** — it adapts to the 2.1.178 agent-teams API (auto session-scoped teams; `TeamCreate`/`TeamDelete` removed). If your Claude Code is **≤ 2.1.177**, use **[release v0.1.0](https://github.com/SR-A-W/agent-team-work-zone/releases/tag/v0.1.0)** instead (it targets the old agent-teams API). The installer also enforces this floor.

> **Platform support**: currently supported on **Linux** and **macOS**. The install/upgrade scripts and runtime hooks are bash-based; **Windows is not yet supported** (native Windows has no bash — native support is on the roadmap, planned for the next major release). Windows users can run it via WSL for now.

### 1. Get the template

```bash
git clone https://github.com/SR-A-W/agent-team-work-zone.git
```

### 2. Copy into your project

Just copy the template directory into your project root:

```bash
cp -r claude_code/en/_agent_team_work_zone /path/to/your/project/   # English edition — run this one
# Or, for the Chinese edition instead, run this one:
# cp -r claude_code/zh/_agent_team_work_zone /path/to/your/project/
```

> **Prefer not to use the command line?** Do it right in your file manager (Finder / Nautilus, etc.): open the cloned repo, **copy** the whole `claude_code/en/_agent_team_work_zone` (or `zh/`) folder, and **paste** it into your target project's root directory — exactly the same result.

### 3. Install

```bash
cd /path/to/your/project
bash _agent_team_work_zone/install.sh
```

The script installs the skills and agent definitions into `.claude/` and enables the required Claude Code settings.

### 4. Start an agent and onboard it

Enter Claude Code right in your project directory:

```bash
claude
```

Then onboard the agent:

```
/onboard help me reproduce the experiments in this github repo
```

> The text after `/onboard` is a description of **what your project is about** — the above is just an example; write it to match your real goal. The skill first asks whether to make a flat workstation or a team lead, then creates the right structure automatically. **For projects with real complexity, choose / let it form a team at this step.**

### 5. Let the team work (checkpoints are automatic)

Usually the team lead forms the team during `/onboard`, per your decision. Just tell it to get going — the lead decomposes the task, proposes teammates, saves a recipe, and spawns the workers.

> **Rare case**: if `/onboard` didn't create a team, just tell the team lead "form a team to do X" and it'll invoke `/spawn-team` (you can call it yourself too, but you usually don't need to).

> **Tip**: in agent team mode, run Claude Code in **"auto mode"** (auto-approve) — teammates trigger a lot of per-action permission prompts, and auto mode spares you from approving them one by one. The installer offers to set this as the default (`permissions.defaultMode:"auto"`, recommended); you can also toggle it anytime with `Shift+Tab`.

**About checkpoints — you don't manage them.** Teammates don't need you to trigger any saving by hand: this ops layer uses a hook to ensure **every teammate automatically writes a checkpoint before going idle** (default interval 15 minutes). A checkpoint captures that teammate's "current-state snapshot + recent work journal" — what it's doing, how far it got, what it agreed with whom, and what it still owes. **It's exactly these auto-persisted checkpoints that let a team be restored after a session is interrupted.**

### 6. Make two agents collaborate via the meeting room

When two agents in **different conversations** need to collaborate (e.g. two team leads), use the meeting room — the async channel. **It does not sync automatically**, so you broker it:

1. **Have the sender leave a document** — in agent A's conversation, say e.g. "Write this conclusion up as a document in the meeting room, addressed to B." A creates a markdown file under `_agent_team_work_zone/meeting_room/` tagged `to: B`.
2. **Have the receiver pick it up** — switch to agent B's conversation and run `/check-inbox`. B scans the meeting room, picks out the documents addressed `to: B`, handles them, and marks each `RESOLVED` when done.
3. **Have the issuer archive** — `/check-inbox` also archives: back in **agent A's** conversation, run `/check-inbox` again, and A (as the document's issuer) archives the now-`RESOLVED` doc, keeping the meeting room tidy.

> When a team lead runs `/check-inbox`, it also scans its own team's roundtable; a flat agent only scans the top-level meeting room.

### 7. Resume and reactivate the team

When you come back, go through Claude Code's normal resume flow, then in the conversation:

```
/reactivate-team
```

The lead uses the team registry and each teammate's checkpoint to restore the team to its previous operating state.

### Update the framework to the latest version

To upgrade **Agent Team Work Zone itself** to the latest version (pulling the newest skills / hooks / docs and running any migrations automatically), run from your project root:

```bash
bash _agent_team_work_zone/upgrade.sh
```

It only updates framework files — **it never touches the work inside your agents' workstations**.

---

## Built-In Skills

### User-facing skills (you call these — sorted by typical frequency)

| Skill | Purpose |
|---|---|
| `/reactivate-team` | Restore the whole team from checkpoints after a resume |
| `/check-inbox` | Process meeting room / roundtable messages for this agent |
| `/onboard` | Create a flat or team-lead workstation for a new agent |
| `/sync` | Recover role context after compaction and check inboxes |
| `/handoff` | Transfer task context from one agent to another |
| `/promote-to-team` | Upgrade a flat workstation to team lead |

### Automatic skills (agents call these — you usually don't need to invoke them)

| Skill | Purpose |
|---|---|
| `/checkpoint` | (hook-triggered) Update a teammate's recoverable working context |
| `/spawn-team` | Structured 6-phase flow to form a teammate group |
| `/add-teammate` | Add a new teammate to an existing team |
| `/remove-teammate` | Retire a teammate with handoff and archive discipline |
| `/bench-teammate` | Temporarily take a teammate offline to free a slot; reactivate later |

---

## When to Use It: Complex, Multi-Session Projects

**Best for highly complex projects.** The bigger, longer, more role-heavy, and more traceability-demanding a project is, the more this layer pays off. Specifically, it suits:

- Ongoing projects that span multiple sessions
- Agents with several specialized roles
- Caring about who did what, and why
- Cases where context compaction has caused lost work
- Tasks that need handoffs, tracking, or periodic status reports

---

## Design Principles

**Dedicated notes and memory beat a generic chat context.** Claude Code has its own memory system, but a chat context is often not specific or detailed enough. Writing "what a future agent needs to know" explicitly into workstation files is more reliable and precise than relying on generalized conversation memory.

**A workstation is a working notebook.** Workstation files are an agent's external notebook: current understanding, local knowledge, pitfalls hit, outstanding commitments, and recovery entry points.

**Auto-persist, don't rely on discipline.** A teammate's working state is checkpointed **automatically** by a hook (by default before it goes idle, roughly every 15 minutes), never dependent on anyone remembering to save — this is the underlying guarantee that lets a team recover after an unexpected interruption.

**Human-in-the-loop keeps technical debt low.** Role definitions and division of labor are settled by you together with the agents — so responsibilities are clear *and* you actually know what each agent is doing; and the cross-session meeting-room coordination is something you orchestrate — you decide who leaves a document for whom, and direct agents to write up specific project questions — which drives agentic technical debt down further.

**Low coupling.** Each agent owns only its own workstation. Never edit someone else's files directly — cross-workstation collaboration goes through the meeting room or roundtable.

**A report is a prompt.** A good agent-to-agent report is essentially a high-quality prompt packet: what happened, what was tried, what failed, what changed, what's needed next, and where the relevant files are.

**The team lead coordinates.** The context window should be spent on task decomposition, routing, review, and synthesis — not on implementation.

---

## Documentation

- [User Manual](claude_code/en/_agent_team_work_zone/docs/user_manual.md) — getting started, skills reference, workflow patterns
- Technical report — *(planned, stay tuned)*

---

## In One Sentence

**Agent Team Work Zone is a persistence and management layer for Claude Code and its Agent Teams: it gives AI agents roles, workstations, working notes, reports, handoffs, checkpoints, and an audit trail, so the multi-agent workflows in your project can rebuild knowledge and keep moving after compaction, a session interruption, and resume.**
