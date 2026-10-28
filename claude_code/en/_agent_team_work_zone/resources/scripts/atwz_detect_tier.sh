#!/usr/bin/env bash
# atwz_detect_tier.sh — detect the subscription tier of the current Claude Code login, so that
# /quickstart and /onboard can choose the default model for teammates; with --model it also reads
# the lead's current effort level.
#
# Usage: bash _agent_team_work_zone/resources/scripts/atwz_detect_tier.sh [--model <the lead's current model>] [--plan default|conservative]
# Output: one line of JSON, for example
#   {"tier": "max_20x", "source": "subscriptionType=max; organizationRateLimitTier=default_claude_max_20x", "lead_effort_current": "medium", "lead_effort_source": "model default", "lead_advice": "…"}
#   Without --model, lead_effort_current is null.
#   tier is one of: pro / max_5x / max_20x / team / api / unknown
#   source holds only the field names and values that were used: no email, organization name,
#   account ID or token.
#
# Rules:
#   - Reads only authMethod and subscriptionType from `claude auth status`; when the plan is max,
#     it also reads one tier field (an undocumented internal field that may be renamed later) to
#     tell Max 5x from Max 20x.
#   - The credentials file holds tokens: jq extracts the single rateLimitTier field, and nothing
#     else from the file is printed or saved.
#   - Any error prints unknown; the script always exits 0 so it never interrupts the calling skill.
#   - Works with bash 3.2 (the macOS default). Needs jq; without jq it prints unknown.

emit() {
  # keep only safe characters so the output is always valid JSON
  _src="$(printf '%s' "$2" | tr -cd 'A-Za-z0-9_=;. -')"
  if [ -n "$lead_effort" ]; then _eff="\"$lead_effort\""; else _eff="null"; fi
  build_advice "$1"
  printf '{"tier": "%s", "source": "%s", "lead_effort_current": %s, "lead_effort_source": "%s", "lead_advice": "%s"}\n' \
    "$1" "$_src" "$_eff" "$lead_effort_src" "$lead_advice"
  exit 0
}

# Arguments: --model <the lead's current model: alias, ID or name> (for example opus, claude-opus-5-5, "Opus 5.5")
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

# The lead's current effort level (read only). Teammates cannot get their own effort level; those spawned afterwards use the lead's.
# Take the first valid value in this order (low / medium / high / xhigh / max; auto and anything else count as no value):
#   a. the CLAUDE_CODE_EFFORT_LEVEL environment variable;  b. the top-level effortLevel in the project's .claude/settings.json;
#   c. in the user settings (settings.json under CLAUDE_CONFIG_DIR or ~/.claude), the modelSettings effortLevel for the current model;
#   d. the top-level effortLevel in the user settings, which counts only for models before the 5.5 series (skipped for Haiku / Sonnet / Opus 5.5 and Fable);
#   e. the model default: medium for the 5.5-series Haiku / Sonnet / Opus, high otherwise. A --effort startup flag cannot be read.
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
  # 5.5 series or later (including an alias without a version, and Fable) → yes
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

# Text used in the suggestion sentence (English version)
L_JOIN=" and "
L_DESC_MODEL="using "
L_DESC_EFFORT="on "
L_DESC_EFFORT_END=" effort"
L_P1_A="You are "
L_P1_B=", which uses up your "
L_P1_C=" limits fast"
L_PRO_FABLE=", and Fable is pay-as-you-go on Pro"
L_P1_D="; I suggest you "
L_CMD_MODEL="type /model "
L_FABLE_NOTE=" (Fable uses at most half of your weekly limits)"
L_CMD_EFFORT="type /effort "
L_EFFORT_NOTE=" (teammates spawned or re-spawned afterwards use the same effort level)"
L_FIRST="first "
L_THEN=", then "
L_UP20_ALONE="Your Max 20x plan has enough usage; for stronger planning and judgment, you can "
L_UP_ALONE="For stronger planning and judgment, you can "
L_UP_AFTER="; for stronger planning and judgment, you can also "
L_UPPRO_ALONE="For stronger planning and judgment, you can switch "
L_UPPRO_AFTER="; for stronger planning and judgment, you can also switch "
L_SUBJ_MODEL="the model"
L_SUBJ_EFFORT="the effort"
L_UPPRO_TO=" to "
L_UPPRO_MID=" ("
L_UPPRO_END="); on Pro, watch your usage"
L_END=". This also becomes the default for your later sessions; you can change it again any time."

# The suggestion sentence for the lead (built only when --model is given): rules in the "How to write the suggestion to the lead" section of docs/model_policy_schema.md.
# Suggested values follow the tier and --plan (default or conservative; default if omitted); Max 20x's default plan compares against fable.
# Compare current and suggested values by rank: first what to lower (mentioning usage), then what to raise; all equal → empty string.
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
  # On Pro mention effort first and then the model; on the other plans the model first and then effort
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

# 1. ANTHROPIC_BASE_URL points somewhere other than api.anthropic.com → pay-as-you-go
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

# 2. claude auth status (exits 1 when not logged in but still prints JSON, so the exit code is ignored)
status="$(claude auth status 2>/dev/null)"
[ -n "$status" ] || emit unknown "auth status=no output"
fields="$(printf '%s' "$status" | jq -r '[(.authMethod // ""), (.subscriptionType // ""), (.configDirectory // "")] | @tsv' 2>/dev/null)" \
  || emit unknown "auth status=unparsed"
auth_method="$(printf '%s' "$fields" | cut -f1)"
sub_type="$(printf '%s' "$fields" | cut -f2)"
config_dir="$(printf '%s' "$fields" | cut -f3)"
[ -n "$auth_method" ] || emit unknown "authMethod=none"

# 3. Not logged in → cannot tell; not a claude.ai account login (API key, cloud provider) → pay-as-you-go
[ "$auth_method" = "none" ] && emit unknown "authMethod=none"
[ "$auth_method" = "claude.ai" ] || emit api "authMethod=$auth_method"

# 5. Read the tier field: first oauthAccount.organizationRateLimitTier in .claude.json,
#    then claudeAiOauth.rateLimitTier in the credentials file; use the first non-empty value.
#    The config directory is the configDirectory that auth status reports (without that field,
#    CLAUDE_CONFIG_DIR, and failing that ~/.claude); the credentials file is in it. .claude.json is
#    in that directory when CLAUDE_CONFIG_DIR is set, and at ~/.claude.json when it is not (not in
#    ~/.claude/; a file of the same name there is not the current one).
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

# 4. By subscription type
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
