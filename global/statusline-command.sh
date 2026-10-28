#!/usr/bin/env bash
input=$(cat)

j() { printf '%s' "$input" | jq -r "$1 // empty" 2>/dev/null; }

cwd=$(j '.workspace.current_dir')
[ -z "$cwd" ] && cwd=$(j '.cwd')
repo=$(j '.workspace.repo.name')
[ -z "$repo" ] && repo=$(basename "$(j '.workspace.project_dir // .workspace.current_dir // .cwd')" 2>/dev/null)
model=$(j '.model.display_name')
effort=$(j '.effort.level')
pr_num=$(j '.pr.number')
pr_kind=$(j '.pr.kind')
pr_review=$(j '.pr.review_state')
ctx=$(j '.context_window.used_percentage')
tok_in=$(j '.context_window.total_input_tokens')
tok_out=$(j '.context_window.total_output_tokens')
cost=$(j '.cost.total_cost_usd')
five=$(j '.rate_limits.five_hour.used_percentage')
five_at=$(j '.rate_limits.five_hour.resets_at')
week=$(j '.rate_limits.seven_day.used_percentage')
week_at=$(j '.rate_limits.seven_day.resets_at')

export LC_NUMERIC=C

cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/claude-statusline"

branch=""; staged=0; modified=0
if [ -n "$cwd" ]; then
  cache="$cache_dir/git-$(printf '%s' "$cwd" | cksum | cut -d' ' -f1)"
  mkdir -p "$cache_dir" 2>/dev/null
  mtime=$(stat -c %Y "$cache" 2>/dev/null || echo 0)
  if [ $(( $(date +%s) - mtime )) -lt 5 ]; then
    IFS='|' read -r branch staged modified < "$cache"
  else
    if git -C "$cwd" --no-optional-locks rev-parse --git-dir >/dev/null 2>&1; then
      branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short -q HEAD 2>/dev/null \
        || git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
      staged=$(git -C "$cwd" --no-optional-locks diff --cached --name-only 2>/dev/null | wc -l)
      modified=$(git -C "$cwd" --no-optional-locks diff --name-only 2>/dev/null | wc -l)
    fi
    printf '%s|%s|%s\n' "$branch" "$staged" "$modified" > "$cache" 2>/dev/null
  fi
fi

# Epoch -> "1h29 (17:13)" / "3j00h (04/10 15:56)" / "12m (17:13)"
fmt_reset() {
  local n=${1%.*} now d days h m at
  case "$n" in ''|*[!0-9]*) return ;; esac
  now=$(date +%s)
  d=$(( n - now )); [ "$d" -lt 0 ] && d=0
  days=$(( d / 86400 )); h=$(( d % 86400 / 3600 )); m=$(( d % 3600 / 60 ))
  if [ "$days" -gt 0 ]; then
    at=$(date -d "@$n" '+%d/%m %H:%M' 2>/dev/null)
    printf '%dj%02dh (%s)' "$days" "$h" "$at"
  elif [ "$h" -gt 0 ]; then
    at=$(date -d "@$n" '+%H:%M' 2>/dev/null)
    printf '%dh%02d (%s)' "$h" "$m" "$at"
  else
    at=$(date -d "@$n" '+%H:%M' 2>/dev/null)
    printf '%dm (%s)' "$m" "$at"
  fi
}

R=$'\033[0m'; DIM=$'\033[2m'; BLUE=$'\033[34m'; CYAN=$'\033[36m'
GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RED=$'\033[31m'; GRAY=$'\033[90m'; MAGENTA=$'\033[35m'
sep="${DIM} · ${R}"

color_for() {
  local p=${1%.*}
  if [ "$p" -ge 85 ]; then printf '%s' "$RED"
  elif [ "$p" -ge 60 ]; then printf '%s' "$YELLOW"
  else printf '%s' "$GREEN"; fi
}

# Valeur en cache pour <type> <cle> (meme perimee, vide si inconnue / echec).
# Au-dela de 60 s, la commande qui suit est relancee en arriere-plan depuis $cwd (verrou perime apres 30 s).
cached() {
  local f lock age slug
  slug="${ci_repo_full:-$(printf '%s' "$cwd" | cksum | cut -d' ' -f1)}"
  f="$cache_dir/$1-$(printf '%s' "${slug}-$2" | tr -c 'A-Za-z0-9._-' '_')"; lock="$f.lock"
  shift 2
  mkdir -p "$cache_dir" 2>/dev/null || return
  age=$(( $(date +%s) - $(stat -c %Y "$f" 2>/dev/null || echo 0) ))
  if [ "$age" -ge 60 ]; then
    if [ -e "$lock" ] && [ $(( $(date +%s) - $(stat -c %Y "$lock" 2>/dev/null || echo 0) )) -gt 30 ]; then
      rm -f "$lock"
    fi
    if ( set -o noclobber; : > "$lock" ) 2>/dev/null; then
      (
        out=$(cd "${cwd:-.}" 2>/dev/null; "$@")
        printf '%s\n' "$out" > "$f.tmp.$$" 2>/dev/null && mv -f "$f.tmp.$$" "$f"
        rm -f "$lock"
      ) >/dev/null 2>&1 &
      disown 2>/dev/null
    fi
  fi
  [ -r "$f" ] && head -n1 "$f"
}

# Etat CI de la PR : pass | fail | pending | (vide)
fetch_ci_state() {
  local out
  out=$(timeout 15 gh pr checks "$1" ${ci_repo_full:+-R "$ci_repo_full"} --json bucket 2>/dev/null)
  printf '%s' "$out" | jq -e 'type=="array"' >/dev/null 2>&1 || return
  printf '%s' "$out" | jq -r '
    [.[].bucket] as $b
    | if ($b | map(select(. == "fail" or . == "cancel")) | length) > 0 then "fail"
      elif ($b | map(select(. == "pending")) | length) > 0 then "pending"
      elif ($b | map(select(. == "pass")) | length) > 0 then "pass"
      else "" end'
}
# Nombre de fils de revue non resolus (vide si inconnu).
fetch_threads_count() {
  local nwo="$ci_repo_full" out
  [ -z "$nwo" ] && nwo=$(timeout 10 gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null)
  case "$nwo" in */*) ;; *) return ;; esac
  out=$(timeout 15 gh api graphql \
    -f query='query($o:String!,$n:String!,$p:Int!){repository(owner:$o,name:$n){pullRequest(number:$p){reviewThreads(first:100){nodes{isResolved}}}}}' \
    -F o="${nwo%%/*}" -F n="${nwo#*/}" -F p="$1" \
    --jq '[.data.repository.pullRequest.reviewThreads.nodes[]|select(.isResolved|not)]|length' 2>/dev/null)
  case "$out" in ''|*[!0-9]*) ;; *) printf '%s' "$out" ;; esac
}
# Repli si Claude Code ne transmet pas .pr : "numero|review_state" de la PR ouverte de la branche.
fetch_branch_pr() {
  local res
  res=$(timeout 15 gh pr list --head "$1" --state open ${ci_repo_full:+-R "$ci_repo_full"} \
    --json number,isDraft,reviewDecision --jq '.[0] // empty
      | "\(.number)|\(if .isDraft then "draft"
          elif .reviewDecision == "APPROVED" then "approved"
          elif .reviewDecision == "CHANGES_REQUESTED" then "changes_requested"
          elif .reviewDecision == "REVIEW_REQUIRED" then "pending"
          else "" end)"' 2>/dev/null)
  case "$res" in [0-9]*'|'*) printf '%s' "$res" ;; esac
}
# .pr reste attache a la session apres le merge : son etat sert a masquer une PR mergee ou fermee.
fetch_pr_state() {
  timeout 15 gh pr view "$1" ${ci_repo_full:+-R "$ci_repo_full"} --json state --jq .state 2>/dev/null
}
ci_repo_full=""
ci_owner=$(j '.workspace.repo.owner'); ci_rname=$(j '.workspace.repo.name')
[ -n "$ci_owner" ] && [ -n "$ci_rname" ] && ci_repo_full="${ci_owner}/${ci_rname}"

# Le compte gh actif peut ne pas voir le depot : retenir (cache 1 jour) le compte qui y a acces.
if [ -n "$ci_repo_full" ] && command -v gh >/dev/null 2>&1; then
  gh_user_f="$cache_dir/ghuser-$(printf '%s' "$ci_repo_full" | tr -c 'A-Za-z0-9._-' '_')"
  if [ $(( $(date +%s) - $(stat -c %Y "$gh_user_f" 2>/dev/null || echo 0) )) -ge 86400 ]; then
    mkdir -p "${gh_user_f%/*}" 2>/dev/null
    for u in $(gh auth status 2>/dev/null | sed -n 's/.* account \([^ ]*\) .*/\1/p'); do
      GH_TOKEN=$(gh auth token --user "$u" 2>/dev/null) timeout 5 gh api "repos/$ci_repo_full" --silent >/dev/null 2>&1 \
        && { printf '%s\n' "$u" > "$gh_user_f"; break; }
    done
    [ -s "$gh_user_f" ] || : > "$gh_user_f"
  fi
  gh_user=$(head -n1 "$gh_user_f" 2>/dev/null)
  [ -n "$gh_user" ] && GH_TOKEN=$(gh auth token --user "$gh_user" 2>/dev/null) && export GH_TOKEN
fi

if [ -n "$pr_num" ] && [ "$pr_kind" != "mr" ] && command -v gh >/dev/null 2>&1; then
  case "$(cached state "$pr_num" fetch_pr_state "$pr_num")" in MERGED|CLOSED) pr_num=""; pr_review="" ;; esac
fi

if [ -z "$pr_num" ] && [ -n "$branch" ] && git -C "$cwd" --no-optional-locks symbolic-ref -q HEAD >/dev/null 2>&1 \
  && command -v gh >/dev/null 2>&1; then
  IFS='|' read -r pr_num pr_review <<< "$(cached pr "$branch" fetch_branch_pr "$branch")"
fi

# Ligne 1 : projet
l1=""
[ -n "$repo" ] && l1="📁 ${BLUE}${repo}${R}"
if [ -n "$branch" ]; then
  g="🌿 ${CYAN}${branch}${R}"
  gs=""
  [ "${staged:-0}" -gt 0 ] && gs="${gs} ${GREEN}+${staged}${R}"
  [ "${modified:-0}" -gt 0 ] && gs="${gs} ${YELLOW}~${modified}${R}"
  [ -z "$gs" ] && gs=" ✅"
  l1="${l1:+$l1 }${g}${gs}"
fi
if [ -n "$pr_num" ]; then
  if [ "$pr_kind" = "mr" ]; then pr_label="MR !${pr_num}"; else pr_label="PR #${pr_num}"; fi
  pr_rs_txt=""
  case "$pr_review" in
    approved)          pr_rs_txt="${GREEN}✔ approuvée${R}" ;;
    changes_requested) pr_rs_txt="${RED}✖ modifs demandées${R}" ;;
    pending)           pr_rs_txt="${YELLOW}⏳ en attente${R}" ;;
    draft)             pr_rs_txt="${GRAY}✎ brouillon${R}" ;;
  esac
  pr_ci_txt=""; pr_th_txt=""
  if [ "$pr_kind" != "mr" ] && command -v gh >/dev/null 2>&1; then
    ci_state=$(cached ci "$pr_num" fetch_ci_state "$pr_num")
    case "$ci_state" in
      pass)    pr_ci_txt="${GREEN}● CI ok${R}" ;;
      fail)    pr_ci_txt="${RED}● CI ko${R}" ;;
      pending) pr_ci_txt="${YELLOW}● CI…${R}" ;;
    esac
    th=$(cached threads "$pr_num" fetch_threads_count "$pr_num")
    case "$th" in ''|*[!0-9]*) ;; *) [ "$th" -gt 0 ] && pr_th_txt="${YELLOW}💬 ${th}${R}" ;; esac
  fi
  l1="${l1:+$l1 }🔀 ${MAGENTA}${pr_label}${R}${pr_rs_txt:+ $pr_rs_txt}${pr_ci_txt:+ $pr_ci_txt}${pr_th_txt:+ $pr_th_txt}"
fi
m=""
[ -n "$model" ] && m="${model}"
[ -n "$effort" ] && m="${m:+$m }(${effort})"
[ -n "$m" ] && l1="${l1:+$l1$sep}🤖 ${GRAY}${m}${R}"

# Ligne 2 : metriques
l2=""
if [ -n "$ctx" ]; then
  p=${ctx%.*}; [ -z "$p" ] && p=0
  fill=$(( (p * 10 + 50) / 100 )); [ "$fill" -gt 10 ] && fill=10
  bar=""
  for i in 1 2 3 4 5 6 7 8 9 10; do
    if [ "$i" -le "$fill" ]; then bar="${bar}█"; else bar="${bar}░"; fi
  done
  c=$(color_for "$p")
  l2="🧠 ${GRAY}ctx${R} ${c}${bar} ${p}%${R}"
fi
if [ -n "$tok_in" ]; then
  fmt_tok() { awk -v n="${1:-0}" 'BEGIN{ if (n>=1000000) printf "%.1fM", n/1e6; else if (n>=1000) printf "%.1fk", n/1e3; else printf "%d", n }'; }
  l2="${l2:+$l2$sep}🔢 ${GRAY}tokens${R} $(fmt_tok "$tok_in") ${GRAY}in${R} / $(fmt_tok "$tok_out") ${GRAY}out${R}"
fi
if [ -n "$cost" ]; then
  l2="${l2:+$l2$sep}💰 ${YELLOW}\$$(printf '%.2f' "$cost" 2>/dev/null)${R}"
fi
if [ -n "$five" ]; then
  c=$(color_for "$five")
  rs=$(fmt_reset "$five_at")
  l2="${l2:+$l2$sep}⏱ ${GRAY}5h${R} ${c}$(printf '%.0f' "$five")%${R}${rs:+ ${GRAY}reset dans ${rs}${R}}"
fi
if [ -n "$week" ]; then
  c=$(color_for "$week")
  rs=$(fmt_reset "$week_at")
  l2="${l2:+$l2$sep}📅 ${GRAY}7j${R} ${c}$(printf '%.0f' "$week")%${R}${rs:+ ${GRAY}reset dans ${rs}${R}}"
fi

[ -n "$l1" ] && printf '%s\n' "$l1"
[ -n "$l2" ] && printf '%s\n' "$l2"
exit 0
