# Leçons étiquetées et budget du CLAUDE.md : plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal :** chaque leçon de `lecons.md` porte une étiquette (`méca`, `jugement`, `ponctuel`) ; `lessons-extractor`
trie par étiquette et propose une garde mécanique, une règle, ou le déplacement ou le retrait d'une règle qui a
récidivé ; un test borne `CLAUDE.md` (73 lignes) et `global/CLAUDE.md` (26).

**Architecture :** une fonction shell `line_budget_overruns` et deux tests dans `tests/test_rules.sh` ; le reste est
du texte lu par les sessions (`global/skills/pr/SKILL.md`, `global/agents/lessons-extractor.md`,
`global/skills/pr/merge.md`, `docs/domaine.md`, `docs/reste-a-faire.md`).

**Tech Stack :** bash (tests), Markdown (skills et agents Claude Code).

**Spec :** `docs/superpowers/specs/2026-11-23-lecons-sans-regle-design.md`

## Découpage en PR

Une seule PR : 6 fichiers touchés hors spec et plan, une seule story (P1).

## Contraintes globales

- Lignes de 120 colonnes au plus dans tout Markdown ajouté ou réécrit ; une ligne déjà plus longue ne se réécrit pas,
  on écrit dessous (`CLAUDE.md` du dépôt). `test_branch_respects_rules` le vérifie.
- Édition par Edit/Write uniquement, jamais `sed -i`, `python3 -c`, `printf` ni `echo` (`CLAUDE.md` du dépôt).
- Termes du glossaire (`docs/domaine.md`, contexte « Leçons ») : friction, leçon, étiquette, règle, garde
  mécanique, proposition, récidive, règle citée, budget de lignes. À ne pas dire : erreur, incident, catégorie, type
  (pour l'étiquette), rappel, doublon (pour la récidive), référence (pour la règle citée), limite de taille.
- `global/skills/pr/SKILL.md` reste à 200 lignes au plus (`test_pr_skill_table_matches_files`) : il en a 198.
- Commit par fichier (`git add <fichier>`), jamais `git add -A` : une autre session peut toucher `global/skills/*`.
- Commits : `Co-Authored-By: <modèle de l'implémenteur>`.
- Texte des skills et agents : pas de test automatique ; le test d'une tâche de texte est un `git grep -nF` d'un
  fragment de la nouvelle phrase, absent avant (rouge) et présent après (vert), plus le grep de l'ancienne phrase,
  présent avant et absent après.
- `bash tests/run.sh` (timeout 580000) reste vert, sortie lue par `grep -v '^PASS'`.

## Traçabilité

| Exigence (§ de la spec) | Tâche | Test qui la prouve |
|---|---|---|
| §2 R4, critères 5, 6, 7, 11 : budget 73 et 26, message qui nomme fichier, taille et budget, les deux à la fois | 1 | `test_line_budget_overruns_names_each_file`, `test_instruction_files_within_line_budget` |
| §2 R4 : budget écrit dans le test, une seule fois | 1, 3 | grep : `git grep -n "budget" global/agents/lessons-extractor.md` ne donne aucun chiffre |
| §2 R1, critère 1 : format, trois étiquettes définies dans `pr/SKILL.md`, citation de récidive | 2 | grep `[<étiquette>]` et `(récidive :` dans `pr/SKILL.md` ; `test_pr_skill_table_matches_files` (≤ 200 lignes) |
| §2 R1 : session qui pose l'étiquette | 2 | même grep (la puce dit le format que la session écrit) |
| §2 R2, critères 2, 3, 8, 9 : tri par étiquette, leçons lues, ré-étiquetage, garde `méca` | 3 | grep `## Trier` et `ponctuel` dans `lessons-extractor.md` ; recette |
| §2 R2 (correctifs de review I1, M1-M4) : `méca` sans garde → `jugement`, `méca` avec règle → suite 1, règle de la PR exclue, une proposition par leçon, règle liée à son retrait | 3 (review) | grep `ce n'est`, `dans son diff`, `jamais « à trancher »`, `, avec #1` dans `lessons-extractor.md` ; recette F rejouée |
| §2 R3, critère 4 : trois suites, palier à la deuxième citation | 3 | grep `## Récidive` et `citée deux fois` ; recette |
| §2 R4, critère 10 : proposition au-delà du budget vient avec une ligne retirée | 3 | grep `line_budget_overruns` dans `lessons-extractor.md` ; recette |
| §2 Portée R2-R4 : « Cible », « Réponse », `description` de l'agent, point de `final-review.md` vu deux fois | 3 | grep `garde mécanique` dans la `description` et la table « Cible » ; grep `final-review.md` vu deux fois |
| §2 Portée R2-R4 : `merge.md` étape 2 renvoie à l'agent, garde trop grosse en issue | 4 | grep `« Trier » et « Récidive »` dans `merge.md` ; grep de l'ancienne phrase vide |
| — (doc : glossaire, reste à faire) | 5 | grep `proposé :` vide dans le contexte « Leçons » ; point 8 rayé |

Usages vérifiés à l'étape 1b (`git grep -n "lessons-extractor\|lecons\.md\|règle écrite aurait évité" -- .
':!docs/superpowers'`) :

| Fichier | Usage | Ce qu'il devient | Ce qui fige l'inchangé |
|---|---|---|---|
| `global/skills/feature/SKILL.md:28`, `global/skills/bugfix/SKILL.md:36` | « frictions de la session dans `lecons.md` » | renvoient au format de `pr/SKILL.md` (correctif de review P1) | grep `avec leur étiquette (format : skill` dans les deux fichiers |
| `global/skills/pr/comments.md:60`, `rebase.md:13`, `recette.md:39`, `merge.md:22`, `merge.md:54` | « frictions dans `lecons.md` » | inchangés | idem |
| `global/skills/pr/SKILL.md:33` | liste des agents, cite `lessons-extractor` | inchangé | `test_pr_skill_table_matches_files` |
| `global/skills/pr/SKILL.md:54-56` | définition de `lecons.md` | tâche 2 | grep |
| `global/skills/pr/merge.md:12-17` | étape 2, recopie les critères | tâche 4 | grep |
| `global/agents/lessons-extractor.md` | agent | tâche 3 | grep, recette |
| `docs/domaine.md:83`, `:91-112` | glossaire | tâche 5 (colonnes « proposé ») | `test_branch_respects_rules` |
| `docs/reste-a-faire.md:39-45` | point 8 | tâche 5, rayé | — |

Pas de tâche de caractérisation (spec §5) ni de refacto (spec §7, sans objet).

## Lot A — parallélisable (tâches 2, 3, 4)

Fichiers : tâche 2 `global/skills/pr/SKILL.md` ; tâche 3 `global/agents/lessons-extractor.md` ; tâche 4
`global/skills/pr/merge.md`. Aucun fichier commun ni dépendance : la tâche 4 renvoie aux titres « Trier » et
« Récidive » que la tâche 3 crée, sans lire son fichier.

### Task 1 : test du budget de lignes

Spec : §2 R4 ; critères 5, 6, 7, 11.

**Files :** Modify `tests/test_rules.sh` (après `plugins_without_bump`, avant `rules_repo`, pour la fonction ; après
`test_branch_respects_rules` pour les tests).

Noms de premier niveau déjà dans `tests/test_rules.sh` : `md_long_lines`, `plugins_without_bump`, `rules_repo`,
`test_md_long_lines_*`, `test_plugins_without_bump*`, `test_branch_respects_rules`, `test_githooks_unset_git_env` :
aucun n'est redéclaré.

Entrées hostiles : fichier absent (signalé, pas d'erreur arithmétique) ; les deux fichiers au-delà (deux lignes) ;
fichier pile au budget (rien).

- [ ] **Étape 1 : écrire les tests**

`tests/test_rules.sh` (après `test_branch_respects_rules`) :

```bash
test_line_budget_overruns_names_each_file() {
  local repo="$SANDBOX/budget"
  mkdir -p "$repo/global"
  seq 73 >"$repo/CLAUDE.md"
  seq 26 >"$repo/global/CLAUDE.md"
  assert_eq "$(line_budget_overruns "$repo")" "" "fichiers au budget"
  seq 74 >"$repo/CLAUDE.md"
  assert_eq "$(line_budget_overruns "$repo")" "CLAUDE.md : 74 lignes, budget 73" "CLAUDE.md au-delà"
  seq 27 >"$repo/global/CLAUDE.md"
  assert_eq "$(line_budget_overruns "$repo")" \
    "$(printf 'CLAUDE.md : 74 lignes, budget 73\nglobal/CLAUDE.md : 27 lignes, budget 26')" "les deux au-delà"
  seq 73 >"$repo/CLAUDE.md"
  assert_eq "$(line_budget_overruns "$repo")" "global/CLAUDE.md : 27 lignes, budget 26" "global/CLAUDE.md au-delà"
  rm "$repo/CLAUDE.md"
  assert_contains "$(line_budget_overruns "$repo")" "CLAUDE.md : absent" "fichier absent"
}

test_instruction_files_within_line_budget() {
  assert_eq "$(line_budget_overruns "$REPO_SRC")" "" "budget de lignes des CLAUDE.md"
}
```

- [ ] **Étape 2 : voir le rouge**

```bash
bash tests/run.sh line_budget 2>&1 | grep -v '^PASS'
```

Rouge attendu : `line_budget_overruns: command not found` (équivalent d'un échec de compilation), les deux tests en
échec.

- [ ] **Étape 3 : écrire la fonction**

`tests/test_rules.sh` (après `plugins_without_bump`) :

```bash
# Fichiers de consignes au-delà de leur budget de lignes. Le budget ne se relève pas pour faire passer une règle :
# une règle ajoutée en retire ou en déplace une autre. Il se baisse à la main quand le fichier rétrécit.
line_budget_overruns() {  # <dépôt>
  local f budget lines
  while read -r f budget; do
    [[ -f "$1/$f" ]] || { echo "$f : absent"; continue; }
    lines="$(wc -l <"$1/$f")"
    (( lines <= budget )) || echo "$f : $lines lignes, budget $budget"
  done <<<"CLAUDE.md 73
global/CLAUDE.md 26"
}
```

- [ ] **Étape 4 : voir le vert, puis la mutation**

```bash
bash tests/run.sh line_budget 2>&1 | grep -v '^PASS'
```

Vert attendu : aucune ligne. Mutation : remplacer `<=` par `<` dans la fonction, relancer, voir
`test_line_budget_overruns_names_each_file` et `test_instruction_files_within_line_budget` échouer, puis remettre
`<=` (Edit). `shellcheck tests/test_rules.sh` sans sortie.

- [ ] **Étape 5 : commit**

```bash
git add tests/test_rules.sh
git commit -m "✅ tests: Budget de lignes de CLAUDE.md et global/CLAUDE.md

Co-Authored-By: <modèle de l'implémenteur>"
```

### Task 2 : format d'une leçon dans `pr/SKILL.md`

Spec : §2 R1 ; critère 1. Lot A.

**Files :** Modify `global/skills/pr/SKILL.md:54-56` (puce `lecons.md` de « Dossier de suivi »).

- [ ] **Étape 1 : rouge**

```bash
git grep -nF '[<étiquette>]' -- global/skills/pr/SKILL.md; git grep -nF '(récidive :' -- global/skills/pr/SKILL.md
```

Attendu : aucune sortie.

- [ ] **Étape 2 : remplacer la puce**

Texte actuel (3 lignes) :

```markdown
- `lecons.md` : une ligne datée par friction (correction de l'utilisateur, commande refusée, piège, consigne
  oubliée), ajoutée en fin de session de travail sur la branche (`feature` étape 7, `bugfix` étape 8, `push`, `squash`,
  `recette`, `comments`, `rebase`, `merge` avant son étape 2, puis à la fin pour la PR suivante). Rien à noter → rien.
```

Nouveau texte (5 lignes, largeurs mesurées : 117, 117, 118, 119, 119 ; le fichier passe à 200 lignes) :

```markdown
- `lecons.md` : une ligne `- <date> (<action>) [<étiquette>] : <friction>` par friction (correction de l'utilisateur,
  commande refusée, piège, consigne oubliée), action facultative. Étiquette : `méca` (un programme peut la vérifier),
  `jugement` (seule une phrase lue l'évite), `ponctuel` (cas unique sans retour). Règle écrite qui la couvrait : finir
  par `(récidive : <fichier> « <fragment d'une ligne> »)`. Ajoutée en fin de session sur la branche (`feature` étape 7,
  `bugfix` étape 8, `push`, `squash`, `recette`, `comments`, `rebase`, `merge` avant l'étape 2, à la fin). Rien → rien.
```

- [ ] **Étape 3 : vert**

```bash
git grep -nF '[<étiquette>]' -- global/skills/pr/SKILL.md; git grep -nF '(récidive :' -- global/skills/pr/SKILL.md
git grep -nF 'une ligne datée par friction' -- global/skills/pr/SKILL.md
bash tests/run.sh pr_skill 2>&1 | grep -v '^PASS'
```

Attendu : une ligne pour chacun des deux premiers greps, rien pour le troisième, aucun échec (≤ 200 lignes).

- [ ] **Étape 4 : commit**

```bash
git add global/skills/pr/SKILL.md
git commit -m "📝 pr: Leçon étiquetée méca, jugement ou ponctuel, règle citée en récidive

Co-Authored-By: <modèle de l'implémenteur>"
```

### Task 3 : tri et récidive dans `lessons-extractor`

Spec : §2 R2, R3, R4 (budget côté extracteur), Portée R2-R4 ; critères 2, 3, 4, 8, 9, 10. Lot A.

**Files :** Modify `global/agents/lessons-extractor.md`.

- [ ] **Étape 1 : rouge**

```bash
git grep -nF '## Trier' -- global/agents/lessons-extractor.md; git grep -nF 'citée deux fois' -- global/agents/lessons-extractor.md
```

Attendu : aucune sortie.

- [ ] **Étape 2 : `description` du front matter**

Remplacer la ligne `description:` par (le front matter est exempté de la largeur) :

```markdown
description: Leçons d'une PR avant son merge (skill pr, action merge, étape 2) — lit lecons.md et final-review.md du dossier de suivi et des PR précédentes, trie les leçons par étiquette (méca, jugement, ponctuel) et propose une garde mécanique, une règle, ou le déplacement ou le retrait d'une règle qui a récidivé, sans rien écrire. Lancer avec model sonnet, passé explicitement.
```

- [ ] **Étape 3 : paragraphe d'ouverture**

Remplacer :

```markdown
La PR va être squashée puis mergée. Tu cherches dans son historique de travail les règles à écrire pour que les PR
suivantes ne refassent pas les mêmes erreurs. Tu proposes ; la session montre tes diffs à l'utilisateur et
n'applique que ce qu'il accepte.
```

par :

```markdown
La PR va être squashée puis mergée. Tu cherches dans son historique de travail ce qui empêchera les PR suivantes de
buter sur les mêmes frictions : une garde mécanique quand un programme peut vérifier, une règle sinon, et la remise
en cause d'une règle qui n'a pas suffi. Tu proposes ; la session montre tes diffs à l'utilisateur et n'applique que
ce qu'il accepte.
```

- [ ] **Étape 4 : remplacer la section « Retenir » par « Trier » et « Récidive »**

Remplacer toute la section `## Retenir` (titre et ses quatre puces) par :

```markdown
## Trier

Étiquettes, posées par la session qui écrit la leçon (format : `pr/SKILL.md`, « Dossier de suivi ») : `méca` (un
programme peut vérifier la friction), `jugement` (seule une phrase lue par la session peut l'éviter), `ponctuel`
(cas unique sans chance de revenir).

- Leçons traitées : celles de la PR, plus les anciennes qui forment une récidive ou une répétition avec elles. Un
  point de `final-review.md` vu deux fois, dans cette PR ou entre deux PR, se traite comme une leçon sans étiquette.
- Leçon sans étiquette → l'étiqueter, en le disant. Étiquette fausse → la corriger, en le disant : un `ponctuel` dont
  la friction revient dans une autre PR n'est pas ponctuel.
- `ponctuel` → aucune proposition. Rien non plus pour ce que git, GitHub ou le code disent déjà.
- `méca` → une garde mécanique (test, hook, script, ou changement qui supprime le piège), jamais une phrase. Un test
  se propose en diff ; un hook ou un script, trop gros pour un diff accepté d'un mot (mutations, scripts adverses),
  devient une issue ou un point du reste à faire, que la session crée après accord.
- `jugement` → chercher (grep) la règle dans la cible, les skills et les agents globaux (`~/.claude/skills/*/`,
  `~/.claude/agents/`) et, pour `claude-config`, `docs/domaine.md` et `CLAUDE.md`. Aucune règle → proposer une
  règle. Une règle existe, ou la leçon la cite (`(récidive : <fichier> « <fragment> »)`) → récidive.

## Récidive

Jamais une reformulation seule. L'une de ces trois suites, liste fermée :

1. mécaniser : une garde remplace la phrase ;
2. déplacer : la règle va à l'étape du skill où l'action a lieu, si la phrase était lue ailleurs ;
3. retirer : la règle n'a rien empêché et aucune garde n'est possible.

Règle citée deux fois (deux récidives, dans cette PR ou entre deux PR) : seulement mécaniser ou retirer.

Pour `claude-config`, `CLAUDE.md` et `global/CLAUDE.md` ont un budget de lignes (`line_budget_overruns`,
`tests/test_rules.sh`) : une règle qui le ferait dépasser vient avec la ligne qu'elle retire ou déplace.
```

- [ ] **Étape 5 : section « Cible »**

Sous la table existante (ses trois lignes restent), ajouter deux lignes à la table :

```markdown
| une garde mécanique (test, changement qui supprime le piège) | `tests/` du projet (pour `claude-config` : `tests/test_*.sh`) ou le fichier du piège |
| un hook ou un script trop gros pour la PR | issue, ou point du reste à faire versionné s'il existe ; le fichier visé (pour `claude-config` : `global/*-hook.sh`) va dans son corps |
```

Puis, après la phrase « Cible globale hors projet `claude-config` … après accord. », ajouter :

```markdown
Un déplacement ou un retrait vise le fichier de la règle citée.
```

- [ ] **Étape 6 : section « Réponse »**

Remplacer la table et la phrase qui la suit par :

```markdown
| # | Leçon (une ligne) | Étiquette | Proposition | Source | Cible | notify |
|---|---|---|---|---|---|---|
| 1 | … | `jugement` | retrait (règle citée deux fois) | `lecons.md:12`, `../x/lecons.md:4` | `CLAUDE.md` | non |

Proposition : règle, garde, déplacement, retrait ou issue. Puis les étiquettes posées ou corrigées
(`lecons.md:7` : sans étiquette → `méca`). Puis, pour chaque ligne, le diff unifié prêt à appliquer, au ton et au
format des lignes voisines ; pour une issue, son titre et son corps. Rien à retenir → « Aucune leçon », avec ce qui
a été lu.
```

- [ ] **Étape 7 : vert**

```bash
git grep -nF '## Trier' -- global/agents/lessons-extractor.md; git grep -nF 'citée deux fois' -- global/agents/lessons-extractor.md
git grep -nF 'garde mécanique' -- global/agents/lessons-extractor.md; git grep -nF 'line_budget_overruns' -- global/agents/lessons-extractor.md
git grep -nF 'qu'"'"'une règle écrite aurait évitée' -- global/agents/lessons-extractor.md
git grep -nE 'budget[^|]*[0-9]{2}' -- global/agents/lessons-extractor.md
bash tests/run.sh rules 2>&1 | grep -v '^PASS'
```

Attendu : sortie pour les quatre premiers greps (`garde mécanique` dans la `description` et la table), aucune pour
les deux suivants (ancienne phrase retirée ; aucun chiffre de budget recopié), aucun échec.

- [ ] **Étape 8 : commit**

```bash
git add global/agents/lessons-extractor.md
git commit -m "📝 lessons-extractor: Tri par étiquette, garde mécanique, récidive qui met la règle en cause

Co-Authored-By: <modèle de l'implémenteur>"
```

### Task 4 : `merge.md` étape 2 renvoie au tri de l'agent

Spec : §2 Portée R2-R4 (ligne `merge.md`). Lot A.

**Files :** Modify `global/skills/pr/merge.md:14-16`. Les lignes 13 (122 colonnes) et 17 (172) ne se réécrivent pas :
le nouveau texte remplace les lignes 14 à 16 et se raccorde au début de la ligne 17 (« pour le skill ou l'agent
global en cause. »).

- [ ] **Étape 1 : rouge**

```bash
git grep -nF '« Trier » et « Récidive »' -- global/skills/pr/merge.md
```

Attendu : aucune sortie.

- [ ] **Étape 2 : remplacer les lignes 14 à 16**

Texte actuel :

```markdown
   `final-review.md` du dossier de suivi, puis ceux des PR précédentes (`<racine>/.superpowers/sdd/*/`) : une friction
   qu'une règle écrite aurait évitée, ou un même type de point vu deux fois, devient une règle proposée pour
   l'`AGENTS.md` ou le `CLAUDE.md` du projet, pour la grille qualité de `feature` s'il vaut pour tous les projets, ou
```

Nouveau texte (chaque ligne ≤ 120 colonnes, à mesurer avant le commit) :

```markdown
   `final-review.md` du dossier de suivi, puis ceux des PR précédentes (`<racine>/.superpowers/sdd/*/`), et trie les
   leçons par étiquette (agent `lessons-extractor`, « Trier » et « Récidive ») : il propose une garde mécanique, une
   règle, ou le déplacement ou le retrait d'une règle qui a récidivé ; un hook ou un script trop gros pour la PR
   devient une issue ou un point du reste à faire, créé par la session après accord comme à l'étape **Issues** de
   `push.md`. Cibles : l'`AGENTS.md`, le `CLAUDE.md` ou les tests du projet, la grille qualité de `feature` pour
   une règle de tous les projets, ou
```

- [ ] **Étape 3 : vert**

```bash
git grep -nF '« Trier » et « Récidive »' -- global/skills/pr/merge.md
git grep -nF 'aurait évitée, ou un même type de point' -- global/skills/pr/merge.md
awk 'NR>=12 && NR<=25 && length > 120 {print NR": "length}' global/skills/pr/merge.md
bash tests/run.sh rules 2>&1 | grep -v '^PASS'
```

Attendu : une ligne pour le premier grep, rien pour le second ; `awk` ne liste que les lignes déjà longues avant la
tâche (12, 13, la ligne de « Ses propositions arrivent », celle de « Si elle a quand même été écrite ») ; aucun échec.

- [ ] **Étape 4 : commit**

```bash
git add global/skills/pr/merge.md
git commit -m "📝 pr merge: L'étape 2 renvoie au tri par étiquette de lessons-extractor

Co-Authored-By: <modèle de l'implémenteur>"
```

### Task 5 : glossaire et reste à faire

Spec : — (doc). Ferme la story P1.

**Files :** Modify `docs/domaine.md` (contexte « Leçons »), `docs/reste-a-faire.md` (Features, point 8).

- [ ] **Étape 1 : rouge**

```bash
git grep -nF '(proposé :' -- docs/domaine.md
```

Attendu : trois lignes (Étiquette, Règle citée, Budget de lignes).

- [ ] **Étape 2 : colonnes « Dans le code » du contexte « Leçons »**

Cellules exemptées de la largeur (tableau) :

- Leçon : `` ligne `- <date> : …` de `lecons.md` `` → `` ligne `- <date> (<action>) [<étiquette>] : …` de `lecons.md` ``
- Étiquette : `— (proposé : marqueur dans la ligne de `lecons.md`)` → `` `[méca]`, `[jugement]`, `[ponctuel]` dans la ligne de `lecons.md` ``
- Règle citée : `— (proposé : citation dans la ligne de `lecons.md`)` → `` `(récidive : <fichier> « <fragment> »)` en fin de ligne de `lecons.md` ``
- Budget de lignes : `— (proposé : `tests/test_rules.sh`)` → `` `line_budget_overruns`, `tests/test_rules.sh` ``
- Proposition, définition : `ou issue pour une garde trop grosse` → `ou issue ou point du reste à faire pour une garde
  trop grosse`

Puis, dans les invariants du contexte, remplacer « le `CLAUDE.md` de `claude-config` ne dépasse pas son budget de
lignes. » par « le `CLAUDE.md` de `claude-config` et `global/CLAUDE.md` ne dépassent pas leur budget de lignes. »
(lignes de 120 colonnes au plus).

- [ ] **Étape 3 : rayer le point 8 de `docs/reste-a-faire.md`**

Entourer le texte du point 8 (du `**Collecte` jusqu'à `(#180)` exclu) de `~~`, comme les points 1, 2 et 5, et
finir par ` Fait : leçons étiquetées, tri et récidive dans `lessons-extractor`, test `line_budget_overruns`.
Hors périmètre (spec) : hook de format des leçons, nettoyage des dossiers de suivi, budget d'un autre projet. (#180)`
en lignes de 120 colonnes au plus.

- [ ] **Étape 4 : vert**

```bash
git grep -nF '(proposé :' -- docs/domaine.md
git grep -nw "proposé" -- . ':!docs/superpowers' | grep -i "lecons\|budget\|étiquette"
bash tests/run.sh rules 2>&1 | grep -v '^PASS'
```

Attendu : aucune sortie pour les deux greps, aucun échec.

- [ ] **Étape 5 : commits**

```bash
git add docs/domaine.md
git commit -m "📝 domaine: Format de la leçon et test du budget dans le contexte Leçons

Co-Authored-By: <modèle de l'implémenteur>"
git add docs/reste-a-faire.md
git commit -m "📝 reste-a-faire: Collecte des leçons faite (#180)

Co-Authored-By: <modèle de l'implémenteur>"
```

## Recette (étape 6)

Agent neuf (`general-purpose`, Sonnet), qui lit `global/agents/lessons-extractor.md` de la branche et l'exécute sur
un vrai dossier de suivi de `<racine>/.superpowers/sdd/` choisi par le contrôleur : au moins quatre leçons sans
étiquette, dont une friction revenue dans une autre PR. Il n'écrit rien. Attendus (critères de la spec) :

La recette tourne aussi sur un dossier de suivi fabriqué dans le scratchpad : aucun `lecons.md` réel n'a encore
d'étiquette ni de citation de récidive, et le `CLAUDE.md` est pile à son budget. Le contrôleur y écrit, au format
R1, une dizaine de leçons qui forcent les scénarios 4, 5 et 6 : un `jugement` dont la règle est citée deux fois
(dans deux `lecons.md` de deux dossiers), un `ponctuel` déjà posé dont la friction revient dans l'autre dossier, un
`méca` pour un hook, et un `jugement` sans règle dont la cible est le `CLAUDE.md` de `claude-config`.

| # | Scénario | Attendu |
|---|---|---|
| 1 | Leçons sans étiquette de la PR | chacune étiquetée dans la réponse, « en le disant » (critères 2, 9) |
| 2 | Leçon `ponctuel` | aucune proposition (critère 2) |
| 3 | Leçon `méca` | une garde (test en diff, ou issue pour un hook ou un script), jamais une phrase (critère 3) |
| 4 | Leçon `jugement` dont la règle existe | mécaniser, déplacer ou retirer ; seulement mécaniser ou retirer si la règle est citée deux fois (critère 4) |
| 5 | Friction revenue dans une autre PR | pas ignorée comme `ponctuel` (critère 8) |
| 6 | Règle proposée pour `CLAUDE.md` de `claude-config` | vient avec la ligne retirée ou déplacée si le budget est atteint (critère 10) |

Les critères 5, 6, 7 et 11 sont prouvés par les tests de la tâche 1. Résultat dans `recette.md` du dossier de suivi.
Recette relancée sur le texte final après les correctifs de review, avant `/pr push`.
