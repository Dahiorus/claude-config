# Jeton de session dans les skills : plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal :** les skills agissent sur GitHub par le jeton de session, sans préfixe de jeton ponctuel, et s'arrêtent
dans un projet à profil quand ce jeton manque.

**Architecture :** une phrase de règle (R1) remplace la règle du jeton ponctuel dans cinq skills et le skill
`profile` ; `pr-risk` perd la première ligne de son bloc de publication ; `bugfix`, `CLAUDE.md` et le reste à faire
suivent. Un test de `tests/test_skills.sh` empêche le préfixe de revenir.

**Tech Stack :** Markdown (skills Claude Code), bash (test).

**Spec :** `docs/superpowers/specs/2026-11-18-jeton-session-skills-design.md`

## Découpage en PR

Fichiers touchés hors tests, spec et plan : 11 (≤ 15). Une seule PR, une seule story (P1).

## Table de traçabilité

| Exigence (§ spec) | Tâche | Test qui la prouve |
|---|---|---|
| R1 (phrase dans `pr`, `notify`, `release`, `todo`, `pr-risk`) | 1 | `test_no_per_command_token` ; recette R6 cas 4 |
| R1 décision « test une fois avant la première commande » | 1 | recette R6 cas 4 (le skill suivi teste `GH_TOKEN` avant `gh`) |
| R1 / #142 (`account` en échec → s'arrêter) | 1 | phrase présente une fois dans chacun des cinq skills (tâche 1, étape 4) |
| R2 (rien) | — | aucun changement : `git diff` de `pr-risk` sans ligne sur `R` |
| R3 (bloc `pr-risk`) | 1 | `test_no_per_command_token` (motif `t=$(gh auth token -u`) |
| R4 (`EnterWorktree` dans `pr` l. 19, `pr-risk` l. 25) | 1 | recette R6 cas 5 |
| R5 skill `profile` + `version` 0.1.2 | 1 | `test_no_per_command_token` ; `jq -r .version` = `0.1.2` |
| R5 `CLAUDE.md` l. 4, 7, 8 | 2 | grep de la tâche 2, étape 2 |
| Portée `bugfix` l. 30, 57, 58 | 2 | grep de la tâche 2, étape 2 |
| R6 recette (cas 1 à 5) | étape 6 de `feature` | `recette.md` du dossier de suivi |
| § 4 nominal (`/pr list`, `pr-risk`, `todo sync`) | 1 | recette R6 cas 4, `todo sync` compris |
| § 4 refus `GH_TOKEN` vide | 1 | recette R6 cas 6 : un agent neuf suit `/pr list` après `unset GH_TOKEN` dans le même appel, il s'arrête et renvoie à `/profile` sans lancer `gh` |
| § 4 refus `account` en échec (#142) | 1 | recette R6 cas 7 : un agent neuf suit `/pr list` dans un dépôt jetable dont `profile.sh account` échoue (`profiles.json` mal formé dans un `CLAUDE_CONFIG_DIR` jetable), il rapporte la sortie et s'arrête |
| R7 limite au reste à faire, points 6 et 8 rayés | 3 (doc, —) | grep de la tâche 3 |
| R8 `require-token` (six lignes du tableau) | 4 | `test_profile_require_token_*` (un par ligne, plus la casse) |
| R1 révisée (`require-token` dans les cinq skills), R3 révisée, M1 (R4) | 5 | `test_skills_call_require_token` ; recette cas 4, 6, 8 |
| R7 fermée (point 11 rayé), glossaire « Jeton de session refusé », `CLAUDE.md` l. 8 | 5 (doc, —) | grep de la tâche 5 |
| Glossaire `docs/domaine.md` | fait (commit de la spec) | — |
| Mémoire `gh-account-push.md` | au merge (`/pr merge`) | — |

Usages vérifiés à l'étape 1b : `git grep 'profile.sh account'` et `git grep 'gh auth token\|GH_TOKEN'` hors
`docs/superpowers` ne montrent que les endroits de la Portée. `feature/SKILL.md` l. 42, `profile.sh`,
`statusline-gh.sh`, `tests/test_main_guard_ast.sh` l. 87 et le diagnostic du skill `profile` l. 39-42 restent
inchangés (le test de la tâche 1 ne vise pas `[ -n "$(gh auth token -u …)" ]`).

Décision (Plannotator) : le test du jeton reste dans la règle de `pr/SKILL.md`, toujours chargé avant une
action ; les actions (`pr/*.md`) ne le répètent pas. Les cas 6 et 7 de la recette le prouvent sur `/pr list`.

## Global Constraints

- Ligne de skill ou de Markdown ajoutée ou réécrite : 120 colonnes au plus (`CLAUDE.md` du dépôt).
- Texte français ou Markdown : Edit/Write, jamais `sed -i`, `python3 -c`, `printf` ni `echo` en ligne.
- Commiter fichier par fichier (`git add <fichier>`), jamais `git add -A`.
- Commits au format de `CONTRIBUTING.md`, fin : `Co-Authored-By: <modèle de l'implémenteur>`.
- `bash tests/run.sh` dure plus de 120 s : `timeout: 580000`, sortie lue par `grep -v '^PASS'`.
- La phrase R1 est identique dans les quatre skills français, mot pour mot (voir tâche 1).

## Review Focus

- Une étape de `pr` qui écrit encore « avec le jeton » ou « sous jeton ponctuel » ailleurs que l. 18-19 et 88 :
  grep de la tâche 1, étape 4.
- `pr-risk` sans compte : le bloc ne doit rien tester (pas de `[ -n "$GH_TOKEN" ] || exit 1` sans compte).
- Une phrase coupée à 120 colonnes dont le raccord casse : relire la phrase entière après chaque Edit.

---

### Task 1 : Règle du jeton de session dans les skills

**Spec :** R1, R3, R4, R5 (skill `profile`, `version`), § 4, #142.

**Files :**
- Test : `tests/test_skills.sh` (ajout en fin de fichier)
- Modify : `global/skills/pr/SKILL.md:18-19,88`
- Modify : `global/skills/notify/SKILL.md:28-29`
- Modify : `global/skills/release/SKILL.md:39`
- Modify : `global/skills/todo/SKILL.md:37`
- Modify : `global/skills/pr-risk/SKILL.md:20-26,230`
- Modify : `mods/profile/skills/profile/SKILL.md:81-85`
- Modify : `mods/profile/.claude-plugin/plugin.json` (`version`)

**Interfaces :** Produces : la phrase R1 ci-dessous, reprise telle quelle par la tâche 2 pour `bugfix` (« avec le
compte du profil »).

- [ ] **Step 1 : Écrire le test**

`tests/test_skills.sh`, à la fin :

```bash
test_no_per_command_token() {
  local hits
  # shellcheck disable=SC2016 # motif littéral, pas d'expansion voulue
  hits="$(grep -rnF 't=$(gh auth token -u' "$REPO_SRC/global/skills" "$REPO_SRC/mods/profile/skills")" \
    || [[ $? -eq 1 ]] || fail "grep en erreur"
  assert_eq "$hits" "" "préfixe de jeton ponctuel dans un skill"
}
```

- [ ] **Step 2 : Le voir rouge**

```bash
bash -c 'set -euo pipefail; REPO_SRC=$PWD; TESTS_DIR=$PWD/tests; source tests/helpers.sh; source tests/test_skills.sh; test_no_per_command_token'
```

Attendu : échec « préfixe de jeton ponctuel dans un skill », avec les lignes de `pr`, `notify`, `release`, `todo`,
`pr-risk` (l. 21 et 230) et `profile` (l. 82). Garder la sortie pour le rapport.

- [ ] **Step 3 : Réécrire les règles**

Phrase R1, mot pour mot, coupée à 120 colonnes, dans `pr` l. 17-18 (elle remplace tout depuis « Les commandes `gh` »
en fin de l. 17, après « La PR est cherchée dans le dépôt courant uniquement. »), `notify` l. 28-29 (« Pour lire une
PR, le compte gh vient… », « le » en minuscule, indentation de 3 espaces gardée, l. 29 « jamais `gh auth switch`. »
retirée car reprise par R1), `release` l. 39 (suivie de « Projet
sans profil et accès refusé → demander quel compte utiliser. », inchangée), `todo` l. 37 (indentation gardée) :

```markdown
Le compte gh vient du profil du projet (`bash ~/.claude/profile.sh account`) par le jeton de session que le plugin
`profile` exporte : les commandes `gh`, `git push`, `git fetch` et `git pull` partent sans préfixe. `account` en
échec : rapporter sa sortie et s'arrêter. Avant la première commande `gh` ou git distante, compte non vide et
`[ -n "$GH_TOKEN" ]` faux : s'arrêter et renvoyer à `/profile` (gh prendrait le compte actif). Un `cd` vers un
autre dépôt ne change le jeton qu'à l'appel Bash suivant. Projet sans profil : compte actif. Jamais
`gh auth switch`.
```

Dans `pr` l. 18, retirer aussi « (même forme devant `git push`… `origin/main` périmée) », « jamais le jeton recopié
en clair ; jeton vide → … `gh auth switch` » et « Les étapes écrivent `git fetch`, `git pull` et `git push` sans ce
préfixe : il s'ajoute à chacune. » ; garder, après la phrase R1 : « Sur un dépôt privé, un `fetch` sans jeton
répond « Repository not found » et laisse `origin/main` périmée. »
`pr` l. 19 : « refuse `git -c …` et `VAR=… git/gh …` (commandes `gh` à jeton comprises) : » devient « refuse
`git -c …` et `VAR=… git/gh …` : ». Le reste de la phrase (`ExitWorktree`… depuis le dépôt principal) reste : le
cas 5 de la recette dit s'il tombe. La l. 19 réécrite est coupée à 120 colonnes.
`pr` l. 88 : « (sous jeton ponctuel, `@me` = soi » → « (sous jeton de session, `@me` = soi ».

`pr-risk` l. 20-26, à la place des deux puces sur le compte et le refus `EnterWorktree` :

```markdown
- gh account: `bash ~/.claude/profile.sh account`, through the session token
  that the `profile` plugin exports: run `gh` and `git fetch` with no prefix.
  `account` fails: report its output and stop. Account not empty and
  `[ -n "$GH_TOKEN" ]` false: stop before the first `gh` or `git fetch` call and say to run
  `/profile` (gh would fall back to the active account). No account: use the
  active account. A `cd` to another repository changes the token only at the
  next Bash call.
```

`pr-risk` l. 224-227 : la raison « run the block as one command so every `gh` call, `gh api user` included, uses
the profile account (otherwise `ME` is the active account, nothing matches, and a duplicate is posted). » devient
« run the block as one command: its first line stops it when the session token is missing (otherwise `ME` is the
active account, nothing matches, and a duplicate is posted). » ; « Without a profile account, drop the first line: »
reste. La première ligne du bloc devient :

```bash
[ -n "$GH_TOKEN" ] || exit 1
```

`profile` l. 81-85, premier point de « À savoir » :

```markdown
- Le compte gh suit le propriétaire du dépôt (`account`) : le plugin exporte le jeton de session, et les skills
  lancent `gh`, `git push`, `git fetch` et `git pull` sans préfixe. Compte non vide et `GH_TOKEN` absent : ils
  s'arrêtent et renvoient ici (diagnostic plus haut). Un `cd` ne change le jeton qu'à l'appel Bash suivant ; hors
  profil, gh prend le compte actif. Jamais `gh auth switch`.
```

`mods/profile/.claude-plugin/plugin.json` : `"version": "0.1.2"`.

- [ ] **Step 4 : Vérifier**

```bash
bash -c 'set -euo pipefail; REPO_SRC=$PWD; TESTS_DIR=$PWD/tests; source tests/helpers.sh; source tests/test_skills.sh; test_no_per_command_token' && echo VERT
for f in pr notify release todo; do
  printf '%s ' "$f"; tr -s '\n ' '  ' < "global/skills/$f/SKILL.md" | grep -cF "\`account\` en échec : rapporter sa sortie et s'arrêter"
done
tr -s '\n ' '  ' < global/skills/pr-risk/SKILL.md | grep -cF '`account` fails: report its output and stop'
git grep -n 'jeton ponctuel\|avec le jeton\|à jeton' -- global/skills mods/profile/skills
jq -r .version mods/profile/.claude-plugin/plugin.json
git diff -U0 | grep '^+' | awk 'length > 121'
```

Attendu : `VERT` ; `pr`, `notify`, `release`, `todo` à 1, puis `1` pour `pr-risk` ; seules les lignes 30 et 57 de `bugfix` (tâche 2) ;
`0.1.2` ; aucune ligne de plus de 120 colonnes. Puis `bash tests/run.sh` (timeout 580000), sortie par
`grep -v '^PASS'` : aucun échec.

- [ ] **Step 5 : Commit**

```bash
git add tests/test_skills.sh global/skills/pr/SKILL.md global/skills/notify/SKILL.md global/skills/release/SKILL.md
git add global/skills/todo/SKILL.md global/skills/pr-risk/SKILL.md mods/profile/skills/profile/SKILL.md
git add mods/profile/.claude-plugin/plugin.json
git commit -m "♻️ skills: Use the session token instead of a per-command gh token

Co-Authored-By: <modèle de l'implémenteur>"
```

### Task 2 : `bugfix` et `CLAUDE.md`

**Spec :** R5 (`CLAUDE.md` l. 4, 7, 8), Portée `bugfix` l. 30, 57, 58, R4 (`CLAUDE.md` l. 9 inchangée).

**Files :**
- Modify : `global/skills/bugfix/SKILL.md:30,57-58`
- Modify : `CLAUDE.md:4,7,8`

**Interfaces :** Consumes : la règle R1 de la tâche 1.

- [ ] **Step 1 : Réécrire**

`bugfix` l. 30 : « (`git fetch origin main`, avec le jeton du compte du profil, voir `profile`) » → « (`git fetch
origin main`, avec le compte du profil, voir `profile`) ».
`bugfix` l. 57-58 : « …fait le `git fetch origin main` de l'étape 2, avec le jeton du profil. L'agent, sans jeton,
crée sa branche par… » → « …fait le `git fetch origin main` de l'étape 2, avec le compte du profil. L'agent crée sa
branche par… ».
`CLAUDE.md` l. 4 : retirer la phrase « Même réponse pour un appel `gh` à jeton ponctuel
(`GH_TOKEN=$(gh auth token -u …)`) lancé avec un autre Bash. »
`CLAUDE.md` l. 7 : « Un compte gh ou un jeton ne s'ajoute pas par hook : les skills le passent dans la commande. »
→ « Un compte gh ou un jeton ne s'ajoute pas par réécriture de commande. »
`CLAUDE.md` l. 8 :

```markdown
- Compte gh : `bash ~/.claude/profile.sh account`, porté par le jeton de session du plugin `profile` ; `GH_TOKEN`
  absent dans un projet à profil → `/profile`. `GH_CONFIG_DIR` ne change pas de compte sans jeton en clair dans
  `hosts.yml` (trousseau partagé) : piste écartée.
```

- [ ] **Step 2 : Vérifier**

```bash
git grep -n 'jeton ponctuel\|avec le jeton\|sans jeton,\|passent dans la commande' -- CLAUDE.md global/skills
git diff -U0 | grep '^+' | awk 'length > 121'
```

Attendu : aucune sortie aux deux commandes. Puis `bash tests/run.sh` (timeout 580000) par `grep -v '^PASS'`.

- [ ] **Step 3 : Commit**

```bash
git add global/skills/bugfix/SKILL.md
git add CLAUDE.md
git commit -m "📝 bugfix: Drop the per-command token from bugfix and CLAUDE.md

Co-Authored-By: <modèle de l'implémenteur>"
```

### Task 3 : Reste à faire (doc)

**Spec :** — (tâche de doc) ; § 6, R7.

**Files :**
- Modify : `docs/reste-a-faire.md:37-43` et ajout en fin de la liste « Profils » (après le point 10 ou le dernier
  point de la même liste)

- [ ] **Step 1 : Rayer et ajouter**

Point 6 : `6. ~~**Préfixe …** … (#140)~~ Fait : jeton de session (spec 2026-11-18-jeton-session-skills).`
Point 8 : même forme, `(#142)` puis « Fait : règle R1 (spec 2026-11-18-jeton-session-skills). »
Nouveau point, numéro suivant de la liste :

```markdown
N. **`GH_TOKEN` hérité du shell** : compte du profil non connecté, `session-start` n'exporte rien et un `GH_TOKEN`
   du shell passe le test des skills ; fermer en comparant `gh api user --jq .login` au compte. (spec
   2026-11-18-jeton-session-skills, R7)
```

- [ ] **Step 2 : Vérifier**

```bash
git grep -n -F 'GH_TOKEN=$(gh auth token' -- . ':!docs/superpowers' ':!tests'
```

Attendu : seule la ligne rayée du point 6 de `docs/reste-a-faire.md` et `docs/domaine.md` l. 16 (« Jeton
ponctuel », gardé pour la statusline).

- [ ] **Step 3 : Commit**

```bash
git add docs/reste-a-faire.md
git commit -m "📝 todo: Close #140 and #142, log the inherited GH_TOKEN limit

Co-Authored-By: <modèle de l'implémenteur>"
```

## Review finale

Correctifs retenus (« corrige tout ») : I1 et P1 (R8, R1 révisée), P2 positif, M1, M3 (la phrase réécrite a son « s'il
échoue »). Spec amendée d'abord (R1, R3, R4, R7, R8, Portée, § 4, R6 cas 8).

### Task 4 : `profile.sh require-token`

**Spec :** R8.

**Files :**
- Modify : `tests/helpers.sh` (`make_gh_stub`)
- Test : `tests/test_profile.sh` (ajout en fin de fichier)
- Modify : `mods/profile/scripts/profile.sh` (fonction, `case`, usage, commentaire l. 19)

- [ ] **Step 1 : Faux gh et tests**

`tests/helpers.sh`, `make_gh_stub` : commentaire d'en-tête complété par « , échec de « gh api user » $GH_API_USER_ERROR »
et branche ajoutée au `case`, avant `"api repos/"*` :

```bash
  "api user")
    [[ -z "${GH_API_USER_ERROR:-}" ]] || { echo "$GH_API_USER_ERROR" >&2; exit 1; }
    echo "${GH_TOKEN#tok-}" ;;
```

`tests/test_profile.sh`, à la fin :

```bash
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
```

- [ ] **Step 2 : Les voir rouges**

```bash
bash tests/run.sh 2>&1 | grep -v '^PASS'
```

(timeout 580000.) Attendu : les six `test_profile_require_token_*` en échec (sous-commande inconnue : code 2, usage),
le reste vert. Garder la sortie pour le rapport.

- [ ] **Step 3 : La sous-commande**

`mods/profile/scripts/profile.sh`, après `account()` :

```bash
# Garde des skills : le jeton de session est celui du compte du profil (rien à vérifier hors profil).
require_token() {  # <dossier>
  local account login
  account=$(account "$1") || return 1
  [[ -n "$account" ]] || return 0
  [[ -n "${GH_TOKEN:-}" ]] || { echo "GH_TOKEN absent pour le compte $account : lancer /profile" >&2; return 1; }
  login=$(gh api user --jq .login 2>&1) || { echo "gh api user a échoué : ${login%%$'\n'*}" >&2; return 1; }
  [[ "${login,,}" == "${account,,}" ]] \
    || { echo "jeton de session de $login, compte attendu $account : lancer /profile" >&2; return 1; }
}
```

Dans le `case` final, après `account) …` :

```bash
  require-token) require_token "${2:-.}" ;;
```

Ligne d'usage : `detect|account|current|telemetry [dossier]` devient `detect|account|require-token|current|telemetry
[dossier]`. Commentaire l. 19 : « # les skills placent le compte dans une commande shell (gh auth token -u <compte>) »
devient « # le compte passe à gh auth token -u <compte> (write_token) et se compare au login (require_token) ».

- [ ] **Step 4 : Vérifier**

`shellcheck mods/profile/scripts/profile.sh tests/test_profile.sh tests/helpers.sh`, puis `bash tests/run.sh`
(timeout 580000) par `grep -v '^PASS'` : aucun échec.

- [ ] **Step 5 : Commit**

```bash
git add tests/helpers.sh
git add tests/test_profile.sh
git add mods/profile/scripts/profile.sh
git commit -m "✨ profile: Check that the session token belongs to the profile account

Co-Authored-By: <modèle de l'implémenteur>"
```

### Task 5 : Les skills appellent `require-token`

**Spec :** R1 révisée, R3 révisée, R4 (M1), R5, R7 fermée, Portée (glossaire, `CLAUDE.md` l. 8, skill `profile`).

**Files :**
- Test : `tests/test_skills.sh` (ajout en fin de fichier)
- Modify : `global/skills/pr/SKILL.md`, `global/skills/notify/SKILL.md`, `global/skills/release/SKILL.md`,
  `global/skills/todo/SKILL.md`, `global/skills/pr-risk/SKILL.md`
- Modify : `mods/profile/skills/profile/SKILL.md` (diagnostic l. 39-42, « À savoir » l. 81-84)
- Modify : `CLAUDE.md` l. 8-9, `docs/domaine.md` l. 18 et 22, `docs/reste-a-faire.md` point 11

**Interfaces :** Consumes : `profile.sh require-token` de la Task 4.

- [ ] **Step 1 : Écrire le test**

`tests/test_skills.sh`, à la fin :

```bash
test_skills_call_require_token() {
  local skill
  for skill in pr notify release todo pr-risk; do
    grep -qF 'bash ~/.claude/profile.sh require-token' "$REPO_SRC/global/skills/$skill/SKILL.md" \
      || fail "$skill ne lance pas require-token"
  done
}
```

- [ ] **Step 2 : Le voir rouge**

```bash
bash -c 'set -euo pipefail; REPO_SRC=$PWD; TESTS_DIR=$PWD/tests; source tests/helpers.sh; source tests/test_skills.sh; test_skills_call_require_token'
```

Attendu : « ÉCHEC : pr ne lance pas require-token ».

- [ ] **Step 3 : Réécrire**

Phrase R1 révisée, mot pour mot, à la place de la phrase R1 actuelle (de « Le compte gh vient du profil du projet » à
« Jamais `gh auth switch`. ») dans `pr`, `release`, `todo` (indentation gardée) et `notify` (« Pour lire une PR, le
compte gh vient… », indentation de 3 espaces gardée), coupée à 120 colonnes :

```markdown
Le compte gh vient du profil du projet par le jeton de session que le plugin `profile` exporte : les commandes
`gh`, `git push`, `git fetch` et `git pull` partent sans préfixe. Avant la première d'entre elles, et après tout
`cd` vers un autre dépôt, lancer `bash ~/.claude/profile.sh require-token` : s'il échoue, rapporter sa sortie et
s'arrêter. Un `cd` ne change le jeton qu'à l'appel Bash suivant. Projet sans profil : compte actif. Jamais
`gh auth switch`.
```

`pr`, fin de la même ligne (M1) : « En session `EnterWorktree`, Claude Code refuse `git -c …` et `VAR=… git/gh …` :
`ExitWorktree` avec `action: "keep"`, puis lancer fetch, pull et push depuis le dépôt principal. » devient « En
session `EnterWorktree`, Claude Code refuse `git -c …` et `VAR=… git/gh …` : ce skill n'en écrit pas. »

`pr-risk`, la puce « gh account: … next Bash call. » devient :

```markdown
- gh account: the session token that the `profile` plugin exports; run `gh`
  and `git fetch` with no prefix. Before the first of them, and after any `cd`
  to another repository, run `bash ~/.claude/profile.sh require-token`: if it
  fails, report its output and stop. A `cd` changes the token only at the next
  Bash call. No profile account: use the active account.
```

`pr-risk`, bloc de publication : « its first line stops it when the session token is missing (otherwise » devient
« its first line stops it when the session token is missing or belongs to another account (otherwise » ; la phrase
finit par « posted): » au lieu de « posted). » ; la ligne « Without a profile account, drop the first line: » est
retirée ; la première ligne du bloc devient :

```bash
bash ~/.claude/profile.sh require-token || exit 1
```

`mods/profile/skills/profile/SKILL.md`, après le point du diagnostic « compte attendu mais `GH_TOKEN` absent… relancer
la session. », nouveau point :

```markdown
- `profile.sh require-token` signale le jeton d'un autre compte : un `GH_TOKEN` posé dans le shell (le retirer), ou
  un `cd` hors des répertoires de travail que Claude Code a annulé après que le hook a posé le jeton du dossier visé.
  Relancer la session depuis le dépôt.
```

« À savoir », premier point :

```markdown
- Le compte gh suit le propriétaire du dépôt (`account`) : le plugin exporte le jeton de session, et les skills
  lancent `gh`, `git push`, `git fetch` et `git pull` sans préfixe, après `profile.sh require-token`. Jeton absent
  ou d'un autre compte : ils s'arrêtent et renvoient ici (diagnostic plus haut). Un `cd` ne change le jeton qu'à
  l'appel Bash suivant ; hors profil, gh prend le compte actif. Jamais `gh auth switch`.
```

`CLAUDE.md` l. 8-10 :

```markdown
- Compte gh : `bash ~/.claude/profile.sh account`, porté par le jeton de session du plugin `profile` ; les skills le
  vérifient par `profile.sh require-token` (jeton absent ou d'un autre compte → `/profile`). `GH_CONFIG_DIR` ne
  change pas de compte sans jeton en clair dans `hosts.yml` (trousseau partagé) : piste écartée.
```

`docs/domaine.md` l. 18 : terme « Jeton de session absent » → « Jeton de session refusé » ; définition : « Projet à
profil (compte du profil non vide) dont le `GH_TOKEN` manque (hook pas encore installé ou pas relancé, compte non
connecté) ou appartient à un autre compte (`GH_TOKEN` du shell, `cd` annulé par Claude Code). gh agirait avec un
autre compte : les skills s'arrêtent et renvoient à `/profile` » ; code : `profile.sh require-token` ; « À ne pas
dire » inchangé. l. 22, fin de l'invariant : « jeton de session absent, il s'arrête » → « jeton de session refusé,
il s'arrête ».

`docs/reste-a-faire.md` point 11 : `11. ~~**`GH_TOKEN` hérité du shell** : … R7)~~ Fait : `profile.sh require-token`
(spec 2026-11-18-jeton-session-skills, R8).`

- [ ] **Step 4 : Vérifier**

```bash
bash -c 'set -euo pipefail; REPO_SRC=$PWD; TESTS_DIR=$PWD/tests; source tests/helpers.sh; source tests/test_skills.sh; test_skills_call_require_token; test_no_per_command_token' && echo VERT
for f in pr notify release todo; do
  printf '%s ' "$f"; tr -s '\n ' '  ' < "global/skills/$f/SKILL.md" | grep -cF "lancer \`bash ~/.claude/profile.sh require-token\` : s'il échoue, rapporter sa sortie et s'arrêter"
done
git grep -n 'GH_TOKEN" \] faux\|\[ -n "\$GH_TOKEN" \] ||\|drop the first line\|Jeton de session absent\|jeton de session absent\|push depuis le dépôt principal' -- . ':!docs/superpowers'
git diff -U0 HEAD | grep '^+' | awk 'length > 121'
```

Attendu : `VERT` ; 1 pour chaque skill ; aucune sortie aux deux dernières commandes. Puis `bash tests/run.sh`
(timeout 580000) par `grep -v '^PASS'` : aucun échec.

- [ ] **Step 5 : Commit**

```bash
git add tests/test_skills.sh global/skills/pr/SKILL.md global/skills/notify/SKILL.md global/skills/release/SKILL.md
git add global/skills/todo/SKILL.md global/skills/pr-risk/SKILL.md mods/profile/skills/profile/SKILL.md
git add CLAUDE.md docs/domaine.md docs/reste-a-faire.md
git commit -m "♻️ skills: Guard gh calls with profile.sh require-token

Co-Authored-By: <modèle de l'implémenteur>"
```
