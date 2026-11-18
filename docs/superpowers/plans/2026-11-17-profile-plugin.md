# Plugin `profile` : plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal :** `profile.sh` et le skill `/profile` deviennent le plugin `mods/profile/` du marketplace claude-config,
qui exporte en plus le jeton de session (`GH_TOKEN`) du compte du profil et le suit après un `cd`.

**Architecture :** le script bash existant est déplacé dans `mods/profile/scripts/profile.sh` ; `global/profile.sh`
devient un lien vers lui (chemin stable `~/.claude/profile.sh`). Il gagne la validation de `profiles.json`, la
remontée des erreurs git, l'écriture du jeton dans `CLAUDE_ENV_FILE` (`session-start`) et la sous-commande
`cwd-changed`. Le plugin porte le hook `SessionStart` ; `settings/base.json` porte `CwdChanged`.

**Tech Stack :** bash, jq, gh ; tests `bash tests/run.sh` (runner maison, shellcheck).

**Spec :** `docs/superpowers/specs/2026-11-17-profile-plugin-design.md`

## Découpage en PR

Une seule PR : les tâches dépendent toutes du script déplacé, et le plugin n'a de sens qu'avec le jeton.

## Global Constraints

- `bash tests/run.sh` avec `timeout: 580000` ; `shellcheck` sur chaque `.sh` modifié avant de commiter.
- Commit fichier par fichier (`git add <fichier>`), jamais `git add -A` ; message en anglais, préfixe gitmoji
  (`✨ profile: …`), dernière ligne `Co-Authored-By: <modèle de l'implémenteur>`.
- Texte français (skill, doc, spec) édité avec Edit/Write, jamais `sed -i` ; lignes Markdown de 120 colonnes au plus.
- Aucun jeton réel dans un test, un commit, une sortie : faux `gh` uniquement (`tok-<compte>`).
- Les tests ne lisent ni n'écrivent `~/.claude` : `HOME` du bac à sable, `CLAUDE_CONFIG_DIR` et `CLAUDE_ENV_FILE`
  retirés par `setup_sandbox`.
- Marqueur exact : `# claude-config-profile`, sur sa propre ligne. Lignes exactes : `export GH_TOKEN='<jeton>'` et
  `export GH_TOKEN=`. Jamais `unset`. Fichier d'env en 600.
- Compte : `^[A-Za-z0-9-]+$` ; jeton : `^[A-Za-z0-9_-]+$`.
- `profiles.json` par défaut : `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/profiles.json` ; `PROFILES_FILE` le remplace.

## Review Focus

1. `CLAUDE_ENV_FILE` absent (hook lancé hors Claude Code, ancienne version) : aucun fichier écrit, pas d'erreur.
2. `new_cwd` absent ou dossier supprimé dans l'entrée de `CwdChanged` : rien écrit, code 0.
3. Jeton contenant `'` ou un saut de ligne (gh corrompu) : refusé par le format, jamais écrit.
4. `profiles.json` qui n'est pas un objet JSON (tableau, texte) : message, pas de plantage jq brut.
5. Deux sessions en parallèle : chaque hook n'écrit que son propre `CLAUDE_ENV_FILE`.

Chaque ligne a son test dans la tâche qui porte le code (Task 3 pour 4, Task 4 pour 1 et 3, Task 5 pour 2) ; la 5
découle de l'écriture dans le seul `$CLAUDE_ENV_FILE`, vérifiée en review.

## Table de traçabilité

| Exigence (spec) | Tâche | Test qui la prouve |
|---|---|---|
| Constat 7 (`systemMessage` de `CwdChanged`) | 1 | Constat noté dans la spec |
| Conception 2 : `profiles.json` du dossier de config | 2 | `test_profile_reads_config_dir_profiles` |
| Conception 2 : fichier absent → rien, `apply` échoue | 2 | `test_profile_without_profiles_file_is_silent`, `test_profile_apply_without_profiles_file_fails` |
| Conception 3 : chemin stable `global/profile.sh` | 2 | `test_profile_global_path_is_link` ; suite existante verte |
| § 3 : `profiles.json` actuel valide | 3 | suite existante verte (`detect` valide avant de lire `origin`) |
| Conception 2 : validation des profils | 3 | `test_profile_rejects_malformed_profiles`, `test_profile_rejects_shared_owner` |
| Conception 4 : échec de git dit | 3 | `test_profile_git_failure_is_reported`, `test_profile_detect_unknown_owner_or_host` (pas de git → vide) |
| Conception 4 : `SessionStart` exporte le jeton, 600 | 4 | `test_profile_session_start_exports_token`, `test_profile_env_file_mode_600` |
| Conception 4 : compte non connecté, jeton hors format | 4 | `test_profile_session_start_account_without_token`, `test_profile_session_start_rejects_bad_token` |
| Conception 4 : 600 avant d'écrire, gh absent, vidage impossible (review) | — | `test_profile_session_start_chmod_failure_writes_no_token`, `test_profile_session_start_without_gh`, `test_profile_cwd_changed_reports_unwritable_env_file` |
| Conception 4 : compte suit le détecté | 4 | `test_profile_session_start_token_follows_detected` |
| Conception 4 : `CwdChanged` bascule, vide, respecte le dev | 5 | `test_profile_cwd_changed_*` (5 tests) |
| Conception 4 : contrat de marqueur entre copies | 5 | `test_profile_cwd_changed_reads_session_start_file` |
| Conception 1 : plugin, marketplace, activation | 6 | `test_profile_plugin_layout`, `claude plugin validate mods/profile` |
| Conception 4 : `SessionStart` retiré de `base.json`, `CwdChanged` ajouté | 6 | `test_base_settings_profile_hook` (réécrit) |
| Conception 5 : skill déplacé et complété | 6 | `test_profile_plugin_layout` ; recette (Task 8) |
| Portée : README, `docs/domaine.md` | 7 | `git grep` des termes retirés |
| P1, P2 de bout en bout | 8 | Recette dans une vraie session |

Usages vérifiés à l'étape 1b : skills `pr`, `notify`, `release`, `todo`, `pr-risk`, `CLAUDE.md` et
`statusline-gh.sh` appellent `~/.claude/profile.sh` : inchangés, le lien suit (`test_statusline.sh` les fige) ;
`deps.sh` lit `global/profiles.json` du dépôt : inchangé (`test_deps.sh`).

---

### Task 1 : Constat 7, message d'un hook `CwdChanged`

**Files :** Modify : `docs/superpowers/specs/2026-11-17-profile-plugin-design.md` (constat 7)

- [ ] **Step 1 :** Dans un dossier jetable, `CLAUDE_CONFIG_DIR=$(mktemp -d)` avec un `settings.json` qui déclare un
  hook `CwdChanged` `echo '{"systemMessage":"cwd-test"}'`, lancer
  `claude -p --debug "cd /tmp puis pwd"` (connexion copiée si besoin : ne jamais toucher `~/.claude`).
  Expected : la sortie de debug montre ou non le `systemMessage` du hook.
- [ ] **Step 2 :** Écrire le résultat au constat 7 de la spec (« affiché » ou « non affiché : le message
  `CwdChanged` part dans `stderr` du hook seulement »). Non observable en `-p` → le noter, la recette (Task 8) le
  tranche dans une session interactive.
- [ ] **Step 3 :** `git add <spec> && git commit -m "📝 profile: Record whether CwdChanged messages show"`

### Task 2 : Script déplacé, `profiles.json` du dossier de config

**Files :**
- Move : `global/profile.sh` → `mods/profile/scripts/profile.sh` (`git mv`) ; Create : lien `global/profile.sh` →
  `../mods/profile/scripts/profile.sh`
- Modify : `mods/profile/scripts/profile.sh` (défaut de `PROFILES_FILE`, garde « fichier absent »)
- Modify : `tests/helpers.sh` (`setup_sandbox` : `unset CLAUDE_CONFIG_DIR CLAUDE_ENV_FILE` ; `make_gh_stub` déplacé
  ici depuis `tests/test_statusline.sh`, inchangé)
- Modify : `tests/test_statusline.sh` (`make_gh_stub` retiré ; `run_statusline` passe
  `PROFILES_FILE="${PROFILES_FILE:-$REPO/global/profiles.json}"`)
- Test : `tests/test_profile.sh` (`profile()` passe `PROFILES_FILE="${PROFILES_FILE:-$REPO/global/profiles.json}"`)

**Interfaces :** Produces : `PROFILES_FILE` par défaut `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/profiles.json` ;
`require_profiles()` → 0 si le fichier existe, sinon 1 sans rien écrire.

- [ ] **Step 1 : tests rouges**

```bash
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
```

- [ ] **Step 2 :** `bash tests/run.sh test_profile_` → Expected : les 4 nouveaux tests en FAIL (lien absent, défaut
  voisin du script).
- [ ] **Step 3 :** `git mv`, lien relatif (`ln -s ../mods/profile/scripts/profile.sh global/profile.sh`), défaut de
  `PROFILES_FILE`, `require_profiles` en tête de `detect`, `session_start` (et `cwd_changed` plus tard) qui rendent 0
  sans sortie ; dans `apply`, message `profiles.json introuvable : <chemin>` et code 1. Helpers et statusline comme
  dans « Files ».
- [ ] **Step 4 :** `bash tests/run.sh` (580 s) → Expected : tout vert, `test_statusline` et `test_deps` compris.
- [ ] **Step 5 :** commits : le `git mv` + lien d'abord (`🚚 profile: Move profile.sh into the profile plugin`),
  puis le reste (`✨ profile: Read profiles.json from the config dir`).

### Task 3 : Validation des profils et erreurs de git

**Files :** Modify : `mods/profile/scripts/profile.sh` ; Test : `tests/test_profile.sh`

**Interfaces :** Produces : `validate_profiles()` → 0, ou 1 avec un message sur stderr qui nomme le profil fautif ;
`origin_owner <dossier>` → propriétaire, vide (pas de dépôt, pas de `origin`, hors github.com) ou code 1 avec
`git : <première ligne de stderr>` (autre échec : dépôt à propriété douteuse, git absent → `git introuvable`).
`detect` valide `profiles.json` **avant** de chercher le propriétaire, puis appelle `origin_owner` ;
`session_start` transforme toute erreur en `systemMessage`.

- [ ] **Step 1 : tests rouges**

```bash
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
  done
  bad_profiles '.perso.env = "x"'
  local out; out=$(jq -nc --arg d "$SANDBOX/p" '{cwd:$d}' | PROFILES_FILE="$SANDBOX/bad.json" profile session-start)
  assert_contains "$(jq -r .systemMessage <<<"$out")" "perso"
  [[ ! -e "$SANDBOX/p/.claude" ]] || fail "profil appliqué malgré l'erreur"
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
  err=$(PATH="$SANDBOX/empty" "$BASH" "$p" detect "$SANDBOX/p" 2>&1) || rc=$?
  assert_eq "$rc" "1" "code" ; assert_contains "$err" "git"
  local out; out=$(jq -nc --arg d "$SANDBOX/p" '{cwd:$d}' | PATH="$SANDBOX/empty" "$BASH" "$p" session-start)
  assert_contains "$(jq -r .systemMessage <<<"$out")" "git"
}
```

  `PATH` sans git : `jq` seul ; `"$BASH"` évite de chercher `bash` dans ce `PATH`.
  Le cas « dubious ownership » ne se reproduit
  pas sans changer de propriétaire : couvert par la branche générique (stderr non reconnu → code 1), testée en
  plus avec `GIT_DIR` pointé vers un fichier illisible si possible, sinon noté en review.
- [ ] **Step 2 :** `bash tests/run.sh test_profile_` → Expected : FAIL des 3 nouveaux ; les anciens verts.
- [ ] **Step 3 :** `validate_profiles` en un seul `jq -e` (objet racine ; chaque profil objet ; `owners` tableau de
  chaînes ; `enabledPlugins`, `skillOverrides`, `env`, `secretEnv` objets s'ils sont présents ; `account` au motif ;
  propriétaires en minuscules uniques, message `propriétaire <x> dans les profils <a> et <b>`).
  `origin_owner` : `LC_ALL=C git -C … remote get-url origin`, code 2 ou stderr `not a git repository` / `cannot
  change to` → vide ; `command -v git` faux → `git introuvable` ; autre → `git : <ligne>`, code 1.
  `test_profile_account_rejects_unsafe_name` reste vert (le compte est refusé plus tôt : adapter son message attendu
  s'il le cite, le nommer dans le commit).
- [ ] **Step 4 :** `bash tests/run.sh test_profile_` puis la suite complète → Expected : vert.
- [ ] **Step 5 :** `🐛 profile: Validate profiles.json and report git failures`

### Task 4 : Jeton de session au démarrage

**Files :** Modify : `mods/profile/scripts/profile.sh` ; Test : `tests/test_profile.sh`

**Interfaces :** Produces : `MARKER='# claude-config-profile'` ; `write_token <dossier> <fichier>` → écrit dans
`<fichier>` (600) le marqueur et `export GH_TOKEN='<jeton>'` du compte de `account <dossier>`, ou rien si pas de
compte ; rend sur stdout un message d'erreur éventuel (compte non connecté, jeton refusé), code 0. Le marqueur
n'est écrit qu'avec une ligne `export` : compte non connecté ou jeton refusé → fichier laissé vide. `session_start`
applique le profil comme avant, extrait en `apply_detected` (dette §7), qui seul garde le test `current` ; puis
`write_token "$dir" "$CLAUDE_ENV_FILE"` s'exécute **que le profil soit déjà appliqué ou non**, si la variable est
posée ; les messages sont réunis en un seul `systemMessage`.

- [ ] **Step 1 : tests rouges** (faux `gh` de `tests/helpers.sh`, `PATH="$STUBS:$PATH"`)

```bash
ss_file() { echo "$SANDBOX/session-env/sessionstart-hook-0.sh"; }  # fichiers à chemin fixe :
cd_file() { echo "$SANDBOX/session-env/cwdchanged-hook-0.sh"; }       # lisibles hors des $(…)
start_with_env() {  # <dossier> : session-start avec un fichier d'env jetable, sortie = systemMessage
  [[ -x "$STUBS/gh" ]] || make_gh_stub   # garde un faux gh modifié par le test
  mkdir -p "$SANDBOX/session-env"
  jq -nc --arg d "$1" '{cwd:$d}' | PATH="$STUBS:$PATH" CLAUDE_ENV_FILE="$(ss_file)" profile session-start
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
  [[ ! -s "$(ss_file)" ]] || fail "marqueur ou export écrit sans jeton"
}
test_profile_session_start_rejects_bad_token() {   # Review Focus 3
  repo_with_origin "$SANDBOX/v" https://github.com/softwarevidal/y.git
  make_gh_stub; sed -i 's/echo "tok-$4"/echo "x'"'"'y"/' "$STUBS/gh"
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
  jq -nc --arg d "$SANDBOX/v" '{cwd:$d}' | PATH="$STUBS:$PATH" profile session-start >/dev/null || fail "code"
}
test_profile_session_start_no_profile_writes_nothing() {
  repo_with_origin "$SANDBOX/o" https://github.com/someone/x.git
  start_with_env "$SANDBOX/o" >/dev/null
  [[ ! -s "$(ss_file)" ]] || fail "fichier écrit hors profil"
}
```

  `test_profile_session_start_applies_once` (2e démarrage : sortie vide) reste vrai sans `CLAUDE_ENV_FILE`.
- [ ] **Step 2 :** `bash tests/run.sh test_profile_session_start` → Expected : FAIL des nouveaux.
- [ ] **Step 3 :** `write_token` : `gh auth token -u <compte> 2>/dev/null` ; vide → message `compte gh <compte> non
  connecté : gh auth login -h github.com, puis relance la session` ; hors motif → `jeton gh de <compte> refusé
  (format inattendu)` ; sinon `umask 077`, écriture, puis `chmod 600` (fichier préexistant). Le jeton ne passe
  jamais en argument d'une commande autre que `printf` (builtin).
- [ ] **Step 4 :** `bash tests/run.sh` (580 s) → Expected : vert.
- [ ] **Step 5 :** `✨ profile: Export the profile account's GH_TOKEN at session start`

### Task 5 : `cwd-changed`

**Files :** Modify : `mods/profile/scripts/profile.sh` (sous-commande et usage) ; Test : `tests/test_profile.sh`

**Interfaces :** Consumes : `write_token`, `MARKER`. Produces : `profile.sh cwd-changed` lit `{new_cwd}` sur stdin ;
sans `CLAUDE_ENV_FILE`, sans `new_cwd` ou dossier absent → rien, code 0. Dossier à profil et jeton → `write_token`.
Sinon (sans profil, ou compte non connecté) → `export GH_TOKEN=` précédé du marqueur, **seulement si** un fichier
`sessionstart-hook-*.sh` du dossier de `CLAUDE_ENV_FILE` contient la ligne exacte du marqueur ; message éventuel en
`systemMessage`.

- [ ] **Step 1 : tests rouges**

```bash
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
  make_gh_stub; mkdir -p "$SANDBOX/session-env"
  echo '{}' | CLAUDE_ENV_FILE="$SANDBOX/session-env/cwdchanged-hook-0.sh" profile cwd-changed || fail "sans new_cwd"
  jq -nc '{new_cwd:"/nulle/part"}' | CLAUDE_ENV_FILE="$SANDBOX/session-env/cwdchanged-hook-0.sh" \
    profile cwd-changed || fail "dossier absent"
  [[ ! -s "$SANDBOX/session-env/cwdchanged-hook-0.sh" ]] || fail "écrit"
}
test_profile_cwd_changed_without_profiles_file() {   # spec : sans profiles.json, les hooks ne font rien
  repo_with_origin "$SANDBOX/v" https://github.com/softwarevidal/y.git
  mkdir -p "$SANDBOX/session-env"; : > "$(cd_file)"
  jq -nc --arg d "$SANDBOX/v" '{new_cwd:$d}' | CLAUDE_ENV_FILE="$(cd_file)" bash "$REPO/global/profile.sh" \
    cwd-changed || fail "code"
  [[ ! -s "$(cd_file)" ]] || fail "écrit"
}
```

`profiles.json` mal formé ou git en échec après un `cd` (décision de l'utilisateur) : traité comme un compte non
connecté, `export GH_TOKEN=` si le marqueur est présent, plus un `systemMessage` qui rapporte l'erreur.

```bash
test_profile_cwd_changed_reports_error() {
  repo_with_origin "$SANDBOX/v" https://github.com/softwarevidal/y.git
  repo_with_origin "$SANDBOX/p" https://github.com/Dahiorus/x.git
  start_with_env "$SANDBOX/v" >/dev/null
  bad_profiles '.perso.env = "x"'
  local out; out=$(PROFILES_FILE="$SANDBOX/bad.json" cwd_to "$SANDBOX/p")
  assert_contains "$(jq -r .systemMessage <<<"$out")" "perso"
  assert_eq "$(cat "$(cd_file)")" $'# claude-config-profile\nexport GH_TOKEN=' "vidé"
}
```

- [ ] **Step 2 :** `bash tests/run.sh test_profile_cwd` → Expected : FAIL (`usage`, code 2).
- [ ] **Step 3 :** `cwd_changed` comme dans « Interfaces » ; usage mis à jour avec `cwd-changed`.
- [ ] **Step 4 :** `bash tests/run.sh` (580 s) → Expected : vert.
- [ ] **Step 5 :** `✨ profile: Follow the gh account on cd with a CwdChanged hook`

### Task 6 : Plugin, skill et réglages

**Files :**
- Create : `mods/profile/.claude-plugin/plugin.json`
  (`name` `profile`, `version` `0.1.0`, `description` « Profil de projet et compte gh selon le propriétaire du
  dépôt »)
- Create : `mods/profile/hooks/hooks.json` : `SessionStart` **sans matcher** (décision de l'utilisateur : le jeton
  est réécrit à chaque `SessionStart`, `/clear` compris ; l'application du profil reste unique grâce au test
  `current`), commande `bash "${CLAUDE_PLUGIN_ROOT}/scripts/profile.sh" session-start`. Test : dans
  `test_profile_plugin_layout`, `assert_eq "$(jq -r '.hooks.SessionStart[0].matcher // ""' "$m/hooks/hooks.json")" ""
  "matcher"`. La recette (Task 8) vérifie le jeton après `/clear`.
- Create : `mods/profile/profiles.example.json` (forme de `global/profiles.json` : profils `vidal` et `perso`, comptes
  `mon-compte-vidal` / `mon-compte-perso`, sans `secretEnv`, `CLAUDE_CODE_ENABLE_TELEMETRY: "0"` dans perso)
- Move : `global/skills/profile/SKILL.md` → `mods/profile/skills/profile/SKILL.md` (`git mv`, puis édition)
- Modify : `.claude-plugin/marketplace.json` (entrée `profile`, source `./mods/profile`)
- Modify : `settings/base.json` : retirer le hook `bash ~/.claude/profile.sh session-start` (garder
  `dirty-skills-hook.sh` dans son bloc) ; ajouter `hooks.CwdChanged` → `bash ~/.claude/profile.sh cwd-changed` ;
  `enabledPlugins["profile@claude-config"] = true`
- Test : `tests/test_settings.sh` (`test_base_settings_profile_hook` réécrit), `tests/test_profile.sh`

- [ ] **Step 1 : tests rouges**

```bash
# tests/test_settings.sh, dans test_base_settings_profile_hook, à la place de la 1re assertion :
assert_not_contains "$(jq -r '.hooks.SessionStart[].hooks[].command' "$b")" "profile.sh"
assert_eq "$(jq -r '.hooks.CwdChanged[].hooks[].command' "$b")" "bash ~/.claude/profile.sh cwd-changed" "cwd"
assert_eq "$(jq -r '.enabledPlugins["profile@claude-config"]' "$b")" "true" "plugin"

# tests/test_profile.sh
test_profile_plugin_layout() {
  local m="$REPO/mods/profile"
  assert_eq "$(jq -r '.plugins[] | select(.name=="profile") | .source' "$REPO/.claude-plugin/marketplace.json")" \
    "./mods/profile" "marketplace"
  assert_contains "$(jq -r '.hooks.SessionStart[].hooks[].command' "$m/hooks/hooks.json")" \
    '${CLAUDE_PLUGIN_ROOT}/scripts/profile.sh" session-start'
  [[ -f "$m/skills/profile/SKILL.md" && ! -e "$REPO/global/skills/profile" ]] || fail "skill"
  PROFILES_FILE="$m/profiles.example.json" bash "$m/scripts/profile.sh" detect "$SANDBOX" || fail "exemple invalide"
}
```

- [ ] **Step 2 :** `bash tests/run.sh test_base_settings_profile_hook` et `test_profile_plugin_layout` → FAIL.
- [ ] **Step 3 :** fichiers ci-dessus. Skill (spec Conception 5) : commandes via
  `bash "${CLAUDE_PLUGIN_ROOT}/scripts/profile.sh" <sous-commande>` ; vérifier d'abord que `profiles.json` existe ;
  code non nul → rapporter et s'arrêter (« detected dubious ownership » → `git config --global --add
  safe.directory <dossier>`) ; phrase « Rien ne l'ajoute tout seul… » remplacée par celle de la spec ; cas
  `GH_TOKEN` absent (`[ -n "$GH_TOKEN" ]`, jamais affiché) ; section « Sans `profiles.json` » reprise du skill
  harnais (exemple du plugin, `gh auth status`, `owners`) ; colonne Télémétrie et « Jeton Exploradora » gardées ;
  « éditer `global/profiles.json` » devient « éditer `profiles.json` du dossier de config (dans claude-config :
  `global/profiles.json`) ».
- [ ] **Step 4 :** `bash tests/run.sh` (580 s) et `claude plugin validate mods/profile` → Expected : vert, `✔`.
- [ ] **Step 5 :** un commit par fichier ou groupe cohérent : plugin (`✨ profile: Package profile as a plugin`),
  skill (`🚚 profile: Move the /profile skill into the plugin`), réglages
  (`🔧 settings: Run the profile hooks from the plugin and on cd`).

### Task 7 : Documentation

**Files :** Modify : `README.md` (l. 34-35), `docs/domaine.md` (« Dans le code » de Profils : `mods/profile/`,
`global/profiles.json`, skill `/profile` du plugin ; invariant de Réglages amendé comme la spec),
`docs/reste-a-faire.md`
(ajout : retirer le préfixe `GH_TOKEN=$(gh auth token -u …)` des skills une fois le hook éprouvé, origine : spec
2026-11-17-profile-plugin) ; glossaire Profils : « Compte non connecté » = compte du profil dont `gh auth token -u`
ne rend pas de jeton · à ne pas dire : compte sans jeton

- [ ] **Step 1 :** éditer avec Edit.
- [ ] **Step 2 :** `git grep -n -e 'global/skills/profile' -e 'global/profile\.sh' -- . ':!docs/superpowers'` →
  Expected : seulement `tests/test_profile.sh` (chemin `$REPO/global/profile.sh` gardé exprès) ;
  `git grep -n 'global/skills/profile' --
  <spec> <plan>` relu.
- [ ] **Step 3 :** `📝 profile: Document the profile plugin`

### Task 8 : Recette

**Files :** `recette.md` du dossier de suivi (non commité)

- [ ] **Step 1 :** agent neuf, `CLAUDE_CONFIG_DIR` jetable avec `profiles.json` copié et un `settings.json` qui
  déclare le `CwdChanged` de `base.json` ; `claude --plugin-dir mods/profile` dans un clone d'un dépôt
  `softwarevidal` puis `Dahiorus` : `/profile`, `[ -n "$GH_TOKEN" ]`, `gh api user --jq .login` (compte attendu),
  `cd` vers l'autre dépôt puis `/tmp`, `/clear` puis `[ -n "$GH_TOKEN" ]` dans un dépôt à profil, constat 7.
- [ ] **Step 2 :** résultats (tableau scénario | ✅/❌) dans `recette.md` ; écart → correctif avec test, puis relance.
