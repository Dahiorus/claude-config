# shellcheck shell=bash
# Fonctions gh de statusline-command.sh, qui le source : $cwd, $cache_dir, $ci_repo_full viennent de lui.
# shellcheck disable=SC2154

# Etat CI de la PR : pass | fail | pending | (vide)
# shellcheck disable=SC2329 # appelée par cached, via "$@"
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
# Nombre de fils de revue en attente du compte de la statusline (vide si inconnu).
# shellcheck disable=SC2329 # appelée par cached, via "$@"
fetch_threads_count() {
  local nwo="$ci_repo_full" out
  [ -z "$nwo" ] && nwo=$(timeout 10 gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null)
  case "$nwo" in */*) ;; *) return ;; esac
  # shellcheck disable=SC2016 # variables GraphQL, pas du shell
  out=$(timeout 15 gh api graphql \
    -f query='query($o:String!,$n:String!,$p:Int!){repository(owner:$o,name:$n){pullRequest(number:$p){reviewThreads(first:100){nodes{isResolved all:comments{totalCount} first:comments(first:1){nodes{author{__typename}}} last:comments(last:1){nodes{author{login}}}}}}}viewer{login}}' \
    -F o="${nwo%%/*}" -F n="${nwo#*/}" -F p="$1" \
    2>/dev/null | jq -r '
      .data.viewer.login as $me
      | [.data.repository.pullRequest.reviewThreads.nodes[]
         | select((.isResolved | not)
                  and ((.first.nodes[0].author.__typename // "") != "Bot")
                  and ((.last.nodes[0].author.login // "") != $me or .all.totalCount < 2))]
      | length' 2>/dev/null)
  case "$out" in ''|*[!0-9]*) ;; *) printf '%s' "$out" ;; esac
}
# Repli si Claude Code ne transmet pas .pr : "numero|review_state" de la PR ouverte de la branche.
# shellcheck disable=SC2329 # appelée par cached, via "$@"
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
# shellcheck disable=SC2329 # appelée par cached, via "$@"
fetch_pr_state() {
  timeout 15 gh pr view "$1" ${ci_repo_full:+-R "$ci_repo_full"} --json state --jq .state 2>/dev/null
}
# Sonde : ecrit le compte gh qui voit $ci_repo_full (vide si aucun), cache d'un jour dans $cache_dir.
probe_gh_user() {
  local cache_file account token
  cache_file="$cache_dir/ghuser-$(printf '%s' "$ci_repo_full" | tr -c 'A-Za-z0-9._-' '_')"
  if [ $(( $(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || echo 0) )) -lt 86400 ]; then
    head -n1 "$cache_file"
    return
  fi
  mkdir -p "${cache_file%/*}" 2>/dev/null
  for account in $(gh auth status 2>/dev/null | sed -n 's/.* account \([^ ]*\) .*/\1/p'); do
    token=$(token_for "$account") || continue  # GH_TOKEN vide : gh prendrait le compte actif
    GH_TOKEN=$token timeout 5 gh api "repos/$ci_repo_full" --silent >/dev/null 2>&1 \
      && { printf '%s\n' "$account" > "$cache_file"; break; }
  done
  [ -s "$cache_file" ] || : > "$cache_file"
  head -n1 "$cache_file" 2>/dev/null
}
token_for() {  # <compte> : écrit son jeton (rien si compte vide ou sans jeton)
  [ -n "$1" ] && gh auth token --user "$1" 2>/dev/null
}
# Compte gh : celui du profil du projet d'abord, sinon sonde des comptes (cache 1 jour) ; jeton exporte pour ce seul processus.
select_gh_token() {
  local token="" gh_user=""
  command -v gh >/dev/null 2>&1 || return 0
  if [ -n "$cwd" ]; then
    gh_user=$(bash "$(dirname "$(readlink -f "$0")")/profile.sh" account "$cwd" 2>/dev/null)
    token=$(token_for "$gh_user")
  fi
  if [ -z "$token" ] && [ -n "$ci_repo_full" ]; then
    gh_user=$(probe_gh_user)
    token=$(token_for "$gh_user")
  fi
  [ -n "$token" ] && export GH_TOKEN="$token"
  return 0
}
