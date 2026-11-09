# shellcheck shell=bash
# Dépendances externes : chaque ensure_* vérifie la présence puis installe si besoin.
# Un échec produit un « warn » et n'interrompt jamais install.
# Les installeurs lisent </dev/null : ils ne doivent pas consommer le stdin des boucles « while read ».
# Sourcé par bin/claude-config, qui définit CLAUDE_HOME et log.
# shellcheck disable=SC2154

RTK_INSTALL_URL="https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh"
BUILD_BRIEF_FORMULA="static-var/tap/build-brief"
PLANNOTATOR_INSTALL_URL="https://plannotator.ai/install.sh"
SHFMT_VERSION="v3.14.1"
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

# Tap tiers : on n'approuve pas la formule à la place de l'utilisateur (« brew trust --formula … »).
ensure_build_brief() {
  if command -v build-brief >/dev/null 2>&1; then
    log ok build-brief
  elif ! command -v brew >/dev/null 2>&1; then
    log warn "brew absent : build-brief non installé"
  elif bounded brew install "$BUILD_BRIEF_FORMULA" </dev/null; then
    log installed "build-brief (brew)"
  else
    log warn "échec de brew install $BUILD_BRIEF_FORMULA (formule approuvée ? brew trust --formula $BUILD_BRIEF_FORMULA)"
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

# Le shfmt du PATH écrit BinaryCmd.Op en texte, comme main-guard l'attend (3.14 ou plus) ; avant, c'est un entier
# et main-guard refuse tout push. Le format est testé plutôt que la version.
shfmt_ok() {
  shfmt -ln bash --to-json <<<'a && b' 2>/dev/null | jq -e '.Stmts[0].Cmd.Op == "&&"' >/dev/null 2>&1
}

# main-guard lit les commandes avec shfmt : sans lui, il refuse tout push.
ensure_shfmt() {
  local os arch bin="$HOME/.local/bin/shfmt" how dir="$HOME/.local/bin"
  if shfmt_ok; then
    log ok shfmt
    return 0
  elif command -v brew >/dev/null 2>&1; then
    if bounded brew install shfmt </dev/null; then
      how=brew dir="$(brew --prefix 2>/dev/null </dev/null)/bin"
    else
      log warn "échec de brew install shfmt"
      return 0
    fi
  else
    os="$(uname -s | tr '[:upper:]' '[:lower:]')"
    case "$(uname -m)" in
      x86_64 | amd64) arch=amd64 ;;
      arm64 | aarch64) arch=arm64 ;;
      *) arch="$(uname -m)" ;;
    esac
    mkdir -p "${bin%/*}"
    if curl -fsSL "https://github.com/mvdan/sh/releases/download/$SHFMT_VERSION/shfmt_${SHFMT_VERSION}_${os}_$arch" \
      "${CURL_OPTS[@]}" -o "$bin" && chmod +x "$bin"; then
      how="$bin"
    else
      rm -f "$bin"
      log warn "échec du téléchargement de shfmt $SHFMT_VERSION ($os/$arch)"
      return 0
    fi
  fi
  if shfmt_ok; then
    log installed "shfmt ($how)"
  else
    log warn "shfmt installé ($how), mais le shfmt du PATH ($(command -v shfmt || echo absent)) n'écrit pas l'arbre attendu (shfmt 3.14 ou plus requis) : main-guard refusera tout push ; mettre $dir en tête du PATH"
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

# Plugins à true dans settings.json ou dans un profil du dépôt, sans doublon.
enabled_plugin_ids() {
  local profiles="$REPO_ROOT/global/profiles.json"
  [[ -f "$profiles" ]] || profiles=/dev/null
  {
    jq -r '.enabledPlugins // {} | to_entries[] | select(.value == true) | .key' "$1"
    jq -r '.[].enabledPlugins | to_entries[] | select(.value == true) | .key' "$profiles"
  } | sort -u
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
  done < <(enabled_plugin_ids "$settings")
}

ensure_all() {
  ensure_rtk
  ensure_build_brief
  ensure_plannotator
  ensure_shfmt
  ensure_angular_developer
  ensure_plugins
}
