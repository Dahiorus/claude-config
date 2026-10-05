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
cost=$(j '.cost.total_cost_usd')
five=$(j '.rate_limits.five_hour.used_percentage')
five_at=$(j '.rate_limits.five_hour.resets_at')
week=$(j '.rate_limits.seven_day.used_percentage')
week_at=$(j '.rate_limits.seven_day.resets_at')

export LC_NUMERIC=C

branch=""; staged=0; modified=0
if [ -n "$cwd" ]; then
  cache="/tmp/statusline-git-$(id -u)-$(printf '%s' "$cwd" | cksum | cut -d' ' -f1)"
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

# Etat CI de la PR : cache fichier (TTL 60 s), rafraichi en arriere-plan.
# Affiche la valeur en cache (meme perimee) : pass | fail | pending | (vide)
pr_ci_state() {
  local num=$1 dir key f age lock slug
  dir="${XDG_CACHE_HOME:-$HOME/.cache}/claude-statusline"
  slug="${ci_repo_full:-$(printf '%s' "$cwd" | cksum | cut -d' ' -f1)}"
  key=$(printf '%s' "${slug}-${num}" | tr -c 'A-Za-z0-9._-' '_')
  f="$dir/ci-$key"; lock="$f.lock"
  mkdir -p "$dir" 2>/dev/null || return
  age=$(( $(date +%s) - $(stat -c %Y "$f" 2>/dev/null || echo 0) ))
  if [ "$age" -ge 60 ]; then
    # verrou perime apres 30 s
    if [ -e "$lock" ] && [ $(( $(date +%s) - $(stat -c %Y "$lock" 2>/dev/null || echo 0) )) -gt 30 ]; then
      rm -f "$lock"
    fi
    if ( set -o noclobber; : > "$lock" ) 2>/dev/null; then
      (
        out=$(cd "${cwd:-.}" 2>/dev/null; timeout 15 gh pr checks "$num" ${ci_repo_full:+-R "$ci_repo_full"} --json bucket 2>/dev/null)
        st=""
        if printf '%s' "$out" | jq -e 'type=="array"' >/dev/null 2>&1; then
          st=$(printf '%s' "$out" | jq -r '
            [.[].bucket] as $b
            | if ($b | map(select(. == "fail" or . == "cancel")) | length) > 0 then "fail"
              elif ($b | map(select(. == "pending")) | length) > 0 then "pending"
              elif ($b | map(select(. == "pass")) | length) > 0 then "pass"
              else "" end')
        fi
        printf '%s\n' "$st" > "$f.tmp.$$" 2>/dev/null && mv -f "$f.tmp.$$" "$f"
        rm -f "$lock"
      ) >/dev/null 2>&1 &
      disown 2>/dev/null
    fi
  fi
  [ -r "$f" ] && head -n1 "$f"
}
# Fils de revue non resolus : meme mecanisme (cache 60 s, arriere-plan, verrou, timeout).
# Affiche le nombre en cache (vide si inconnu / echec).
pr_threads_count() {
  local num=$1 dir key f age lock slug
  dir="${XDG_CACHE_HOME:-$HOME/.cache}/claude-statusline"
  slug="${ci_repo_full:-$(printf '%s' "$cwd" | cksum | cut -d' ' -f1)}"
  key=$(printf '%s' "${slug}-${num}" | tr -c 'A-Za-z0-9._-' '_')
  f="$dir/threads-$key"; lock="$f.lock"
  mkdir -p "$dir" 2>/dev/null || return
  age=$(( $(date +%s) - $(stat -c %Y "$f" 2>/dev/null || echo 0) ))
  if [ "$age" -ge 60 ]; then
    if [ -e "$lock" ] && [ $(( $(date +%s) - $(stat -c %Y "$lock" 2>/dev/null || echo 0) )) -gt 30 ]; then
      rm -f "$lock"
    fi
    if ( set -o noclobber; : > "$lock" ) 2>/dev/null; then
      (
        cd "${cwd:-.}" 2>/dev/null
        nwo="$ci_repo_full"
        [ -z "$nwo" ] && nwo=$(timeout 10 gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null)
        cnt=""
        case "$nwo" in
          */*)
            out=$(timeout 15 gh api graphql \
              -f query='query($o:String!,$n:String!,$p:Int!){repository(owner:$o,name:$n){pullRequest(number:$p){reviewThreads(first:100){nodes{isResolved}}}}}' \
              -F o="${nwo%%/*}" -F n="${nwo#*/}" -F p="$num" \
              --jq '[.data.repository.pullRequest.reviewThreads.nodes[]|select(.isResolved|not)]|length' 2>/dev/null)
            case "$out" in ''|*[!0-9]*) ;; *) cnt="$out" ;; esac
            ;;
        esac
        printf '%s\n' "$cnt" > "$f.tmp.$$" 2>/dev/null && mv -f "$f.tmp.$$" "$f"
        rm -f "$lock"
      ) >/dev/null 2>&1 &
      disown 2>/dev/null
    fi
  fi
  [ -r "$f" ] && head -n1 "$f"
}
ci_repo_full=""
ci_owner=$(j '.workspace.repo.owner'); ci_rname=$(j '.workspace.repo.name')
[ -n "$ci_owner" ] && [ -n "$ci_rname" ] && ci_repo_full="${ci_owner}/${ci_rname}"

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
    ci_state=$(pr_ci_state "$pr_num")
    case "$ci_state" in
      pass)    pr_ci_txt="${GREEN}● CI ok${R}" ;;
      fail)    pr_ci_txt="${RED}● CI ko${R}" ;;
      pending) pr_ci_txt="${YELLOW}● CI…${R}" ;;
    esac
    th=$(pr_threads_count "$pr_num")
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
