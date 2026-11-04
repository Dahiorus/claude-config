# Profils par projet — plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** chaque projet prend tout seul le profil (plugins, compte gh) qui correspond au propriétaire de son dépôt GitHub.

**Architecture:** un script `global/profile.sh` porte toute la logique (détection, application, compte) et lit
`global/profiles.json`. Trois points d'appel : un hook `SessionStart`, le hook Bash existant (préfixe `GH_TOKEN`) et
le skill `/profile`. `deps.sh` installe aussi les plugins que seuls les profils activent.

> **Révisé après recette (2026-11-04) :** le préfixe `GH_TOKEN` du hook Bash (tâches 0, 3 et la tâche du worktree) a
> été retiré, avec ses tests : le mode auto refuse les commandes qu'un hook modifie. Les skills passent le jeton
> eux-mêmes. Voir la spec, §2 « Compte gh ».

**Tech Stack:** bash, jq, git ; tests maison `tests/run.sh` + shellcheck.

**Spec:** `docs/superpowers/specs/2026-11-04-profils-projet-design.md`

## Découpage en PR

Une seule story (P1). Fichiers touchés hors tests, spec et plan : 13 (`profiles.json`, `profile.sh`,
`bash-rewrite-hook.sh`, `base.json`, `deps.sh`, `run.sh`, `README.md`, skills `profile`, `pr`, `feature`, `release`,
`todo`, `notify`) → **une seule PR**.

## Global Constraints

- Profils : `vidal` (`owners: ["softwarevidal"]`, compte `brondon-ung`), `perso` (`owners: ["Dahiorus", "tuonick"]`,
  compte `Dahiorus`), contenus exactement comme au §2 de la spec.
- Propriétaire inconnu ou pas d'`origin` GitHub → aucun effet, sortie identique à aujourd'hui.
- `settings.local.json` existant : fusion clé par clé, jamais écrasé ; JSON invalide → rien écrit, erreur.
- Le compte gh suit le propriétaire du dépôt (`origin`), pas le profil écrit dans le projet.
- Jamais de `gh auth switch`.
- `settings/base.json` : `github@claude-plugins-official` → `false`, `jdtls-lsp@claude-plugins-official` → `true`.

## Review Focus

1. `origin` en SSH (`git@github.com:Dahiorus/x.git`) ou en `ssh://` → même profil qu'en HTTPS (test Tâche 1).
2. `origin` sur un autre hôte que github.com (`gitlab.com/Dahiorus/x`) → aucun profil (test Tâche 1).
3. Commande où `gh` n'est qu'un morceau de mot (`echo ghost`, `light`) → pas de préfixe (test Tâche 3).
4. Projet local sans git → `/profile perso` écrit dans le dossier courant, sans toucher `.git/info/exclude` (test Tâche 2).
5. `settings.local.json` déjà exclu par le `.gitignore` du projet → pas de ligne ajoutée à `exclude` (test Tâche 2).

## Traçabilité

| Exigence (spec) | Tâche | Test |
|---|---|---|
| §5 filet sur le hook Bash | 0 | `test_hook_gh_without_profile_unchanged` |
| §2 profils, détection par `origin` ; §4 cas 5 | 1 | `test_profile_detect_*` |
| §2 `account` ; §4 cas 9, 10 | 1 | `test_profile_account_*` |
| §2 « Ce qu'écrit `apply` » ; §3 ; §4 cas 6, 7, 8 | 2 | `test_profile_apply_*` |
| §2 hook `SessionStart` ; §3 profil déjà appliqué ; §4 cas 1, 2, 5, 9 | 2 | `test_profile_session_start_*` |
| §2 `base.json` (github, jdtls, entrée SessionStart) | 2 | `test_base_settings_profile_hook` |
| §2 hook Bash ; §4 cas 3, 11 | 3 | `test_hook_gh_*` |
| §2 `deps.sh` ; §4 cas 8bis | 4 | `test_deps_installs_profile_plugins` |
| §2 skill `/profile` ; §4 cas 4, 6 | 5 | relecture (skill en prose), cas 4 et 6 via `apply` (Tâche 2) |
| §2 consignes de compte des skills `pr`, `feature`, `release`, `todo`, `notify` ; README | 5 | `grep` de contrôle (Tâche 5, étape 3) |

Usages vérifiés à l'étape 1b : `bash-rewrite-hook.sh` n'est appelé que par `settings/base.json` (PreToolUse) et
`tests/test_hook.sh` ; `ensure_plugins` seulement par `ensure_all` (`deps.sh`) ; consignes de compte aux lignes listées
au §2 de la spec (pr l.16-17 et 143-144, feature l.28 et 46, release l.37-40, todo l.37-39, notify l.28-29) ;
`statusline-command.sh` garde sa propre détection (inchangé).

---

### Task 0: Filet sur le hook Bash

**Files:**
- Test: `tests/test_hook.sh`

- [ ] **Step 1: Écrire le test de caractérisation**

```bash
# Hors projet à profil : gh pr list n'est pas réécrit, git reçoit seulement rtk.
test_hook_gh_without_profile_unchanged() {
  stub_rewriters
  mkdir -p "$SANDBOX/local" && git -C "$SANDBOX/local" init -q
  assert_eq "$(hook_command_in "$SANDBOX/local" 'gh pr list')" "" "gh"
  assert_eq "$(hook_command_in "$SANDBOX/local" 'git status')" "rtk git status" "git"
}
```

- [ ] **Step 2: Lancer, vert sur l'état actuel**

Run: `bash tests/run.sh test_hook_gh_without_profile_unchanged` — Expected: `PASS`.

- [ ] **Step 3: Commit** — `✅ tests: Pin the Bash hook output outside profiles`

### Task 1: Profils et détection

**Files:**
- Create: `global/profiles.json` (contenu exact du §2 de la spec)
- Create: `global/profile.sh`
- Modify: `tests/run.sh:47` (ajouter `global/profile.sh` à la liste shellcheck)
- Test: `tests/test_profile.sh` (nouveau)

**Interfaces:**
- Produces :
  - `bash global/profile.sh detect [dir]` → nom du profil sur stdout, rien si aucun ; code 0.
  - `bash global/profile.sh account [dir]` → compte gh du profil détecté, rien si aucun ; code 0.
  - Fichier des profils : `$PROFILES_FILE`, par défaut `profiles.json` à côté du script réel (`readlink -f "$0"`).
  - Fonction interne `origin_owner <dir>` : propriétaire GitHub de `origin` (HTTPS, `git@github.com:`, `ssh://git@github.com/`), vide sinon.

- [ ] **Step 1: Tests qui échouent**

```bash
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
  git -C "$SANDBOX/p" commit -q --allow-empty -m init
  git -C "$SANDBOX/p" worktree add -q "$SANDBOX/wt" -b w
  mkdir -p "$SANDBOX/wt/sub"
  assert_eq "$(profile account "$SANDBOX/wt/sub")" "Dahiorus" "worktree"
}
```

- [ ] **Step 2: Lancer** — `bash tests/run.sh test_profile_` → FAIL (script absent).

- [ ] **Step 3: Écrire `global/profiles.json` et `global/profile.sh` (`detect`, `account`)**

`set -uo pipefail`, sous-commande en `case`, `jq` pour lire les profils (`to_entries[] | select(.value.owners |
index($o)) | .key`). Commande inconnue → message sur stderr, code 2. Le compte d'un worktree se lit comme ailleurs :
`git -C <dir> remote get-url origin`.

- [ ] **Step 4: Lancer** — `bash tests/run.sh` → tout `PASS`, shellcheck compris.

- [ ] **Step 5: Commit** — `✨ profiles: Detect the project profile from origin`

### Task 2: Application du profil et démarrage de session

**Files:**
- Modify: `global/profile.sh`
- Modify: `settings/base.json` (SessionStart, `github` → false, `jdtls-lsp` → true)
- Test: `tests/test_profile.sh`, `tests/test_settings.sh`

**Interfaces:**
- Consumes : `detect`, `account` (Tâche 1).
- Produces :
  - `bash profile.sh apply <profil> [dir]` → fusionne dans `<racine git ou dir>/.claude/settings.local.json` ; code 0 ; profil inconnu → stderr « profil inconnu : <nom> (connus : perso, vidal) », code 2 ; JSON invalide → stderr, code 1, fichier intact.
  - `bash profile.sh current [dir]` → valeur de `env.CLAUDE_PROFILE` du projet, vide sinon.
  - `bash profile.sh session-start` → lit le JSON du hook sur stdin (`.cwd`) ; écrit `{"systemMessage":"Profil <nom> appliqué à ce projet : relance la session pour l'alléger."}` seulement s'il vient d'appliquer.

- [ ] **Step 1: Tests qui échouent**

```bash
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
```

Dans `tests/test_settings.sh` :

```bash
test_base_settings_profile_hook() {
  local b="$REPO/settings/base.json"
  assert_contains "$(jq -r '.hooks.SessionStart[].hooks[].command' "$b")" "profile.sh session-start"
  assert_eq "$(jq -r '.enabledPlugins["github@claude-plugins-official"]' "$b")" "false" "github"
  assert_eq "$(jq -r '.enabledPlugins["jdtls-lsp@claude-plugins-official"]' "$b")" "true" "jdtls"
}
```

- [ ] **Step 2: Lancer** — `bash tests/run.sh test_profile_ ; bash tests/run.sh test_base_settings` → FAIL.

- [ ] **Step 3: Implémenter `apply`, `current`, `session-start` ; modifier `settings/base.json`**

Fusion : `jq --argjson p "$profil" '.enabledPlugins += $p.enabledPlugins | .skillOverrides += $p.skillOverrides |
.env.CLAUDE_PROFILE = $name'`, écrite dans un fichier temporaire puis `mv`. Exclusion : seulement dans un dépôt git,
si `git check-ignore -q .claude/settings.local.json` échoue. Nouvelle entrée SessionStart :

```json
{
  "matcher": "startup",
  "hooks": [{ "type": "command", "command": "bash ~/.claude/profile.sh session-start" }]
}
```

- [ ] **Step 4: Lancer** — `bash tests/run.sh` → tout `PASS`.

- [ ] **Step 5: Commit** — `✨ profiles: Apply the profile at session start`

### Task 3: Compte gh dans le hook Bash

**Files:**
- Modify: `global/bash-rewrite-hook.sh` (fin du script, sortie)
- Test: `tests/test_hook.sh`

**Interfaces:**
- Consumes : `profile.sh account <cwd>` (Tâche 1), appelé par `"$(dirname "$(readlink -f "$0")")/profile.sh"`.
- Produces : fonction `prefix_gh_token <commande>` ; préfixe exact `export GH_TOKEN="$(gh auth token -u <compte>)"; `.

- [ ] **Step 1: Tests qui échouent**

```bash
perso_repo() { repo_with_origin "$SANDBOX/p" https://github.com/Dahiorus/x.git; }
PREFIX_PERSO='export GH_TOKEN="$(gh auth token -u Dahiorus)"; '

test_hook_gh_prefixed_in_profile_repo() {
  stub_rewriters; perso_repo
  assert_eq "$(hook_command_in "$SANDBOX/p" 'gh pr list')" "${PREFIX_PERSO}gh pr list" "gh"
}

test_hook_git_prefixed_after_rtk_once() {
  stub_rewriters; perso_repo
  assert_eq "$(hook_command_in "$SANDBOX/p" 'git push && gh pr view')" "${PREFIX_PERSO}rtk git push && gh pr view" "git"
}

test_hook_gh_word_part_not_prefixed() {
  stub_rewriters; perso_repo
  assert_eq "$(hook_command_in "$SANDBOX/p" 'echo ghost')" "" "pas de réécriture"
}
```

`repo_with_origin` est défini dans `tests/test_profile.sh` (Tâche 1), chargé par `run.sh` comme les autres fichiers
de test : ne pas le redéfinir ici.

- [ ] **Step 2: Lancer** — `bash tests/run.sh test_hook_` → les trois nouveaux FAIL, les autres PASS.

- [ ] **Step 3: Implémenter**

La commande finale est celle de `rtk_out` s'il existe, sinon `rewritten`. Si elle contient `gh` ou `git` en mot
entier (même motif que la ligne 26) et que `account` renvoie un compte : préfixer, puis émettre la sortie
(`rtk_out` patché par `jq`, ou la sortie build-brief, ou une nouvelle sortie si rien n'avait changé). Sans compte :
sortie strictement identique à aujourd'hui.

- [ ] **Step 4: Lancer** — `bash tests/run.sh` → tout `PASS`, dont `test_hook_gh_without_profile_unchanged`.

- [ ] **Step 5: Commit** — `✨ hooks: Use the profile gh account in Bash commands`

### Task 4: Plugins des profils installés

**Files:**
- Modify: `deps.sh:77-107` (`ensure_plugins`)
- Test: `tests/test_deps.sh`

**Interfaces:**
- Consumes : `global/profiles.json` du dépôt (`$REPO_ROOT/global/profiles.json`).

- [ ] **Step 1: Test qui échoue**

```bash
test_deps_installs_profile_plugins() {
  printf '%s\n' '{"enabledPlugins":{"a@m":true,"s@m":false}}' > "$REPO/settings/base.json"
  printf '%s\n' '{"vidal":{"owners":[],"account":"x","enabledPlugins":{"s@m":true,"a@m":true},"skillOverrides":{}}}' \
    > "$REPO/global/profiles.json"
  make_stub rtk; make_stub plannotator; fake_angular_skill
  stub_claude '[]' '[]'
  run_install >/dev/null
  local c; c="$(calls)"
  assert_contains "$c" "claude plugin install s@m --scope user"
  assert_eq "$(grep -c 'plugin install a@m' <<<"$c")" "1" "a@m une seule fois"
}
```

- [ ] **Step 2: Lancer** — FAIL.

- [ ] **Step 3: Implémenter** — la liste lue par la boucle devient l'union triée et dédoublonnée des clés à `true`
  de `settings.json` et de tous les profils (`sort -u`) ; fichier de profils absent → comportement actuel.

- [ ] **Step 4: Lancer** — `bash tests/run.sh` → tout `PASS`.

- [ ] **Step 5: Commit** — `✨ deps: Install plugins enabled by a profile`

### Task 5: Skill `/profile` et consignes de compte

**Files:**
- Create: `global/skills/profile/SKILL.md`
- Modify: `global/skills/pr/SKILL.md:16-17,143-144`, `global/skills/feature/SKILL.md:28,46`,
  `global/skills/release/SKILL.md:37-40`, `global/skills/todo/SKILL.md:37-39`, `global/skills/notify/SKILL.md:28-29`
- Modify: `README.md` (une ligne)

- [ ] **Step 1: Écrire `global/skills/profile/SKILL.md`**

```markdown
---
name: profile
description: Use when the user invokes /profile, asks which profile, plugins or gh account a project uses, or wants to switch a project to the vidal or perso profile (« passe ce projet en perso », « quel profil ici ? »).
argument-hint: "[vidal|perso]"
---
```

Corps : sans argument, `bash ~/.claude/profile.sh current` et `detect` sur le dossier courant, puis un tableau
*profil appliqué | profil détecté | compte gh (`account`)*. Avec un nom : `bash ~/.claude/profile.sh apply <nom>`,
rapporter l'erreur telle quelle (profil inconnu, JSON invalide), sinon demander de relancer la session. Rappeler que
le compte gh suit le dépôt et que les profils se modifient dans `global/profiles.json` de claude-config.

- [ ] **Step 2: Remplacer les consignes de compte**

Chaque passage listé devient : « le compte gh vient du profil du projet (hook Bash, voir `/profile`) ; jamais `gh auth
switch`. » Retirer les recettes `GH_TOKEN=$(gh auth token -u <compte>)` et `credential.helper`. `release` l.40 :
« Projet sans profil et accès refusé → demander quel compte utiliser. »

- [ ] **Step 3: Contrôle**

Run: `grep -rn "gh auth token -u\|jeton ponctuel\|credential.helper" global/skills` — Expected: aucune sortie.

- [ ] **Step 4: README** — sous la ligne des skills perso : « Profils par projet (`global/profiles.json`) : plugins et
  compte gh selon le propriétaire du dépôt, voir `/profile`. »

- [ ] **Step 5: Lancer** — `bash tests/run.sh` → tout `PASS`.

- [ ] **Step 6: Commit** — `✨ skills: Add /profile and drop per-skill gh accounts`

## Recette

Manuelle, après `claude-config install` : ouvrir une session dans MtgCollection (perso) puis dans un projet
`softwarevidal` ; vérifier le message, relancer, contrôler `/plugin` et `/profile`, puis `gh pr list` sans préfixe
écrit à la main avec le compte actif réglé sur l'autre compte.

Dans un worktree ouvert par `EnterWorktree` dans un projet à profil, lancer `git status` : le hook le réécrit en
`export GH_TOKEN=…; git status`. Commande refusée par Claude Code → ne pas préfixer les commandes d'un worktree lié
et figer ce cas par un test dans `tests/test_hook.sh`.

## Convergence 1

### Task C1: Préfixe gh avec build-brief, sans rtk (§4 cas 11)

**Files:**
- Test: `tests/test_hook.sh`

Le cas 11 n'est prouvé que pour `git push && gh pr view` (rtk). Le chemin où seul build-brief réécrit (rtk sans
sortie) n'a aucun test : le préfixe doit y être ajouté une seule fois, en tête.

- [ ] **Step 1: Écrire le test** (corriger `hook_command_in` si besoin ; implémentation attendue déjà correcte)

```bash
test_hook_gh_prefixed_once_with_build_brief() {
  stub_rewriters; perso_repo
  assert_eq "$(hook_command_in './gradlew test && gh pr view' "$SANDBOX/p")" \
    "${PREFIX_PERSO}build-brief ./gradlew test && gh pr view" "build-brief puis gh"
  assert_eq "$(hook_command_in 'rtk gh pr list' "$SANDBOX/p" | grep -o 'GH_TOKEN' | wc -l)" "1" "préfixe unique"
}
```

- [ ] **Step 2: Lancer** — `bash tests/run.sh test_hook_gh_prefixed_once` → `PASS`.
- [ ] **Step 3: Commit** — `✅ tests: Cover the gh prefix with build-brief`

### Task C2: Worktree d'un projet perso, premier démarrage (§4 cas 10)

**Files:**
- Test: `tests/test_profile.sh`

Le cas 10 demande que le fichier du worktree reçoive son profil au premier démarrage dedans ; seul `account` en
worktree est testé.

- [ ] **Step 1: Écrire le test**

```bash
test_profile_session_start_in_worktree() {
  repo_with_origin "$SANDBOX/p" https://github.com/Dahiorus/x.git
  git -C "$SANDBOX/p" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
  git -C "$SANDBOX/p" worktree add -q "$SANDBOX/wt" -b w
  assert_contains "$(session_start_in "$SANDBOX/wt")" "Profil perso appliqué"
  assert_eq "$(profile current "$SANDBOX/wt")" "perso" "profil du worktree"
  assert_eq "$(profile account "$SANDBOX/wt")" "Dahiorus" "compte"
  assert_eq "$(git -C "$SANDBOX/wt" status --short)" "" "fichier exclu de git status"
}
```

- [ ] **Step 2: Lancer** — `bash tests/run.sh test_profile_session_start_in_worktree` → `PASS`.
- [ ] **Step 3: Commit** — `✅ tests: Cover profile start in a worktree`
