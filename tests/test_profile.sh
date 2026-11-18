# shellcheck shell=bash
# shellcheck disable=SC2154

profile() { PROFILES_FILE="${PROFILES_FILE:-$REPO/global/profiles.json}" bash "$REPO/global/profile.sh" "$@"; }

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
  mkdir -p "$SANDBOX/c" "$SANDBOX/d"; git -C "$SANDBOX/d" init -q
  assert_eq "$(profile detect "$SANDBOX/a")" "" "autre propriétaire"
  assert_eq "$(profile detect "$SANDBOX/b")" "" "autre hôte"
  assert_eq "$(profile detect "$SANDBOX/c")" "" "pas de git"
  local rc=0 out; out=$(profile detect "$SANDBOX/d" 2>&1) || rc=$?
  assert_eq "$rc:$out" "0:" "dépôt sans origin"
  rc=0; out=$(profile detect "$SANDBOX/absent" 2>&1) || rc=$?
  assert_eq "$rc:$out" "0:" "dossier absent"
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

# Entrée en here-string, pas en pipe : un hook qui sort sans la lire tuerait jq (SIGPIPE, 141 sous pipefail).
session_start_in() { profile session-start <<<"$(jq -nc --arg d "$1" '{cwd:$d}')"; }

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

test_profile_session_start_reports_apply_failure_cause() {   # PR 143 : la cause, pas « illisible »
  repo_with_origin "$SANDBOX/p" https://github.com/Dahiorus/x.git
  : > "$SANDBOX/p/.claude"   # fichier à la place du dossier : mkdir échoue
  local out; out=$(session_start_in "$SANDBOX/p" 2>/dev/null)
  assert_contains "$out" "mkdir"
  [[ "$out" != *"illisible"* ]] || fail "cause remplacée par « illisible »"
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

# Profil vidal muni d'un secret S lu dans ~/.claude/s.token (plus aucun profil réel n'a de secretEnv).
secret_profiles() {
  jq '.vidal.secretEnv = {"S": "~/.claude/s.token"}' "$REPO/global/profiles.json" > "$SANDBOX/profiles.json"
  export PROFILES_FILE="$SANDBOX/profiles.json"
}

test_profile_apply_vidal_sets_no_telemetry() {
  mkdir -p "$SANDBOX/p/.claude"
  printf '%s\n' '{"env":{"A":"1"}}' > "$SANDBOX/p/.claude/settings.local.json"
  local err; err=$(profile apply vidal "$SANDBOX/p" 2>&1)
  assert_eq "$err" "" "aucun avertissement"
  assert_eq "$(jq -cS '.env' "$SANDBOX/p/.claude/settings.local.json")" '{"A":"1","CLAUDE_PROFILE":"vidal"}' "env"
}

# Claude Code ignore CLAUDE_CODE_ENABLE_TELEMETRY dans un fichier projet ; seul un exporteur à none y est lu.
test_profile_apply_perso_cuts_telemetry() {
  mkdir -p "$SANDBOX/p"
  profile apply perso "$SANDBOX/p"
  assert_eq "$(jq -cS '.env' "$SANDBOX/p/.claude/settings.local.json")" \
    '{"CLAUDE_PROFILE":"perso","OTEL_LOGS_EXPORTER":"none","OTEL_METRICS_EXPORTER":"none"}' "coupure"
  profile apply vidal "$SANDBOX/p"
  assert_eq "$(jq -cS '.env' "$SANDBOX/p/.claude/settings.local.json")" '{"CLAUDE_PROFILE":"vidal"}' "coupure retirée"
}

test_profile_apply_secret_with_file() {
  secret_profiles
  mkdir -p "$HOME/.claude" "$SANDBOX/p" && printf 's3cret\n' > "$HOME/.claude/s.token"
  local err; err=$(profile apply vidal "$SANDBOX/p" 2>&1)
  assert_eq "$err" "" "aucun avertissement"
  assert_eq "$(jq -r '.env.S' "$SANDBOX/p/.claude/settings.local.json")" "s3cret" "secret lu"
  profile apply perso "$SANDBOX/p"
  assert_eq "$(jq -r '.env.S // "absent"' "$SANDBOX/p/.claude/settings.local.json")" "absent" "secret retiré en perso"
}

test_profile_apply_secret_without_file_warns() {
  secret_profiles
  mkdir -p "$SANDBOX/p"
  local err; err=$(profile apply vidal "$SANDBOX/p" 2>&1)
  assert_contains "$err" "S omise"
  local s; s="$(local_settings "$SANDBOX/p")"
  assert_eq "$(jq -r '.env.S // "absent"' <<<"$s")" "absent" "secret"
  assert_eq "$(jq -r '.env.CLAUDE_PROFILE' <<<"$s")" "vidal" "profil appliqué"
}

test_profile_session_start_reports_missing_secret() {
  secret_profiles
  repo_with_origin "$SANDBOX/v" https://github.com/softwarevidal/y.git
  assert_contains "$(session_start_in "$SANDBOX/v")" "s.token absent"
}

# Réglages utilisateur pour telemetry : <env JSON>
user_settings() { mkdir -p "$HOME/.claude" && jq -n --argjson env "$1" '{env: $env}' > "$HOME/.claude/settings.json"; }

test_profile_telemetry_status() {
  mkdir -p "$SANDBOX/p"
  assert_eq "$(profile telemetry "$SANDBOX/p")" "off" "sans réglages"
  user_settings '{"CLAUDE_CODE_ENABLE_TELEMETRY":"1"}'
  assert_eq "$(profile telemetry "$SANDBOX/p")" "sans jeton" "sans en-tête"
  user_settings '{"CLAUDE_CODE_ENABLE_TELEMETRY":"1","OTEL_EXPORTER_OTLP_METRICS_HEADERS":"Authorization=Bearer x"}'
  assert_eq "$(profile telemetry "$SANDBOX/p")" "on" "réglages utilisateur"
  profile apply vidal "$SANDBOX/p"
  assert_eq "$(profile telemetry "$SANDBOX/p")" "on" "vidal"
  profile apply perso "$SANDBOX/p"
  assert_eq "$(profile telemetry "$SANDBOX/p")" "off" "perso"
  user_settings '{"CLAUDE_CODE_ENABLE_TELEMETRY":"0"}'
  profile apply vidal "$SANDBOX/p"
  assert_eq "$(profile telemetry "$SANDBOX/p")" "off" "coupée par l'utilisateur"
  local on='{"CLAUDE_CODE_ENABLE_TELEMETRY":"1","OTEL_EXPORTER_OTLP_METRICS_HEADERS":"x"}'
  user_settings "$(jq -c '.OTEL_METRICS_EXPORTER = "none"' <<<"$on")"
  assert_eq "$(profile telemetry "$SANDBOX/p")" "off" "exporteur coupé par l'utilisateur"
  jq -n '{env: {CLAUDE_PROFILE: "vidal", OTEL_METRICS_EXPORTER: "otlp"}}' > "$SANDBOX/p/.claude/settings.local.json"
  assert_eq "$(profile telemetry "$SANDBOX/p")" "off" "coupure utilisateur malgré un projet à otlp"
  mkdir -p "$SANDBOX/cfg" && jq -n --argjson env "$on" '{env: $env}' > "$SANDBOX/cfg/settings.json"
  assert_eq "$(CLAUDE_CONFIG_DIR="$SANDBOX/cfg" profile telemetry "$SANDBOX/p")" "on" "dossier de config"
}

# Clés de l'ancien profil vidal, ignorées par Claude Code dans un fichier projet : jeton compris, retirées.
test_profile_apply_drops_ignored_telemetry_keys() {
  mkdir -p "$SANDBOX/p/.claude"
  printf '%s\n' '{"env":{"A":"1","CLAUDE_CODE_ENABLE_TELEMETRY":"1","OTEL_EXPORTER_OTLP_METRICS_HEADERS":"Bearer vieux",
    "OTEL_EXPORTER_OTLP_METRICS_ENDPOINT":"e","OTEL_EXPORTER_OTLP_METRICS_PROTOCOL":"p",
    "OTEL_METRICS_INCLUDE_REPOSITORY":"true","CLAUDE_PROFILE":"vidal"}}' > "$SANDBOX/p/.claude/settings.local.json"
  profile apply vidal "$SANDBOX/p"
  assert_eq "$(jq -cS '.env' "$SANDBOX/p/.claude/settings.local.json")" '{"A":"1","CLAUDE_PROFILE":"vidal"}' "nettoyé"
}

test_profile_apply_blank_secret_file_is_missing() {
  secret_profiles
  mkdir -p "$HOME/.claude" "$SANDBOX/p"
  local content
  for content in '' '\n' '  \n'; do
    printf '%b' "$content" > "$HOME/.claude/s.token"
    assert_contains "$(profile apply vidal "$SANDBOX/p" 2>&1)" "absent ou vide"
    assert_eq "$(jq -r '.env.S // "absent"' "$SANDBOX/p/.claude/settings.local.json")" "absent" "fichier [$content]"
  done
}

test_profile_apply_secret_drops_trailing_blanks() {
  secret_profiles
  mkdir -p "$HOME/.claude" "$SANDBOX/p" && printf 'a b\n\n' > "$HOME/.claude/s.token"
  profile apply vidal "$SANDBOX/p"
  assert_eq "$(jq -c '.env.S' "$SANDBOX/p/.claude/settings.local.json")" '"a b"' "blancs finaux retirés"
}

test_profile_apply_rejects_non_object_secret_env() {
  mkdir -p "$SANDBOX/p"
  jq '.vidal.secretEnv = "oops"' "$REPO/global/profiles.json" > "$SANDBOX/profiles.json"
  local rc=0 err; err=$(PROFILES_FILE="$SANDBOX/profiles.json" profile apply vidal "$SANDBOX/p" 2>&1) || rc=$?
  assert_eq "$rc" "1" "code"
  assert_contains "$err" "secretEnv doit être un objet"
  [[ ! -e "$SANDBOX/p/.claude/settings.local.json" ]] || fail "fichier écrit"
}

test_profile_apply_drops_secret_without_file() {
  secret_profiles
  mkdir -p "$SANDBOX/p/.claude"
  printf '%s\n' '{"env":{"S":"vieux"}}' > "$SANDBOX/p/.claude/settings.local.json"
  profile apply vidal "$SANDBOX/p" 2>/dev/null
  assert_eq "$(jq -r '.env.S // "absent"' "$SANDBOX/p/.claude/settings.local.json")" "absent" "secret périmé retiré"
}

test_profile_global_path_is_link() {
  assert_symlink_to "$REPO/global/profile.sh" "../mods/profile/scripts/profile.sh"
}

test_profile_reads_config_dir_profiles() {
  repo_with_origin "$SANDBOX/p" https://github.com/Dahiorus/x.git
  mkdir -p "$SANDBOX/cfg" && cp "$REPO/global/profiles.json" "$SANDBOX/cfg/"
  assert_eq "$(CLAUDE_CONFIG_DIR="$SANDBOX/cfg" bash "$REPO/global/profile.sh" detect "$SANDBOX/p")" "perso" "config"
}

test_profile_without_profiles_file_is_silent() {   # HOME du bac à sable : pas de profiles.json
  repo_with_origin "$SANDBOX/p" https://github.com/Dahiorus/x.git
  local p="$REPO/global/profile.sh"
  assert_eq "$(bash "$p" detect "$SANDBOX/p" 2>&1)" "" "detect"
  assert_eq "$(bash "$p" account "$SANDBOX/p" 2>&1)" "" "account"
  assert_eq "$(jq -nc --arg d "$SANDBOX/p" '{cwd:$d}' | bash "$p" session-start 2>&1)" "" "session-start"
  [[ ! -e "$SANDBOX/p/.claude" ]] || fail "profil appliqué sans profiles.json"
}

test_profile_apply_without_profiles_file_fails() {
  mkdir -p "$SANDBOX/p"
  local rc=0 err; err=$(bash "$REPO/global/profile.sh" apply perso "$SANDBOX/p" 2>&1) || rc=$?
  assert_eq "$rc" "1" "code"
  assert_contains "$err" "profiles.json introuvable"
}

bad_profiles() { jq "$1" "$REPO/global/profiles.json" > "$SANDBOX/bad.json"; }
test_profile_rejects_malformed_profiles() {
  repo_with_origin "$SANDBOX/p" https://github.com/Dahiorus/x.git
  local f
  for f in '.perso = null' '.perso.owners = "Dahiorus"' '.perso.owners = [1]' '.perso.env = "x"' \
           '.perso.enabledPlugins = []' '.perso.account = "a b"' '[.]'; do
    bad_profiles "$f"
    local rc=0 err; err=$(PROFILES_FILE="$SANDBOX/bad.json" profile detect "$SANDBOX/p" 2>&1) || rc=$?
    assert_eq "$rc" "1" "code pour $f"
    [[ "$f" == '[.]' ]] || assert_contains "$err" "perso"
    assert_not_contains "$err" "jq: error"
  done
  bad_profiles '.perso.env = "x"'
  local out; out=$(jq -nc --arg d "$SANDBOX/p" '{cwd:$d}' | PROFILES_FILE="$SANDBOX/bad.json" profile session-start)
  assert_contains "$(jq -r .systemMessage <<<"$out")" "perso"
  [[ ! -e "$SANDBOX/p/.claude" ]] || fail "profil appliqué malgré l'erreur"
  local rc=0; PROFILES_FILE="$SANDBOX/bad.json" profile apply vidal "$SANDBOX/p" 2>/dev/null || rc=$?
  assert_eq "$rc" "1" "apply refuse aussi"
  bad_profiles '.perso.account = "a b"'   # défaut que merge_profile laisse passer : seule la validation l'arrête
  rc=0; PROFILES_FILE="$SANDBOX/bad.json" profile apply perso "$SANDBOX/p" 2>/dev/null || rc=$?
  assert_eq "$rc" "1" "apply refuse un compte invalide"
  [[ ! -e "$SANDBOX/p/.claude" ]] || fail "profil appliqué malgré un compte invalide"
}
test_profile_rejects_shared_owner() {
  repo_with_origin "$SANDBOX/p" https://github.com/Dahiorus/x.git
  bad_profiles '.vidal.owners += ["dahiorus"]'
  local rc=0 err; err=$(PROFILES_FILE="$SANDBOX/bad.json" profile detect "$SANDBOX/p" 2>&1) || rc=$?
  assert_eq "$rc" "1" "code"
  assert_contains "$err" "propriétaire dahiorus dans les profils"
  assert_contains "$err" "perso" ; assert_contains "$err" "vidal"
}
test_profile_git_failure_is_reported() {
  repo_with_origin "$SANDBOX/p" https://github.com/Dahiorus/x.git
  mkdir -p "$SANDBOX/empty"; ln -s "$(command -v jq)" "$SANDBOX/empty/jq"   # git introuvable
  local p="$REPO/global/profile.sh" rc=0 err
  err=$(PROFILES_FILE="$REPO/global/profiles.json" PATH="$SANDBOX/empty" "$BASH" "$p" detect "$SANDBOX/p" 2>&1) || rc=$?
  assert_eq "$rc" "1" "code" ; assert_contains "$err" "git"
  local out
  out=$(jq -nc --arg d "$SANDBOX/p" '{cwd:$d}' \
    | PROFILES_FILE="$REPO/global/profiles.json" PATH="$SANDBOX/empty" "$BASH" "$p" session-start)
  assert_contains "$(jq -r .systemMessage <<<"$out")" "git"
}

ss_file() { echo "$SANDBOX/session-env/sessionstart-hook-0.sh"; }  # fichiers à chemin fixe :
cd_file() { echo "$SANDBOX/session-env/cwdchanged-hook-0.sh"; }       # lisibles hors des $(…)
start_with_env() {  # <dossier> : session-start avec un fichier d'env jetable, sortie = systemMessage
  [[ -x "$STUBS/gh" ]] || make_gh_stub   # garde un faux gh modifié par le test
  mkdir -p "$SANDBOX/session-env"
  PATH="$STUBS:$PATH" CLAUDE_ENV_FILE="$(ss_file)" profile session-start <<<"$(jq -nc --arg d "$1" '{cwd:$d}')"
}
test_profile_session_start_exports_token() {
  repo_with_origin "$SANDBOX/v" https://github.com/softwarevidal/y.git
  start_with_env "$SANDBOX/v" >/dev/null
  assert_eq "$(cat "$(ss_file)")" $'# claude-config-profile\nexport GH_TOKEN=\'tok-brondon-ung\'' "fichier"
}
test_profile_env_file_mode_600() {
  repo_with_origin "$SANDBOX/v" https://github.com/softwarevidal/y.git
  mkdir -p "$SANDBOX/session-env"; : > "$SANDBOX/session-env/sessionstart-hook-0.sh"
  chmod 644 "$SANDBOX/session-env/sessionstart-hook-0.sh"
  start_with_env "$SANDBOX/v" >/dev/null
  assert_eq "$(stat -c %a "$(ss_file)")" "600" "mode"
}
test_profile_session_start_account_without_token() {
  repo_with_origin "$SANDBOX/v" https://github.com/softwarevidal/y.git
  local out; out=$(GH_MISSING=brondon-ung start_with_env "$SANDBOX/v")
  assert_contains "$(jq -r .systemMessage <<<"$out")" "brondon-ung"
  assert_contains "$(jq -r .systemMessage <<<"$out")" "gh auth login"
  [[ ! -s "$(ss_file)" ]] || fail "marqueur ou export écrit pour un compte non connecté"
}
test_profile_session_start_reports_gh_failure() {   # PR 143 : trousseau verrouillé ≠ compte non connecté
  repo_with_origin "$SANDBOX/v" https://github.com/softwarevidal/y.git
  local out; out=$(GH_TOKEN_ERROR="Secret Service indisponible" start_with_env "$SANDBOX/v")
  assert_contains "$(jq -r .systemMessage <<<"$out")" "Secret Service indisponible"
  [[ "$(jq -r .systemMessage <<<"$out")" != *"gh auth login"* ]] || fail "conseil gh auth login sur un autre échec"
  [[ ! -s "$(ss_file)" ]] || fail "export écrit malgré l'échec de gh"
}
test_profile_session_start_chmod_failure_writes_no_token() {   # review P1 : protéger avant d'écrire
  repo_with_origin "$SANDBOX/v" https://github.com/softwarevidal/y.git
  make_gh_stub; printf '#!/bin/sh\nexit 1\n' > "$STUBS/chmod"; /bin/chmod +x "$STUBS/chmod"
  local out; out=$(start_with_env "$SANDBOX/v")
  assert_contains "$(jq -r .systemMessage <<<"$out")" "jeton non écrit"
  assert_not_contains "$(cat "$(ss_file)" 2>/dev/null)" "tok-"
}
test_profile_session_start_without_gh() {   # review P3
  repo_with_origin "$SANDBOX/v" https://github.com/softwarevidal/y.git
  mkdir -p "$SANDBOX/nogh" "$SANDBOX/session-env"
  local tool; for tool in jq git dirname chmod; do ln -s "$(command -v "$tool")" "$SANDBOX/nogh/$tool"; done
  local out; out=$(jq -nc --arg d "$SANDBOX/v" '{cwd:$d}' | PROFILES_FILE="$REPO/global/profiles.json" \
    PATH="$SANDBOX/nogh" CLAUDE_ENV_FILE="$(ss_file)" "$BASH" "$REPO/global/profile.sh" session-start)
  assert_contains "$(jq -r .systemMessage <<<"$out")" "gh introuvable"
}
test_profile_session_start_rejects_bad_token() {   # Review Focus 3
  repo_with_origin "$SANDBOX/v" https://github.com/softwarevidal/y.git
  make_gh_stub
  # shellcheck disable=SC2016  # motif sed littéral
  sed -i 's/echo "tok-$4"/echo "x'"'"'y"/' "$STUBS/gh"
  local out; out=$(start_with_env "$SANDBOX/v")
  assert_contains "$(jq -r .systemMessage <<<"$out")" "jeton"
  assert_not_contains "$(cat "$(ss_file)" 2>/dev/null)" "export"
}
test_profile_session_start_token_follows_detected() {   # profil appliqué perso dans un dépôt vidal
  repo_with_origin "$SANDBOX/v" https://github.com/softwarevidal/y.git
  profile apply perso "$SANDBOX/v"
  start_with_env "$SANDBOX/v" >/dev/null
  assert_contains "$(cat "$(ss_file)")" "tok-brondon-ung"
}
test_profile_session_start_without_env_file() {   # Review Focus 1
  repo_with_origin "$SANDBOX/v" https://github.com/softwarevidal/y.git
  make_gh_stub
  local out; out=$(jq -nc --arg d "$SANDBOX/v" '{cwd:$d}' | PATH="$STUBS:$PATH" profile session-start 2>&1) || fail "code"
  assert_not_contains "$out" "jeton"; assert_not_contains "$out" "CLAUDE_ENV_FILE"
}
test_profile_session_start_no_profile_writes_nothing() {
  repo_with_origin "$SANDBOX/o" https://github.com/someone/x.git
  start_with_env "$SANDBOX/o" >/dev/null
  [[ ! -s "$(ss_file)" ]] || fail "fichier écrit hors profil"
}
stale_token() {  # jeton laissé par un démarrage vidal précédent (/clear, resume)
  mkdir -p "$SANDBOX/session-env"
  printf '%s\n' '# claude-config-profile' "export GH_TOKEN='tok-brondon-ung'" > "$(ss_file)"
}
test_profile_session_start_clears_stale_token() {   # PR 143, R4
  repo_with_origin "$SANDBOX/o" https://github.com/someone/x.git
  stale_token
  start_with_env "$SANDBOX/o" >/dev/null
  [[ ! -s "$(ss_file)" ]] || fail "jeton périmé gardé hors profil"
}
test_profile_session_start_clears_stale_token_without_profiles_file() {
  repo_with_origin "$SANDBOX/v" https://github.com/softwarevidal/y.git
  stale_token
  PROFILES_FILE="$SANDBOX/absent.json" start_with_env "$SANDBOX/v" >/dev/null
  [[ ! -s "$(ss_file)" ]] || fail "jeton périmé gardé sans profiles.json"
}
test_profile_session_start_clears_stale_token_on_gh_failure() {
  repo_with_origin "$SANDBOX/v" https://github.com/softwarevidal/y.git
  stale_token
  GH_MISSING=brondon-ung start_with_env "$SANDBOX/v" >/dev/null
  [[ ! -s "$(ss_file)" ]] || fail "jeton périmé gardé pour un compte non connecté"
}

cwd_to() {  # <dossier> : cwd-changed avec le fichier cwdchanged de la même session
  [[ -x "$STUBS/gh" ]] || make_gh_stub
  mkdir -p "$SANDBOX/session-env"; : > "$(cd_file)"
  jq -nc --arg d "$1" '{old_cwd:"/", new_cwd:$d}' \
    | PATH="$STUBS:$PATH" CLAUDE_ENV_FILE="$(cd_file)" profile cwd-changed
}
test_profile_cwd_changed_switches_account() {
  repo_with_origin "$SANDBOX/v" https://github.com/softwarevidal/y.git
  repo_with_origin "$SANDBOX/p" https://github.com/Dahiorus/x.git
  start_with_env "$SANDBOX/v" >/dev/null
  cwd_to "$SANDBOX/p" >/dev/null
  assert_eq "$(cat "$(cd_file)")" $'# claude-config-profile\nexport GH_TOKEN=\'tok-Dahiorus\'' "fichier"
  assert_eq "$(stat -c %a "$(cd_file)")" "600" "mode"
}
test_profile_cwd_changed_reads_session_start_file() {   # contrat entre copies : vider après un démarrage à profil
  repo_with_origin "$SANDBOX/v" https://github.com/softwarevidal/y.git
  mkdir -p "$SANDBOX/tmpdir"
  start_with_env "$SANDBOX/v" >/dev/null
  cwd_to "$SANDBOX/tmpdir" >/dev/null
  assert_eq "$(cat "$(cd_file)")" $'# claude-config-profile\nexport GH_TOKEN=' "vidé"
}
test_profile_cwd_changed_reports_unwritable_env_file() {   # review M1 : vidage impossible → message
  repo_with_origin "$SANDBOX/v" https://github.com/softwarevidal/y.git
  mkdir -p "$SANDBOX/tmpdir"
  start_with_env "$SANDBOX/v" >/dev/null
  printf '#!/bin/sh\nexit 1\n' > "$STUBS/chmod"; /bin/chmod +x "$STUBS/chmod"
  local out; out=$(cwd_to "$SANDBOX/tmpdir")
  assert_contains "$(jq -r .systemMessage <<<"$out")" "jeton non vidé"
}
test_profile_cwd_changed_keeps_dev_token() {   # démarrage hors profil : rien à vider
  mkdir -p "$SANDBOX/tmpdir" "$SANDBOX/session-env"
  cwd_to "$SANDBOX/tmpdir" >/dev/null
  [[ ! -s "$(cd_file)" ]] || fail "GH_TOKEN du dev touché"
}
test_profile_cwd_changed_from_outside_profile() {   # démarrage hors profil, cd vidal
  repo_with_origin "$SANDBOX/v" https://github.com/softwarevidal/y.git
  cwd_to "$SANDBOX/v" >/dev/null
  assert_contains "$(cat "$(cd_file)")" "export GH_TOKEN='tok-brondon-ung'"
}
test_profile_cwd_changed_account_without_token() {
  repo_with_origin "$SANDBOX/v" https://github.com/softwarevidal/y.git
  repo_with_origin "$SANDBOX/p" https://github.com/Dahiorus/x.git
  start_with_env "$SANDBOX/v" >/dev/null
  local out; out=$(GH_MISSING=Dahiorus cwd_to "$SANDBOX/p")
  assert_contains "$(jq -r .systemMessage <<<"$out")" "Dahiorus"
  assert_eq "$(tail -n1 "$(cd_file)")" "export GH_TOKEN=" "vidé"
}
test_profile_cwd_changed_bad_input() {   # Review Focus 2
  repo_with_origin "$SANDBOX/v" https://github.com/softwarevidal/y.git
  start_with_env "$SANDBOX/v" >/dev/null   # marqueur posé : seul le garde d'entrée évite le vidage
  echo '{}' | CLAUDE_ENV_FILE="$SANDBOX/session-env/cwdchanged-hook-0.sh" profile cwd-changed || fail "sans new_cwd"
  jq -nc '{new_cwd:"/nulle/part"}' | CLAUDE_ENV_FILE="$SANDBOX/session-env/cwdchanged-hook-0.sh" \
    profile cwd-changed || fail "dossier absent"
  [[ ! -s "$SANDBOX/session-env/cwdchanged-hook-0.sh" ]] || fail "écrit"
}
test_profile_cwd_changed_without_profiles_file() {   # spec : sans profiles.json, les hooks ne font rien
  repo_with_origin "$SANDBOX/v" https://github.com/softwarevidal/y.git
  mkdir -p "$SANDBOX/session-env"; : > "$(cd_file)"
  CLAUDE_ENV_FILE="$(cd_file)" bash "$REPO/global/profile.sh" cwd-changed \
    <<<"$(jq -nc --arg d "$SANDBOX/v" '{new_cwd:$d}')" || fail "code"
  [[ ! -s "$(cd_file)" ]] || fail "écrit"
}
test_profile_cwd_changed_reports_error() {
  repo_with_origin "$SANDBOX/v" https://github.com/softwarevidal/y.git
  repo_with_origin "$SANDBOX/p" https://github.com/Dahiorus/x.git
  start_with_env "$SANDBOX/v" >/dev/null
  bad_profiles '.perso.env = "x"'
  local out; out=$(PROFILES_FILE="$SANDBOX/bad.json" cwd_to "$SANDBOX/p")
  assert_contains "$(jq -r .systemMessage <<<"$out")" "perso"
  assert_eq "$(cat "$(cd_file)")" $'# claude-config-profile\nexport GH_TOKEN=' "vidé"
}

test_profile_plugin_layout() {
  local m="$REPO/mods/profile"
  assert_eq "$(jq -r '.plugins[] | select(.name=="profile") | .source' "$REPO/.claude-plugin/marketplace.json")" \
    "./mods/profile" "marketplace"
  # shellcheck disable=SC2016  # ${CLAUDE_PLUGIN_ROOT} littéral : Claude Code l'expanse
  assert_contains "$(jq -r '.hooks.SessionStart[].hooks[].command' "$m/hooks/hooks.json")" \
    '${CLAUDE_PLUGIN_ROOT}/scripts/profile.sh" session-start'
  assert_eq "$(jq -r '.hooks.SessionStart[0].matcher // ""' "$m/hooks/hooks.json")" "" "matcher"
  [[ -f "$m/skills/profile/SKILL.md" && ! -e "$REPO/global/skills/profile" ]] || fail "skill"
  PROFILES_FILE="$m/profiles.example.json" bash "$m/scripts/profile.sh" detect "$SANDBOX" || fail "exemple invalide"
}

token_check() {  # <dossier> <GH_TOKEN> : « code:stderr » de require-token, faux gh
  [[ -x "$STUBS/gh" ]] || make_gh_stub
  local rc=0 err
  err=$(PATH="$STUBS:$PATH" GH_TOKEN="$2" profile require-token "$1" 2>&1) || rc=$?
  printf '%s:%s' "$rc" "$err"
}

test_profile_require_token_matching_account() {
  repo_with_origin "$SANDBOX/p" https://github.com/Dahiorus/x.git
  assert_eq "$(token_check "$SANDBOX/p" tok-Dahiorus)" "0:" "même compte"
  assert_eq "$(token_check "$SANDBOX/p" tok-dahiorus)" "0:" "casse ignorée"
}

test_profile_require_token_without_profile() {
  repo_with_origin "$SANDBOX/a" https://github.com/someone/x.git
  assert_eq "$(token_check "$SANDBOX/a" "")" "0:" "projet sans profil"
  [[ ! -s "$CALLS_LOG" ]] || fail "gh lancé hors profil"
}

test_profile_require_token_missing_token() {
  repo_with_origin "$SANDBOX/p" https://github.com/Dahiorus/x.git
  assert_eq "$(token_check "$SANDBOX/p" "")" "1:GH_TOKEN absent pour le compte Dahiorus : lancer /profile" "jeton vide"
  [[ ! -s "$CALLS_LOG" ]] || fail "gh lancé sans jeton"
}

test_profile_require_token_other_account() {   # review finale I1 : cd annulé, GH_TOKEN du shell
  repo_with_origin "$SANDBOX/p" https://github.com/Dahiorus/x.git
  assert_eq "$(token_check "$SANDBOX/p" tok-brondon-ung)" \
    "1:jeton de session de brondon-ung, compte attendu Dahiorus : lancer /profile" "autre compte"
}

test_profile_require_token_gh_failure() {
  repo_with_origin "$SANDBOX/p" https://github.com/Dahiorus/x.git
  assert_eq "$(GH_API_USER_ERROR=$'HTTP 401: Bad credentials\ndétail' token_check "$SANDBOX/p" tok-Dahiorus)" \
    "1:gh api user a échoué : HTTP 401: Bad credentials" "échec de gh"
}

test_profile_require_token_account_failure() {
  repo_with_origin "$SANDBOX/p" https://github.com/Dahiorus/x.git
  echo '{' > "$SANDBOX/bad.json"
  local out; out=$(PROFILES_FILE="$SANDBOX/bad.json" token_check "$SANDBOX/p" tok-Dahiorus)
  assert_contains "$out" "1:profiles.json illisible"
  [[ ! -s "$CALLS_LOG" ]] || fail "gh lancé malgré l'échec de account"
}

test_profile_skill_lists_merge_telemetry_keys() {   # issue 146 : la liste du skill suit celle de merge_profile
  local script skill
  script=$(awk '/^merge_profile\(\)/,/^}/' "$REPO/global/profile.sh" \
    | grep -oE '"(CLAUDE_CODE_ENABLE_TELEMETRY|OTEL_[A-Z_]+)"' | tr -d '"' | sort)
  skill=$(awk '/porte encore une de ces clés/,/qui les retire/' "$REPO/mods/profile/skills/profile/SKILL.md" \
    | grep -oE "\`(CLAUDE_CODE_ENABLE_TELEMETRY|OTEL_[A-Z_]+)\`" | tr -d "\`" | sort)
  [[ -n "$script" ]] || fail "aucune clé lue dans merge_profile"
  assert_eq "$skill" "$script" "clés de télémétrie du skill"
}
