#!/usr/bin/env bash
# atwz_detect_tier.sh — 判断当前 Claude Code 登录所用的订阅档位，供 /quickstart 和 /onboard
# 决定成员默认用什么模型。
#
# 用法：bash _agent_team_work_zone/resources/scripts/atwz_detect_tier.sh [--model <lead 当前模型>] [--plan default|conservative]
# 输出：一行 JSON，例如
#   {"tier": "max_20x", "source": "subscriptionType=max; organizationRateLimitTier=default_claude_max_20x", "lead_effort_current": "medium", "lead_effort_source": "model default", "lead_advice": "…"}
#   没给 --model 时 lead_effort_current 为 null。
#   tier 取值：pro / max_5x / max_20x / team / api / unknown
#   source 只写用到的字段名和取值，不含邮箱、组织名、账户编号或令牌。
#
# 规则：
#   - 只读两样东西：`claude auth status` 的 authMethod、subscriptionType；订阅是 max 时，
#     再读一个档位字段（没有文档的内部字段，以后可能改名）来分 Max 5x 和 Max 20x。
#   - 凭据文件里有令牌：只用 jq 取 rateLimitTier 这一个字段，不打印、不保存任何其他内容。
#   - 任何出错都输出 unknown；永远以 0 退出，不中断调用它的技能。
#   - 兼容 bash 3.2（macOS 自带）。需要 jq，没有 jq 时输出 unknown。

emit() {
  # 只保留安全字符，保证输出是合法 JSON
  _src="$(printf '%s' "$2" | tr -cd 'A-Za-z0-9_=;. -')"
  if [ -n "$lead_effort" ]; then _eff="\"$lead_effort\""; else _eff="null"; fi
  build_advice "$1"
  printf '{"tier": "%s", "source": "%s", "lead_effort_current": %s, "lead_effort_source": "%s", "lead_advice": "%s"}\n' \
    "$1" "$_src" "$_eff" "$lead_effort_src" "$lead_advice"
  exit 0
}

# 参数：--model <lead 当前模型的别名、ID 或名称>（例如 opus、claude-opus-5-5、"Opus 5.5"）
lead_model=""
plan=default
while [ $# -gt 0 ]; do
  case "$1" in
    --model) lead_model="$2"; [ $# -ge 2 ] && shift; shift ;;
    --model=*) lead_model="${1#--model=}"; shift ;;
    --plan) plan="$2"; [ $# -ge 2 ] && shift; shift ;;
    --plan=*) plan="${1#--plan=}"; shift ;;
    *) shift ;;
  esac
done

# lead 当前的思考强度（只读）。成员不能单独设思考强度，之后派生的成员用 lead 的。
# 按顺序取第一个有效值（low / medium / high / xhigh / max；auto 和其他值当作没有）：
#   a. 环境变量 CLAUDE_CODE_EFFORT_LEVEL；  b. 项目 .claude/settings.json 顶层的 effortLevel；
#   c. 用户设置（CLAUDE_CONFIG_DIR 或 ~/.claude 下的 settings.json）里 modelSettings 中对应当前模型的 effortLevel；
#   d. 用户设置顶层的 effortLevel，只对 5.5 系列之前的模型算数（Haiku / Sonnet / Opus 5.5 和 Fable 跳过）；
#   e. 模型默认：5.5 系列的 Haiku / Sonnet / Opus 为 medium，其他为 high。启动参数 --effort 读不到。
lead_effort=""
lead_effort_src="no --model given"
valid_effort() {
  case "$1" in low|medium|high|xhigh|max) return 0 ;; *) return 1 ;; esac
}
if [ -n "$lead_model" ]; then
  m="$(printf '%s' "$lead_model" | tr 'A-Z' 'a-z')"
  fam=""
  case "$m" in
    *haiku*) fam=haiku ;; *sonnet*) fam=sonnet ;; *opus*) fam=opus ;; *fable*) fam=fable ;;
  esac
  ver="$(printf '%s' "$m" | sed -nE 's/.*(haiku|sonnet|opus)[^0-9]*([0-9]+)([-.]([0-9]+))?.*/\2 \4/p' 2>/dev/null)"
  major="$(printf '%s' "$ver" | cut -d' ' -f1)"
  minor="$(printf '%s' "$ver" | cut -s -d' ' -f2)"
  [ -n "$minor" ] || minor=0
  # 5.5 系列及之后（含只给别名、没有版本号的情况，以及 Fable）→ yes
  new_series=yes
  if [ -n "$major" ]; then
    if [ "$major" -lt 5 ] 2>/dev/null || { [ "$major" -eq 5 ] 2>/dev/null && [ "$minor" -lt 5 ] 2>/dev/null; }; then
      new_series=no
    fi
  fi
  sig="$fam$major"; [ -n "$major" ] && sig="$sig$minor"
  user_settings="$(printenv CLAUDE_CONFIG_DIR 2>/dev/null)"
  user_settings="${user_settings:-$HOME/.claude}/settings.json"
  have_jq=no; command -v jq >/dev/null 2>&1 && have_jq=yes

  v="$(printenv CLAUDE_CODE_EFFORT_LEVEL 2>/dev/null)"
  if valid_effort "$v"; then lead_effort="$v"; lead_effort_src="CLAUDE_CODE_EFFORT_LEVEL"; fi
  if [ -z "$lead_effort" ] && [ "$have_jq" = yes ] && [ -f .claude/settings.json ]; then
    v="$(jq -r '.effortLevel // empty' .claude/settings.json 2>/dev/null)"
    if valid_effort "$v"; then lead_effort="$v"; lead_effort_src="project effortLevel"; fi
  fi
  if [ -z "$lead_effort" ] && [ "$have_jq" = yes ] && [ -n "$fam" ] && [ -f "$user_settings" ]; then
    v="$(jq -r --arg m "$m" --arg f "$fam" --arg s "$sig" '
      [(.modelSettings // {}) | to_entries[] | select(.value.effortLevel != null)] as $e
      | ([$e[] | select((.key | ascii_downcase) == $m)]
         + [$e[] | select((.key | ascii_downcase) == $f)]
         + [$e[] | select(.key | ascii_downcase | gsub("[^a-z0-9]"; "") | contains($s))])
      | .[0].value.effortLevel // empty' "$user_settings" 2>/dev/null)"
    if valid_effort "$v"; then lead_effort="$v"; lead_effort_src="user modelSettings"; fi
  fi
  if [ -z "$lead_effort" ] && [ "$have_jq" = yes ] && [ "$new_series" = no ] && [ -f "$user_settings" ]; then
    v="$(jq -r '.effortLevel // empty' "$user_settings" 2>/dev/null)"
    if valid_effort "$v"; then lead_effort="$v"; lead_effort_src="user effortLevel"; fi
  fi
  if [ -z "$lead_effort" ]; then
    case "$fam" in
      haiku|sonnet|opus) [ "$new_series" = yes ] && lead_effort=medium || lead_effort=high ;;
      *) lead_effort=high ;;
    esac
    lead_effort_src="model default"
  fi
fi

# 建议句用到的文字（中文版）
L_JOIN="、"
L_DESC_MODEL="用的是 "
L_DESC_EFFORT="思考强度是 "
L_DESC_EFFORT_END=""
L_P1_A="你现在"
L_P1_B="，"
L_P1_C=" 的额度会消耗得很快"
L_PRO_FABLE="，而且 Fable 在 Pro 上要按量付费"
L_P1_D="；建议"
L_CMD_MODEL="输入 /model "
L_FABLE_NOTE="（Fable 最多占每周额度的一半）"
L_CMD_EFFORT="输入 /effort "
L_EFFORT_NOTE="（之后派生或重新派生的成员会用同样的思考强度）"
L_FIRST="先"
L_THEN="，再考虑"
L_UP20_ALONE="你的 Max 20x 额度足够，想要更强的规划判断，可以"
L_UP_ALONE="想要更强的规划判断，可以"
L_UP_AFTER="；想要更强的规划判断，也可以"
L_UPPRO_ALONE="想要更强的规划判断，可以提高到 "
L_UPPRO_AFTER="；想要更强的规划判断，也可以提高到 "
L_SUBJ_MODEL=""
L_SUBJ_EFFORT=""
L_UPPRO_TO=""
L_UPPRO_MID="（"
L_UPPRO_END="），Pro 下留意额度"
L_END="。这也会成为你以后会话的默认，随时可以再改。"

# 给 lead 的建议句（只在给了 --model 时拼）：规则见 docs/model_policy_schema.md 的"给 lead 的建议怎么写"。
# 建议值按档位和 --plan（default 或 conservative，默认 default）；Max 20x 的默认方案按 fable 比较。
# 按等级比较当前值和建议值：先说该降的（提示额度），再说该升的；都相同就输出空字符串。
rank_model() { case "$1" in haiku) echo 1 ;; sonnet) echo 2 ;; opus) echo 3 ;; fable) echo 4 ;; *) echo 0 ;; esac; }
rank_effort() { case "$1" in low) echo 1 ;; medium) echo 2 ;; high) echo 3 ;; xhigh) echo 4 ;; max) echo 5 ;; *) echo 0 ;; esac; }
join2() {  # $1 $2 $3=joiner
  if [ -n "$1" ] && [ -n "$2" ]; then printf '%s%s%s' "$1" "$3" "$2"; else printf '%s%s' "$1" "$2"; fi
}
build_advice() {
  lead_advice=""
  [ -n "$lead_model" ] && [ -n "$fam" ] || return 0
  sm=""; se=""; pname=""
  case "$plan:$1" in
    conservative:pro)    sm=sonnet; se=low;    pname="Pro" ;;
    conservative:max_5x) sm=sonnet; se=low;    pname="Max 5x" ;;
    conservative:max_20x) sm=opus;  se=medium; pname="Max 20x" ;;
    conservative:team)   sm=sonnet; se=low;    pname="Team / Enterprise" ;;
    *:pro)    sm=sonnet; se=medium; pname="Pro" ;;
    *:max_5x) sm=opus;   se=medium; pname="Max 5x" ;;
    *:max_20x) sm=fable; se=high;   pname="Max 20x" ;;
    *:team)   sm=opus;   se=medium; pname="Team / Enterprise" ;;
  esac
  [ -n "$pname" ] || return 0
  cm="$(rank_model "$fam")"; tm="$(rank_model "$sm")"
  mdir=""; [ "$cm" -gt "$tm" ] && mdir=down; [ "$cm" -lt "$tm" ] && mdir=up
  edir=""
  if [ -n "$lead_effort" ]; then
    ce="$(rank_effort "$lead_effort")"; te="$(rank_effort "$se")"
    [ "$ce" -gt "$te" ] && edir=down; [ "$ce" -lt "$te" ] && edir=up
  fi
  [ -n "$mdir" ] || [ -n "$edir" ] || return 0
  mitem="$L_CMD_MODEL$sm"; [ "$sm" = fable ] && mitem="$mitem$L_FABLE_NOTE"
  eitem="$L_CMD_EFFORT$se$L_EFFORT_NOTE"
  # Pro 先说思考强度再说模型，其他档先模型后思考强度
  down1=""; down2=""; up1=""; up2=""; upvals=""; upsubj=""
  if [ "$1" = pro ]; then order="e m"; else order="m e"; fi
  for k in $order; do
    if [ "$k" = m ]; then d="$mdir"; it="$mitem"; val="$sm"; subj="$L_SUBJ_MODEL"; else d="$edir"; it="$eitem"; val="$se"; subj="$L_SUBJ_EFFORT"; fi
    if [ "$d" = down ]; then
      if [ -z "$down1" ]; then down1="$it"; else down2="$it"; fi
    elif [ "$d" = up ]; then
      if [ -z "$up1" ]; then up1="$it"; else up2="$it"; fi
      upvals="$(join2 "$upvals" "$val" "$L_JOIN")"
      upsubj="$(join2 "$upsubj" "$subj" "$L_JOIN")"
    fi
  done
  items_of() { if [ -n "$2" ]; then printf '%s%s%s%s' "$L_FIRST" "$1" "$L_THEN" "$2"; else printf '%s' "$1"; fi; }
  part1=""
  if [ -n "$down1" ]; then
    desc=""
    [ "$mdir" = down ] && desc="$L_DESC_MODEL$fam"
    [ "$edir" = down ] && desc="$(join2 "$desc" "$L_DESC_EFFORT$lead_effort$L_DESC_EFFORT_END" "$L_JOIN")"
    fee=""; [ "$1" = pro ] && [ "$fam" = fable ] && fee="$L_PRO_FABLE"
    part1="$L_P1_A$desc$L_P1_B$pname$L_P1_C$fee$L_P1_D$(items_of "$down1" "$down2")"
  fi
  part2=""
  if [ -n "$up1" ]; then
    ui="$(items_of "$up1" "$up2")"
    if [ "$1" = pro ]; then
      if [ -n "$part1" ]; then part2="$L_UPPRO_AFTER"; else part2="$L_UPPRO_ALONE"; fi
      part2="$part2$upsubj$L_UPPRO_TO$upvals$L_UPPRO_MID$ui$L_UPPRO_END"
    elif [ "$1" = max_20x ] && [ -z "$part1" ]; then
      part2="$L_UP20_ALONE$ui"
    elif [ -n "$part1" ]; then
      part2="$L_UP_AFTER$ui"
    else
      part2="$L_UP_ALONE$ui"
    fi
  fi
  lead_advice="$part1$part2$L_END"
}

# 1. ANTHROPIC_BASE_URL 指向 api.anthropic.com 以外的服务 → 按用量计费
base="$(printenv ANTHROPIC_BASE_URL 2>/dev/null)"
if [ -n "$base" ]; then
  host="${base#*://}"
  host="${host%%/*}"
  host="${host%%:*}"
  if [ "$host" != "api.anthropic.com" ]; then
    emit api "ANTHROPIC_BASE_URL=other"
  fi
fi

command -v jq >/dev/null 2>&1 || emit unknown "jq=missing"
command -v claude >/dev/null 2>&1 || emit unknown "claude=missing"

# 2. claude auth status（没登录时以 1 退出，但仍输出 JSON，所以不看退出码）
status="$(claude auth status 2>/dev/null)"
[ -n "$status" ] || emit unknown "auth status=no output"
fields="$(printf '%s' "$status" | jq -r '[(.authMethod // ""), (.subscriptionType // ""), (.configDirectory // "")] | @tsv' 2>/dev/null)" \
  || emit unknown "auth status=unparsed"
auth_method="$(printf '%s' "$fields" | cut -f1)"
sub_type="$(printf '%s' "$fields" | cut -f2)"
config_dir="$(printf '%s' "$fields" | cut -f3)"
[ -n "$auth_method" ] || emit unknown "authMethod=none"

# 3. 没登录 → 判断不出；不是 claude.ai 账号登录（API key、云厂商）→ 按用量计费
[ "$auth_method" = "none" ] && emit unknown "authMethod=none"
[ "$auth_method" = "claude.ai" ] || emit api "authMethod=$auth_method"

# 5. 读档位字段：先 .claude.json 的 oauthAccount.organizationRateLimitTier，
#    再凭据文件的 claudeAiOauth.rateLimitTier；取第一个非空的值。
#    配置目录取 auth status 报告的 configDirectory（没有这个字段时取 CLAUDE_CONFIG_DIR，
#    再没有就是 ~/.claude）；凭据文件在这个目录下。.claude.json：设了 CLAUDE_CONFIG_DIR 时在
#    这个目录下，没设时在 ~/.claude.json（不在 ~/.claude/ 里；那里即使有同名文件也不是当前的）。
env_config_dir="$(printenv CLAUDE_CONFIG_DIR 2>/dev/null)"
[ -n "$config_dir" ] || config_dir="${env_config_dir:-$HOME/.claude}"
if [ -n "$env_config_dir" ]; then
  account_file="$config_dir/.claude.json"
else
  account_file="$HOME/.claude.json"
fi
cred_file="$config_dir/.credentials.json"

read_rate_tier() {
  if [ -f "$account_file" ]; then
    v="$(jq -r '.oauthAccount.organizationRateLimitTier // empty' "$account_file" 2>/dev/null)"
    if [ -n "$v" ]; then printf 'organizationRateLimitTier=%s' "$v"; return 0; fi
  fi
  if [ -f "$cred_file" ]; then
    v="$(jq -r '.claudeAiOauth.rateLimitTier // empty' "$cred_file" 2>/dev/null)"
    if [ -n "$v" ]; then printf 'rateLimitTier=%s' "$v"; return 0; fi
  fi
  return 1
}

# 4. 按订阅类型
case "$sub_type" in
  pro)
    emit pro "subscriptionType=pro" ;;
  max)
    rate="$(read_rate_tier)" || emit max_5x "subscriptionType=max; rate tier=not found"
    case "$rate" in
      *default_claude_zero*) emit unknown "subscriptionType=max; $rate" ;;
      *20x*) emit max_20x "subscriptionType=max; $rate" ;;
      *5x*)  emit max_5x "subscriptionType=max; $rate" ;;
      *)     emit max_5x "subscriptionType=max; $rate" ;;
    esac ;;
  team|enterprise)
    emit team "subscriptionType=$sub_type" ;;
  *)
    emit unknown "subscriptionType=${sub_type:-none}" ;;
esac
