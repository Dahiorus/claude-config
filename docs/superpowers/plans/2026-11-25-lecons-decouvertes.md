# Découvertes dans les leçons Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `lecons.md` capte les découvertes en plus des frictions, et `lessons-extractor` les trie au merge.

**Architecture:** texte de skills et d'un agent seulement. La règle de `lecons.md` (`pr/SKILL.md`, « Dossier de
suivi ») porte la définition ; les étapes qui écrivent les leçons y renvoient et disent « leçons » ; l'extracteur
élargit `jugement` et son but.

**Tech Stack:** Markdown, `git grep`.

**Spec:** `docs/superpowers/specs/2026-11-25-lecons-decouvertes-design.md`

## Découpage en PR

9 fichiers hors spec et plan (`docs/domaine.md` compris) : une seule PR, une seule story (P1).

## Table de traçabilité

| Exigence | Tâche | Preuve |
|---|---|---|
| R1, format `<friction ou découverte>` et exemples | Task 1 | `git grep -nF "<friction ou découverte>" -- global/skills/pr/SKILL.md` : une ligne |
| R2, découverte déjà dite non écrite | Task 1 | `git grep -nF "fichier lu à chaque session" -- global/skills/pr/SKILL.md` : une ligne |
| R3, `jugement` élargi (règle de `lecons.md`) | Task 1 | `git grep -nF "l'évite ou la transmet" -- global/skills/pr/SKILL.md` : une ligne |
| R3, `jugement` élargi (extracteur) | Task 3 | `git grep -nF "peut l'éviter ou la transmettre" -- global/agents/lessons-extractor.md` : une ligne |
| R4, récidive d'une découverte refaite | Task 1 | `git grep -nF "découverte refaite" -- global/skills/pr/SKILL.md` : une ligne |
| R5, particularité de la machine → mémoire | Task 1 | `git grep -nF "propre à la machine" -- global/skills/pr/SKILL.md` : une ligne |
| R6, « leçons » dans les étapes | Task 2 | `git grep -n -i "friction" -- global/skills` : seulement `global/skills/pr/SKILL.md` |
| But de l'extracteur, description, l. 36 et 49 | Task 3 | `git grep -n -i "friction" -- global/agents/lessons-extractor.md` : seulement l. 3 (description), l. 11 (« frictions ni de refaire ») et l. 43 (`méca`) |
| §2, « Nettoyage des branches » déplacé dans `merge.md` | Task 4 | `bash tests/run.sh` : `test_pr_skill_table_matches_files` passe (200 lignes au plus) |
| §2, renvoi de `pr/SKILL.md` au nettoyage (review M1) | correctif de review | `git grep -n "Nettoyage des branches" -- . ':!docs/superpowers'` : `merge.md` (section, renvoi) et `pr/SKILL.md` (renvoi) |
| R2 et R4 sans contradiction (review I3) | correctif de review | `git grep -nF "refaite sans l'avoir trouvée dans une règle écrite" -- global/skills/pr/SKILL.md` : une ligne |
| R5, piège écrit en mémoire tout de suite (review de la PR) | correctif de review | `git grep -nF "l'écrire tout de suite dans la mémoire du projet" -- global/skills/pr/SKILL.md` : une ligne |
| §4 P1, critères nominaux, refus et combinés | Recette (étape 6) | agent neuf, dossier d'essai (voir « Recette ») |
| — glossaire (`docs/domaine.md`, « Leçons ») | fait dans les commits de la spec | `git grep -nF "découverte refaite" -- docs/domaine.md` : une ligne |

Usages vérifiés (étape 1b, `git grep -n -i "friction"` et `git grep -n "lecons.md"` sur tout le dépôt hors
`docs/superpowers`) : `recette.md:39` (« Écrire `recette.md` et `lecons.md` ») reste inchangé, il ne nomme pas le
contenu ; « Récidive » et « Cible » de l'extracteur restent inchangés (R4 réutilise la récidive, R5 ne passe pas par
lui) ; aucun test ne lit `lecons.md` ni « friction » (`git grep -n "lecons\|friction" tests` vide), donc ni
caractérisation ni test cassé.

## Global Constraints

- Texte français : Edit/Write seulement, jamais `sed -i` ni script.
- Prose Markdown ajoutée : 120 colonnes au plus par ligne (`test_branch_respects_rules`).
- Termes du glossaire : « découverte », « leçon », « friction » ; jamais « astuce », « tip », « apprentissage ».
- Commit : `Co-Authored-By: <modèle de l'implémenteur>`, remplacé par le modèle réel.

## Review Focus

- Le paragraphe de `pr/SKILL.md` s'allonge : chaque phrase garde un seul référent (« la », « elle »).
- « Rien → rien » reste la dernière phrase du paragraphe.
- La liste des exemples de découverte est ouverte (« par exemple »).
- `méca` garde sa définition dans les deux fichiers.
- `merge.md:28` : la phrase coupée sur deux lignes se relit entière après le remplacement.

---

## Lot parallélisable : Task 1, Task 2, Task 3

Aucun fichier commun, aucune dépendance.

- Task 1 : `global/skills/pr/SKILL.md`
- Task 2 : `global/skills/feature/SKILL.md`, `global/skills/bugfix/SKILL.md`, `global/skills/pr/comments.md`,
  `global/skills/pr/merge.md`, `global/skills/pr/rebase.md`
- Task 3 : `global/agents/lessons-extractor.md`

### Task 1 : Règle de `lecons.md`

Spec : R1, R2, R3, R4, R5.

**Files:**
- Modify: `global/skills/pr/SKILL.md:54-58`

- [ ] **Step 1 : Rouge**

```bash
git grep -nF -e "<friction ou découverte>" -e "fichier lu à chaque session" -e "l'évite ou la transmet" \
  -e "découverte refaite" -e "propre à la machine" -- global/skills/pr/SKILL.md
```

Attendu : aucune ligne.

- [ ] **Step 2 : Remplacer le paragraphe `lecons.md` par ce texte exact**

```markdown
- `lecons.md` : une ligne `- <date> (<action>) [<étiquette>] : <friction ou découverte>` par friction (correction de
  l'utilisateur, commande refusée, piège, consigne oubliée) ou découverte (savoir acquis en route qui aurait fait
  gagner du temps : par exemple commande trouvée, manière de tester qui a marché, convention du code suivie,
  particularité de l'environnement), action facultative. Pas de découverte que le code, git ou un
  fichier lu à chaque session disent déjà ; une particularité propre à la machine (chemin local, compte, outil
  installé ici seulement) est un piège, que la mémoire garde (`merge.md`, étape 6), pas `lecons.md`. Étiquette :
  `méca` (un programme peut vérifier la leçon), `jugement` (seule une phrase lue l'évite ou la transmet), `ponctuel`
  (cas unique sans retour).
  Règle écrite qui couvrait la friction revenue ou la découverte refaite : finir par `(récidive : <fichier>
  « <fragment d'une ligne> »)`. Ajoutée en fin de session sur la branche (`feature` étape 7, `bugfix` étape 8,
  `push`, `squash`, `recette`, `comments`, `rebase`, `merge` avant l'étape 2, à la fin). Rien → rien.
```

- [ ] **Step 3 : Vert**

La commande du Step 1 rend une ligne par motif (5 lignes au plus, deux motifs pouvant tomber sur la même ligne :
chaque motif présent).

- [ ] **Step 4 : Commit**

```bash
git add global/skills/pr/SKILL.md
git commit -m "📝 pr: Découvertes dans la règle de lecons.md

Co-Authored-By: <modèle de l'implémenteur>"
```

### Task 2 : « Leçons » dans les étapes qui les écrivent

Spec : R6.

**Files:**
- Modify: `global/skills/feature/SKILL.md:28`, `global/skills/bugfix/SKILL.md:36`, `global/skills/pr/comments.md:60`,
  `global/skills/pr/merge.md:28`, `global/skills/pr/merge.md:73`, `global/skills/pr/rebase.md:18`

- [ ] **Step 1 : Rouge**

```bash
git grep -n -i "friction" -- global/skills ':!global/skills/pr/SKILL.md'
```

Attendu : les 6 lignes ci-dessous.

- [ ] **Step 2 : Remplacer, mot pour mot**

| Fichier | Avant | Après |
|---|---|---|
| `feature/SKILL.md:28` | `Enfin, noter les frictions de la session` | `Enfin, noter les leçons de la session` |
| `bugfix/SKILL.md:36` | `frictions de la session dans` | `leçons de la session dans` |
| `pr/comments.md:60` | `frictions dans `lecons.md`` | `leçons dans `lecons.md`` |
| `pr/merge.md:28` | `Les frictions des étapes` | `Les leçons des étapes` |
| `pr/merge.md:73` | `7. Frictions du squash, du merge et du nettoyage dans `lecons.md`, pour les leçons de la PR suivante.` | `7. Leçons du squash, du merge et du nettoyage dans `lecons.md` : la PR suivante les lira.` |
| `pr/rebase.md:18` | `6. Frictions dans` | `6. Leçons dans` |

Ligne de tableau déjà au-delà de 120 colonnes (`feature`, `bugfix`) : remplacer le mot seul, sans réécrire la ligne.

- [ ] **Step 3 : Vert**

La commande du Step 1 ne rend rien.

- [ ] **Step 4 : Commit**

```bash
git add global/skills/feature/SKILL.md global/skills/bugfix/SKILL.md global/skills/pr/comments.md \
  global/skills/pr/merge.md global/skills/pr/rebase.md
git commit -m "📝 pr: Leçons de la session, plus seulement ses frictions

Co-Authored-By: <modèle de l'implémenteur>"
```

### Task 3 : `lessons-extractor` trie aussi les découvertes

Spec : R3, R6 (but et description de l'agent, §2).

**Files:**
- Modify: `global/agents/lessons-extractor.md:3`, `:11`, `:36`, `:43-44`, `:49`

- [ ] **Step 1 : Rouge**

```bash
git grep -n -i "friction" -- global/agents/lessons-extractor.md
```

Attendu : l. 11, 36, 43, 49.

- [ ] **Step 2 : Remplacer, mot pour mot**

| Ligne | Avant | Après |
|---|---|---|
| 3 | `trie les leçons par étiquette` | `trie les leçons (frictions et découvertes) par étiquette` |
| 11 | `buter sur les mêmes frictions :` | `buter sur les mêmes frictions ni refaire les mêmes découvertes :` |
| 36 | `quand la friction en vient` | `quand la leçon en vient` |
| 43-44 | `(seule une phrase lue par la session peut l'éviter)` | `(seule une phrase lue par la session peut l'éviter ou la transmettre)` |
| 49 | `la friction revient dans une autre PR` | `la leçon revient dans une autre PR` |

`méca` (l. 43, « peut vérifier la friction ») ne change pas. Les lignes 11 et 43-44 se recoupent à 120 colonnes : le
reste du paragraphe glisse, sans autre mot changé.

- [ ] **Step 3 : Vert**

La commande du Step 1 rend 3 lignes : la description (l. 3, « frictions et découvertes »), le but (l. 11,
« frictions ni refaire ») et `méca` (l. 43, « vérifier la friction »).

- [ ] **Step 4 : Commit**

```bash
git add global/agents/lessons-extractor.md
git commit -m "📝 pr: lessons-extractor trie aussi les découvertes

Co-Authored-By: <modèle de l'implémenteur>"
```

## Amendement en cours d'exécution

Task 1 porte `pr/SKILL.md` à 206 lignes, au-delà du budget de 200 (`test_pr_skill_table_matches_files`). Décision de
l'utilisateur : déplacer « Nettoyage des branches » dans `merge.md`, seul fichier qui la cite.

### Task 4 : « Nettoyage des branches » dans `merge.md`

Spec : §2 (Portée, « Nettoyage des branches »).

**Files:**
- Modify: `global/skills/pr/SKILL.md` (section « Nettoyage des branches », retirée), `global/skills/pr/merge.md`
  (section ajoutée en fin de fichier, renvoi de l'étape 5)

- [ ] **Step 1 : Rouge** — `bash tests/run.sh` : `test_pr_skill_table_matches_files` échoue (206 lignes).
- [ ] **Step 2 : Déplacer** la section, titre compris, mot pour mot, en fin de `merge.md` ; l'étape 5 de `merge.md`
  devient « section « Nettoyage des branches » ci-dessous ».
- [ ] **Step 3 : Vert** — `wc -l global/skills/pr/SKILL.md` : 200 au plus ;
  `git grep -n "Nettoyage des branches" -- . ':!docs/superpowers'` : la section et le renvoi dans `merge.md`,
  le renvoi de `pr/SKILL.md` (review M1).
- [ ] **Step 4 : Commit** (`📝 pr: Nettoyage des branches lu par merge seul`, `Co-Authored-By: <modèle de l'implémenteur>`).

## Recette (étape 6)

Agent neuf, sur le texte final. Il crée un dossier d'essai jetable sous le scratchpad, avec un `lecons.md` de cinq
lignes : une friction `jugement`, une découverte `jugement` (commande utile), une découverte refaite qui porte
`(récidive : CLAUDE.md « <fragment existant> »)`, une découverte que le code dit déjà, une découverte qu'un script
porterait. Il joue `lessons-extractor` (lecture seule, brief de `merge.md` étape 2) deux fois : d'abord avec le texte
de `origin/main` (`git worktree add` jetable), puis avec le texte final. Attendu sur le texte final : règle proposée
pour la découverte, suite de récidive (déplacer, mécaniser ou retirer) pour la découverte refaite, rien pour celle
que le code dit, `jugement` et une règle pour celle qu'un script porterait. Un second dossier, avec un `lecons.md` de
frictions seules, se trie comme sur `origin/main`.
Puis il écrit, en suivant la règle de `pr/SKILL.md`, les leçons de deux sessions fictives. La première a une friction,
une découverte, un chemin local et une convention lue dans le fichier voisin : deux lignes, sans le chemin local ni la
convention. La seconde n'a ni friction ni découverte : rien n'est écrit.
