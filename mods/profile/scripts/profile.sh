#!/usr/bin/env bash
# Profil de projet (vidal, perso) déduit du propriétaire GitHub de origin.
set -uo pipefail

PROFILES_FILE="${PROFILES_FILE:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/profiles.json}"

require_profiles() { [[ -f "$PROFILES_FILE" ]]; }

# Premier défaut de profiles.json, un message par ligne (rien si le fichier est valide).
# shellcheck disable=SC2016  # programme jq : les $ ne sont pas du shell
VALIDATION_PROGRAM='
  def sections_errors($name): ("enabledPlugins", "skillOverrides", "env", "secretEnv") as $field
    | select(has($field) and (.[$field] | type) != "object") | "profil \($name) : \($field) doit être un objet";
  def profile_errors: .key as $name | .value
    | if type != "object" then "profil \($name) doit être un objet" else
        (select(.owners | type != "array" or any(type != "string"))
          | "profil \($name) : owners doit être une liste de noms"),
        sections_errors($name),
        # les skills placent le compte dans une commande shell (gh auth token -u <compte>)
        (select(.account | type != "string" or (test("^[A-Za-z0-9-]+$") | not))
          | "compte gh invalide pour le profil \($name)")
      end;
  def shared_owner_errors: [to_entries[] | .key as $name | .value.owners[] | {owner: ascii_downcase, name: $name}]
    | group_by(.owner)[] | select(length > 1) | "propriétaire \(.[0].owner) dans les profils \(.[0].name) et \(.[1].name)";
  if type != "object" then "profiles.json doit être un objet" else
    [to_entries[] | profile_errors] as $errors
    | if ($errors | length) > 0 then $errors[] else shared_owner_errors end
  end'

validate_profiles() {
  local errors
  errors=$(jq -r "$VALIDATION_PROGRAM" "$PROFILES_FILE" 2>&1) || { echo "profiles.json illisible : $errors" >&2; return 1; }
  [[ -z "$errors" ]] || { printf '%s\n' "${errors%%$'\n'*}" >&2; return 1; }
}

origin_owner() {  # <dossier>
  local url code
  command -v git >/dev/null || { echo "git introuvable" >&2; return 1; }
  url=$(LC_ALL=C git -C "$1" remote get-url origin 2>&1) && code=0 || code=$?
  if (( code != 0 )); then
    # pas de origin (2) ou pas un dépôt : aucun propriétaire ; le reste (propriété douteuse…) remonte
    [[ $code == 2 || "$url" == *"not a git repository"* || "$url" == *"cannot change to"* ]] && return 0
    echo "git : ${url%%$'\n'*}" >&2
    return 1
  fi
  [[ "$url" =~ ^(https://github\.com/|git@github\.com:|ssh://git@github\.com/)([^/]+)/ ]] \
    && printf '%s\n' "${BASH_REMATCH[2]}"
  return 0
}

detect() {  # <dossier>
  require_profiles || return 0
  validate_profiles || return 1
  local owner
  owner=$(origin_owner "$1") || return 1
  [[ -n "$owner" ]] || return 0
  jq -r --arg owner "$owner" \
    'to_entries[] | select(.value.owners | map(ascii_downcase) | index($owner | ascii_downcase)) | .key' "$PROFILES_FILE"
}

account() {  # <dossier>
  local name account
  name=$(detect "$1") || return 1
  [[ -n "$name" ]] || return 0
  account=$(jq -r --arg name "$name" '.[$name].account' "$PROFILES_FILE")   # format vérifié par detect
  printf '%s\n' "$account"
}

project_root() {  # <dossier>
  git -C "$1" rev-parse --show-toplevel 2>/dev/null || printf '%s\n' "$1"
}

current() {  # <dossier>
  local file
  file="$(project_root "$1")/.claude/settings.local.json"
  [[ -f "$file" ]] && jq -r '.env.CLAUDE_PROFILE // empty' "$file" 2>/dev/null
  return 0
}

# État écrit par le profil, comme current : ~/.claude/settings.json et le shell ne sont pas lus.
telemetry() {  # <dossier>
  local file
  file="$(project_root "$1")/.claude/settings.local.json"
  [[ -f "$file" ]] || { echo off; return 0; }
  jq -r '.env // {} | if .CLAUDE_CODE_ENABLE_TELEMETRY != "1" then "off"
    elif .OTEL_EXPORTER_OTLP_METRICS_HEADERS then "on" else "sans jeton" end' "$file"
}

exclude_from_git() {  # <racine>
  local root="$1" exclude
  git -C "$root" rev-parse --git-dir >/dev/null 2>&1 || return 0
  git -C "$root" check-ignore -q .claude/settings.local.json && return 0
  exclude=$(git -C "$root" rev-parse --path-format=absolute --git-path info/exclude)
  mkdir -p "$(dirname "$exclude")"
  # Un fichier sans saut de ligne final collerait la ligne au dernier motif.
  [[ ! -s "$exclude" || -z "$(tail -c1 "$exclude")" ]] || echo >> "$exclude"
  printf '.claude/settings.local.json\n' >> "$exclude"
}

# secretEnv : variable -> fichier hors git qui porte sa valeur (dépôt public). Fichier absent : variable omise.
# Une valeur secrète ne passe jamais en argument (lisible dans /proc/<pid>/cmdline) : --rawfile, stdin.
read_secrets() {  # <profil>
  local secrets='{}' entries var path
  entries=$(jq -r --arg name "$1" '.[$name].secretEnv // {}
    | if type == "object" then to_entries[] | "\(.key)\t\(.value)" else error("secretEnv doit être un objet") end' \
    "$PROFILES_FILE") || return 1
  while IFS=$'\t' read -r var path; do
    [[ -n "$var" ]] || continue
    path="${path/#\~/$HOME}"
    if ! grep -q '[^[:space:]]' "$path" 2>/dev/null; then
      echo "profil $1 : $var omise, fichier $path absent ou vide" >&2
      continue
    fi
    secrets=$(jq -c --arg k "$var" --rawfile v "$path" '.[$k] = ($v | sub("\\s+$"; ""))' <<<"$secrets") || return 1
  done <<<"$entries"
  printf '%s\n' "$secrets"
}

# Retire d'abord les clés que déclare un profil quelconque : passer de perso à vidal ne garde pas les réglages perso.
merge_profile() {  # <profil> <fichier> <secrets>
  jq --arg name "$1" --slurpfile profiles "$PROFILES_FILE" --slurpfile secrets <(printf '%s' "$3") \
    '$profiles[0] as $all
     | ([$all[].enabledPlugins | keys[]]) as $plugins
     | ([$all[].skillOverrides | keys[]]) as $skills
     | ([$all[] | (.env // {}), (.secretEnv // {}) | keys[]]) as $envs
     | .enabledPlugins = ((.enabledPlugins // {}) | del(.[$plugins[]])) + $all[$name].enabledPlugins
     | .skillOverrides = ((.skillOverrides // {}) | del(.[$skills[]])) + $all[$name].skillOverrides
     | .env = ((.env // {}) | del(.[$envs[]])) + ($all[$name].env // {}) + $secrets[0]
     | .env.CLAUDE_PROFILE = $name' "$2"
}

apply() {  # <profil> [dossier]
  local name="$1" root file merged secrets
  require_profiles || { echo "profiles.json introuvable : $PROFILES_FILE" >&2; return 1; }
  validate_profiles || return 1
  if ! jq -e --arg name "$name" 'has($name)' "$PROFILES_FILE" >/dev/null; then
    echo "profil inconnu : $name (connus : $(jq -r 'keys | join(", ")' "$PROFILES_FILE"))" >&2
    return 2
  fi
  secrets=$(read_secrets "$name") || return 1
  root=$(project_root "${2:-.}")
  file="$root/.claude/settings.local.json"
  exclude_from_git "$root"  # avant l'écriture : le jeton n'existe jamais hors de l'exclusion
  # fichier absent, vide ou fait de blancs : jq n'y lirait aucune valeur et écrirait un fichier vide
  grep -q '[^[:space:]]' "$file" 2>/dev/null || { mkdir -p "$root/.claude" && echo '{}' > "$file"; }
  merged=$(mktemp "$root/.claude/settings.local.json.XXXXXX") || return 1
  if ! { merge_profile "$name" "$file" "$secrets" > "$merged" && mv "$merged" "$file"; }; then
    rm -f "$merged"
    return 1
  fi
}

notice() { jq -nc --arg message "$1" '{systemMessage: $message}'; }

MARKER='# claude-config-profile'

# Applique le profil détecté si le projet n'en a pas encore ; rend le message à afficher.
apply_detected() {  # <dossier> <profil>
  local warn
  [[ -z "$(current "$1")" ]] || return 0
  if ! warn=$(apply "$2" "$1" 2>&1); then
    warn=${warn%%$'\n'*}   # jq et mktemp écrivent plusieurs lignes
    echo "Profil $2 non appliqué : ${warn:-.claude/settings.local.json illisible}."
    return 0
  fi
  echo "Profil $2 appliqué à ce projet : relance la session pour l'alléger.${warn:+ $warn}"
}

# Compte absent de gh → conseil de connexion ; autre échec (trousseau, D-Bus) → première ligne de gh.
token_failure() {  # <compte> <stderr de gh>
  if [[ -z "$2" || "$2" == "no oauth token found"* ]]; then
    echo "compte gh $1 non connecté : gh auth login -h github.com, puis relance la session"
    return
  fi
  echo "gh auth token -u $1 a échoué : ${2%%$'\n'*}"
}

# Écrit le jeton gh du compte du profil détecté ; rend l'erreur éventuelle (le jeton ne passe qu'à printf, builtin).
write_token() {  # <dossier> <fichier>
  local account token
  account=$(account "$1" 2>&1) || { echo "$account"; return 0; }
  [[ -n "$account" ]] || return 0
  command -v gh >/dev/null || { echo "gh introuvable : jeton de $account non exporté"; return 0; }
  # En échec, token ne porte que le stderr de gh : jamais de jeton dans un message.
  token=$(gh auth token -u "$account" 2>&1) || { token_failure "$account" "$token"; return 0; }
  [[ -n "$token" ]] || { token_failure "$account" ""; return 0; }
  [[ "$token" =~ ^[A-Za-z0-9_-]+$ ]] || { echo "jeton gh de $account refusé (format inattendu)"; return 0; }
  write_env "$2" "export GH_TOKEN='$token'" || echo "jeton non écrit : $2 non inscriptible en 600"
}

write_env() {  # <fichier> <ligne export> : le fichier passe en 600 avant de recevoir la ligne
  ( umask 077; : > "$1" ) && chmod 600 "$1" || return 1
  printf '%s\n%s\n' "$MARKER" "$2" > "$1"
}

session_start() {
  local dir name messages token_message=""
  # Le fichier peut garder le jeton d'un démarrage précédent (/clear, resume) : vidé avant tout, comme cwd_changed.
  [[ -z "${CLAUDE_ENV_FILE:-}" ]] || : > "$CLAUDE_ENV_FILE"
  require_profiles || return 0
  dir=$(jq -r '.cwd // empty')
  [[ -d "$dir" ]] || return 0
  name=$(detect "$dir" 2>&1) || { notice "Profil non appliqué : $name"; return 0; }
  [[ -n "$name" ]] || return 0
  messages=$(apply_detected "$dir" "$name")
  [[ -z "${CLAUDE_ENV_FILE:-}" ]] || token_message=$(write_token "$dir" "$CLAUDE_ENV_FILE")
  messages="$messages${messages:+${token_message:+ }}$token_message"
  [[ -z "$messages" ]] || notice "$messages"
}

# Le jeton d'un démarrage à profil vit dans le fichier du SessionStart : seul lui justifie de le vider.
session_start_set_token() {  # <fichier d'env du CwdChanged>
  grep -qxF "$MARKER" "$(dirname "$1")"/sessionstart-hook-*.sh 2>/dev/null
}

cwd_changed() {
  local dir message
  require_profiles || return 0
  [[ -n "${CLAUDE_ENV_FILE:-}" ]] || return 0
  dir=$(jq -r '.new_cwd // empty')
  [[ -d "$dir" ]] || return 0
  : > "$CLAUDE_ENV_FILE"
  message=$(write_token "$dir" "$CLAUDE_ENV_FILE")
  if [[ ! -s "$CLAUDE_ENV_FILE" ]] && session_start_set_token "$CLAUDE_ENV_FILE"; then
    write_env "$CLAUDE_ENV_FILE" "export GH_TOKEN=" || message="jeton non vidé : $CLAUDE_ENV_FILE non inscriptible"
  fi
  [[ -z "$message" ]] || notice "$message"
}

case "${1:-}" in
  detect) detect "${2:-.}" ;;
  account) account "${2:-.}" ;;
  apply) apply "${2:?profil}" "${3:-.}" ;;
  current) current "${2:-.}" ;;
  telemetry) telemetry "${2:-.}" ;;
  session-start) session_start ;;
  cwd-changed) cwd_changed ;;
  *) echo "usage: profile.sh detect|account|current|telemetry [dossier], apply <profil> [dossier], session-start|cwd-changed < entrée du hook" >&2; exit 2 ;;
esac
