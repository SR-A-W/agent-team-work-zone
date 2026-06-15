#!/usr/bin/env bash
#
# check_pending_checkpoint.sh — 已退役（RETIRED, v0.2.3）
#
# 历史作用：UserPromptSubmit hook，读 teammate 工位下的 .checkpoint_pending flag，
#   通过 additionalContext 提醒该 teammate 跑 /checkpoint。
#
# 退役原因（读写不对称的死结）：这条"读侧"链路对 in-process teammate 从不工作——
#   UserPromptSubmit 的 payload 不带 teammate 身份；in-process 下 teammate 与 lead 共用
#   进程、cwd 都是项目根，认不出当前是 lead 还是哪个 teammate（详见 developer_manual §5）。
#
# v0.2.3 起，自动 checkpoint 改由 teammate_idle_checkpoint.sh 单边完成：在带身份的
#   "写侧"(TeammateIdle) 用 working-context.md mtime 闸门 + exit 2，把提醒的 stderr 直接喂给
#   正在 idle 的那个 teammate——彻底不经过这条认不出身份的"读侧"。本消费者因此不再需要。
#
# 本文件保留为【无害 no-op】（立即 exit 0）：万一某下游 .claude/settings.json 仍残留旧的
#   UserPromptSubmit 钩子（bootstrap 的 deep-merge 不会删除已不在模板里的键，需靠 migration
#   显式 del），它也只是立刻退出、绝不阻塞、绝不注入任何身份。settings_hooks_template.json
#   已移除 UserPromptSubmit 条目；migration v0.2.2→v0.2.3 会显式 del(.hooks.UserPromptSubmit)。

exit 0
