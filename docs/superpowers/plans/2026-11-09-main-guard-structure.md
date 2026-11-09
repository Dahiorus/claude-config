# main-guard : séparer jugement et suivi — plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `global/main-guard-hook.sh` se lit de haut en bas (entrée et état, jugement et suivi, parseur, flux
principal), `violates` ne fait que juger, le suivi s'applique sans `pending_*`, même décision pour toute commande.

**Architecture:** refactor d'un seul script bash. `parse` lit la tête du segment une fois ; `track` (avec `track_cd`,
`track_switch`) met à jour `here` et `switched_*` ; `violates` (avec `pushes_main`) juge. La boucle compte le plafond
et revient au départ après un séparateur autre que `&&`. Le parseur (`emit` … `flatten_plain`) ne bouge pas, hormis
le `ctx=""` mort.

**Tech Stack:** bash, `tests/run.sh` (runner maison + shellcheck), jq, git.

**Spec:** `docs/superpowers/specs/2026-11-09-main-guard-structure-design.md`

## Découpage en PR

Une seule PR, une seule story (P1). Fichier touché hors tests, spec et plan : `global/main-guard-hook.sh` (1 < 15).
`docs/domaine.md` est déjà commité avec la spec.

## Global Constraints

- Aucun changement de décision : `tests/test_main_guard.sh` reste identique à `main`
  (`git diff main -- tests/test_main_guard.sh` vide) et passe.
- Au plus 243 lignes de code : `grep -cvE '^\s*(#|$)' global/main-guard-hook.sh` ≤ 243 (spec R6).
- Parseur intouché hormis R4 : les lignes de `# flatten écrit dans flat` jusqu'à la fin de `flatten_plain` sont
  celles de `main`, moins `LC_ALL=C` (déplacé) et `ctx=""`.
- Les deux textes de refus et le message « entrée illisible » sont recopiés à l'octet.
- Commiter fichier par fichier (`git add <fichier>`), jamais `git add -A`.
- Vérification : `bash tests/run.sh guard` pendant les tâches (filtre), `bash tests/run.sh` (tests + shellcheck,
  plus de 120 s, `timeout: 580000`) avant chaque commit.
- Pas de rouge à prouver pour les tâches 2 et 3 (refactor sans changement de comportement) : la preuve est la suite
  verte avant et après, plus les mutations de la tâche 1 rejouées à la tâche 3.

## Review Focus

1. Reste d'un segment au suivant (`sub`, `dir`, `args`) : `parse` remet tout à zéro ;
   `test_guard_forgets_previous_segment` (tâche 1).
2. `-C` lu par le suivi d'un switch : `test_guard_track_reads_dash_c_of_switch` (tâche 1).
3. Préfixe de lancement devant `cd` (`env cd`) : `test_guard_track_skips_prefix_of_cd` (tâche 1).
4. Plafond compté deux fois par segment : `test_guard_counts_each_segment_once` (tâche 1).
5. `switch -` qui relit la branche prise avant de l'écrire (R1b) : tests existants des lignes 171-173 et 182 de
   `tests/test_main_guard.sh`.

## Traçabilité

| Exigence (spec) | Tâche | Preuve |
|---|---|---|
| §5 — filet : quatre cas combinés figés, verts sur `main` | 1 | `tests/test_main_guard_track.sh` (4 tests) ; mutations de l'étape 3 |
| R2 — `LC_ALL=C` après la lecture de l'entrée, état groupé en tête, commentaires du glossaire | 2 (placement), 3 (état final) | `grep -n 'LC_ALL' ` une seule ligne, après `cwd=` ; suite verte |
| R3 — ordre du fichier, `deny` avant la boucle | 2 | `grep -nE '^[a-z_]+\(\)'` dans l'ordre de R3 (tâche 3, étape 5) |
| R4 — `ctx=""` retiré de `flatten_plain` | 2 | `sed -n '/^flatten_plain/,/^}/p'` sans `ctx` ; suite verte |
| R5 — sept lignes `shortcut:` | 2 | `grep -c '^# shortcut:'` = 7, aucune ligne > 200 caractères |
| R1 — `parse`, `track`, `track_cd`, `track_switch`, `violates`, `pushes_main` ; plafond dans la boucle ; `local a ref` | 3 | suite verte ; tests de la tâche 1 ; `violates` sans affectation globale |
| R1b — suivi appliqué tout de suite, `pending_*` retirés | 3 | `grep -c pending` = 0 ; tests existants `&&`/`;`/`||` (l. 164-185) |
| R6 — ≤ 243 lignes de code | 3 | `grep -cvE '^\s*(#|$)'` ≤ 243 |
| §4 — refus inchangés (entrée illisible, plafond, commit, push) | 1, 3 | `test_guard_refuses_unreadable_input`, `test_guard_caps_forks_not_lines`, `test_guard_denies_commit_on_main`, `test_guard_denies_push_of_main`, `test_guard_counts_each_segment_once` ; textes : `grep -cF` de la tâche 3, étape 5 |
| §7 — dette reportée (`track_switch`, `pushes_main`, `parse`, fichier > 200) | — | reportée au reste à faire à `/pr push` (spec §7) |

Usages vérifiés à l'étape 1b (`git grep main-guard`, `git grep -E 'pending_|switched_to|flatten_plain'` hors du
hook) :

| Fichier | Usage | Devient |
|---|---|---|
| `settings/base.json:30` | `bash ~/.claude/main-guard-hook.sh` | inchangé (même chemin) |
| `tests/test_main_guard.sh:21,158` | lance le script par son chemin | inchangé, figé par la contrainte globale |
| `CLAUDE.md:10-11` | décrit le comportement | inchangé (comportement identique) ; suite verte |
| `docs/domaine.md` | glossaire « Garde de main » (`switched_to`, `flatten_plain`) | déjà à jour (commit de la spec) |

---

### Task 1 : Caractérisation du suivi et du plafond

**Spec :** §4 (cas combinés), §5.

**Files:**
- Create: `tests/test_main_guard_track.sh`

**Interfaces:**
- Consumes : `make_repo`, `guard`, `GUARD_REPO` de `tests/test_main_guard.sh` ; `assert_eq`, `SANDBOX` de
  `tests/helpers.sh` (le runner source tous les `tests/test_*.sh` avant de lancer un test).
- Produces : quatre tests que les tâches 2 et 3 doivent garder verts.

- [ ] **Step 1 : écrire le fichier de tests**

`tests/test_main_guard_track.sh` :

```bash
# shellcheck shell=bash
# shellcheck disable=SC2154
# Caractérisation du suivi des cd et des switch (issue #109) ; make_repo et guard viennent de test_main_guard.sh.

# Chemin relatif : read -ra coupe un chemin à espaces, et le bac à sable en contient.
test_guard_track_reads_dash_c_of_switch() {
  make_repo
  git -C "$GUARD_REPO" worktree add -q "$SANDBOX/wt" feat/x
  GUARD_REPO="$SANDBOX/wt"
  assert_eq "$(guard 'git -C ../work commit -m x')" deny "commit -C sur main"
  assert_eq "$(guard 'git -C ../work switch -c y && git -C ../work commit -m x')" allow "switch -C"
}

test_guard_track_skips_prefix_of_cd() {
  make_repo
  git -C "$GUARD_REPO" worktree add -q "$SANDBOX/wt" feat/x
  assert_eq "$(guard 'env cd ../wt && git commit -m x')" allow "env cd"
}

test_guard_counts_each_segment_once() {
  make_repo
  local c
  c="$(printf 'git status; %.0s' {1..1499})git status"
  assert_eq "$(guard "$c")" allow "1500 git"
}

test_guard_forgets_previous_segment() {
  make_repo
  assert_eq "$(guard 'git switch -c y && git commit -m x; echo ok')" allow "segment non git après un commit permis"
}
```

- [ ] **Step 2 : lancer sur le hook de `main`**

Run : `bash tests/run.sh guard_`
Attendu : 18 réussi(s), 0 échec(s) (14 existants + 4).

- [ ] **Step 3 : prouver que chaque test mord (tient lieu de rouge)**

Pour chaque mutation, modifier `global/main-guard-hook.sh`, lancer le test nommé, noter l'échec, puis
`git restore global/main-guard-hook.sh`. Toutes portent sur le code actuel :

| Mutation (code actuel) | Test qui doit échouer |
|---|---|
| l. 81 : `git -C "$dir" rev-parse --show-toplevel` → `git -C "$here" rev-parse --show-toplevel` | `test_guard_track_reads_dash_c_of_switch` |
| l. 44 : `if [[ "${w[i]:-}" == cd \|\| …` → `if [[ $i == 0 && ( "${w[i]:-}" == cd \|\| "${w[i]:-}" == pushd ) ]]` | `test_guard_track_skips_prefix_of_cd` |
| l. 42 : `((++forks > 2000))` → `((forks += 2, forks > 2000))` | `test_guard_counts_each_segment_once` |

`test_guard_forgets_previous_segment` n'a pas de mutation sur `main` : le code actuel ne garde rien d'un segment à
l'autre. Il fige ce comportement pour `parse` ; sa mutation se joue à la tâche 3, étape 5.

Le rapport recopie, pour chaque mutation, la ligne `FAIL` et l'assertion en échec.

- [ ] **Step 4 : suite complète**

Run : `bash tests/run.sh` (`timeout: 580000`)
Attendu : 0 échec, `PASS  shellcheck`.

- [ ] **Step 5 : commit**

```bash
git add tests/test_main_guard_track.sh
git commit -m "✅ hooks: Pin main-guard tracking before the refactor

Co-Authored-By: <modèle de l'implémenteur>"
```

### Task 2 : En-tête, état en tête, ordre du fichier, code mort

**Spec :** R2 (placement), R3, R4, R5.

**Files:**
- Modify: `global/main-guard-hook.sh` (l. 5-7, 17-18, 112-116, 268, 275-282)

**Interfaces:**
- Consumes : tests de la tâche 1.
- Produces : un fichier dans l'ordre de R3, que la tâche 3 restructure sans le réordonner.

- [ ] **Step 1 : suite verte avant modification**

Run : `bash tests/run.sh guard`
Attendu : 18 réussi(s), 0 échec(s).

- [ ] **Step 2 : en-tête (R5)**

Les lignes 5 à 7 deviennent, à l'octet :

```bash
# shortcut: un cd non résolu (chemin calculé $VAR, $(…), cd -) est jugé sur le dossier de départ ; résoudre les variables si ça gêne.
# shortcut: après ; || | ou un saut de ligne, retour au départ : depuis un worktree, « git switch main; git commit » passe ; garder un retour vers main si ça gêne.
# shortcut: le contenu de $( ) et de ` n'est pas jugé ; un vrai parseur shell si ça gêne.
# shortcut: un « motif) » de case dans $( ) ferme le $( ) trop tôt ; un vrai parseur shell si ça gêne.
# shortcut: un << arithmétique ($((1<<2))) est pris pour un heredoc ; un vrai parseur shell si ça gêne.
# shortcut: les lignes d'un heredoc hors $( ) sont jugées comme des commandes ; un vrai parseur shell si ça gêne.
# shortcut: guillemets déséquilibrés (ou contexte de lecture resté ouvert) : repli où chaque saut de ligne coupe, guillemets ignorés ; un vrai parseur shell si ça gêne.
```

- [ ] **Step 3 : réglage et état en tête (R2)**

Retirer `LC_ALL=C # un octet par caractère` (l. 116) et la ligne 282 (`pending="" … forks=0`). Juste après
`cwd="${cwd:-$PWD}"`, ajouter `LC_ALL=C` ; le bloc d'état devient :

```bash
cwd="${cwd:-$PWD}"
LC_ALL=C # un octet par caractère : la commande se lit octet par octet

here="$cwd"                    # dossier jugé : celui du segment, après les cd reliés par &&
switched_dir="" switched_to="" # branche prise par un « git switch » plus tôt dans la commande
pending="" pending_dir="" pending_to="" pending_here="" # suivi du segment, appliqué si le suivant commence par &&
forks=0                        # plafond de processus : segments cd, pushd ou git lus
```

La ligne `pending_*` est provisoire : la tâche 3 la retire.

- [ ] **Step 4 : ordre (R3) et code mort (R4)**

- Déplacer `deny()` (l. 277-280, inchangée) juste après la fin de `violates`, avant le commentaire
  `# flatten écrit dans flat…`.
- `flatten || flatten_plain` reste juste avant la boucle `while IFS= read -r segment`, à la fin du fichier.
- Dans `flatten_plain`, `flat="" last="" prev="" ctx=""` devient `flat="" last="" prev=""`.

- [ ] **Step 5 : vérifier**

Run : `bash tests/run.sh guard`
Attendu : 18 réussi(s), 0 échec(s).

Run : `grep -n 'LC_ALL\|^# shortcut:\|ctx=""' global/main-guard-hook.sh`
Attendu : sept lignes `# shortcut:` (l. 5-11), une ligne `LC_ALL=C` juste après `cwd="${cwd:-$PWD}"`, aucun `ctx=""`.

Run : `awk 'length > 200' global/main-guard-hook.sh`
Attendu : rien.

Run : `bash tests/run.sh` (`timeout: 580000`)
Attendu : 0 échec, `PASS  shellcheck`.

- [ ] **Step 6 : commit**

```bash
git add global/main-guard-hook.sh
git commit -m "♻️ hooks: Order main-guard top to bottom, one shortcut per limit

Co-Authored-By: <modèle de l'implémenteur>"
```

### Task 3 : Séparer lecture, suivi et jugement

**Spec :** R1, R1b, R2 (état final), R6.

**Files:**
- Modify: `global/main-guard-hook.sh` (bloc d'état, `violates` remplacé, boucle finale)

**Interfaces:**
- Consumes : le fichier ordonné de la tâche 2.
- Produces : globales de segment `verb`, `dir`, `sub`, `args` (écrites par `parse`, lues par `track*`, `violates`,
  `pushes_main`) ; fonctions sans argument `parse "${words[@]}"`, `track`, `violates` (code retour 0 = refus).

- [ ] **Step 1 : suite verte avant modification**

Run : `bash tests/run.sh guard`
Attendu : 18 réussi(s), 0 échec(s).

- [ ] **Step 2 : état final (R2, R1b)**

La ligne provisoire `pending_*` de la tâche 2 est remplacée par :

```bash
verb="" dir="" sub="" args=()  # segment lu par parse
```

- [ ] **Step 3 : remplacer `violates` (R1, R1b)**

`branch_of` et `resolve` ne changent pas. Entre `resolve` et `deny`, `violates` (tout le bloc actuel, commentaire
`# Vrai si le segment…` compris) est remplacé par ce qui suit. La regex des préfixes, la lecture de `-C`/`-c`, la
boucle de `switch`/`checkout` et celle de `push` sont celles de `main` ; ce qui change : `w` → `args` dans les
boucles, `pending_*` → écriture directe, `local a ref current pos=()` / `local a create="" to pos=()`.

```bash
# Lit un segment (mots d'une commande simple) : verb cd ou git (vide sinon), dir (dossier de -C, sinon dossier jugé), sub, args.
parse() {
  local -a w=("$@")
  local i=0 n=${#w[@]}
  verb="" dir="$here" sub="" args=()
  # Seuls les préfixes de lancement précèdent git : « echo git push » n'est pas un push.
  while ((i < n)) && [[ "${w[i]}" =~ ^(rtk|sudo|env|command|time|\{|!|if|then|elif|else|while|until|do|[A-Za-z_][A-Za-z0-9_]*=.*)$ ]]; do ((i++)); done
  case "${w[i]:-}" in
    cd | pushd) verb=cd args=("${w[@]:i+1}") ;;
    git | */git) verb=git ;;
  esac
  [[ "$verb" == git ]] || return 0
  ((i++))
  while ((i < n)) && [[ "${w[i]}" == -* ]]; do
    case "${w[i]}" in
      -C) dir="$(resolve "${w[i+1]:-}")"; dir="${dir:-$here}"; ((i += 2)) ;;
      -c) ((i += 2)) ;;
      *) ((i++)) ;;
    esac
  done
  sub="${w[i]:-}" args=("${w[@]:i+1}")
}

# Suivi : un cd ou un switch change le dossier jugé ou la branche prise ; la boucle revient au départ après ; || |.
track() {
  [[ "$verb" == cd ]] && track_cd
  [[ "$sub" == switch || "$sub" == checkout ]] && track_switch
}

track_cd() {
  local i=0 to
  while [[ "${args[i]:-}" =~ ^-[LPe@]+$ ]]; do ((i++)); done
  [[ "${args[i]:-}" == -- ]] && ((i++))
  to="$(resolve "${args[*]:i}")" # tout le reste : un chemin entre guillemets peut contenir des espaces
  # Chemin non résolu (cd -, $VAR) : dossier de départ, où « cd - » ramène le plus souvent.
  here="${to:-$cwd}"
}
```

`track_switch()` : corps du `switch | checkout)` de `main` (l. 68-87), avec `"${args[@]}"` au lieu de `"${w[@]:i}"`,
`local a create="" to pos=()` en première ligne de code (et `to="${pos[0]:-}"` sans `local`), `|| return` au lieu de
`|| return 1`, `local top; top=…` / `top="${top:-$dir}"` au lieu de `pending_dir`, et pour finir
`switched_dir="$top" switched_to="$to"` au lieu de `pending=1 pending_to="$to"`.

```bash
# Vrai si le segment lu par parse commite sur main ou pousse vers main.
violates() {
  case "$sub" in
    commit) [[ "$(branch_of "$dir")" == main ]] ;;
    push) pushes_main ;;
    *) return 1 ;;
  esac
}
```

`pushes_main()` : corps du `push)` de `main` (l. 91-106), avec `local a ref current pos=()` en première ligne,
`"${args[@]}"` au lieu de `"${w[@]:i}"`, et `current="$(branch_of "$dir")"` juste avant le commentaire
`# Sans refspec, git pousse la branche courante.`

- [ ] **Step 4 : boucle (R1, R1b)**

Le corps de la boucle, après la lecture de `sep`, devient :

```bash
  # Un cd ou un switch ne compte que suivi de && : après ; || |, ou un saut de ligne, il a pu échouer ou tourner dans un sous-shell.
  [[ -n "$sep" && "$sep" != "&&" ]] && here="$cwd" switched_dir="" switched_to=""
  parse "${words[@]}"
  # Chaque cd, pushd ou git peut coûter un processus (2 à 3 ms) : au-delà de 2000, le délai de 60 s du hook laisserait tout passer.
  [[ -n "$verb" ]] && ((++forks > 2000)) && deny "Plus de 2000 cd ou git dans la commande, trop long pour que main-guard la juge : découpe-la."
  track
  violates && deny "Pas de commit ni de push sur main : passe par /pr push, qui crée la branche et ouvre la PR."
```

Le bloc `if [[ "$sep" == "&&" ]] … fi` et `pending="" pending_here=""` disparaissent.

- [ ] **Step 5 : vérifier**

Run : `bash tests/run.sh guard`
Attendu : 18 réussi(s), 0 échec(s).

Run : `grep -c pending global/main-guard-hook.sh`
Attendu : `0`.

Run : `grep -cvE '^\s*(#|$)' global/main-guard-hook.sh`
Attendu : ≤ 243 (243 dans l'essai de la spec).

Run : `grep -nE '^[a-z_]+\(\)' global/main-guard-hook.sh | cut -d'(' -f1`
Attendu, dans cet ordre : `branch_of`, `resolve`, `parse`, `track`, `track_cd`, `track_switch`, `violates`,
`pushes_main`, `deny`, `emit`, `amp_pipe`, `eol`, `escape`, `in_string`, `heredoc_op`, `heredoc_bodies`, `in_code`,
`flatten`, `plain_char`, `flatten_plain`.

Run : `sed -n '/^violates()/,/^}/p' global/main-guard-hook.sh | grep -E '(here|switched_[a-z]+|forks|pending[a-z_]*)='`
Attendu : rien (R1 : `violates` n'écrit aucune globale).

Run : `git diff main -- tests/test_main_guard.sh`
Attendu : vide.

Run : `grep -cF -e 'main-guard : entrée illisible, appel refusé' -e 'Plus de 2000 cd ou git dans la commande, trop long pour que main-guard la juge : découpe-la.' -e 'Pas de commit ni de push sur main : passe par /pr push, qui crée la branche et ouvre la PR.' global/main-guard-hook.sh`
Attendu : `3` (textes de refus recopiés à l'octet ; aucun test ne les lit).

Rejouer les quatre mutations de la tâche 1 sur le nouveau code (même effet, autres lignes) :
`git -C "$dir"` → `git -C "$here"` dans `track_switch` ; `cd | pushd)` → `cd | pushd) [[ $i == 0 ]] &&` dans `parse` ;
`((++forks > 2000))` → `((forks += 2, forks > 2000))` ; `verb="" dir="$here" sub="" args=()` →
`verb="" dir="$here" args=()` dans `parse`. Chacune fait échouer son test ; `git restore` après chacune.

Run : `bash tests/run.sh` (`timeout: 580000`)
Attendu : 0 échec, `PASS  shellcheck`.

- [ ] **Step 6 : commit**

```bash
git add global/main-guard-hook.sh
git commit -m "♻️ hooks: Split main-guard reading, tracking and judgment

Co-Authored-By: <modèle de l'implémenteur>"
```
