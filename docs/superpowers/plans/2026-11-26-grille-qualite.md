# Grille qualité dans son propre fichier — plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal :** la grille qualité quitte `global/skills/feature/SKILL.md` pour `global/grille-qualite.md`
(`~/.claude/grille-qualite.md`), que chaque lecteur cite par son chemin.

**Architecture :** déplacement de texte. Tâche 1 : le fichier neuf, le § de renvoi dans `feature`, le lien
`~/.claude`. Tâche 2 : la garde de test, puis chaque citation réécrite.

**Tech Stack :** Markdown, bash (`tests/run.sh`).

**Spec :** `docs/superpowers/specs/2026-11-26-grille-qualite-design.md`

## Découpage en PR

Fichiers touchés hors tests, spec et plan : 12 (`global/grille-qualite.md`, `feature/SKILL.md`, `bugfix/SKILL.md`,
`pr/SKILL.md`, `pr/review.md`, `pr/merge.md`, 4 agents, `CLAUDE.md`, `docs/domaine.md`). Moins de ~15 : une seule PR,
une seule story (P1).

## Table de traçabilité

| Exigence (§ spec) | Tâche | Test qui la prouve |
|---|---|---|
| R1, § 4 « contient dans l'ordre », « mot pour mot » | 1 | commande de comparaison (Task 1, Step 1) |
| R1, repli des 5 lignes longues | 1 | `test_branch_respects_rules` (`tests/run.sh`) |
| R2, § 4 « le § tient en une phrase » | 1 | `test_quality_grid_cited_by_path` : « grille qualité (ci-dessous) » absent ; Step 4 de Task 1 (`awk` du §) |
| Approches A : lien avant le changement des lecteurs ; § 4 dernier critère | 1 | `bin/claude-config status` (Task 1, Step 5) |
| R3, § 2 (chaque ligne de la table), § 4 « aucune citation ne reste » | 2 | `test_quality_grid_cited_by_path`, motifs de `pr/SKILL.md` l. 28 et de `docs/domaine.md` l. 43 (colonne « Dans le code ») ajoutés en review (I1) ; grep de Task 2, Step 6 |
| § 4 cas combiné (`sdd-final-reviewer` l. 77, `pr/review.md` Angular) | 2 | Step 5 de Task 2 : `grep` de ces deux renvois, inchangés |
| § 5 garde | 2 | `test_quality_grid_cited_by_path`, rouge avant les réécritures |
| — (doc : `docs/domaine.md`, `CLAUDE.md`) | 2 | `test_quality_grid_cited_by_path` + grep des termes retirés (Task 2, Step 6) |

Usages vérifiés (étape 1b) : la garde de Task 2 sort 17 lignes sur la branche avant réécriture (lancée au plan) ;
`pr/SKILL.md` l. 28 et la colonne « Dans le code » de `docs/domaine.md` l. 43 lui échappent, le grep de Task 2
Step 6 les couvre. Inchangés et laissés hors garde : `feature/SKILL.md`
l. 28, 96, 215 (« la grille qualité » sans emplacement), `pr/push.md` l. 42, `frontend-reviewer.md` l. 10,
`docs/reste-a-faire.md` l. 96, `docs/superpowers/**`. Aucun test existant ne lit la grille : rien à caractériser (§ 5).

## Contraintes globales

- Texte Markdown : Edit/Write seulement, jamais `sed -i`, `printf`, `echo`, `fmt` ni script (`CLAUDE.md`).
- Chaque ligne de prose ajoutée ou modifiée tient en 120 colonnes ; une ligne déjà longue qu'on modifie se replie
  (`test_branch_respects_rules`). Tableaux exemptés.
- `bash tests/run.sh` : `timeout: 580000`, sortie lue par `grep -v '^PASS'`, lancé seul dans son appel Bash.
- `git commit` seul dans son appel Bash, fichier par fichier (`git add <fichiers>`), jamais `git add -A`.
- Commits : remplacer `<modèle de l'implémenteur>` par son propre modèle.

## Review Focus

- Ligne déjà longue modifiée (`pr/merge.md` l. 21, `pr/review.md` l. 40-41) : repliée, sinon `tests/run.sh` échoue.
- Repli du bloc déplacé : listes numérotées et indentation Markdown gardées (un `fmt` les casserait).
- `docs/domaine.md` l. 44, colonne « Dans le code » : `global/grille-qualite.md`, plus le § de `feature`.
- `~/.claude/grille-qualite.md` lié avant le commit de Task 2 (sinon toutes les sessions lisent un chemin absent).
- Phrases relues entières après chaque remplacement (« la section » qui précède « « Grille qualité » de »).

---

### Task 1 : Fichier de la grille et § de renvoi

Spec : R1, R2, Approches (A), § 4 critères 1 à 3 et 6.

**Files :**
- Create : `global/grille-qualite.md`
- Modify : `global/skills/feature/SKILL.md:22,24,266-355`

**Interfaces :**
- Produces : `global/grille-qualite.md`, lu en `~/.claude/grille-qualite.md` ; titre `# Grille qualité` ; corps =
  ancien § à partir de la ligne 5.

- [ ] **Step 1 : rouge**

```bash
cd /home/bung@france.groupe.intra/IdeaProjects/claude-config
diff <(git show daffb68:global/skills/feature/SKILL.md | sed -n '268,355p' \
  | sed 's/comme tout écart, étape 4)/comme tout écart, `feature` étape 4)/' | tr -s ' \n' ' ') \
  <(tail -n +5 global/grille-qualite.md | tr -s ' \n' ' ') && echo IDENTIQUE
```

Attendu : `tail: impossible d'ouvrir 'global/grille-qualite.md'`, pas de `IDENTIQUE`.

- [ ] **Step 2 : créer `global/grille-qualite.md`** (Write)

Lignes 1 à 4, exactes :

```markdown
# Grille qualité

Lue au plan, à l'implémentation et en review (`feature`, `bugfix`, `pr`), faute de grille du projet.

```

Puis les lignes 268 à 355 de `global/skills/feature/SKILL.md`, recopiées. Deux retouches seulement :
- point 5 : « comme tout écart, étape 4) » → « comme tout écart, `feature` étape 4) » ;
- les lignes de plus de 120 colonnes (l. 292, 296, 310, 318, 331 de l'ancien fichier, après la retouche ci-dessus
  pour la l. 293 si elle déborde) se replient au dernier espace avant la colonne 120, la suite passant à la ligne
  suivante avec la même indentation que sa ligne (5 espaces dans la liste numérotée, 2 dans les puces) ; aucun mot
  changé.

- [ ] **Step 3 : remplacer le § dans `global/skills/feature/SKILL.md`** (Edit)

Les lignes 266 à 355 deviennent :

```markdown
## Grille qualité (plan, implémentation, review Opus)

Grille du projet (WORKFLOW.md, ou un AGENTS.md qui en tient une complète) si elle existe, sinon
`~/.claude/grille-qualite.md`, adaptée au langage et amendée par les conventions de l'`AGENTS.md` du projet.
```

Ligne 22 (étape 2) : « Le code du plan respecte la grille qualité (ci-dessous). » → « Le code du plan respecte la
grille qualité (`~/.claude/grille-qualite.md`). » (ligne de tableau : pas de repli).

Ligne 24 (étape 4) : « (section « Grille qualité » de `~/.claude/skills/feature/SKILL.md`, ou grille du projet) » →
« (`~/.claude/grille-qualite.md`, ou grille du projet) ».

- [ ] **Step 4 : vert**

Relancer la commande du Step 1. Attendu : `IDENTIQUE`, sortie de `diff` vide. Puis :

```bash
awk '/^## Grille qualité/{f=1;next} /^## /{f=0} f && NF' global/skills/feature/SKILL.md | wc -l
```

Attendu : `2` (une phrase sur deux lignes). Puis `bash tests/run.sh` (appel seul), lu par `grep -v '^PASS'` :
aucun `FAIL`.

- [ ] **Step 5 : lien (contrôleur, dépôt principal)**

```bash
bin/claude-config install
```

Puis :

```bash
bin/claude-config status | grep grille-qualite
```

Attendu : `ok        grille-qualite.md`. À faire avant de lancer Task 2.

- [ ] **Step 6 : commit**

```bash
git add global/grille-qualite.md global/skills/feature/SKILL.md
git commit -m "♻️ grille: Grille qualité sortie de feature dans global/grille-qualite.md

Co-Authored-By: <modèle de l'implémenteur>"
```

### Task 2 : Garde et citations par le chemin

Spec : R3, § 2, § 4 critères 4 et 5, § 5. Tâche de doc (`docs/domaine.md`, `CLAUDE.md`) comprise.

**Files :**
- Test : `tests/test_skills.sh` (fonction ajoutée en fin de fichier ; aucun nom `test_quality*` n'y existe)
- Modify : `global/skills/bugfix/SKILL.md:36`, `global/skills/pr/SKILL.md:28`, `global/skills/pr/review.md:41`,
  `global/skills/pr/merge.md:19-22`, `global/agents/sdd-implementer.md:15-16`,
  `global/agents/sdd-final-reviewer.md:42`, `global/agents/pr-reviewer.md:31-32`,
  `global/agents/lessons-extractor.md:35-36,94`, `CLAUDE.md:60`,
  `docs/domaine.md:37,43,44,102,117`

**Interfaces :**
- Consumes : `global/grille-qualite.md` (Task 1), lien `~/.claude/grille-qualite.md`.

- [ ] **Step 1 : écrire la garde**

`tests/test_skills.sh`, en fin de fichier :

```bash
test_quality_grid_cited_by_path() {
  local hits
  [[ -f "$REPO_SRC/global/grille-qualite.md" ]] || fail "global/grille-qualite.md absent"
  # shellcheck disable=SC2016 # les accents graves sont ceux du Markdown
  hits="$(grep -rnE -e '« Grille qualité » de' -e 'grille (qualité )?de `feature`' -e 'grille qualité du skill' \
    -e 'grille qualité \(ci-dessous\)' "$REPO_SRC/global" "$REPO_SRC/CLAUDE.md" "$REPO_SRC/docs/domaine.md")" \
    || [[ $? -eq 1 ]] || fail "grep en erreur"
  assert_eq "$hits" "" "grille qualité citée par l'ancien emplacement"
}
```

- [ ] **Step 2 : rouge**

`bash tests/run.sh` (appel seul), lu par `grep -v '^PASS'`. Attendu : `test_quality_grid_cited_by_path` en échec,
15 lignes citées (les 17 moins `feature/SKILL.md` l. 22 et l. 24, réglées en Task 1).

- [ ] **Step 3 : réécrire les citations** (Edit ; chaque phrase relue entière, prose ≤ 120 colonnes)

| Fichier | Avant | Après |
|---|---|---|
| `bugfix/SKILL.md` l. 36 | « grille qualité du skill `feature` » | « grille qualité `~/.claude/grille-qualite.md` » |
| `pr/SKILL.md` l. 28 | « `feature` reste la référence pour le tri des retours et la grille qualité. » | « `feature` reste la référence pour le tri des retours ; la grille qualité est `~/.claude/grille-qualite.md`. » |
| `pr/review.md` l. 41 | « sinon la section « Grille qualité » de `~/.claude/skills/feature/SKILL.md`, amendée » | « sinon `~/.claude/grille-qualite.md`, amendée » |
| `pr/merge.md` l. 19 | « la grille qualité de `feature` pour » | « la grille qualité (`~/.claude/grille-qualite.md`) pour » |
| `pr/merge.md` l. 21-22 | « Une règle pour un skill global (grille de `feature`, skills `pr`…) » | « Une règle globale (grille qualité, skills `pr`…) » |
| `sdd-implementer.md` l. 15-16 (un seul Edit) | « sinon la section « Grille qualité » de `~/.claude/skills/feature/SKILL.md`, amendée » | « sinon `~/.claude/grille-qualite.md`, amendée » |
| `sdd-final-reviewer.md` l. 42 | « sinon la section « Grille qualité » de `~/.claude/skills/feature/SKILL.md`, amendée » | « sinon `~/.claude/grille-qualite.md`, amendée » |
| `pr-reviewer.md` l. 31-32 | « sinon la section « Grille qualité » de `~/.claude/skills/feature/SKILL.md`, amendée » | « sinon `~/.claude/grille-qualite.md`, amendée » |
| `lessons-extractor.md` l. 35-36 (un seul Edit) | « section « Grille qualité » de `~/.claude/skills/feature/SKILL.md`, » | « grille qualité `~/.claude/grille-qualite.md`, » |
| `lessons-extractor.md` l. 94 | « grille qualité de `feature` » | « grille qualité (`~/.claude/grille-qualite.md`) » |
| `CLAUDE.md` l. 60 | « la grille de `feature` » | « la grille qualité » |
| `docs/domaine.md` l. 37 | « grille qualité de `feature` (en aval, recopiée dans le brief faute de grille du projet) » | « grille qualité `~/.claude/grille-qualite.md` (en aval, lue par l'agent faute de grille du projet) » |
| `docs/domaine.md` l. 43, définition | « sinon la grille qualité de `feature` amendée » | « sinon la grille qualité amendée » (le chemin est l. 44) |
| `docs/domaine.md` l. 43, colonne « Dans le code » | « § « Grille qualité » » | « `global/grille-qualite.md` » |
| `docs/domaine.md` l. 44, colonne « Dans le code » | « § « Grille qualité » de `global/skills/feature/SKILL.md` » | « `global/grille-qualite.md` (`~/.claude/grille-qualite.md`) » |
| `docs/domaine.md` l. 102 et l. 117 | « grille qualité de `feature` » | « grille qualité (`global/grille-qualite.md`) » |

- [ ] **Step 4 : vert**

`bash tests/run.sh` (appel seul), lu par `grep -v '^PASS'` : aucun `FAIL`.

- [ ] **Step 5 : cas combiné**

```bash
grep -n "relance (\`feature\`, « Exécution »)" global/agents/sdd-final-reviewer.md
grep -n -A1 "skill \`angular-developer\` aussi, comme$" global/skills/pr/review.md
```

Attendu : une ligne pour `sdd-final-reviewer.md` ; pour `review.md`, la ligne Angular suivie de « dans `feature`. »
(renvois à `feature` hors grille, intacts).

- [ ] **Step 6 : grep des termes retirés**

```bash
git grep -nF -e 'Grille qualité » de' -e 'grille de `feature`' -e 'grille qualité de `feature`' \
  -e 'grille qualité du skill' -e 'tri des retours et la grille qualité' -e '§ « Grille qualité » |' \
  -- . ':!docs/superpowers' ':!docs/reste-a-faire.md'
git grep -nF -e 'Grille qualité » de' -e 'grille de `feature`' -e 'grille qualité de `feature`' \
  -- docs/superpowers/specs/2026-11-26-grille-qualite-design.md docs/superpowers/plans/2026-11-26-grille-qualite.md
```

Attendu : vide pour le premier ; le second ne sort que les citations de la spec et du plan qui décrivent l'ancien
texte (colonnes « Avant », § 2).

- [ ] **Step 7 : commit**

```bash
git add tests/test_skills.sh global/skills/bugfix/SKILL.md global/skills/pr/SKILL.md global/skills/pr/review.md \
  global/skills/pr/merge.md global/agents/sdd-implementer.md global/agents/sdd-final-reviewer.md \
  global/agents/pr-reviewer.md global/agents/lessons-extractor.md CLAUDE.md docs/domaine.md
git commit -m "♻️ grille: Grille qualité citée par ~/.claude/grille-qualite.md

Co-Authored-By: <modèle de l'implémenteur>"
```
