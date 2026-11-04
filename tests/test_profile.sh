# shellcheck shell=bash
# shellcheck disable=SC2154

profile() { bash "$REPO/global/profile.sh" "$@"; }

repo_with_origin() {  # <dossier> <url>
  mkdir -p "$1" && git -C "$1" init -q && git -C "$1" remote add origin "$2"
}

test_profile_detect_https_owner() {
  repo_with_origin "$SANDBOX/p" https://github.com/Dahiorus/x.git
  assert_eq "$(profile detect "$SANDBOX/p")" "perso" "profil"
}

test_profile_detect_ssh_owner() {
  repo_with_origin "$SANDBOX/a" git@github.com:softwarevidal/y.git
  repo_with_origin "$SANDBOX/b" ssh://git@github.com/tuonick/z.git
  assert_eq "$(profile detect "$SANDBOX/a")" "vidal" "scp"
  assert_eq "$(profile detect "$SANDBOX/b")" "perso" "ssh"
}

test_profile_detect_unknown_owner_or_host() {
  repo_with_origin "$SANDBOX/a" https://github.com/someone/x.git
  repo_with_origin "$SANDBOX/b" https://gitlab.com/Dahiorus/x.git
  mkdir -p "$SANDBOX/c"
  assert_eq "$(profile detect "$SANDBOX/a")" "" "autre propriétaire"
  assert_eq "$(profile detect "$SANDBOX/b")" "" "autre hôte"
  assert_eq "$(profile detect "$SANDBOX/c")" "" "pas de git"
}

test_profile_account_follows_owner() {
  repo_with_origin "$SANDBOX/p" https://github.com/Dahiorus/x.git
  repo_with_origin "$SANDBOX/v" https://github.com/softwarevidal/y.git
  assert_eq "$(profile account "$SANDBOX/p")" "Dahiorus" "perso"
  assert_eq "$(profile account "$SANDBOX/v")" "brondon-ung" "vidal"
}

test_profile_account_in_worktree_subdir() {
  repo_with_origin "$SANDBOX/p" https://github.com/Dahiorus/x.git
  git -C "$SANDBOX/p" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
  git -C "$SANDBOX/p" worktree add -q "$SANDBOX/wt" -b w
  mkdir -p "$SANDBOX/wt/sub"
  assert_eq "$(profile account "$SANDBOX/wt/sub")" "Dahiorus" "worktree"
}

local_settings() { cat "$1/.claude/settings.local.json"; }

test_profile_apply_merges_existing_settings() {
  repo_with_origin "$SANDBOX/p" https://github.com/Dahiorus/x.git
  mkdir -p "$SANDBOX/p/.claude"
  printf '%s\n' '{"permissions":{"allow":["Bash(ls)"]},"env":{"A":"1"}}' > "$SANDBOX/p/.claude/settings.local.json"
  profile apply perso "$SANDBOX/p"
  local s; s="$(local_settings "$SANDBOX/p")"
  assert_eq "$(jq -r '.permissions.allow[0]' <<<"$s")" "Bash(ls)" "permissions"
  assert_eq "$(jq -r '.env.A + .env.CLAUDE_PROFILE' <<<"$s")" "1perso" "env"
  assert_eq "$(jq -r '.enabledPlugins["php-lsp@claude-plugins-official"]' <<<"$s")" "true" "php-lsp"
  assert_eq "$(jq -r '.skillOverrides["angular-developer"]' <<<"$s")" "off" "angular"
}

test_profile_apply_rejects_unknown_profile() {
  mkdir -p "$SANDBOX/p"
  local rc=0 err; err="$(profile apply inconnu "$SANDBOX/p" 2>&1)" || rc=$?
  assert_eq "$rc" "2" "code"
  assert_contains "$err" "connus : perso, vidal"
  [[ ! -e "$SANDBOX/p/.claude/settings.local.json" ]] || fail "fichier écrit"
}

test_profile_apply_keeps_invalid_json() {
  mkdir -p "$SANDBOX/p/.claude" && printf '{oops' > "$SANDBOX/p/.claude/settings.local.json"
  local rc=0; profile apply perso "$SANDBOX/p" 2>/dev/null || rc=$?
  assert_eq "$rc" "1" "code"
  assert_eq "$(cat "$SANDBOX/p/.claude/settings.local.json")" "{oops" "contenu"
}

test_profile_apply_excludes_file_from_git() {
  repo_with_origin "$SANDBOX/p" https://github.com/Dahiorus/x.git
  profile apply perso "$SANDBOX/p"
  profile apply perso "$SANDBOX/p"
  assert_eq "$(grep -c '^\.claude/settings\.local\.json$' "$SANDBOX/p/.git/info/exclude")" "1" "une ligne"
}

test_profile_apply_respects_gitignore() {
  repo_with_origin "$SANDBOX/p" https://github.com/Dahiorus/x.git
  printf '.claude/settings.local.json\n' > "$SANDBOX/p/.gitignore"
  profile apply perso "$SANDBOX/p"
  assert_not_contains "$(cat "$SANDBOX/p/.git/info/exclude")" "settings.local.json"
}

test_profile_apply_local_project_without_git() {
  mkdir -p "$SANDBOX/local"
  profile apply vidal "$SANDBOX/local"
  assert_eq "$(profile current "$SANDBOX/local")" "vidal" "profil"
}

session_start_in() { jq -nc --arg d "$1" '{cwd:$d}' | profile session-start; }

test_profile_session_start_applies_once() {
  repo_with_origin "$SANDBOX/v" https://github.com/softwarevidal/y.git
  assert_contains "$(session_start_in "$SANDBOX/v")" "Profil vidal appliqué"
  assert_eq "$(session_start_in "$SANDBOX/v")" "" "deuxième démarrage"
}

test_profile_session_start_keeps_manual_choice() {
  repo_with_origin "$SANDBOX/p" https://github.com/Dahiorus/x.git
  profile apply vidal "$SANDBOX/p"
  assert_eq "$(session_start_in "$SANDBOX/p")" "" "message"
  assert_eq "$(profile current "$SANDBOX/p")" "vidal" "choix gardé"
  assert_eq "$(profile account "$SANDBOX/p")" "Dahiorus" "compte du dépôt"
}

test_profile_session_start_ignores_unknown_repo() {
  repo_with_origin "$SANDBOX/o" https://github.com/someone/x.git
  assert_eq "$(session_start_in "$SANDBOX/o")" "" "message"
  [[ ! -e "$SANDBOX/o/.claude" ]] || fail "dossier .claude créé"
}

test_profile_session_start_in_worktree() {
  repo_with_origin "$SANDBOX/p" https://github.com/Dahiorus/x.git
  git -C "$SANDBOX/p" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
  git -C "$SANDBOX/p" worktree add -q "$SANDBOX/wt" -b w
  assert_contains "$(session_start_in "$SANDBOX/wt")" "Profil perso appliqué"
  assert_eq "$(profile current "$SANDBOX/wt")" "perso" "profil du worktree"
  assert_eq "$(profile account "$SANDBOX/wt")" "Dahiorus" "compte"
  assert_eq "$(git -C "$SANDBOX/wt" status --short)" "" "fichier exclu de git status"
}

test_profile_apply_drops_other_profile_overrides() {
  profile apply perso "$SANDBOX/p"
  profile apply vidal "$SANDBOX/p"
  assert_eq "$(jq -c .skillOverrides "$SANDBOX/p/.claude/settings.local.json")" "{}" "angular-developer retiré"
}

test_profile_apply_keeps_user_overrides_on_switch() {
  mkdir -p "$SANDBOX/p/.claude"
  printf '%s\n' '{"skillOverrides":{"mine":"off"}}' > "$SANDBOX/p/.claude/settings.local.json"
  profile apply perso "$SANDBOX/p"
  profile apply vidal "$SANDBOX/p"
  assert_eq "$(jq -c .skillOverrides "$SANDBOX/p/.claude/settings.local.json")" '{"mine":"off"}' "clé utilisateur"
}

test_profile_session_start_reports_invalid_json() {
  repo_with_origin "$SANDBOX/p" https://github.com/Dahiorus/x.git
  mkdir -p "$SANDBOX/p/.claude" && printf '{oops' > "$SANDBOX/p/.claude/settings.local.json"
  assert_contains "$(session_start_in "$SANDBOX/p" 2>/dev/null)" "non appliqué"
}

test_profile_apply_exclude_without_trailing_newline() {
  repo_with_origin "$SANDBOX/p" https://github.com/Dahiorus/x.git
  printf 'foo' > "$SANDBOX/p/.git/info/exclude"
  profile apply perso "$SANDBOX/p"
  assert_eq "$(head -1 "$SANDBOX/p/.git/info/exclude")" "foo" "motif gardé"
  assert_eq "$(grep -c '^\.claude/settings\.local\.json$' "$SANDBOX/p/.git/info/exclude")" "1" "ligne propre"
}

test_profile_apply_empty_file_is_empty_object() {
  mkdir -p "$SANDBOX/p/.claude" && : > "$SANDBOX/p/.claude/settings.local.json"
  profile apply perso "$SANDBOX/p"
  assert_eq "$(profile current "$SANDBOX/p")" "perso" "profil"
}

test_profile_apply_blank_file_is_empty_object() {
  mkdir -p "$SANDBOX/p/.claude" && printf '\n  \n' > "$SANDBOX/p/.claude/settings.local.json"
  profile apply perso "$SANDBOX/p"
  assert_eq "$(profile current "$SANDBOX/p")" "perso" "profil"
}

test_profile_detect_ignores_owner_case() {
  repo_with_origin "$SANDBOX/p" https://github.com/dahiorus/x.git
  assert_eq "$(profile detect "$SANDBOX/p")" "perso" "profil"
}

test_profile_account_rejects_unsafe_name() {
  repo_with_origin "$SANDBOX/p" https://github.com/Dahiorus/x.git
  jq '.perso.account = "a\";touch pwned;\""' "$REPO/global/profiles.json" > "$SANDBOX/profiles.json"
  assert_eq "$(PROFILES_FILE="$SANDBOX/profiles.json" profile account "$SANDBOX/p" 2>/dev/null)" "" "compte refusé"
}
