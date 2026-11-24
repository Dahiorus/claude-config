# Contrôle non lancé : plan d'implémentation

> **Pour les agents :** sous-skill requis : `superpowers:subagent-driven-development`. Étapes en cases à cocher.

**But :** un contrôle sans verdict est relancé une fois, puis écrit « non lancé », jamais « aucun défaut ».

**Architecture :** deux textes changent : un paragraphe ajouté à « Exécution » de `global/skills/feature/SKILL.md`
(R1, R2, R3) et un paragraphe de `global/skills/bugfix/SKILL.md` qui y renvoie. Aucun script, aucun agent modifié :
l'absence de verdict se constate chez le contrôleur.

**Pile :** Markdown lu par des agents ; `tests/run.sh` (shellcheck, 120 colonnes de prose).

**Spec :** `docs/superpowers/specs/2026-11-24-relecteur-non-lance-design.md`

## Découpage en PR

Une seule PR : 2 fichiers touchés hors tests, spec et plan (`docs/domaine.md` est déjà commité avec la spec ;
`docs/reste-a-faire.md` se met à jour à l'étape 5 du cycle). La review M2 en ajoute 4 : la ligne `Verdict :` de
`ddd` et de trois agents.

## Contraintes globales

- Texte français, édité par Edit, jamais `sed -i` ni `printf` ; prose ajoutée ≤ 120 colonnes
  (`test_branch_respects_rules`) ; une ligne existante plus longue ne se réécrit pas, on écrit dessous.
- Le skill ne recopie pas la liste des reviews : il écrit « chaque review lancée à l'étape 7 » (spec, R1).
- Termes du glossaire : « non lancé », « verdict » ; jamais « aucun défaut », « rien à signaler » pour un contrôle
  sans verdict (`docs/domaine.md`, « Contrôle non lancé »).
- Commits : `Co-Authored-By: <modèle de l'implémenteur>`, remplacé par le modèle réel.

## Review Focus

- `code-review` ou `security-review` qui rend une liste vide : c'est un verdict, pas un « non lancé » (pas de ligne
  de verdict, seuls erreur, délai et réponse vide comptent) ; Task 1, grep `seuls l'erreur`.
- Une seule review sur deux sans verdict : le tri des autres points part sans l'attendre ; Task 1, grep `compte comme
  rendue` ; recette, cas Opus.
- `pr-risk` sans verdict dans `bugfix` : Opus part même sur un petit correctif ; Task 2, grep `donc Opus part`.
- Relance d'un `Agent` : seule dans son message, comme tout appel `Agent` (« Exécution », déjà écrit plus haut).

## Traçabilité

| Exigence (§ spec) | Tâche | Preuve |
|---|---|---|
| R1 : contrôles visés, sans liste de reviews, `pr-risk` compris | 1 | grep `chaque review lancée à l'étape 7, \`pr-risk\` compris` |
| R1 : définition de « sans verdict », cas `code-review` / `security-review` | 1 | grep `seuls l'erreur, le délai et la réponse vide` |
| R1 : relance une fois, même brief, même modèle | 1 | grep `est relancé une fois` |
| R2 : « non lancé » et cause, jamais un verdict (liste commune, review I1) | 1, 2 | grep `jamais un verdict (« aucun défaut »` dans `feature` et `bugfix` ; recette |
| R2 : validation fonctionnelle, message du contrôleur avant Plannotator, compte comme revenu | 1 | grep `dans le message du contrôleur avant Plannotator`, `compte comme revenu` ; recette, cas YAGNI |
| R2 : contrôle de tâche dans `progress.md`, arrêt | 1 | grep `Contrôle de tâche : dans \`progress.md\`` |
| R2 : convergence dans `convergence-N.md`, arrêt | 1 | grep `Convergence : dans \`convergence-N.md\`` |
| R2 : review en « à trancher » `N1…` de `final-review.md`, compte comme rendue | 1 | grep `« à trancher » numéroté` ; recette, cas Opus |
| R2 : « corrige N1 » relance la review | 1 | grep `« corrige N1 » relance cette review` |
| R2 : review coupée deux fois, points déjà lus recopiés « à vérifier » (recette 2) | recette | grep `garde les points déjà lus` dans `feature` |
| R3 : `pr-risk` « non lancé » vaut Moyen ; dangers inconnus nommés (question ci-dessous) | 1 | grep `vaut le niveau Moyen`, `` `security-review` ne part pas `` ; recette, cas `pr-risk` |
| R3 dans `bugfix` (Opus part) ; renvoi de `bugfix` à « Exécution » | 2 | grep `donc Opus part` dans `bugfix` |
| § 2 : ligne `Verdict :` des 4 contrôles sans ligne de verdict (review M2) | review | grep `` `Verdict : `` dans `ddd/SKILL.md`, `spec-yagni-checker.md`, `sdd-final-reviewer.md`, `frontend-reviewer.md` |
| § 4, critères d'acceptation | 1, 2 | recette (étape 6) : agent neuf sur le texte final |
| Portée : `docs/domaine.md` | — (commit a14b953) | grep `Contrôle non lancé` dans `docs/domaine.md` |

Usages vérifiés à l'étape 1b, inchangés :

| Usage | Ce qu'il devient | Ce qui le fige |
|---|---|---|
| `feature` « Dosage des reviews » : « Le tri attend toutes les reviews lancées », numérotation `R/S/F` | Inchangé : le paragraphe ajouté dit qu'une review « non lancée » compte comme rendue et ajoute `N1…` | grep de la ligne existante, inchangée dans le diff |
| `feature` « Dosage » : « `code-review` et `security-review` partent dès le verdict rendu » | Inchangé : R3 donne un niveau quand `pr-risk` n'a pas de verdict | idem |
| `feature` étape 5b (« toujours pas convergé après 3 tours ») | Inchangé, cité par R2 | idem |
| `feature` « Validation fonctionnelle » (« aucun écart ne s'applique avant le retour des deux ») | Inchangé, R2 dit qu'un « non lancé » compte comme revenu | idem |
| `pr/push.md` l. 35-36 (points non retenus de `final-review.md`) | Inchangé : un point `N…` non retenu en est un | idem |
| `lessons-extractor` (lit `final-review.md`) | Inchangé : un point `N…` est un point comme un autre | idem |

---

### Task 1 : Paragraphe « non lancé » dans « Exécution » de `feature`

§ spec : R1, R2, R3, § 4.

**Fichiers :**
- Modifier : `global/skills/feature/SKILL.md`, § « Exécution », après la ligne
  « `spec-yagni-checker` obéit aux mêmes interdits et rend aussi son rapport dans sa réponse. » (l. 180)

- [ ] **Étape 1 : rouge**

```bash
git grep -nF 'non lancé' -- global/skills/feature/SKILL.md
```

Attendu : aucune sortie, code 1.

- [ ] **Étape 2 : insérer le texte suivant, tel quel, sur ses propres lignes, juste après la ligne citée**

```markdown
Un contrôle sans verdict (erreur, délai, réponse vide ou coupée, sans la ligne de verdict que son agent ou son skill
définit ; pour `code-review` et `security-review`, sans ligne de verdict, seuls l'erreur, le délai et la réponse vide
comptent) est relancé une fois, par un nouvel appel `Agent` ou `Skill` avec le même brief et le même modèle.
Contrôles visés : `ddd revue` (spec et plan), `spec-yagni-checker`, `sdd-task-reviewer`, `convergence-checker`, et
chaque review lancée à l'étape 7, `pr-risk` compris.
Toujours sans verdict, le contrôle est « non lancé » : le contrôleur l'écrit avec la cause vue là où le verdict
serait allé, jamais un verdict (« aucun défaut », « aucun point », « rien à signaler », « conforme », « convergé »…).
Validation fonctionnelle : dans le message du contrôleur avant Plannotator, et le contrôle compte comme revenu.
Contrôle de tâche : dans `progress.md`, face à la tâche, puis s'arrêter et rapporter.
Convergence : dans `convergence-N.md`, puis s'arrêter et rapporter, comme sans convergence après 3 tours.
Review : dans son rapport et en tête de `final-review.md`, en « à trancher » numéroté `N1…` (relancer plus tard,
recommandé, ou livrer sans cet angle) ; « corrige N1 » relance cette review, et elle compte comme rendue pour le tri.
Un `pr-risk` « non lancé » vaut le niveau Moyen pour le dosage des reviews : le risque n'est jamais supposé faible
sans preuve. Ses dangers restent inconnus : sa ligne `N…` dit que `security-review` ne part pas faute de danger cité.
```

Décisions de relecture du plan (spec amendée, R2 et R3) : la relance d'un `N…` est recommandée, donc « corrige
tout » la relance ; la ligne `N…` de `pr-risk` dit que `security-review` ne part pas, le dosage ne change pas.

- [ ] **Étape 3 : vert**

```bash
for f in 'seuls l'\''erreur, le délai et la réponse vide' 'est relancé une fois' \
  'chaque review lancée à l'\''étape 7, `pr-risk` compris' 'jamais un verdict (« aucun défaut »' 'compte comme revenu' \
  'Contrôle de tâche : dans `progress.md`' 'Convergence : dans `convergence-N.md`' '« à trancher » numéroté' \
  'vaut le niveau Moyen' '« corrige N1 » relance cette review' 'dans le message du contrôleur avant Plannotator' \
  '`security-review` ne part pas'; do
  git grep -qF -e "$f" -- global/skills/feature/SKILL.md || echo "absent : $f"; done
```

Attendu : aucune sortie. Puis `bash tests/run.sh` (timeout 580000), lu par `grep -v '^PASS'` : aucun `FAIL`.

- [ ] **Étape 4 : commit**

```bash
git add global/skills/feature/SKILL.md
git commit -m "📝 feature: Contrôle sans verdict relancé, puis « non lancé »

Co-Authored-By: <modèle de l'implémenteur>"
```

### Task 2 : Renvoi de `bugfix` à la règle

§ spec : R2 (review de `bugfix`), R3 dans `bugfix`, § 2 (ligne `bugfix`).

**Fichiers :**
- Modifier : `global/skills/bugfix/SKILL.md`, nouveau paragraphe après celui qui finit par « reviews (seuls les « à
  trancher » détaillés), ce qui reste. » (l. 39-40)

**Interfaces :** consomme le paragraphe de la Task 1 (« Exécution » de `feature`).

- [ ] **Étape 1 : rouge**

```bash
git grep -nF 'non lancé' -- global/skills/bugfix/SKILL.md
```

Attendu : aucune sortie, code 1.

- [ ] **Étape 2 : insérer, précédé d'une ligne vide, le paragraphe suivant tel quel**

```markdown
Une review de l'étape 8 sans verdict, `pr-risk` compris, se relance une fois, puis s'écrit « non lancé » en « à
trancher » `N1…` de `final-review.md`, jamais un verdict (« aucun défaut », « aucun point », « rien à signaler »,
« conforme », « convergé »…), comme dans `feature`, « Exécution » ; un `pr-risk` « non lancé » vaut le niveau
Moyen, donc Opus part.
```

- [ ] **Étape 3 : vert**

```bash
for f in 'se relance une fois' '`N1…` de `final-review.md`' 'donc Opus part'; do
  git grep -qF -e "$f" -- global/skills/bugfix/SKILL.md || echo "absent : $f"; done
```

Attendu : aucune sortie. Puis `bash tests/run.sh` (timeout 580000), lu par `grep -v '^PASS'` : aucun `FAIL`.

- [ ] **Étape 4 : commit**

```bash
git add global/skills/bugfix/SKILL.md
git commit -m "📝 bugfix: Review sans verdict « non lancé », comme feature

Co-Authored-By: <modèle de l'implémenteur>"
```
