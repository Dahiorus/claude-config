# shellcheck shell=bash
# Dépendances externes : chaque ensure_* vérifie la présence puis installe si besoin.
# Un échec produit un « warn » et n'interrompt jamais install.
# Les installeurs lisent </dev/null : ils ne doivent pas consommer le stdin des boucles « while read ».
# Sourcé par bin/claude-config, qui définit CLAUDE_HOME et log.
# shellcheck disable=SC2154

RTK_INSTALL_URL="https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh"
PLANNOTATOR_INSTALL_URL="https://plannotator.ai/install.sh"
# Durée maximale (en secondes) d'un installeur ; au-delà il est abandonné avec un « warn ».
DEPS_TIMEOUT="${DEPS_TIMEOUT:-600}"
CURL_OPTS=(--connect-timeout 15 --max-time 300)

# Lance un exécutable avec une limite de durée, si la commande timeout existe.
bounded() {
  if command -v timeout >/dev/null 2>&1; then
    timeout "$DEPS_TIMEOUT" "$@"
  else
    "$@"
  fi
}

# Binaire seulement : pas de « rtk init -g », le hook et RTK.md sont gérés par ce repo.
ensure_rtk() {
  if command -v rtk >/dev/null 2>&1; then
    log ok rtk
  elif command -v brew >/dev/null 2>&1; then
    if bounded brew install rtk </dev/null; then
      log installed "rtk (brew)"
    else
      log warn "échec de brew install rtk"
    fi
  elif curl -fsSL "$RTK_INSTALL_URL" "${CURL_OPTS[@]}" | bounded sh; then
    log installed "rtk (script officiel)"
  else
    log warn "échec de l'installation de rtk"
  fi
}

ensure_plannotator() {
  if command -v plannotator >/dev/null 2>&1; then
    log ok plannotator
  elif curl -fsSL "$PLANNOTATOR_INSTALL_URL" "${CURL_OPTS[@]}" | bounded bash; then
    log installed plannotator
  else
    log warn "échec de l'installation de plannotator"
  fi
}

ensure_angular_developer() {
  if [[ -e "$CLAUDE_HOME/skills/angular-developer" ]]; then
    log ok "skill angular-developer"
  elif ! command -v npx >/dev/null 2>&1; then
    log warn "npx absent : skill angular-developer non installé"
  elif bounded npx -y skills add affaan-m/ecc --skill angular-developer -g -a claude-code -y </dev/null; then
    log installed "skill angular-developer"
  else
    log warn "échec de l'installation du skill angular-developer"
  fi
}

# Ajoute les marketplaces de extraKnownMarketplaces, puis installe les plugins
# activés (enabledPlugins à true) qui ne le sont pas encore.
ensure_plugins() {
  local settings="$CLAUDE_HOME/settings.json" known installed name src id
  if ! command -v claude >/dev/null 2>&1; then
    log warn "claude absent : plugins non installés"
    return 0
  fi
  known="$(claude plugin marketplace list --json </dev/null 2>/dev/null | jq -r '.[].name' || true)"
  while IFS=$'\t' read -r name src; do
    if grep -qxF -- "$name" <<<"$known"; then
      log ok "marketplace $name"
    elif [[ -z "$src" ]]; then
      log warn "marketplace $name : source non gérée"
    elif bounded claude plugin marketplace add "$src" </dev/null; then
      log installed "marketplace $name"
    else
      log warn "échec de l'ajout de la marketplace $name"
    fi
  done < <(jq -r '.extraKnownMarketplaces // {} | to_entries[]
    | [.key, (.value.source.repo // .value.source.url // .value.source.path // "")] | @tsv' "$settings")

  installed="$(claude plugin list --json </dev/null 2>/dev/null | jq -r '.[].id' || true)"
  while IFS= read -r id; do
    if grep -qxF -- "$id" <<<"$installed"; then
      log ok "plugin $id"
    elif bounded claude plugin install "$id" --scope user </dev/null; then
      log installed "plugin $id"
    else
      log warn "échec de l'installation du plugin $id"
    fi
  done < <(jq -r '.enabledPlugins // {} | to_entries[] | select(.value == true) | .key' "$settings")
}

ensure_all() {
  ensure_rtk
  ensure_plannotator
  ensure_angular_developer
  ensure_plugins
}
