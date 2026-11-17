#!/usr/bin/env bash
# Profil de projet (vidal, perso) déduit du propriétaire GitHub de origin.
set -uo pipefail

PROFILES_FILE="${PROFILES_FILE:-$(dirname "$(readlink -f "$0")")/profiles.json}"

origin_owner() {  # <dossier>
  local url
  url=$(git -C "$1" remote get-url origin 2>/dev/null) || return 0
  [[ "$url" =~ ^(https://github\.com/|git@github\.com:|ssh://git@github\.com/)([^/]+)/ ]] \
    && printf '%s\n' "${BASH_REMATCH[2]}"
  return 0
}

detect() {  # <dossier>
  local owner
  owner=$(origin_owner "$1")
  [[ -n "$owner" ]] || return 0
  jq -r --arg owner "$owner" \
    'to_entries[] | select(.value.owners | map(ascii_downcase) | index($owner | ascii_downcase)) | .key' "$PROFILES_FILE"
}

account() {  # <dossier>
  local name account
  name=$(detect "$1")
  [[ -n "$name" ]] || return 0
  account=$(jq -r --arg name "$name" '.[$name].account' "$PROFILES_FILE")
  # Les skills placent le compte dans une commande shell (gh auth token -u <compte>).
  [[ "$account" =~ ^[A-Za-z0-9-]+$ ]] || { echo "compte gh invalide pour le profil $name" >&2; return 1; }
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

session_start() {
  local dir name warn
  dir=$(jq -r '.cwd // empty')
  [[ -d "$dir" && -z "$(current "$dir")" ]] || return 0
  name=$(detect "$dir")
  [[ -n "$name" ]] || return 0
  if ! warn=$(apply "$name" "$dir" 2>&1); then
    jq -nc --arg name "$name" '{systemMessage: "Profil \($name) non appliqué : .claude/settings.local.json illisible."}'
    return 0
  fi
  jq -nc --arg name "$name" --arg warn "$warn" \
    '{systemMessage: ("Profil \($name) appliqué à ce projet : relance la session pour l'"'"'alléger."
      + (if $warn == "" then "" else " " + $warn end))}'
}

case "${1:-}" in
  detect) detect "${2:-.}" ;;
  account) account "${2:-.}" ;;
  apply) apply "${2:?profil}" "${3:-.}" ;;
  current) current "${2:-.}" ;;
  telemetry) telemetry "${2:-.}" ;;
  session-start) session_start ;;
  *) echo "usage: profile.sh detect|account|current|telemetry|session-start [dossier], apply <profil> [dossier]" >&2; exit 2 ;;
esac
