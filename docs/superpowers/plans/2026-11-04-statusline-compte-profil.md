# Statusline : compte gh du profil — plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** la statusline prend le compte gh du profil (`profile.sh account`) et ne sonde les comptes que si le compte du profil manque (projet sans profil, compte invalide ou non connecté dans gh) (issue #70).

**Architecture:** le bloc « compte gh » de `global/statusline-command.sh` appelle d'abord `profile.sh account "$cwd"` ; la boucle actuelle passe dans une fonction `probe_gh_user`, appelée seulement si le compte du profil est vide ou sans jeton. Le script entre dans la liste shellcheck de `tests/run.sh`.

**Tech Stack:** bash, jq, gh (simulé en test), runner `tests/run.sh`.

**Spec:** `docs/superpowers/specs/2026-11-04-statusline-compte-profil-design.md`

## Découpage en PR

Fichiers touchés hors tests, spec et plan : `global/statusline-command.sh`, `tests/run.sh` (liste shellcheck). 2 fichiers → **une seule PR**, une seule story (P1).

## Global Constraints

- La statusline ne lit pas `profiles.json` elle-même : elle passe par `profile.sh account` (glossaire `docs/domaine.md`).
- `profile.sh` se trouve à côté du script réel : `$(dirname "$(readlink -f "$0")")/profile.sh`.
- Sortie d'erreur de `profile.sh` jetée (`2>/dev/null`) ; une sortie en échec compte comme « vide ».
- Compte du profil relu à chaque affichage, sans cache.
- Compte du profil connu et jeton obtenu : ni `gh auth status`, ni `gh api`, ni lecture ou écriture de `ghuser-*`.
- Le compte actif n'est jamais changé (jeton ponctuel `GH_TOKEN` exporté pour le seul processus).
- `global/profile.sh`, `global/profiles.json` : inchangés.

## Review Focus

- `workspace.repo` absent mais `origin` perso : le jeton du profil doit quand même partir (critère 9) — test `test_statusline_profile_without_workspace_repo`, tâche 4.
- Ancien cache `ghuser-*` récent désignant un autre compte : il ne doit pas masquer le profil (critère 6) — test `test_statusline_profile_beats_fresh_cache`, tâche 4.
- `profiles.json` au compte invalide : aucun message dans la statusline (critère 5) — test `test_statusline_invalid_profile_account_falls_back`, tâche 4.
- Dossier du projet supprimé : aucun appel `gh` d'arrière-plan (critère 8) — test `test_statusline_missing_cwd_skips_background_calls`, tâche 2.
- Projet hors GitHub sans `workspace.repo` : aucun jeton, aucune sonde (critère 4) — test `test_statusline_no_github_no_probe`, tâche 4.

## Traçabilité

| Exigence (spec) | Tâche | Test |
|---|---|---|
| §5 filet : boucle sans profil retient le compte qui voit le dépôt, écrit le cache ; critère 3 | 1 | `test_statusline_probe_picks_account_that_sees_repo` |
| §5 filet : cache récent → aucun `gh api` | 1 | `test_statusline_probe_skipped_with_fresh_cache` |
| §7 shellcheck : SC2164 corrigé, critère 8 | 2 | `test_statusline_missing_cwd_skips_background_calls` |
| §7 shellcheck : SC2016, SC2329 en `disable` ; `tests/run.sh` liste le script | 2 | `PASS shellcheck` de `bash tests/run.sh` |
| §7 dette : boucle extraite dans `probe_gh_user` | 3 | tests de la tâche 1, inchangés et verts |
| §2 règle, critère 1 (perso) | 4 | `test_statusline_uses_profile_account` |
| critère 2 (vidal) | 4 | `test_statusline_uses_profile_account` (deuxième dépôt) |
| critère 4 | 4 | `test_statusline_no_github_no_probe` |
| critère 5, §2 « erreurs de profile.sh » | 4 | `test_statusline_invalid_profile_account_falls_back` |
| critère 6, §3 caches existants | 4 | `test_statusline_profile_beats_fresh_cache` |
| critère 7, §2 compte non connecté | 4 | `test_statusline_unlogged_profile_account_falls_back` |
| critère 9, §2 « condition du bloc » | 4 | `test_statusline_profile_without_workspace_repo` |

### Usages vérifiés (étape 1b)

| Symbole | Usages trouvés | Devient |
|---|---|---|
| `gh_user`, `gh_user_f` | `global/statusline-command.sh:146-156` seulement | `gh_user` reçoit d'abord le compte du profil ; `gh_user_f` passe dans `probe_gh_user` |
| cache `ghuser-*` | `global/statusline-command.sh:146-155` seulement | lu et écrit par `probe_gh_user` seule |
| `GH_TOKEN` exporté | hérité par `fetch_ci_state`, `fetch_threads_count`, `fetch_branch_pr`, `fetch_pr_state` via `cached` | inchangé |
| `profile.sh account` | skills `pr`, `feature`, `profile`, `release`, `todo`, `notify` ; `tests/test_profile.sh` | inchangé, un appelant de plus |
| `cached` (`cd "${cwd:-.}"`, ligne 91) | appels des lignes 160, 165, 190, 196 | `cd … \|\| exit` : rien ne part si le dossier manque |
| liste shellcheck | `tests/run.sh:48` | ajoute `global/statusline-command.sh` |

Aucune tâche parallélisable : les quatre touchent `global/statusline-command.sh` ou `tests/test_statusline.sh`.

---

### Task 1: tests de caractérisation de la boucle

**Files:**
- Create: `tests/test_statusline.sh`

**Interfaces:**
- Consumes: `repo_with_origin <dossier> <url>` (`tests/helpers.sh`), `setup_sandbox` (`$SANDBOX`, `$REPO`, `$STUBS`, `$CALLS_LOG`), `assert_eq`, `assert_contains`, `assert_not_contains`, `fail`.
- Produces: `make_gh_stub`, `run_statusline <cwd> [propriétaire/dépôt]`, `wait_for_call <motif>`, `pr_view_call` (utilisés par les tâches 2 et 4).

- [ ] **Step 1: écrire les helpers et les deux tests**

`tests/test_statusline.sh` :

```bash
# shellcheck shell=bash
# shellcheck disable=SC2154

# Faux gh : comptes connectés $GH_ACCOUNTS, compte qui voit le dépôt $GH_SEES, comptes sans jeton $GH_MISSING.
make_gh_stub() {
  mkdir -p "$STUBS"
  cat > "$STUBS/gh" <<'STUB'
#!/usr/bin/env bash
printf 'GH_TOKEN=%s gh %s\n' "${GH_TOKEN:-}" "$*" >> "$CALLS_LOG"
case "$1 $2" in
  "auth status") for a in ${GH_ACCOUNTS:-}; do echo "  ✓ Logged in to github.com account $a (keyring)"; done ;;
  "auth token") [[ " ${GH_MISSING:-} " == *" $4 "* ]] && exit 1; echo "tok-$4" ;;
  "api repos/"*) [[ "${GH_TOKEN:-}" == "tok-${GH_SEES:-}" ]] ;;
esac
STUB
  chmod +x "$STUBS/gh"
}

run_statusline() {  # <cwd> [propriétaire/dépôt]
  local repo=null
  [[ -n "${2:-}" ]] && repo=$(jq -nc --arg o "${2%/*}" --arg n "${2#*/}" '{owner: $o, name: $n}')
  make_gh_stub
  jq -nc --arg cwd "$1" --argjson repo "$repo" '{workspace: {current_dir: $cwd, repo: $repo}, pr: {number: 5}}' \
    | PATH="$STUBS:$PATH" XDG_CACHE_HOME="$SANDBOX/cache" GH_TOKEN='' bash "$REPO/global/statusline-command.sh"
}

wait_for_call() {  # <motif> : vrai dès que le motif paraît dans $CALLS_LOG, 5 s au plus
  local _
  for _ in $(seq 50); do
    grep -q -- "$1" "$CALLS_LOG" 2>/dev/null && return 0
    sleep 0.1
  done
  return 1
}

pr_view_call() {  # appel d'arrière-plan qui porte le jeton retenu
  wait_for_call 'gh pr view 5' || fail "gh pr view jamais appelé"
  grep 'gh pr view 5' "$CALLS_LOG"
}

test_statusline_probe_picks_account_that_sees_repo() {
  repo_with_origin "$SANDBOX/p" https://github.com/someone/x.git
  GH_ACCOUNTS="alice bob" GH_SEES=bob run_statusline "$SANDBOX/p" someone/x >/dev/null
  assert_eq "$(cat "$SANDBOX/cache/claude-statusline/ghuser-someone_x")" "bob" "cache"
  assert_contains "$(pr_view_call)" "GH_TOKEN=tok-bob "
}

test_statusline_probe_skipped_with_fresh_cache() {
  repo_with_origin "$SANDBOX/p" https://github.com/someone/x.git
  mkdir -p "$SANDBOX/cache/claude-statusline"
  echo alice > "$SANDBOX/cache/claude-statusline/ghuser-someone_x"
  GH_ACCOUNTS="alice bob" GH_SEES=bob run_statusline "$SANDBOX/p" someone/x >/dev/null
  assert_contains "$(pr_view_call)" "GH_TOKEN=tok-alice "
  assert_not_contains "$(cat "$CALLS_LOG")" "gh api repos/"
}
```

- [ ] **Step 2: lancer, vert attendu (caractérisation du comportement actuel)**

Run: `bash tests/run.sh statusline`
Expected: `PASS  test_statusline_probe_picks_account_that_sees_repo`, `PASS  test_statusline_probe_skipped_with_fresh_cache`. Preuve que le test mord : remplacer temporairement `GH_SEES=bob` par `GH_SEES=carol` dans le premier test, constater `FAIL` (cache vide), remettre `bob`.

- [ ] **Step 3: commit**

```bash
git add tests/test_statusline.sh
git commit -m "✅ tests: Pin the statusline gh account probe"
```

### Task 2: statusline sous shellcheck

**Files:**
- Modify: `global/statusline-command.sh:91` (`cached`), `:102`, `:114`, `:119`, `:125`, `:137`
- Modify: `tests/run.sh:48`
- Test: `tests/test_statusline.sh`

**Interfaces:**
- Consumes: `run_statusline`, `wait_for_call` (tâche 1).

- [ ] **Step 1: test du critère 8**

```bash
test_statusline_missing_cwd_skips_background_calls() {
  run_statusline "$SANDBOX/supprime" >/dev/null
  if wait_for_call 'gh pr view'; then fail "appel gh lancé hors du dossier du projet"; fi
}
```

- [ ] **Step 2: lancer, rouge attendu**

Run: `bash tests/run.sh missing_cwd`
Expected: `FAIL` avec « appel gh lancé hors du dossier du projet » (aujourd'hui `cd` échoue et `"$@"` tourne quand même).

- [ ] **Step 3: corriger et faire taire les faux positifs**

- ligne 91 : `out=$(cd "${cwd:-.}" 2>/dev/null || exit; "$@")` ;
- au-dessus de chacune des quatre fonctions `fetch_*` : `# shellcheck disable=SC2329 # appelée par cached, via "$@"` ;
- au-dessus de la ligne `-f query='…'` de `fetch_threads_count` : `# shellcheck disable=SC2016 # variables GraphQL, pas du shell` (la directive se place devant la commande `out=$(timeout 15 gh api graphql …)`) ;
- `tests/run.sh:48` : ajouter `global/statusline-command.sh` après `global/profile.sh` dans la liste `ls -d`.

- [ ] **Step 4: suite complète, vert attendu**

Run: `bash tests/run.sh`
Expected: tous `PASS`, dont `PASS  shellcheck` et `PASS  test_statusline_missing_cwd_skips_background_calls`.

- [ ] **Step 5: commit**

```bash
git add global/statusline-command.sh tests/run.sh tests/test_statusline.sh
git commit -m "🚨 statusline: Run it under shellcheck"
```

### Task 3: extraire la boucle dans `probe_gh_user`

**Files:**
- Modify: `global/statusline-command.sh:144-157`

**Interfaces:**
Nom retenu : `probe_gh_user`, inscrit au glossaire (« sonde » du compte qui voit le dépôt).

- Produces: `probe_gh_user` — sans argument, lit `$ci_repo_full` et `$cache_dir`, écrit le compte retenu sur la sortie standard (vide si aucun), en gérant le cache `ghuser-*` d'un jour exactement comme aujourd'hui. Utilisée par la tâche 4.

- [ ] **Step 1: refacto sans changement de comportement**

Déplacer les lignes 146-155 dans `probe_gh_user`, définie avant le bloc. Le bloc devient :

```bash
# Le compte gh actif peut ne pas voir le depot : retenir (cache 1 jour) le compte qui y a acces.
if [ -n "$ci_repo_full" ] && command -v gh >/dev/null 2>&1; then
  gh_user=$(probe_gh_user)
  [ -n "$gh_user" ] && GH_TOKEN=$(gh auth token --user "$gh_user" 2>/dev/null) && export GH_TOKEN
fi
```

- [ ] **Step 2: suite complète, vert attendu**

Run: `bash tests/run.sh`
Expected: tous `PASS`, aucun test modifié.

- [ ] **Step 3: commit**

```bash
git add global/statusline-command.sh
git commit -m "♻️ statusline: Extract the gh account probe"
```

### Task 4: lire le compte du profil d'abord

**Files:**
- Modify: `global/statusline-command.sh` (bloc « compte gh » issu de la tâche 3)
- Test: `tests/test_statusline.sh`

**Interfaces:**
- Consumes: `probe_gh_user` (tâche 3), `run_statusline`, `pr_view_call`, `wait_for_call` (tâche 1), `profile.sh account <dossier>` (inchangé ; perso `Dahiorus` → `Dahiorus`, vidal `softwarevidal` → `brondon-ung`).

- [ ] **Step 1: tests des critères 1, 2, 4, 5, 6, 7, 9**

```bash
assert_no_probe() {
  local calls; calls=$(cat "$CALLS_LOG")
  assert_not_contains "$calls" "gh auth status"
  assert_not_contains "$calls" "gh api repos/"
}

test_statusline_uses_profile_account() {
  repo_with_origin "$SANDBOX/p" https://github.com/Dahiorus/x.git
  GH_ACCOUNTS="alice Dahiorus" GH_SEES=alice run_statusline "$SANDBOX/p" Dahiorus/x >/dev/null
  assert_contains "$(pr_view_call)" "GH_TOKEN=tok-Dahiorus "
  assert_no_probe
  [[ ! -e "$SANDBOX/cache/claude-statusline/ghuser-Dahiorus_x" ]] || fail "cache ghuser écrit"

  : > "$CALLS_LOG"
  repo_with_origin "$SANDBOX/v" https://github.com/softwarevidal/y.git
  GH_ACCOUNTS="alice brondon-ung" GH_SEES=alice run_statusline "$SANDBOX/v" softwarevidal/y >/dev/null
  assert_contains "$(pr_view_call)" "GH_TOKEN=tok-brondon-ung "
  assert_no_probe
}

test_statusline_no_github_no_probe() {
  repo_with_origin "$SANDBOX/p" https://gitlab.com/Dahiorus/x.git
  GH_ACCOUNTS="alice" GH_SEES=alice run_statusline "$SANDBOX/p" >/dev/null
  assert_contains "$(pr_view_call)" "GH_TOKEN= "
  assert_no_probe
}

test_statusline_invalid_profile_account_falls_back() {
  repo_with_origin "$SANDBOX/p" https://github.com/Dahiorus/x.git
  jq '.perso.account = "pas valide"' "$REPO/global/profiles.json" > "$SANDBOX/profiles.json"
  local out
  out=$(PROFILES_FILE="$SANDBOX/profiles.json" GH_ACCOUNTS="alice bob" GH_SEES=bob run_statusline "$SANDBOX/p" Dahiorus/x 2>&1)
  assert_not_contains "$out" "compte gh invalide"
  assert_contains "$(pr_view_call)" "GH_TOKEN=tok-bob "
}

test_statusline_profile_beats_fresh_cache() {
  repo_with_origin "$SANDBOX/p" https://github.com/Dahiorus/x.git
  mkdir -p "$SANDBOX/cache/claude-statusline"
  echo alice > "$SANDBOX/cache/claude-statusline/ghuser-Dahiorus_x"
  GH_ACCOUNTS="alice Dahiorus" GH_SEES=alice run_statusline "$SANDBOX/p" Dahiorus/x >/dev/null
  assert_contains "$(pr_view_call)" "GH_TOKEN=tok-Dahiorus "
}

test_statusline_unlogged_profile_account_falls_back() {
  repo_with_origin "$SANDBOX/p" https://github.com/Dahiorus/x.git
  GH_ACCOUNTS="alice bob" GH_SEES=bob GH_MISSING=Dahiorus run_statusline "$SANDBOX/p" Dahiorus/x >/dev/null
  assert_eq "$(cat "$SANDBOX/cache/claude-statusline/ghuser-Dahiorus_x")" "bob" "cache"
  assert_contains "$(pr_view_call)" "GH_TOKEN=tok-bob "
}

test_statusline_profile_without_workspace_repo() {
  repo_with_origin "$SANDBOX/p" https://github.com/Dahiorus/x.git
  GH_ACCOUNTS="alice Dahiorus" run_statusline "$SANDBOX/p" >/dev/null
  assert_contains "$(pr_view_call)" "GH_TOKEN=tok-Dahiorus "
}
```

- [ ] **Step 2: lancer, rouge attendu**

Run: `bash tests/run.sh statusline`
Expected: `FAIL` pour `uses_profile_account` (jeton `tok-alice`, sonde lancée), `profile_beats_fresh_cache` (`tok-alice`), `profile_without_workspace_repo` (`GH_TOKEN=` vide). Les autres peuvent déjà passer : les noter dans le rapport.

- [ ] **Step 3: implémenter le bloc**

Le bloc « compte gh » devient, dans cet ordre :
Le jeton se prend dans une variable `token`, vide au départ (un `GH_TOKEN` hérité de l'environnement ne doit pas sauter la sonde, comme aujourd'hui) :
1. si `cwd` connu et `gh` installé : `gh_user=$(bash "$(dirname "$(readlink -f "$0")")/profile.sh" account "$cwd" 2>/dev/null)` ; si non vide, `token=$(gh auth token --user "$gh_user" 2>/dev/null)` ;
2. `token` toujours vide et `ci_repo_full` connu : `gh_user=$(probe_gh_user)` puis même prise de jeton ;
3. `token` non vide : `export GH_TOKEN="$token"`.

Commentaire du bloc mis à jour : compte du profil d'abord, sonde des comptes en repli (cache 1 jour). Fonction ≤ 20 lignes, deux niveaux d'indentation au plus.

- [ ] **Step 4: suite complète, vert attendu**

Run: `bash tests/run.sh`
Expected: tous `PASS`, dont `shellcheck` et les 9 `test_statusline_*`.

- [ ] **Step 5: commit**

```bash
git add global/statusline-command.sh tests/test_statusline.sh
git commit -m "✨ statusline: Read the gh account from the project profile"
```
