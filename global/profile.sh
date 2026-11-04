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

# Retire d'abord les clés que déclare un profil quelconque : passer de perso à vidal ne garde pas les réglages perso.
merge_profile() {  # <profil> <fichier>
  jq --arg name "$1" --slurpfile profiles "$PROFILES_FILE" \
    '$profiles[0] as $all
     | ([$all[].enabledPlugins | keys[]]) as $plugins
     | ([$all[].skillOverrides | keys[]]) as $skills
     | .enabledPlugins = ((.enabledPlugins // {}) | del(.[$plugins[]])) + $all[$name].enabledPlugins
     | .skillOverrides = ((.skillOverrides // {}) | del(.[$skills[]])) + $all[$name].skillOverrides
     | .env.CLAUDE_PROFILE = $name' "$2"
}

apply() {  # <profil> [dossier]
  local name="$1" root file merged
  if ! jq -e --arg name "$name" 'has($name)' "$PROFILES_FILE" >/dev/null; then
    echo "profil inconnu : $name (connus : $(jq -r 'keys | join(", ")' "$PROFILES_FILE"))" >&2
    return 2
  fi
  root=$(project_root "${2:-.}")
  file="$root/.claude/settings.local.json"
  # fichier absent, vide ou fait de blancs : jq n'y lirait aucune valeur et écrirait un fichier vide
  grep -q '[^[:space:]]' "$file" 2>/dev/null || { mkdir -p "$root/.claude" && echo '{}' > "$file"; }
  merged=$(mktemp "$root/.claude/settings.local.json.XXXXXX") || return 1
  if ! { merge_profile "$name" "$file" > "$merged" && mv "$merged" "$file"; }; then
    rm -f "$merged"
    return 1
  fi
  exclude_from_git "$root"
}

session_start() {
  local dir name
  dir=$(jq -r '.cwd // empty')
  [[ -d "$dir" && -z "$(current "$dir")" ]] || return 0
  name=$(detect "$dir")
  [[ -n "$name" ]] || return 0
  if ! apply "$name" "$dir" 2>/dev/null; then
    jq -nc --arg name "$name" '{systemMessage: "Profil \($name) non appliqué : .claude/settings.local.json illisible."}'
    return 0
  fi
  jq -nc --arg name "$name" \
    '{systemMessage: "Profil \($name) appliqué à ce projet : relance la session pour l'"'"'alléger."}'
}

case "${1:-}" in
  detect) detect "${2:-.}" ;;
  account) account "${2:-.}" ;;
  apply) apply "${2:?profil}" "${3:-.}" ;;
  current) current "${2:-.}" ;;
  session-start) session_start ;;
  *) echo "usage: profile.sh detect|account|current|session-start [dossier], apply <profil> [dossier]" >&2; exit 2 ;;
esac
