# claude-config Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Un repo git qui versionne la config Claude Code de l'utilisateur, l'installe sur une machine Linux/WSL (`install`), détecte les écarts (`status`), remonte les changements (`capture`) et pose une config dans un nouveau repo (`init-project`).

**Architecture:** Un CLI bash unique `bin/claude-config` qui gère les arguments et délègue à des bibliothèques sourcées (`lib/common.sh`, `lib/links.sh`, `lib/settings.sh`, `lib/project.sh`, `lib/capture.jq`) et au manifeste de dépendances `deps.sh`. Les fichiers de `global/` sont symlinkés dans `$CLAUDE_HOME` ; `settings.json` est généré par fusion `jq` de `settings/base.json` et de `settings/local.json` (facultatif). Les tests sont des fonctions bash exécutées chacune dans son propre processus, au sein d'un bac à sable jetable.

**Tech Stack:** bash 5.1+, GNU coreutils/findutils, jq 1.6+, git ; shellcheck pour les tests.

**Spec:** `docs/superpowers/specs/2026-10-05-claude-config-design.md`

**Écarts assumés par rapport à la spec** (mis à jour dans la spec au Task 1) :
- le code est découpé en `lib/*.sh` au lieu d'un seul fichier `bin/claude-config` ;
- les tests sont répartis en `tests/helpers.sh` + `tests/test_*.sh`, et `tests/run.sh` reste le point d'entrée ;
- `{{PROJECT_NAME}}` est remplacé dans **tous** les fichiers du template, pas seulement `CLAUDE.md` ;
- `install` valide les settings **avant** de créer les symlinks : un `local.json` invalide n'installe rien.

## Global Constraints

- Cibles : Linux et WSL uniquement. Bash ≥ 5.1, GNU `find` (`-printf`), `readlink -f`.
- Dépendances du script : `jq` et `git` uniquement. `shellcheck` sert seulement aux tests.
- `CLAUDE_HOME` vaut `~/.claude` par défaut et toute écriture côté machine passe par cette variable.
- Format de sortie : `printf '%-9s %s\n' <statut> <message>`. Statuts autorisés : `linked`, `ok`, `relinked`, `backup`, `skipped`, `written`, `warn`, `installed`, `missing`, `broken`, `drift`, `info`. Les erreurs vont sur stderr, préfixées de `error`.
- Sauvegardes : `<chemin>.bak-YYYYmmdd-HHMMSS`, avec suffixe `-1`, `-2`… en cas de collision.
- Codes de sortie : `2` pour une erreur d'usage (commande ou option inconnue, argument manquant), `1` pour une autre erreur ou un écart détecté par `status`, `0` sinon.
- Messages utilisateur en français.
- Le script ne commite jamais rien et ne lit ni n'écrit aucun fichier de la liste « Jamais versionné » de la spec (§3.3).
- Les tests ne touchent jamais au vrai `~/.claude`. Le chemin du bac à sable contient des espaces exprès, et le home réel contient un `@` : tout doit être cité.
- Toute fonction des `lib/*.sh` suppose `set -euo pipefail` (posé par `bin/claude-config`). Ne pas finir une fonction par `[[ … ]] && cmd` (sinon le statut 1 fait sortir l'appelant) : utiliser `if`.
- Commits : messages conventionnels, terminés par `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **CLI appelé via un symlink** (ex. `~/.local/bin/claude-config` → repo) : la racine du repo doit être résolue avec `readlink -f`, et les symlinks doivent pointer vers le vrai repo. Test : `test_install_via_symlinked_cli` (Task 3).
2. **JSON invalide** dans `~/.claude/settings.json`, `settings/local.json` ou au moment de `capture` : il faut une erreur claire et ne rien écraser, sauf `install`, qui sauvegarde un `settings.json` invalide avant de le réécrire. Tests : `test_install_rejects_invalid_local`, `test_install_backs_up_invalid_settings`, `test_capture_rejects_invalid_settings` (Task 4).
3. **Deux sauvegardes dans la même seconde** : la seconde ne doit pas écraser la première. Test : `test_backup_path_avoids_collision` (Task 2).
4. **Claude Code réordonne les clés** de `settings.json` : `status` ne doit pas signaler d'écart. Test : `test_status_ignores_key_order` (Task 4).
5. **Nom de projet contenant `&`** ou d'autres caractères spéciaux pour un remplacement : le remplacement doit être littéral, sous bash 5.1 comme 5.2 (`patsub_replacement`). Test : `test_init_project_name_with_special_chars` (Task 6).

---

## File Structure

| Fichier | Responsabilité |
|---|---|
| `.gitignore` | Garde-fou : exclut les secrets, l'état d'exécution et `settings/local.json` |
| `README.md` | Usage du repo (Task 7) |
| `bin/claude-config` | Point d'entrée : résolution de `REPO_ROOT`, chargement des libs, usage, analyse des options, dispatch |
| `lib/common.sh` | `log`, `die`, `timestamp`, `backup_path`, `require_jq` |
| `lib/links.sh` | `managed_links`, `link_item`, `install_links`, `check_link`, `status_links` |
| `lib/settings.sh` | `merged_settings`, `install_settings`, `status_settings`, `capture_settings` |
| `lib/capture.jq` | Fusion inverse utilisée par `capture` quand `local.json` existe |
| `lib/project.sh` | `init_project`, `copy_template_file`, `ensure_gitignore_entry` |
| `deps.sh` | `ensure_rtk`, `ensure_plannotator`, `ensure_angular_developer`, `ensure_plugins`, `ensure_all` |
| `global/CLAUDE.md`, `global/RTK.md`, `global/statusline-command.sh`, `global/skills/.gitkeep` | Config importée depuis `~/.claude` |
| `settings/base.json` | Settings communs (import + Plannotator) |
| `templates/default/.claude/settings.json`, `templates/default/CLAUDE.md` | Template de bootstrap |
| `tests/run.sh` | Runner : découvre les `test_*`, les exécute isolément, puis lance shellcheck |
| `tests/helpers.sh` | Bac à sable, assertions, stubs |
| `tests/test_common.sh`, `test_cli.sh`, `test_links.sh`, `test_settings.sh`, `test_deps.sh`, `test_project.sh` | Tests par domaine |

Toutes les commandes ci-dessous s'exécutent depuis la racine du repo : `~/IdeaProjects/claude-config`.

---

### Task 1: Squelette du repo, import de la config, runner de tests

**Files:**
- Create: `.gitignore`, `global/CLAUDE.md`, `global/RTK.md`, `global/statusline-command.sh`, `global/skills/.gitkeep`, `settings/base.json`, `templates/default/.claude/settings.json`, `templates/default/CLAUDE.md`, `tests/run.sh`, `tests/helpers.sh`
- Modify: `docs/superpowers/specs/2026-10-05-claude-config-design.md` (§4 arborescence, §6.5, §6.2)

**Interfaces:**
- Produces (dans `tests/helpers.sh`, utilisées par tous les tests) :
  - `setup_sandbox` : définit `SANDBOX` (chemin physique avec espaces), `REPO` (copie du repo, sans `.git` ni `settings/local.json`), `HOME="$SANDBOX/home"`, `CLAUDE_HOME="$HOME/.claude"` (non créé), `CALLS_LOG="$SANDBOX/calls.log"`, `STUBS="$SANDBOX/stubs"`, `CLI="$REPO/bin/claude-config"`
  - `fail <msg>`, `assert_eq <obtenu> <attendu> [libellé]`, `assert_contains <texte> <fragment>`, `assert_not_contains <texte> <fragment>`, `assert_has_line <sortie> <statut> <message>`, `assert_symlink_to <lien> <cible>`, `assert_json_eq <fichier> <json>`, `count_backups <dir>`, `snapshot <dir>`, `make_stub <nom> [code_sortie]`
  - `tests/run.sh [filtre]` : lance les `test_*` dont le nom contient le filtre ; sans filtre, lance aussi shellcheck

- [ ] **Step 1: Créer `.gitignore`**

```gitignore
# Garde-fou : rien de tout ça ne doit jamais entrer dans le repo.
.credentials.json
history.jsonl
projects/
sessions/
session-env/
shell-snapshots/
file-history/
plugins/
cache/
skills/synced/
policy-limits*
stats-cache.json
*.bak
*.bak-*

# Surcharges propres à une machine.
settings/local.json
```

- [ ] **Step 2: Importer la config de ce poste**

```bash
mkdir -p global/skills settings templates/default/.claude tests
cp ~/.claude/CLAUDE.md ~/.claude/RTK.md ~/.claude/statusline-command.sh global/
chmod 644 global/RTK.md
chmod 755 global/statusline-command.sh
touch global/skills/.gitkeep
jq --indent 2 '
  .extraKnownMarketplaces = ((.extraKnownMarketplaces // {}) + {
    "plannotator": { "source": { "source": "github", "repo": "backnotprop/plannotator" } }
  })
  | .enabledPlugins["plannotator@plannotator"] = true
' ~/.claude/settings.json > settings/base.json
```

- [ ] **Step 3: Vérifier l'import (absence de secrets, JSON valide)**

Run :
```bash
jq -e '.enabledPlugins["plannotator@plannotator"] == true and .extraKnownMarketplaces.plannotator.source.repo == "backnotprop/plannotator"' settings/base.json
grep -nIiE '(api[_-]?key|token|secret|password|bearer)' global/* settings/base.json || echo "aucun secret détecté"
```
Expected : `true`, puis `aucun secret détecté`. Si `grep` trouve une ligne, s'arrêter et la montrer à l'utilisateur avant d'aller plus loin.

- [ ] **Step 4: Créer le template `default`**

`templates/default/.claude/settings.json` :
```json
{
  "permissions": {
    "deny": ["Read(./.env)", "Read(./.env.*)", "Read(./secrets/**)"]
  }
}
```

`templates/default/CLAUDE.md` :
```markdown
# {{PROJECT_NAME}}

## Stack

## Commandes

- Build :
- Test :
- Lint :

## Conventions
```

- [ ] **Step 5: Créer `tests/helpers.sh`**

```bash
# shellcheck shell=bash
# Outils partagés par les tests : bac à sable, assertions, stubs.
# Les variables définies ici sont utilisées par les fichiers test_*.sh.
# shellcheck disable=SC2034

# Crée un bac à sable jetable (chemin avec espaces) contenant une copie du repo.
setup_sandbox() {
  SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/claude config test.XXXXXX")"
  SANDBOX="$(cd "$SANDBOX" && pwd -P)"
  trap 'rm -rf "$SANDBOX"' EXIT
  REPO="$SANDBOX/repo"
  mkdir -p "$REPO" "$SANDBOX/home"
  tar -C "$REPO_SRC" --exclude=./.git --exclude=./settings/local.json -cf - . | tar -C "$REPO" -xf -
  export HOME="$SANDBOX/home"
  export CLAUDE_HOME="$HOME/.claude"
  export CALLS_LOG="$SANDBOX/calls.log"
  STUBS="$SANDBOX/stubs"
  CLI="$REPO/bin/claude-config"
}

fail() {
  printf 'ÉCHEC : %s\n' "$*" >&2
  exit 1
}

assert_eq() {
  [[ "$1" == "$2" ]] || fail "${3:-valeur} : attendu [$2], obtenu [$1]"
}

assert_contains() {
  [[ "$1" == *"$2"* ]] || fail "[$2] absent de : $1"
}

assert_not_contains() {
  [[ "$1" != *"$2"* ]] || fail "[$2] présent dans : $1"
}

# Vérifie qu'une ligne « <statut> <message> » figure dans la sortie (espacement ignoré).
assert_has_line() {
  sed -E 's/^([a-z-]+) +/\1 /' <<<"$1" | grep -qxF -- "$2 $3" || fail "ligne [$2 $3] absente de : $1"
}

assert_symlink_to() {
  [[ -L "$1" ]] || fail "$1 n'est pas un symlink"
  assert_eq "$(readlink "$1")" "$2" "cible de $1"
}

assert_json_eq() {
  assert_eq "$(jq -S . "$1")" "$(jq -S . <<<"$2")" "contenu JSON de $1"
}

count_backups() {
  find "$1" -name '*.bak-*' | wc -l
}

# Empreinte d'une arborescence : chemins, types, cibles de liens et contenus.
snapshot() {
  (cd "$1" && find . -printf '%p|%y|%l|%m\n' | sort && find . -type f -exec md5sum {} + | sort)
}

# Crée un faux exécutable qui journalise son appel dans $CALLS_LOG et sort avec <code_sortie>.
make_stub() {
  local name="$1" code="${2:-0}"
  mkdir -p "$STUBS"
  {
    printf '#!/usr/bin/env bash\n'
    printf 'printf "%%s\\n" "%s $*" >> "$CALLS_LOG"\n' "$name"
    printf 'exit %s\n' "$code"
  } > "$STUBS/$name"
  chmod +x "$STUBS/$name"
}
```

- [ ] **Step 6: Créer `tests/run.sh`**

```bash
#!/usr/bin/env bash
# Runner de tests sans dépendance : chaque fonction test_* de tests/test_*.sh
# s'exécute dans son propre processus, au sein d'un bac à sable jetable.
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_SRC="$(cd "$TESTS_DIR/.." && pwd -P)"
export TESTS_DIR REPO_SRC

# shellcheck source=tests/helpers.sh
source "$TESTS_DIR/helpers.sh"
for f in "$TESTS_DIR"/test_*.sh; do
  [[ -e "$f" ]] || continue
  # shellcheck source=/dev/null
  source "$f"
done

# Mode interne : exécute un seul test (processus séparé pour que set -e s'applique).
if [[ "${1:-}" == "--one" ]]; then
  setup_sandbox
  "$2"
  exit 0
fi

filter="${1:-}"
passed=0
failed=0
out="$(mktemp)"
trap 'rm -f "$out"' EXIT

while IFS= read -r t; do
  if [[ -n "$filter" && "$t" != *"$filter"* ]]; then
    continue
  fi
  if bash "${BASH_SOURCE[0]}" --one "$t" >"$out" 2>&1; then
    passed=$((passed + 1))
    printf 'PASS  %s\n' "$t"
  else
    failed=$((failed + 1))
    printf 'FAIL  %s\n' "$t"
    sed 's/^/      /' "$out"
  fi
done < <(declare -F | awk '{print $3}' | grep '^test_' | sort || true)

if [[ -z "$filter" ]]; then
  if command -v shellcheck >/dev/null 2>&1; then
    mapfile -t files < <(cd "$REPO_SRC" && ls -d bin/claude-config deps.sh lib/*.sh tests/*.sh 2>/dev/null || true)
    if (cd "$REPO_SRC" && shellcheck -x "${files[@]}"); then
      passed=$((passed + 1))
      printf 'PASS  shellcheck\n'
    else
      failed=$((failed + 1))
      printf 'FAIL  shellcheck\n'
    fi
  else
    printf 'SKIP  shellcheck (non installé)\n'
  fi
fi

printf '\n%d réussi(s), %d échec(s)\n' "$passed" "$failed"
[[ "$failed" -eq 0 ]]
```

Puis : `chmod +x tests/run.sh`

- [ ] **Step 7: Lancer le runner**

Run : `tests/run.sh`
Expected : `PASS  shellcheck` puis `1 réussi(s), 0 échec(s)`, code de sortie 0. Si shellcheck signale un problème dans `tests/*.sh`, le corriger.

- [ ] **Step 8: Mettre la spec à jour pour les écarts assumés**

Dans `docs/superpowers/specs/2026-10-05-claude-config-design.md` :
- §4 Arborescence : ajouter sous `bin/claude-config` les lignes `lib/` (`common.sh`, `links.sh`, `settings.sh`, `project.sh`, `capture.jq`) et, sous `tests/`, `helpers.sh` et `test_*.sh` ;
- §6.5 : remplacer « Remplace le placeholder `{{PROJECT_NAME}}` du `CLAUDE.md` copié » par « Remplace le placeholder `{{PROJECT_NAME}}` dans tous les fichiers copiés » ;
- §6.2 : insérer après l'étape 1 « Valide les settings fusionnés (base + local) ; en cas d'erreur, rien n'est installé ».

- [ ] **Step 9: Commit**

```bash
git add .gitignore global settings templates tests docs
git commit -m "chore: scaffold repo, import current Claude config, add test runner

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Point d'entrée du CLI et fonctions communes

**Files:**
- Create: `bin/claude-config`, `lib/common.sh`
- Test: `tests/test_common.sh`, `tests/test_cli.sh`

**Interfaces:**
- Consumes : helpers de Task 1.
- Produces :
  - variables globales `REPO_ROOT` (racine physique du repo), `CLAUDE_HOME`, `DRY_RUN` (0 ou 1)
  - `log <statut> <message>` (stdout), `die <message> [code=1]` (stderr, sortie), `timestamp` (`YYYYmmdd-HHMMSS`), `backup_path <chemin>` (déplace vers `.bak-<ts>[-N]` et journalise `backup` ; ne fait que journaliser si `DRY_RUN=1`), `require_jq`
  - le `case` de `main` dans `bin/claude-config`, auquel les tâches suivantes ajoutent une ligne par commande

- [ ] **Step 1: Écrire les tests qui échouent**

`tests/test_common.sh` :
```bash
# shellcheck shell=bash
# shellcheck disable=SC2154

test_backup_path_avoids_collision() {
  # shellcheck source=lib/common.sh
  source "$REPO/lib/common.sh"
  DRY_RUN=0
  timestamp() { printf '20260101-000000'; }
  printf 'a' > "$SANDBOX/f"
  backup_path "$SANDBOX/f" >/dev/null
  printf 'b' > "$SANDBOX/f"
  backup_path "$SANDBOX/f" >/dev/null
  assert_eq "$(cat "$SANDBOX/f.bak-20260101-000000")" "a" "première sauvegarde"
  assert_eq "$(cat "$SANDBOX/f.bak-20260101-000000-1")" "b" "seconde sauvegarde"
  [[ ! -e "$SANDBOX/f" ]] || fail "le fichier d'origine aurait dû être déplacé"
}

test_backup_path_dry_run_moves_nothing() {
  # shellcheck source=lib/common.sh
  source "$REPO/lib/common.sh"
  DRY_RUN=1
  printf 'a' > "$SANDBOX/f"
  local out
  out="$(backup_path "$SANDBOX/f")"
  assert_contains "$out" "backup"
  [[ -e "$SANDBOX/f" ]] || fail "dry-run ne doit rien déplacer"
  assert_eq "$(count_backups "$SANDBOX")" 0 "nombre de sauvegardes"
}
```

`tests/test_cli.sh` :
```bash
# shellcheck shell=bash
# shellcheck disable=SC2154

test_cli_help() {
  local out
  out="$("$CLI" --help)"
  assert_contains "$out" "install"
  assert_contains "$out" "init-project"
}

test_cli_unknown_command() {
  local rc=0 out
  out="$("$CLI" frobnicate 2>&1)" || rc=$?
  assert_eq "$rc" 2 "code de sortie"
  assert_contains "$out" "commande inconnue : frobnicate"
}

test_cli_without_command() {
  local rc=0 out
  out="$("$CLI" 2>&1)" || rc=$?
  assert_eq "$rc" 2 "code de sortie"
  assert_contains "$out" "Usage"
}
```

- [ ] **Step 2: Vérifier qu'ils échouent**

Run : `tests/run.sh backup && tests/run.sh cli`
Expected : FAIL sur les 5 tests (`lib/common.sh` et `bin/claude-config` n'existent pas encore).

- [ ] **Step 3: Écrire `lib/common.sh`**

```bash
# shellcheck shell=bash
# Fonctions partagées : journalisation, erreurs, sauvegardes.
# Sourcé par bin/claude-config, qui définit REPO_ROOT, CLAUDE_HOME et DRY_RUN.
# shellcheck disable=SC2154

log() {
  printf '%-9s %s\n' "$1" "$2"
}

die() {
  printf 'error     %s\n' "$1" >&2
  exit "${2:-1}"
}

timestamp() {
  date +%Y%m%d-%H%M%S
}

# Déplace <chemin> vers <chemin>.bak-<timestamp>, avec un suffixe -N si ce nom existe déjà.
backup_path() {
  local path="$1" base candidate n=1
  base="$path.bak-$(timestamp)"
  candidate="$base"
  while [[ -e "$candidate" || -L "$candidate" ]]; do
    candidate="$base-$n"
    n=$((n + 1))
  done
  if [[ "${DRY_RUN:-0}" -eq 0 ]]; then
    mv "$path" "$candidate"
  fi
  log backup "$path -> $candidate"
}

require_jq() {
  command -v jq >/dev/null 2>&1 || die "jq est requis (sudo apt install jq)"
}
```

- [ ] **Step 4: Écrire `bin/claude-config`**

```bash
#!/usr/bin/env bash
# Installe et synchronise la config Claude Code versionnée dans ce repo.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd -P)"
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
DRY_RUN=0

# shellcheck source=lib/common.sh
source "$REPO_ROOT/lib/common.sh"

usage() {
  cat <<'EOF'
Usage : claude-config <commande> [options]

Commandes :
  install [--dry-run] [--no-deps]   Installe la config dans $CLAUDE_HOME (défaut ~/.claude)
  status                            Compare la config installée au repo (code 1 si écart)
  capture                           Recopie $CLAUDE_HOME/settings.json dans settings/base.json
  init-project <dir> [--template <nom>] [--force]
                                    Copie un template de config Claude dans un repo
EOF
}

main() {
  local cmd="${1:-}"
  if [[ $# -gt 0 ]]; then
    shift
  fi
  case "$cmd" in
    -h | --help | help) usage ;;
    "")
      usage >&2
      exit 2
      ;;
    *)
      printf 'error     commande inconnue : %s\n' "$cmd" >&2
      usage >&2
      exit 2
      ;;
  esac
}

main "$@"
```

Puis : `chmod +x bin/claude-config`

- [ ] **Step 5: Vérifier que les tests passent**

Run : `tests/run.sh`
Expected : 5 tests PASS + `PASS  shellcheck`, `0 échec(s)`.

- [ ] **Step 6: Commit**

```bash
git add bin lib tests
git commit -m "feat: add CLI entry point and shared helpers

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Symlinks (`install` et `status`, partie liens)

**Files:**
- Create: `lib/links.sh`
- Modify: `bin/claude-config` (source de `lib/links.sh`, `cmd_install`, `cmd_status`, cases `install` et `status`)
- Test: `tests/test_links.sh`

**Interfaces:**
- Consumes : `log`, `backup_path`, `require_jq`, `DRY_RUN`, `REPO_ROOT`, `CLAUDE_HOME` (Task 2).
- Produces :
  - `managed_links` : affiche un chemin relatif par ligne (`CLAUDE.md`, `RTK.md`, `statusline-command.sh`, `skills/<nom>`), la source étant `$REPO_ROOT/global/<rel>` et la destination `$CLAUDE_HOME/<rel>`
  - `install_links`, `status_links` (renvoie 1 en cas d'écart)
  - `cmd_install [--dry-run] [--no-deps]` et `cmd_status` dans `bin/claude-config` (étendus aux Tasks 4 et 5)

- [ ] **Step 1: Écrire les tests qui échouent**

`tests/test_links.sh` :
```bash
# shellcheck shell=bash
# shellcheck disable=SC2154

add_skill_fixture() {
  mkdir -p "$REPO/global/skills/my-skill"
  printf -- '---\nname: my-skill\n---\n' > "$REPO/global/skills/my-skill/SKILL.md"
}

test_install_links_on_empty_home() {
  add_skill_fixture
  "$CLI" install --no-deps >/dev/null
  local f
  for f in CLAUDE.md RTK.md statusline-command.sh; do
    assert_symlink_to "$CLAUDE_HOME/$f" "$REPO/global/$f"
  done
  assert_symlink_to "$CLAUDE_HOME/skills/my-skill" "$REPO/global/skills/my-skill"
  [[ ! -e "$CLAUDE_HOME/skills/.gitkeep" ]] || fail ".gitkeep ne doit pas être lié"
}

test_install_links_idempotent() {
  add_skill_fixture
  "$CLI" install --no-deps >/dev/null
  local out
  out="$("$CLI" install --no-deps)"
  assert_not_contains "$out" "linked"
  assert_not_contains "$out" "backup"
  assert_has_line "$out" ok CLAUDE.md
  assert_has_line "$out" ok skills/my-skill
  assert_eq "$(count_backups "$CLAUDE_HOME")" 0 "nombre de sauvegardes"
}

test_install_backs_up_real_file() {
  mkdir -p "$CLAUDE_HOME"
  printf 'ancien\n' > "$CLAUDE_HOME/CLAUDE.md"
  local out bak
  out="$("$CLI" install --no-deps)"
  assert_has_line "$out" linked CLAUDE.md
  assert_symlink_to "$CLAUDE_HOME/CLAUDE.md" "$REPO/global/CLAUDE.md"
  bak="$(find "$CLAUDE_HOME" -maxdepth 1 -name 'CLAUDE.md.bak-*')"
  [[ -n "$bak" ]] || fail "sauvegarde de CLAUDE.md absente"
  assert_eq "$(cat "$bak")" "ancien" "contenu sauvegardé"
}

test_install_relinks_foreign_symlink() {
  mkdir -p "$CLAUDE_HOME"
  ln -s /nonexistent "$CLAUDE_HOME/RTK.md"
  local out
  out="$("$CLI" install --no-deps)"
  assert_has_line "$out" relinked RTK.md
  assert_symlink_to "$CLAUDE_HOME/RTK.md" "$REPO/global/RTK.md"
  assert_eq "$(count_backups "$CLAUDE_HOME")" 0 "nombre de sauvegardes"
}

test_install_keeps_foreign_entries() {
  mkdir -p "$CLAUDE_HOME/skills/synced/abc" "$CLAUDE_HOME/skills/other" "$SANDBOX/agents/angular-developer"
  printf 'x' > "$CLAUDE_HOME/skills/other/SKILL.md"
  ln -s "$SANDBOX/agents/angular-developer" "$CLAUDE_HOME/skills/angular-developer"
  local before
  before="$(snapshot "$CLAUDE_HOME/skills")"
  "$CLI" install --no-deps >/dev/null
  assert_eq "$(snapshot "$CLAUDE_HOME/skills")" "$before" "contenu de skills/"
}

test_install_via_symlinked_cli() {
  mkdir -p "$SANDBOX/bin"
  ln -s "$CLI" "$SANDBOX/bin/claude-config"
  "$SANDBOX/bin/claude-config" install --no-deps >/dev/null
  assert_symlink_to "$CLAUDE_HOME/CLAUDE.md" "$REPO/global/CLAUDE.md"
}

test_install_dry_run_changes_nothing() {
  mkdir -p "$CLAUDE_HOME"
  printf 'ancien\n' > "$CLAUDE_HOME/CLAUDE.md"
  printf '{"x":1}\n' > "$CLAUDE_HOME/settings.json"
  local before out
  before="$(snapshot "$SANDBOX")"
  out="$("$CLI" install --dry-run --no-deps)"
  assert_eq "$(snapshot "$SANDBOX")" "$before" "arborescence"
  assert_has_line "$out" linked CLAUDE.md
}

test_install_dry_run_on_missing_home() {
  "$CLI" install --dry-run --no-deps >/dev/null
  [[ ! -e "$CLAUDE_HOME" ]] || fail "dry-run ne doit pas créer $CLAUDE_HOME"
}

test_install_rejects_unknown_option() {
  local rc=0 out
  out="$("$CLI" install --frobnicate 2>&1)" || rc=$?
  assert_eq "$rc" 2 "code de sortie"
  assert_contains "$out" "option inconnue"
}

test_status_clean_after_install() {
  "$CLI" install --no-deps >/dev/null
  "$CLI" status >/dev/null || fail "status devrait renvoyer 0 juste après install"
}

test_status_reports_link_problems() {
  "$CLI" install --no-deps >/dev/null
  rm "$CLAUDE_HOME/CLAUDE.md"
  rm "$CLAUDE_HOME/RTK.md"
  printf 'x' > "$CLAUDE_HOME/RTK.md"
  rm "$CLAUDE_HOME/statusline-command.sh"
  ln -s /nonexistent "$CLAUDE_HOME/statusline-command.sh"
  local rc=0 out
  out="$("$CLI" status)" || rc=$?
  assert_eq "$rc" 1 "code de sortie"
  assert_has_line "$out" missing CLAUDE.md
  assert_has_line "$out" drift "RTK.md (fichier réel, pas un symlink)"
  assert_has_line "$out" broken statusline-command.sh
}
```

- [ ] **Step 2: Vérifier qu'ils échouent**

Run : `tests/run.sh install && tests/run.sh status`
Expected : FAIL avec `commande inconnue : install` / `commande inconnue : status`.

- [ ] **Step 3: Écrire `lib/links.sh`**

```bash
# shellcheck shell=bash
# Éléments de global/ installés par symlink dans $CLAUDE_HOME.
# Sourcé par bin/claude-config, qui définit REPO_ROOT, CLAUDE_HOME et DRY_RUN.
# shellcheck disable=SC2154

# Chemins relatifs gérés : fichiers de global/ (hors skills/) puis chaque dossier global/skills/*.
managed_links() {
  find "$REPO_ROOT/global" -mindepth 1 -maxdepth 1 ! -name skills -printf '%P\n' | sort
  if [[ -d "$REPO_ROOT/global/skills" ]]; then
    find "$REPO_ROOT/global/skills" -mindepth 1 -maxdepth 1 -type d -printf 'skills/%P\n' | sort
  fi
}

link_item() {
  local rel="$1"
  local src="$REPO_ROOT/global/$rel" dest="$CLAUDE_HOME/$rel"
  if [[ -L "$dest" ]]; then
    if [[ "$(readlink "$dest")" == "$src" ]]; then
      log ok "$rel"
      return 0
    fi
    if [[ "$DRY_RUN" -eq 0 ]]; then
      rm "$dest"
      ln -s "$src" "$dest"
    fi
    log relinked "$rel"
    return 0
  fi
  if [[ -e "$dest" ]]; then
    backup_path "$dest"
  fi
  if [[ "$DRY_RUN" -eq 0 ]]; then
    mkdir -p "$(dirname "$dest")"
    ln -s "$src" "$dest"
  fi
  log linked "$rel"
}

install_links() {
  local rel
  while IFS= read -r rel; do
    link_item "$rel"
  done < <(managed_links)
}

# Renvoie 0 si $CLAUDE_HOME/<rel> est le bon symlink, 1 sinon (avec une ligne de diagnostic).
check_link() {
  local rel="$1"
  local src="$REPO_ROOT/global/$rel" dest="$CLAUDE_HOME/$rel"
  if [[ -L "$dest" ]]; then
    if [[ "$(readlink "$dest")" == "$src" ]]; then
      log ok "$rel"
      return 0
    fi
    if [[ -e "$dest" ]]; then
      log drift "$rel -> $(readlink "$dest")"
    else
      log broken "$rel"
    fi
  elif [[ -e "$dest" ]]; then
    log drift "$rel (fichier réel, pas un symlink)"
  else
    log missing "$rel"
  fi
  return 1
}

status_links() {
  local rel rc=0
  while IFS= read -r rel; do
    check_link "$rel" || rc=1
  done < <(managed_links)
  return "$rc"
}
```

Note : un symlink vers une cible inexistante est `broken` ; un symlink vers une autre cible existante est `drift`.

- [ ] **Step 4: Brancher les commandes dans `bin/claude-config`**

Sous la ligne `source "$REPO_ROOT/lib/common.sh"` :
```bash
# shellcheck source=lib/links.sh
source "$REPO_ROOT/lib/links.sh"
```

Au-dessus de `main()` :
```bash
cmd_install() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run) DRY_RUN=1 ;;
      --no-deps) ;;
      *) die "option inconnue pour install : $1" 2 ;;
    esac
    shift
  done
  require_jq
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log info "dry-run : aucune modification"
  fi
  install_links
}

cmd_status() {
  if [[ $# -gt 0 ]]; then
    die "status ne prend pas d'option" 2
  fi
  require_jq
  local rc=0
  status_links || rc=1
  return "$rc"
}
```

Dans le `case` de `main`, avant `-h | --help | help)` :
```bash
    install) cmd_install "$@" ;;
    status) cmd_status "$@" ;;
```

- [ ] **Step 5: Vérifier que les tests passent**

Run : `tests/run.sh`
Expected : tous les tests PASS, y compris shellcheck.

- [ ] **Step 6: Commit**

```bash
git add bin lib tests
git commit -m "feat: install and check symlinks for global config files and skills

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Settings (fusion, `install`, `status`, `capture`)

**Files:**
- Create: `lib/settings.sh`, `lib/capture.jq`
- Modify: `bin/claude-config` (source de `lib/settings.sh`, `cmd_install`, `cmd_status`, nouveau `cmd_capture`, case `capture`)
- Test: `tests/test_settings.sh`

**Interfaces:**
- Consumes : `log`, `die`, `backup_path`, `require_jq` (Task 2) ; `install_links`, `status_links` (Task 3).
- Produces :
  - `merged_settings` : écrit sur stdout le JSON fusionné (indentation 2) ; sort via `die` si `base.json` ou `local.json` est invalide
  - `install_settings` (statut `ok` ou `written`), `status_settings` (renvoie 1 en cas d'écart et affiche un diff unifié), `capture_settings`
  - `cmd_capture` dans `bin/claude-config`

- [ ] **Step 1: Écrire les tests qui échouent**

`tests/test_settings.sh` :
```bash
# shellcheck shell=bash
# shellcheck disable=SC2154

write_base() {
  printf '%s\n' "$1" > "$REPO/settings/base.json"
}

write_local() {
  printf '%s\n' "$1" > "$REPO/settings/local.json"
}

test_install_writes_base_settings() {
  write_base '{"model":"opus","env":{"A":"1"}}'
  local out
  out="$("$CLI" install --no-deps)"
  assert_has_line "$out" written settings.json
  assert_json_eq "$CLAUDE_HOME/settings.json" '{"model":"opus","env":{"A":"1"}}'
}

test_install_merges_local_settings() {
  write_base '{"model":"opus","env":{"A":"1"},"list":[1,2]}'
  write_local '{"model":"sonnet","env":{"B":"2"},"list":[3]}'
  "$CLI" install --no-deps >/dev/null
  assert_json_eq "$CLAUDE_HOME/settings.json" '{"model":"sonnet","env":{"A":"1","B":"2"},"list":[3]}'
}

test_install_settings_idempotent() {
  write_base '{"model":"opus"}'
  "$CLI" install --no-deps >/dev/null
  local out
  out="$("$CLI" install --no-deps)"
  assert_has_line "$out" ok settings.json
  assert_eq "$(count_backups "$CLAUDE_HOME")" 0 "nombre de sauvegardes"
}

test_install_backs_up_different_settings() {
  write_base '{"model":"opus"}'
  mkdir -p "$CLAUDE_HOME"
  printf '{"x":1}\n' > "$CLAUDE_HOME/settings.json"
  "$CLI" install --no-deps >/dev/null
  local bak
  bak="$(find "$CLAUDE_HOME" -maxdepth 1 -name 'settings.json.bak-*')"
  [[ -n "$bak" ]] || fail "sauvegarde de settings.json absente"
  assert_json_eq "$bak" '{"x":1}'
  assert_json_eq "$CLAUDE_HOME/settings.json" '{"model":"opus"}'
}

test_install_backs_up_invalid_settings() {
  write_base '{"model":"opus"}'
  mkdir -p "$CLAUDE_HOME"
  printf 'pas du json\n' > "$CLAUDE_HOME/settings.json"
  "$CLI" install --no-deps >/dev/null
  assert_eq "$(count_backups "$CLAUDE_HOME")" 1 "nombre de sauvegardes"
  assert_json_eq "$CLAUDE_HOME/settings.json" '{"model":"opus"}'
}

test_install_rejects_invalid_local() {
  write_base '{"model":"opus"}'
  write_local '{'
  local rc=0 out
  out="$("$CLI" install --no-deps 2>&1)" || rc=$?
  [[ "$rc" -ne 0 ]] || fail "install aurait dû échouer"
  assert_contains "$out" "local.json"
  [[ ! -e "$CLAUDE_HOME/settings.json" ]] || fail "settings.json ne doit pas être écrit"
  [[ ! -e "$CLAUDE_HOME/CLAUDE.md" ]] || fail "aucun symlink ne doit être créé"
}

test_status_ignores_key_order() {
  write_base '{"a":1,"b":{"c":2,"d":3}}'
  "$CLI" install --no-deps >/dev/null
  printf '{"b":{"d":3,"c":2},"a":1}\n' > "$CLAUDE_HOME/settings.json"
  "$CLI" status >/dev/null || fail "un simple réordonnancement ne doit pas être un écart"
}

test_status_detects_settings_drift() {
  write_base '{"model":"opus"}'
  "$CLI" install --no-deps >/dev/null
  printf '{"model":"haiku"}\n' > "$CLAUDE_HOME/settings.json"
  local rc=0 out
  out="$("$CLI" status)" || rc=$?
  assert_eq "$rc" 1 "code de sortie"
  assert_has_line "$out" drift settings.json
  assert_contains "$out" "haiku"
}

test_capture_without_local() {
  write_base '{"model":"opus"}'
  "$CLI" install --no-deps >/dev/null
  printf '{"model":"opus","theme":"light"}\n' > "$CLAUDE_HOME/settings.json"
  "$CLI" capture >/dev/null
  assert_json_eq "$REPO/settings/base.json" '{"model":"opus","theme":"light"}'
  "$CLI" status >/dev/null || fail "status devrait être propre après capture"
}

test_capture_keeps_local_overrides_out_of_base() {
  write_base '{"model":"opus","env":{"A":"1"}}'
  write_local '{"model":"sonnet","env":{"B":"2"},"onlyLocal":{"k":true}}'
  "$CLI" install --no-deps >/dev/null
  jq '.theme = "light"' "$CLAUDE_HOME/settings.json" > "$SANDBOX/s.json"
  mv "$SANDBOX/s.json" "$CLAUDE_HOME/settings.json"
  "$CLI" capture >/dev/null
  assert_json_eq "$REPO/settings/base.json" '{"model":"opus","env":{"A":"1"},"theme":"light"}'
}

test_capture_rejects_invalid_settings() {
  write_base '{"model":"opus"}'
  "$CLI" install --no-deps >/dev/null
  printf 'oops\n' > "$CLAUDE_HOME/settings.json"
  local rc=0
  "$CLI" capture >/dev/null 2>&1 || rc=$?
  [[ "$rc" -ne 0 ]] || fail "capture aurait dû échouer"
  assert_json_eq "$REPO/settings/base.json" '{"model":"opus"}'
}
```

- [ ] **Step 2: Vérifier qu'ils échouent**

Run : `tests/run.sh settings && tests/run.sh capture && tests/run.sh status_`
Expected : FAIL. `settings.json` n'est pas écrit et la commande `capture` est inconnue. `test_status_clean_after_install` (Task 3) doit rester PASS.

- [ ] **Step 3: Écrire `lib/capture.jq`**

```jq
# Reconstruit base.json à partir des settings courants ($cur) sans y remonter les
# surcharges de local.json ($loc) : pour chaque chemin feuille de $loc (un tableau
# compte comme une feuille), on reprend la valeur de $base si elle existe, sinon on
# supprime le chemin, puis on retire les objets devenus vides absents de $base.

def leafpaths:
  if type == "object" then
    to_entries[] | .key as $k | (.value | leafpaths | [$k] + .)
  else
    []
  end;

def haspath($p):
  if ($p | length) == 0 then true
  else (try (getpath($p[:-1]) | type == "object" and has($p[-1])) catch false)
  end;

def prune($b; $p):
  if ($p | length) == 0 then .
  elif ((try getpath($p) catch null) == {}) and (($b | haspath($p)) | not) then
    delpaths([$p]) | prune($b; $p[:-1])
  else .
  end;

$cur[0] as $c
| $base[0] as $b
| $loc[0] as $l
| reduce ($l | leafpaths) as $p ($c;
    . as $acc
    | if ($b | haspath($p)) then
        (try setpath($p; $b | getpath($p)) catch $acc)
      else
        (try delpaths([$p]) catch $acc) | prune($b; $p[:-1])
      end)
```

- [ ] **Step 4: Écrire `lib/settings.sh`**

```bash
# shellcheck shell=bash
# settings.json : généré depuis settings/base.json (+ settings/local.json), copié et non symlinké.
# Sourcé par bin/claude-config, qui définit REPO_ROOT, CLAUDE_HOME et DRY_RUN.
# shellcheck disable=SC2154

# Écrit sur stdout les settings fusionnés ; sort en erreur si une source est invalide.
merged_settings() {
  local base="$REPO_ROOT/settings/base.json" loc="$REPO_ROOT/settings/local.json"
  [[ -f "$base" ]] || die "settings/base.json introuvable"
  jq -e 'type == "object"' "$base" >/dev/null 2>&1 || die "settings/base.json n'est pas un objet JSON valide"
  if [[ -f "$loc" ]]; then
    jq -e 'type == "object"' "$loc" >/dev/null 2>&1 || die "settings/local.json n'est pas un objet JSON valide"
    jq -s '.[0] * .[1]' "$base" "$loc"
  else
    jq . "$base"
  fi
}

install_settings() {
  local dest="$CLAUDE_HOME/settings.json" merged
  merged="$(merged_settings)"
  if [[ -e "$dest" || -L "$dest" ]]; then
    if jq -e . "$dest" >/dev/null 2>&1 && [[ "$(jq -S . "$dest")" == "$(jq -S . <<<"$merged")" ]]; then
      log ok settings.json
      return 0
    fi
    backup_path "$dest"
  fi
  if [[ "$DRY_RUN" -eq 0 ]]; then
    mkdir -p "$CLAUDE_HOME"
    printf '%s\n' "$merged" > "$dest.tmp"
    mv "$dest.tmp" "$dest"
  fi
  log written settings.json
}

status_settings() {
  local dest="$CLAUDE_HOME/settings.json" merged diff_out
  merged="$(merged_settings)"
  if [[ ! -e "$dest" ]]; then
    log missing settings.json
    return 1
  fi
  if ! jq -e . "$dest" >/dev/null 2>&1; then
    log drift "settings.json (JSON invalide)"
    return 1
  fi
  if diff_out="$(diff -u --label attendu --label actuel <(jq -S . <<<"$merged") <(jq -S . "$dest"))"; then
    log ok settings.json
    return 0
  fi
  log drift settings.json
  printf '%s\n' "$diff_out"
  return 1
}

capture_settings() {
  local src="$CLAUDE_HOME/settings.json" base="$REPO_ROOT/settings/base.json"
  local loc="$REPO_ROOT/settings/local.json" result
  [[ -f "$src" ]] || die "$src introuvable"
  jq -e 'type == "object"' "$src" >/dev/null 2>&1 || die "$src n'est pas un objet JSON valide"
  jq -e 'type == "object"' "$base" >/dev/null 2>&1 || die "settings/base.json n'est pas un objet JSON valide"
  if [[ -f "$loc" ]]; then
    jq -e 'type == "object"' "$loc" >/dev/null 2>&1 || die "settings/local.json n'est pas un objet JSON valide"
    result="$(jq -n --slurpfile cur "$src" --slurpfile base "$base" --slurpfile loc "$loc" \
      -f "$REPO_ROOT/lib/capture.jq")"
  else
    result="$(jq . "$src")"
  fi
  printf '%s\n' "$result" > "$base.tmp"
  mv "$base.tmp" "$base"
  log written settings/base.json
  git -C "$REPO_ROOT" diff --stat -- settings/base.json 2>/dev/null || true
}
```

- [ ] **Step 5: Brancher dans `bin/claude-config`**

Sous `source "$REPO_ROOT/lib/links.sh"` :
```bash
# shellcheck source=lib/settings.sh
source "$REPO_ROOT/lib/settings.sh"
```

Remplacer `cmd_install` et `cmd_status` par :
```bash
cmd_install() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run) DRY_RUN=1 ;;
      --no-deps) ;;
      *) die "option inconnue pour install : $1" 2 ;;
    esac
    shift
  done
  require_jq
  merged_settings >/dev/null
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log info "dry-run : aucune modification"
  fi
  install_links
  install_settings
}

cmd_status() {
  if [[ $# -gt 0 ]]; then
    die "status ne prend pas d'option" 2
  fi
  require_jq
  local rc=0
  status_links || rc=1
  status_settings || rc=1
  return "$rc"
}

cmd_capture() {
  if [[ $# -gt 0 ]]; then
    die "capture ne prend pas d'option" 2
  fi
  require_jq
  capture_settings
}
```

Dans le `case` de `main`, après `status)` :
```bash
    capture) cmd_capture "$@" ;;
```

- [ ] **Step 6: Vérifier que les tests passent**

Run : `tests/run.sh`
Expected : tous PASS, y compris les tests de Task 3 et shellcheck.

- [ ] **Step 7: Commit**

```bash
git add bin lib tests
git commit -m "feat: generate, check and capture settings.json from base + local

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Dépendances externes (`deps.sh`)

**Files:**
- Create: `deps.sh`
- Modify: `bin/claude-config` (`cmd_install` : option `--no-deps` effective, appel de `ensure_all`)
- Test: `tests/test_deps.sh`

**Interfaces:**
- Consumes : `log`, `CLAUDE_HOME` ; `$CLAUDE_HOME/settings.json` déjà écrit par `install_settings` (Task 4).
- Produces : `ensure_rtk`, `ensure_plannotator`, `ensure_angular_developer`, `ensure_plugins`, `ensure_all`. Statuts : `ok`, `installed`, `warn`. Aucune de ces fonctions ne renvoie de code non nul.

- [ ] **Step 1: Écrire les tests qui échouent**

`tests/test_deps.sh` :
```bash
# shellcheck shell=bash
# shellcheck disable=SC2154

# Faux CLI claude : journalise ses appels et renvoie les listes JSON fournies.
stub_claude() {
  mkdir -p "$STUBS"
  printf '%s\n' "$1" > "$SANDBOX/marketplaces.json"
  printf '%s\n' "$2" > "$SANDBOX/plugins.json"
  cat > "$STUBS/claude" <<'EOF'
#!/usr/bin/env bash
printf 'claude %s\n' "$*" >> "$CALLS_LOG"
case "$*" in
  "plugin marketplace list --json") cat "$STUB_DIR/marketplaces.json" ;;
  "plugin list --json") cat "$STUB_DIR/plugins.json" ;;
esac
EOF
  chmod +x "$STUBS/claude"
  export STUB_DIR="$SANDBOX"
}

# PATH réduit : les stubs d'abord, puis seulement les outils système.
run_install() {
  PATH="$STUBS:/usr/bin:/bin" "$CLI" install "$@"
}

calls() {
  cat "$CALLS_LOG" 2>/dev/null || true
}

empty_settings() {
  printf '{}\n' > "$REPO/settings/base.json"
}

fake_angular_skill() {
  mkdir -p "$CLAUDE_HOME/skills/angular-developer"
}

test_deps_nothing_to_install() {
  empty_settings
  make_stub rtk
  make_stub plannotator
  fake_angular_skill
  stub_claude '[]' '[]'
  local out
  out="$(run_install)"
  assert_has_line "$out" ok rtk
  assert_has_line "$out" ok plannotator
  assert_has_line "$out" ok "skill angular-developer"
  assert_not_contains "$(calls)" "install"
  assert_not_contains "$(calls)" "add"
}

test_deps_rtk_via_brew() {
  empty_settings
  make_stub brew
  make_stub plannotator
  fake_angular_skill
  stub_claude '[]' '[]'
  local out
  out="$(run_install)"
  assert_contains "$(calls)" "brew install rtk"
  assert_has_line "$out" installed "rtk (brew)"
}

test_deps_rtk_via_script_without_brew() {
  empty_settings
  make_stub curl
  make_stub plannotator
  fake_angular_skill
  stub_claude '[]' '[]'
  local out
  out="$(run_install)"
  assert_contains "$(calls)" "curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh"
  assert_has_line "$out" installed "rtk (script officiel)"
}

test_deps_failure_is_only_a_warning() {
  empty_settings
  make_stub curl 22
  make_stub plannotator
  fake_angular_skill
  stub_claude '[]' '[]'
  local rc=0 out
  out="$(run_install 2>&1)" || rc=$?
  assert_eq "$rc" 0 "code de sortie"
  assert_contains "$out" "warn"
  assert_contains "$out" "rtk"
}

test_deps_plannotator_via_script() {
  empty_settings
  make_stub rtk
  make_stub curl
  fake_angular_skill
  stub_claude '[]' '[]'
  local out
  out="$(run_install)"
  assert_contains "$(calls)" "curl -fsSL https://plannotator.ai/install.sh"
  assert_has_line "$out" installed plannotator
}

test_deps_angular_developer_via_npx() {
  empty_settings
  make_stub rtk
  make_stub plannotator
  make_stub npx
  stub_claude '[]' '[]'
  local out
  out="$(run_install)"
  assert_contains "$(calls)" "npx -y skills add affaan-m/ecc --skill angular-developer -g -a claude-code -y"
  assert_has_line "$out" installed "skill angular-developer"
}

test_deps_installs_missing_plugins() {
  printf '%s\n' '{"extraKnownMarketplaces":{"plannotator":{"source":{"source":"github","repo":"backnotprop/plannotator"}}},"enabledPlugins":{"a@m":true,"b@m":false,"plannotator@plannotator":true}}' \
    > "$REPO/settings/base.json"
  make_stub rtk
  make_stub plannotator
  fake_angular_skill
  stub_claude '[{"name":"m"}]' '[{"id":"a@m"}]'
  local out c
  out="$(run_install)"
  c="$(calls)"
  assert_contains "$c" "claude plugin marketplace add backnotprop/plannotator"
  assert_contains "$c" "claude plugin install plannotator@plannotator --scope user"
  assert_not_contains "$c" "install a@m"
  assert_not_contains "$c" "install b@m"
  assert_has_line "$out" ok "plugin a@m"
  assert_has_line "$out" installed "plugin plannotator@plannotator"
}

test_deps_skipped_in_dry_run() {
  empty_settings
  make_stub curl
  stub_claude '[]' '[]'
  run_install --dry-run >/dev/null
  assert_eq "$(calls)" "" "appels externes"
}

test_deps_skipped_with_no_deps() {
  empty_settings
  make_stub curl
  stub_claude '[]' '[]'
  run_install --no-deps >/dev/null
  assert_eq "$(calls)" "" "appels externes"
}
```

- [ ] **Step 2: Vérifier qu'ils échouent**

Run : `tests/run.sh deps`
Expected : FAIL sur tous les tests sauf `test_deps_skipped_in_dry_run` et `test_deps_skipped_with_no_deps`, qui passent déjà (aucune dépendance n'est encore gérée).

- [ ] **Step 3: Écrire `deps.sh`**

```bash
# shellcheck shell=bash
# Dépendances externes : chaque ensure_* vérifie la présence puis installe si besoin.
# Un échec produit un « warn » et n'interrompt jamais install.
# Sourcé par bin/claude-config, qui définit CLAUDE_HOME et log.
# shellcheck disable=SC2154

RTK_INSTALL_URL="https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh"
PLANNOTATOR_INSTALL_URL="https://plannotator.ai/install.sh"

# Binaire seulement : pas de « rtk init -g », le hook et RTK.md sont gérés par ce repo.
ensure_rtk() {
  if command -v rtk >/dev/null 2>&1; then
    log ok rtk
  elif command -v brew >/dev/null 2>&1; then
    if brew install rtk; then
      log installed "rtk (brew)"
    else
      log warn "échec de brew install rtk"
    fi
  elif curl -fsSL "$RTK_INSTALL_URL" | sh; then
    log installed "rtk (script officiel)"
  else
    log warn "échec de l'installation de rtk"
  fi
}

ensure_plannotator() {
  if command -v plannotator >/dev/null 2>&1; then
    log ok plannotator
  elif curl -fsSL "$PLANNOTATOR_INSTALL_URL" | bash; then
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
  elif npx -y skills add affaan-m/ecc --skill angular-developer -g -a claude-code -y; then
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
  known="$(claude plugin marketplace list --json 2>/dev/null | jq -r '.[].name' || true)"
  while IFS=$'\t' read -r name src; do
    if grep -qxF -- "$name" <<<"$known"; then
      log ok "marketplace $name"
    elif [[ -z "$src" ]]; then
      log warn "marketplace $name : source non gérée"
    elif claude plugin marketplace add "$src"; then
      log installed "marketplace $name"
    else
      log warn "échec de l'ajout de la marketplace $name"
    fi
  done < <(jq -r '.extraKnownMarketplaces // {} | to_entries[]
    | [.key, (.value.source.repo // .value.source.url // .value.source.path // "")] | @tsv' "$settings")

  installed="$(claude plugin list --json 2>/dev/null | jq -r '.[].id' || true)"
  while IFS= read -r id; do
    if grep -qxF -- "$id" <<<"$installed"; then
      log ok "plugin $id"
    elif claude plugin install "$id" --scope user; then
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
```

- [ ] **Step 4: Brancher dans `cmd_install`**

Remplacer `cmd_install` par :
```bash
cmd_install() {
  local with_deps=1
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run) DRY_RUN=1 ;;
      --no-deps) with_deps=0 ;;
      *) die "option inconnue pour install : $1" 2 ;;
    esac
    shift
  done
  require_jq
  merged_settings >/dev/null
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log info "dry-run : aucune modification"
  fi
  install_links
  install_settings
  if [[ "$with_deps" -eq 1 && "$DRY_RUN" -eq 0 ]]; then
    # shellcheck source=deps.sh
    source "$REPO_ROOT/deps.sh"
    ensure_all
  fi
}
```

- [ ] **Step 5: Vérifier que les tests passent**

Run : `tests/run.sh`
Expected : tous PASS, y compris shellcheck.

- [ ] **Step 6: Commit**

```bash
git add bin deps.sh tests
git commit -m "feat: install external deps (rtk, plannotator, angular-developer, plugins)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Bootstrap de projet (`init-project`)

**Files:**
- Create: `lib/project.sh`
- Modify: `bin/claude-config` (source de `lib/project.sh`, `cmd_init_project`, case `init-project`)
- Test: `tests/test_project.sh`

**Interfaces:**
- Consumes : `log`, `die`, `backup_path` (Task 2) ; `templates/default/` (Task 1).
- Produces : `init_project <dir> <template> <force:0|1>`, `copy_template_file <src> <dest> <rel> <nom_projet> <force>`, `ensure_gitignore_entry <fichier_gitignore>`, `cmd_init_project`.

- [ ] **Step 1: Écrire les tests qui échouent**

`tests/test_project.sh` :
```bash
# shellcheck shell=bash
# shellcheck disable=SC2154

new_target() {
  mkdir -p "$SANDBOX/$1"
  printf '%s' "$SANDBOX/$1"
}

test_init_project_copies_template() {
  local t out
  t="$(new_target 'mon projet')"
  git -C "$t" init -q
  out="$("$CLI" init-project "$t")"
  assert_json_eq "$t/.claude/settings.json" '{"permissions":{"deny":["Read(./.env)","Read(./.env.*)","Read(./secrets/**)"]}}'
  assert_eq "$(head -n 1 "$t/CLAUDE.md")" "# mon projet" "titre du CLAUDE.md"
  assert_has_line "$out" written CLAUDE.md
  assert_has_line "$out" written .claude/settings.json
  assert_not_contains "$out" "warn"
}

test_init_project_keeps_existing_files() {
  local t out
  t="$(new_target p)"
  printf 'mien\n' > "$t/CLAUDE.md"
  out="$("$CLI" init-project "$t")"
  assert_has_line "$out" skipped "CLAUDE.md (exists)"
  assert_eq "$(cat "$t/CLAUDE.md")" "mien" "CLAUDE.md conservé"
}

test_init_project_force_backs_up() {
  local t bak
  t="$(new_target p)"
  printf 'mien\n' > "$t/CLAUDE.md"
  "$CLI" init-project "$t" --force >/dev/null
  assert_eq "$(head -n 1 "$t/CLAUDE.md")" "# p" "CLAUDE.md écrasé"
  bak="$(find "$t" -maxdepth 1 -name 'CLAUDE.md.bak-*')"
  [[ -n "$bak" ]] || fail "sauvegarde absente"
  assert_eq "$(cat "$bak")" "mien" "contenu sauvegardé"
}

test_init_project_updates_gitignore() {
  local t
  t="$(new_target p)"
  printf 'node_modules' > "$t/.gitignore"
  "$CLI" init-project "$t" >/dev/null
  assert_eq "$(cat "$t/.gitignore")" $'node_modules\n.claude/settings.local.json' ".gitignore"
  "$CLI" init-project "$t" >/dev/null
  assert_eq "$(grep -c 'settings.local.json' "$t/.gitignore")" 1 "nombre d'entrées"
}

test_init_project_without_gitignore() {
  local t
  t="$(new_target p)"
  "$CLI" init-project "$t" >/dev/null
  [[ ! -e "$t/.gitignore" ]] || fail ".gitignore ne doit pas être créé"
}

test_init_project_warns_outside_git() {
  local t out
  t="$(new_target p)"
  out="$("$CLI" init-project "$t")"
  assert_contains "$out" "pas un repo git"
}

test_init_project_name_with_special_chars() {
  local t
  t="$(new_target 'a&b')"
  "$CLI" init-project "$t" >/dev/null
  assert_eq "$(head -n 1 "$t/CLAUDE.md")" "# a&b" "titre du CLAUDE.md"
}

test_init_project_missing_dir_fails() {
  local rc=0 out
  out="$("$CLI" init-project "$SANDBOX/absent" 2>&1)" || rc=$?
  assert_eq "$rc" 1 "code de sortie"
  assert_contains "$out" "dossier introuvable"
}

test_init_project_unknown_template_fails() {
  local t rc=0 out
  t="$(new_target p)"
  out="$("$CLI" init-project "$t" --template nope 2>&1)" || rc=$?
  assert_eq "$rc" 1 "code de sortie"
  assert_contains "$out" "template inconnu : nope"
}

test_init_project_without_dir_fails() {
  local rc=0
  "$CLI" init-project >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" 2 "code de sortie"
}
```

- [ ] **Step 2: Vérifier qu'ils échouent**

Run : `tests/run.sh init_project`
Expected : FAIL avec `commande inconnue : init-project`.

- [ ] **Step 3: Écrire `lib/project.sh`**

```bash
# shellcheck shell=bash
# init-project : copie un template de config Claude dans un repo.
# Sourcé par bin/claude-config, qui définit REPO_ROOT.
# shellcheck disable=SC2154

init_project() {
  local dir="$1" template="$2" force="$3"
  local tpl="$REPO_ROOT/templates/$template" name rel
  [[ -d "$dir" ]] || die "dossier introuvable : $dir"
  if [[ -z "$template" || "$template" == */* || ! -d "$tpl" ]]; then
    die "template inconnu : $template"
  fi
  dir="$(cd "$dir" && pwd -P)"
  name="$(basename "$dir")"
  if ! git -C "$dir" rev-parse --git-dir >/dev/null 2>&1; then
    log warn "$dir n'est pas un repo git"
  fi
  while IFS= read -r -d '' rel; do
    copy_template_file "$tpl/$rel" "$dir/$rel" "$rel" "$name" "$force"
  done < <(find "$tpl" -type f -printf '%P\0' | sort -z)
  ensure_gitignore_entry "$dir/.gitignore"
}

# Copie un fichier en remplaçant {{PROJECT_NAME}} ; conserve l'existant sauf avec force=1.
copy_template_file() {
  local src="$1" dest="$2" rel="$3" name="$4" force="$5" content
  if [[ -e "$dest" || -L "$dest" ]]; then
    if [[ "$force" -ne 1 ]]; then
      log skipped "$rel (exists)"
      return 0
    fi
    backup_path "$dest"
  fi
  mkdir -p "$(dirname "$dest")"
  # Le « x » final préserve les retours à la ligne de fin, que $(...) supprimerait.
  content="$(cat "$src"; printf x)"
  content="${content%x}"
  printf '%s' "${content//"{{PROJECT_NAME}}"/"$name"}" > "$dest"
  log written "$rel"
}

ensure_gitignore_entry() {
  local file="$1" entry=".claude/settings.local.json"
  if [[ ! -f "$file" ]]; then
    return 0
  fi
  if grep -qxF -- "$entry" "$file"; then
    log ok .gitignore
    return 0
  fi
  if [[ -s "$file" && -n "$(tail -c 1 "$file")" ]]; then
    printf '\n' >> "$file"
  fi
  printf '%s\n' "$entry" >> "$file"
  log written ".gitignore (+ $entry)"
}
```

- [ ] **Step 4: Brancher dans `bin/claude-config`**

Sous `source "$REPO_ROOT/lib/settings.sh"` :
```bash
# shellcheck source=lib/project.sh
source "$REPO_ROOT/lib/project.sh"
```

Au-dessus de `main()` :
```bash
cmd_init_project() {
  local dir="" template="default" force=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --template)
        [[ $# -ge 2 ]] || die "--template attend un nom" 2
        template="$2"
        shift
        ;;
      --force) force=1 ;;
      -*) die "option inconnue pour init-project : $1" 2 ;;
      *)
        [[ -z "$dir" ]] || die "un seul dossier attendu" 2
        dir="$1"
        ;;
    esac
    shift
  done
  [[ -n "$dir" ]] || die "usage : claude-config init-project <dir> [--template <nom>] [--force]" 2
  init_project "$dir" "$template" "$force"
}
```

Dans le `case` de `main`, après `capture)` :
```bash
    init-project) cmd_init_project "$@" ;;
```

- [ ] **Step 5: Vérifier que les tests passent**

Run : `tests/run.sh`
Expected : tous PASS, y compris shellcheck.

- [ ] **Step 6: Commit**

```bash
git add bin lib tests
git commit -m "feat: bootstrap Claude config into a repo from a template

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: README, validation réelle sur ce poste, publication GitHub

**Files:**
- Create: `README.md`

**Interfaces:**
- Consumes : le CLI complet (Tasks 2 à 6).

- [ ] **Step 1: Écrire `README.md`**

````markdown
# claude-config

Ma configuration Claude Code versionnée : installation sur une machine Linux/WSL,
détection des écarts et bootstrap de nouveaux repos.

## Installation sur une nouvelle machine

```bash
git clone git@github.com:Dahiorus/claude-config.git ~/IdeaProjects/claude-config
cd ~/IdeaProjects/claude-config
bin/claude-config install --dry-run   # relire ce qui va changer
bin/claude-config install
ln -s "$PWD/bin/claude-config" ~/.local/bin/claude-config   # facultatif
```

Prérequis : `jq` et `git`. `install` s'occupe de rtk, Plannotator, du skill
`angular-developer` et des plugins listés dans `settings/base.json`.

## Commandes

| Commande | Effet |
|---|---|
| `install [--dry-run] [--no-deps]` | Symlinke `global/*` dans `~/.claude`, génère `settings.json`, installe les dépendances |
| `status` | Liste les écarts entre le repo et `~/.claude` (code 1 en cas d'écart) |
| `capture` | Recopie `~/.claude/settings.json` dans `settings/base.json` (à relire avec `git diff`, puis à commiter) |
| `init-project <dir> [--template <nom>] [--force]` | Copie `templates/<nom>/` (défaut `default`) dans un repo |

Les fichiers existants sont toujours sauvegardés en `<nom>.bak-<date>` avant d'être remplacés.

## Où modifier quoi

- `CLAUDE.md`, `RTK.md`, statusline, skills perso : directement dans `global/` (ils sont symlinkés).
- Settings : via Claude Code (`/config`…), puis `claude-config capture`. On peut aussi éditer
  `settings/base.json` à la main, puis lancer `claude-config install`.
- Surcharges propres à une machine : `settings/local.json` (non versionné), fusionné par-dessus la base.
- Nouveau template : créer `templates/<nom>/`. `{{PROJECT_NAME}}` y est remplacé par le nom du dossier cible.

## Jamais versionné

Credentials, historique, sessions, caches, `skills/synced/` : voir `.gitignore`.

## Tests

```bash
tests/run.sh           # tous les tests + shellcheck
tests/run.sh capture   # seulement les tests dont le nom contient « capture »
```
````

- [ ] **Step 2: Lancer toute la suite**

Run : `tests/run.sh`
Expected : `0 échec(s)`.

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: add README

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 4: Dry-run sur le vrai `~/.claude`**

Run : `bin/claude-config status; bin/claude-config install --dry-run`
Expected :
- `status` : `drift` sur `CLAUDE.md`, `RTK.md` et `statusline-command.sh` (fichiers réels), puis `drift settings.json` avec un diff limité à l'ajout de Plannotator (`extraKnownMarketplaces.plannotator`, `enabledPlugins["plannotator@plannotator"]`).
- `install --dry-run` : `backup` + `linked` pour ces trois fichiers, `backup` + `written settings.json`, et rien d'autre.

Montrer la sortie à l'utilisateur et **attendre son accord** avant l'étape suivante. Elle modifie son vrai `~/.claude`.

- [ ] **Step 5: Installation réelle**

Run : `bin/claude-config install`
Expected : la même chose que le dry-run, puis `ok rtk`, `ok plannotator`, `ok skill angular-developer`, `installed marketplace plannotator`, `ok plugin …` pour les plugins officiels et `installed plugin plannotator@plannotator`.

- [ ] **Step 6: Vérifier l'état**

Run : `bin/claude-config status; echo "code=$?"`
Expected : uniquement des lignes `ok`, puis `code=0`.
Si `claude plugin install` a réécrit `settings.json` et que `status` signale un `drift settings.json`, lancer `bin/claude-config capture`, montrer `git diff settings/base.json` à l'utilisateur, puis commiter si ça lui convient :
```bash
git add settings/base.json
git commit -m "chore: capture settings after plugin install

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 7: Vérification fonctionnelle dans Claude Code**

Demander à l'utilisateur d'ouvrir une nouvelle session Claude Code et de vérifier :
- la statusline s'affiche comme avant ;
- `rtk gain` montre que le hook réécrit toujours les commandes (une commande `git status` lancée dans la session apparaît dans `rtk gain --history`) ;
- les skills `plannotator*` et `angular-developer` apparaissent. Signaler un éventuel doublon entre les skills installés par la CLI Plannotator et ceux du plugin.

- [ ] **Step 8: Publication sur GitHub (avec confirmation)**

Vérifier qu'aucun secret n'est versionné :
```bash
git grep -nIiE '(api[_-]?key|token|secret|password|bearer)' || echo "aucun secret détecté"
gh auth status
```
Montrer le résultat à l'utilisateur. **Demander confirmation** avant de créer le repo, car l'action est publique côté GitHub même si le repo est privé. Après accord :
```bash
gh repo create Dahiorus/claude-config --private --source . --remote origin --push
gh repo view Dahiorus/claude-config --json visibility -q .visibility
```
Expected : `PRIVATE`.
