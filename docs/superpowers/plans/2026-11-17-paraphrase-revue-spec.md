# Paraphrase en tête de `ddd revue spec` : plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal :** la revue `ddd` d'une spec rend d'abord une paraphrase en deux parties, que `feature` compare à
l'intention avant Plannotator.

**Architecture :** deux modifications de texte de skill, sans script : le § `revue` de `global/skills/ddd/SKILL.md`
(R1 à R4, R6) et le § « Validation fonctionnelle » de `global/skills/feature/SKILL.md` (R5).

**Tech Stack :** Markdown (skills Claude Code).

**Spec :** `docs/superpowers/specs/2026-11-17-paraphrase-revue-spec-design.md`

## Découpage en PR

Une seule PR : 2 fichiers touchés hors spec et plan (plus `docs/reste-a-faire.md` à l'étape 5).

## Contraintes globales

- Lignes de 120 colonnes au plus dans tout Markdown ajouté ou réécrit (`CLAUDE.md` du dépôt).
- Édition par Edit/Write uniquement, jamais `sed -i`, `python3 -c`, `printf` ni `echo` (`CLAUDE.md` du dépôt).
- Mêmes mots dans les deux skills : « paraphrase », « Ce que la spec propose », « L'existant selon la spec ».
- Commit par fichier (`git add <fichier>`), jamais `git add -A` : une autre session peut toucher `global/skills/*`.
- Pas de test automatique des skills : le « test » d'une tâche est un `git grep` qui échoue avant le texte (rouge) et
  réussit après (vert). `bash tests/run.sh` (timeout 580000) reste vert, non touché.

## Traçabilité

| Exigence (spec) | Tâche | Preuve |
|---|---|---|
| R1 deux parties, 2 à 5 phrases | Task 1 | grep « Ce que la spec propose », « L'existant selon la spec » |
| R1 existant regroupé par comportement | Task 1 | grep « regroupés par comportement » dans `ddd` |
| R2 avant le code ; passage non enchaîné | Task 1 | grep « avant de lire le code », « ne parvient pas à enchaîner » |
| R2 sources : § « But », règles, Portée, glossaire | Task 1 | grep « le § « But » » dans `ddd` |
| R2 spec sans § « But » : règles, sinon « à trancher » | review PR #135 | grep « Sans § « But » » dans `ddd` |
| R3 paraphrase en tête, même sans écart | Task 1 | grep « paraphrase puis « rien à signaler » » dans `ddd` |
| R4 existant paraphrasé vérifié dans le code | Task 1 | grep « la paraphrase de l'existant comprise » dans `ddd` |
| R5 `feature` compare avant Plannotator | Task 2 | grep « compare d'abord la paraphrase » dans `feature` |
| R5 revue non relancée après réécriture | Task 2 | grep « La revue n'est pas relancée après cette réécriture » |
| R6 pas de paraphrase pour un plan | Task 1 | grep « Un plan n'a pas de paraphrase » dans `ddd` |
| §4 critère nominal, sur une vraie spec | Étape 5 de `feature` | `ddd revue spec` lancé sur la spec de cette feature |
| §2 reste à faire, point 1 rayé | Étape 5 de `feature` | `docs/reste-a-faire.md` |
| R1 plafond de 5 phrases (Convergence 1) | Task 3 | grep « Pas plus de 5 phrases par partie » |
| R1 décompte des phrases (Convergence 2) | Task 5 | grep « compter les phrases » ; recette 3 |
| R5 référent de « Ses « à corriger » » (Convergence 1) | Task 4 | grep « sans l'avis de l'auteur. Ses » |

Usages vérifiés à l'étape 1b
(`git grep -n "ddd revue\|revue spec\|Validation fonctionnelle" -- . ':!docs/superpowers'`) :
`feature/SKILL.md` l. 20, 131, 282 et `docs/reste-a-faire.md`. L. 20 et 282 restent inchangées (spec §2) ;
`bugfix` n'appelle pas `ddd revue`.

Pas de tâche de doc : aucun terme n'est retiré ni renommé, `CLAUDE.md` et `docs/domaine.md` ne décrivent pas la
revue (spec §2). Les tâches 1 et 2 n'ont aucun fichier commun mais tiennent en quelques lignes : exécutées l'une après
l'autre, sans lot parallélisable.

---

### Task 1 : paraphrase dans le § `revue` de `ddd`

Spec : R1, R2, R3, R4, R6.

**Files :**
- Modify : `global/skills/ddd/SKILL.md:56-76`

- [ ] **Step 1 : constater le rouge**

```bash
git grep -c "Ce que la spec propose" -- global/skills/ddd/SKILL.md
```

Attendu : aucune sortie, code de retour 1.

- [ ] **Step 2 : insérer le paragraphe de la paraphrase**

Entre « Ne pas recevoir l'avis de celui qui a écrit le document. » et « Dérouler chaque parcours du besoin dans le
document et relever : », insérer, puis remplacer « Dérouler chaque parcours » par « Puis dérouler chaque parcours » :

```markdown
**Spec : d'abord la paraphrase.** À partir des règles et de la Portée de la spec, sans reprendre son § « Demande
initiale » (l'auteur la compare à ce §), et du glossaire, avant de lire le code (sinon la revue comble les trous de
la spec sans les voir), écrire deux parties de 2 à 5 phrases chacune, avec les mots du glossaire :
- **Ce que la spec propose** : le changement, pour qui, et pourquoi ;
- **L'existant selon la spec** : comment marche aujourd'hui ce que la spec change, tel que la spec le décrit (son
  but, et ce que devient chaque endroit de sa « Portée ») ; si elle n'en dit rien, « la spec ne décrit pas
  l'existant ».

Un passage que la revue ne parvient pas à enchaîner au reste (deux parties qui ne se relient pas, une étape
manquante entre deux règles) est un écart, trié comme les autres : « à corriger » si une seule réécriture s'impose,
« à trancher » sinon. Un plan n'a pas de paraphrase : il est relu contre une spec déjà approuvée.
```

Décision de relecture du plan : la paraphrase ne reprend pas le § « Demande initiale » (spec, R2 amendée).

- [ ] **Step 3 : vérification et rapport**

Remplacer « Chaque point est vérifié dans le code, puis rendu trié : » par :

```markdown
Chaque point est vérifié dans le code, la paraphrase de l'existant comprise, puis rendu trié. La paraphrase reste
telle que la spec la fait comprendre : un existant que le code contredit est un écart, pas une correction de la
paraphrase.
```

Remplacer « Rien à signaler : le dire en une ligne. Le document lui-même n'est pas modifié : l'appelant applique. »
par :

```markdown
Rapport : la paraphrase en tête pour une spec, puis les trois catégories. Rien à signaler : pour une spec, la
paraphrase puis « rien à signaler » en une ligne ; pour un plan, « rien à signaler » en une ligne. Le document
lui-même n'est pas modifié : l'appelant applique.
```

- [ ] **Step 4 : constater le vert**

```bash
f=global/skills/ddd/SKILL.md
for m in "Ce que la spec propose" "L'existant selon la spec" "avant de lire le code" \
  "ne parvient pas à enchaîner" "paraphrase puis « rien à signaler »" "la paraphrase de l'existant comprise" \
  "Un plan n'a pas de paraphrase" "sans reprendre son § « Demande"; do
  git grep -q -F "$m" -- "$f" || echo "ABSENT: $m"; done
git diff -U0 -- "$f" | grep '^+[^+]' | awk 'length>121'
```

Attendu : aucune sortie. Le contrôle de largeur ne porte que sur les lignes ajoutées (121 : le `+` compte) ; le
fichier a déjà des lignes trop longues (l. 3, 26, 39, 65-67, 70), hors de cette tâche.

- [ ] **Step 5 : commit**

```bash
git add global/skills/ddd/SKILL.md
git commit -m "✨ ddd: Start revue spec with a paraphrase of the spec

Co-Authored-By: <modèle de l'implémenteur> <noreply@anthropic.com>"
```

### Task 2 : comparaison de la paraphrase dans `feature`

Spec : R5.

**Files :**
- Modify : `global/skills/feature/SKILL.md:131-134` (§ « Validation fonctionnelle »)

- [ ] **Step 1 : constater le rouge**

```bash
git grep -c "compare d'abord la paraphrase" -- global/skills/feature/SKILL.md
```

Attendu : aucune sortie, code de retour 1.

- [ ] **Step 2 : ajouter la comparaison**

Après « sans l'avis de l'auteur. » et avant « Ses « à corriger » s'appliquent avant l'ouverture », insérer :

```markdown
Pour une spec, l'auteur compare d'abord la paraphrase qui ouvre le rapport (« Ce que la spec propose »,
« L'existant selon la spec ») au § « Demande initiale » et à son intention : un écart dû à une formulation fait
réécrire le passage qui a égaré la revue, comme un « à corriger » ; un comportement que la spec n'a pas tranché
devient un bloc `:::question` à l'endroit qu'il touche. La revue n'est pas relancée après cette réécriture. La
paraphrase ne s'ouvre pas dans Plannotator.
```

Rejustifier le paragraphe à 120 colonnes, y compris la ligne 132 existante qui les dépasse déjà. Choisir les coupures
pour que chaque motif du Step 3 tienne sur une ligne.

- [ ] **Step 3 : constater le vert**

```bash
f=global/skills/feature/SKILL.md
for m in "compare d'abord la paraphrase" "Ce que la spec propose" "ne s'ouvre pas dans Plannotator" \
  "La revue n'est pas relancée après cette réécriture"; do git grep -q -F "$m" -- "$f" || echo "ABSENT: $m"; done
sed -n '/^\*\*Validation fonctionnelle\*\*/,/^$/p' "$f" | awk 'length>120'
```

Attendu : aucune sortie.

- [ ] **Step 4 : commit**

```bash
git add global/skills/feature/SKILL.md
git commit -m "✨ feature: Compare the ddd paraphrase to the intent before Plannotator

Co-Authored-By: <modèle de l'implémenteur> <noreply@anthropic.com>"
```

## Convergence 1

Recette du critère nominal (§4) : une `ddd revue spec` réelle sur la spec rend 7 et 6 phrases ; « Ses « à corriger » »
suit désormais une phrase sur la paraphrase (référent ambigu).

### Task 3 : plafond impératif de la paraphrase dans `ddd`

Spec : R1, §4 critère nominal (« 2 à 5 phrases chacune »).

**Files :**
- Modify : `global/skills/ddd/SKILL.md` (paragraphe « Spec : d'abord la paraphrase »)

- [ ] **Step 1 : constater le rouge**

```bash
git grep -c "Pas plus de 5 phrases" -- global/skills/ddd/SKILL.md
```

Attendu : aucune sortie, code de retour 1.

- [ ] **Step 2 : ajouter le plafond**

Après la puce « **L'existant selon la spec** : … « la spec ne décrit pas l'existant ». », et avant la ligne vide,
ajouter la ligne :

```markdown
Pas plus de 5 phrases par partie : un détail de plus va dans les écarts, pas dans la paraphrase.
```

- [ ] **Step 3 : constater le vert**

```bash
f=global/skills/ddd/SKILL.md
git grep -q -F "Pas plus de 5 phrases par partie" -- "$f" || echo ABSENT
git diff -U0 -- "$f" | grep '^+[^+]' | awk 'length>121'
```

Attendu : aucune sortie.

- [ ] **Step 4 : commit**

```bash
git add global/skills/ddd/SKILL.md
git commit -m "📝 ddd: Cap each paraphrase part at five sentences

Co-Authored-By: <modèle de l'implémenteur> <noreply@anthropic.com>"
```

### Task 4 : référent de « Ses « à corriger » » dans `feature`

Spec : R5.

**Files :**
- Modify : `global/skills/feature/SKILL.md` (§ « Validation fonctionnelle »)

- [ ] **Step 1 : constater le rouge**

```bash
git grep -c -F "ne s'ouvre pas dans Plannotator. Ses" -- global/skills/feature/SKILL.md
```

Attendu : `1` (le défaut est présent).

- [ ] **Step 2 : remettre les phrases sur la revue avant celles sur la paraphrase**

Déplacer les deux phrases « Ses « à corriger » s'appliquent avant l'ouverture, ses « à trancher » deviennent des
blocs `:::question` à l'endroit qu'ils touchent. Les réouvertures suivantes ne le relancent pas, sauf si les
annotations changent le comportement ou la portée. » juste après « sans l'avis de l'auteur. », avant « Pour une
spec, l'auteur compare d'abord la paraphrase ». Aucun mot ne change ; le paragraphe finit par « La paraphrase ne
s'ouvre pas dans Plannotator. ». Rejustifier à 120 colonnes, chaque motif du Step 3 sur une ligne.

- [ ] **Step 3 : constater le vert**

```bash
f=global/skills/feature/SKILL.md
git grep -q -F "ne s'ouvre pas dans Plannotator. Ses" -- "$f" && echo PRESENT
for m in "compare d'abord la paraphrase" "Ce que la spec propose" "ne s'ouvre pas dans Plannotator" \
  "La revue n'est pas relancée après cette réécriture" "sans l'avis de l'auteur. Ses"; do
  git grep -q -F "$m" -- "$f" || echo "ABSENT: $m"; done
sed -n '/^\*\*Validation fonctionnelle\*\*/,/^$/p' "$f" | awk 'length>120'
```

Attendu : aucune sortie.

- [ ] **Step 4 : commit**

```bash
git add global/skills/feature/SKILL.md
git commit -m "📝 feature: Keep the ddd review rules before the paraphrase comparison

Co-Authored-By: <modèle de l'implémenteur> <noreply@anthropic.com>"
```

## Convergence 2

Recette 2 : « Ce que la spec propose » rend encore 6 phrases malgré la Task 3.

### Task 5 : compter les phrases avant de rendre la paraphrase

Spec : R1, §4 critère nominal.

**Files :**
- Modify : `global/skills/ddd/SKILL.md` (ligne « Pas plus de 5 phrases par partie »)

- [ ] **Step 1 : constater le rouge**

```bash
git grep -c "compter les phrases" -- global/skills/ddd/SKILL.md
```

Attendu : aucune sortie, code de retour 1.

- [ ] **Step 2 : remplacer la ligne du plafond**

Remplacer « Pas plus de 5 phrases par partie : un détail de plus va dans les écarts, pas dans la paraphrase. » par :

```markdown
Pas plus de 5 phrases par partie : avant de rendre, compter les phrases (un point final = une phrase) ; au-delà,
fusionner ou couper.
```

- [ ] **Step 3 : constater le vert**

```bash
f=global/skills/ddd/SKILL.md
for m in "Pas plus de 5 phrases par partie" "compter les phrases" "un point final = une phrase"; do
  git grep -q -F "$m" -- "$f" || echo "ABSENT: $m"; done
git diff -U0 -- "$f" | grep '^+[^+]' | awk 'length>121'
```

Attendu : aucune sortie.

- [ ] **Step 4 : commit**

```bash
git add global/skills/ddd/SKILL.md
git commit -m "📝 ddd: Count the paraphrase sentences before returning it

Co-Authored-By: <modèle de l'implémenteur> <noreply@anthropic.com>"
```
