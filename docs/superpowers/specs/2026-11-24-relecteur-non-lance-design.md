# Contrôle non lancé

## But

Un agent de contrôle qui expire ou ne rend rien laisse un vide que rien ne nomme : le contrôleur peut le lire comme un
contrôle sans écart et écrire « conforme », « convergé » ou « aucun point ». La règle reprend d'EGM
(`agents/synthesizer.md`) la distinction entre un contrôle qui n'a rien trouvé et un contrôle qui n'a pas rendu de
verdict. Termes du glossaire : **contrôle non lancé**, **verdict** (`docs/domaine.md`, contexte « Conception de
feature »).

## 1. Demande initiale

`/feature`, qui reprend le point 3 des Features de `docs/reste-a-faire.md` :

> **Relecteur en échec = « non lancé »** (EGM, `agents/synthesizer.md`) : un agent de review, de convergence,
> `spec-yagni-checker` ou `ddd revue` qui expire ou ne rend rien est relancé une fois. S'il échoue encore, son
> rapport l'affiche « non lancé », jamais « aucun défaut ». Une phrase dans « Exécution » de `feature`, à reporter
> dans `bugfix`. (docs/reste-a-faire.md, point 3)

Réponses dans Plannotator : le contrôle de tâche (`sdd-task-reviewer`) entre dans la règle, bien que la demande ne le
cite pas (« Exécution » le range parmi les « agents de contrôle ») ; un `pr-risk` « non lancé » vaut le niveau
Moyen (R3).

## Règles

**R1 — Un contrôle sans verdict est relancé une fois.** Contrôles visés : `ddd revue` (spec et plan) et
`spec-yagni-checker` (validation fonctionnelle), `sdd-task-reviewer` (contrôle de tâche, étape 4),
`convergence-checker` (étape 5b), et chaque review de la review finale de `feature` (étape 7) ou de l'étape 8 de
`bugfix` : aujourd'hui `ponytail-review`, `sdd-final-reviewer`, `pr-risk` et les angles qu'il ajoute
(`code-review`, `security-review`, `frontend-reviewer`). Le skill ne recopie pas cette liste de reviews : il écrit
« chaque review lancée à l'étape 7 » (8 pour `bugfix`), pour suivre le dosage sans copie à tenir à jour ; la liste
reste ici pour la recette.
Un contrôle est sans verdict quand il s'arrête sur une erreur ou un délai, ou répond sans le verdict que son agent ou
son skill définit (réponse vide, coupée, sans ligne de verdict). `pr-risk` finit par sa ligne `Not read:`,
`ponytail-review` par `Verdict:` ou, sans point, `Looks good. Ship.` : leur absence marque la réponse coupée.
`code-review` et `security-review` n'ont pas de
ligne de verdict : pour eux, seuls l'erreur, le délai et la réponse vide comptent. La relance est un nouvel appel
(`Agent` ou `Skill`) avec le même brief et le même modèle ; un appel `Agent` part seul dans son message
(« Exécution »).

**R2 — Toujours sans verdict, il est « non lancé ».** Le contrôleur écrit « non lancé » et la cause vue (erreur citée,
délai, réponse vide) là où le verdict serait allé, jamais un verdict (« aucun défaut », « aucun point », « rien à
signaler », « conforme », « convergé »…) :
- `ddd revue` (spec ou plan), `spec-yagni-checker` : dans le message du contrôleur, avant l'ouverture dans
  Plannotator. Pour la règle « aucun écart ne s'applique avant le retour des deux », un contrôle « non lancé »
  compte comme revenu ;
- `sdd-task-reviewer` : dans le ledger `progress.md`, face à la tâche ; la tâche n'est pas contrôlée, la suivante
  ne part pas, et le contrôleur s'arrête et rapporte ;
- `convergence-checker` : dans `convergence-N.md` ; le contrôleur s'arrête et rapporte, comme quand la feature
  n'a toujours pas convergé après 3 tours ;
- review finale : dans le rapport de la review (`opus-review.md`…) et en tête de `final-review.md`, en « à
  trancher » (relancer plus tard ou livrer sans cet angle), que `/pr push` reporte comme les autres points non
  retenus. Sans cette ligne, le vide ne se voit pas à la livraison. Pour la règle « le tri attend toutes les reviews
  lancées », une review « non lancée » compte comme rendue. Ce point porte un numéro du tri, préfixe `N1…`
  (« non lancé »), à la suite de `P/C/I/M/R/S/F` : l'utilisateur le vise par « corrige N1 » (relancer la review),
  et `/pr push` le reporte comme tout point non retenu, sans toucher à `push.md`. La relance est la recommandation
  du point : « corrige tout » relance chaque review `N…`. Une review coupée deux fois garde les points déjà lus :
  sa ligne `N…` les recopie, « à vérifier », et le tri les vérifie comme les autres (recette 2, scénario 12 : un C
  déjà lu ne se perd pas).

**R3 — `pr-risk` « non lancé » vaut le niveau Moyen.** Le dosage des reviews part du niveau rendu par `pr-risk`.
Sans verdict, le niveau inconnu est traité comme Moyen : `code-review high` part, et le « non lancé » de `pr-risk`
reste en « à trancher » en tête de `final-review.md`. Le risque n'est jamais supposé faible sans preuve. Ses dangers
restent inconnus : sa ligne `N…` dit que `security-review` ne part pas faute de danger cité (dosage inchangé). R3 vaut
aussi dans `bugfix`, où un niveau Moyen lance en plus Opus (étape 8) : la phrase de `bugfix` la cite.

## 2. Portée

| Endroit | Ce qu'il devient |
|---|---|
| `global/skills/feature/SKILL.md`, § « Exécution » | Phrases ajoutées après « `spec-yagni-checker` obéit aux mêmes interdits… » : R1, R2 et R3 |
| `global/skills/bugfix/SKILL.md`, après le paragraphe « Les étapes 1 à 8 s'enchaînent… » | Une phrase : une review sans verdict suit la règle de `feature`, « Exécution » (relancée une fois, puis « non lancé » en « à trancher » `N…` de `final-review.md`) ; un `pr-risk` sans verdict vaut Moyen (R3), donc Opus part |
| `global/skills/feature/SKILL.md`, étapes 1, 4, 5b, 7, § « Validation fonctionnelle », « Dosage des reviews » | Inchangés : les règles « retour des deux » et « le tri attend » restent, R2 dit qu'un « non lancé » compte comme rendu ; « Exécution » porte la règle pour toutes ces étapes |
| `global/skills/ddd/SKILL.md` (§ `revue`), `global/agents/spec-yagni-checker.md`, `sdd-final-reviewer.md`, `frontend-reviewer.md` | Une ligne `Verdict :` en dernière ligne de la réponse, toujours (review M2) : sans elle, une réponse coupée en cours de liste passerait pour rendue. `rien à signaler` ou décompte à corriger / à trancher / écartés (`ddd revue`, `spec-yagni-checker`) ; `conforme` ou décompte C/I/M (les deux reviewers) |
| `global/agents/sdd-task-reviewer.md`, `convergence-checker.md` | Leur verdict, en tête de réponse, est répété en dernière ligne (review de la PR) : en tête seulement, une réponse coupée garderait son verdict |
| `global/skills/pr/SKILL.md` (« Dossier de suivi »), `push.md` | Inchangés : `final-review.md` et ses points non retenus sont déjà reportés par `/pr push` |
| `docs/domaine.md`, contexte « Conception de feature » | Termes « Contrôle non lancé » et « Verdict », et l'invariant (ajoutés par l'analyse `ddd`) ; « Contrôle non lancé » cite aussi le contrôle de tâche ; « Verdict » cite aussi `sdd-task-reviewer` (`OK`, `KO`, `BLOQUÉ`) ; la Responsabilité et le « Dans le code » du contexte s'élargissent au contrôle de tâche, à la convergence et aux reviews (`sdd-task-reviewer`, `convergence-checker`, `bugfix`) |
| `pr-reviewer`, `recette-runner`, `feedback-triager`, `lessons-extractor`, `todo-verifier`, `bug-worker` | Inchangés : hors de la demande (§ 6) |

## 3. Données existantes

Sans objet : aucun rapport déjà écrit n'est repris.

## 4. Critères d'acceptation

Story unique (P1) : un contrôle sans verdict deux fois de suite est rapporté « non lancé ».

- Nominal : `ddd revue spec` répond vide, est relancé et rend son rapport → le rapport compte, aucun « non lancé ».
- Refus : `convergence-checker` s'arrête deux fois sur un délai → `convergence-N.md` porte « non lancé » et la cause ;
  le chat ne dit pas « convergé », et le cycle s'arrête avant la recette.
- Refus : `sdd-task-reviewer` répond vide deux fois → `progress.md` porte « non lancé (réponse vide) » face à la
  tâche ; la tâche suivante ne part pas.
- Combiné : à l'étape 7, ponytail rend ses points et Opus échoue deux fois → `final-review.md` liste les `P…` et, en
  tête, « N1 — Opus : non lancé (délai) » en « à trancher » ; le tri des `P…` n'attend pas Opus.
- Combiné : `pr-risk` échoue deux fois → `code-review high` part, et `final-review.md` porte en tête « pr-risk : non
  lancé (<cause>) » en « à trancher ».
- Combiné (validation fonctionnelle) : `spec-yagni-checker` échoue deux fois et `ddd revue` rend ses écarts → les
  écarts de `ddd revue` s'appliquent, le message avant Plannotator dit « contrôle YAGNI : non lancé (<cause>) ».
- Plan : `ddd revue plan` répond vide deux fois → le message avant Plannotator dit « revue métier du plan : non
  lancé (réponse vide) ».
- `bugfix` : `ponytail-review` échoue deux fois → `final-review.md` porte en tête « ponytail : non lancé (<cause>) »
  en « à trancher » `N1`, et le rapport d'étape 8 le détaille parmi les « à trancher », pas « aucun point ».
- `bugfix` : `pr-risk` échoue deux fois sur un correctif de 10 lignes → Opus et `code-review high` partent.

## 5. Filet sur l'existant

Sans objet : texte de skill, pas de code. Recette (étape 6) : un agent neuf lit le texte final et dit ce qu'il écrit
dans le cas combiné de l'étape 7, dans celui de `pr-risk` et dans celui de la validation fonctionnelle.

## 6. Origine

- Point traité : point 3 des Features du reste à faire, *hors périmètre* de la spec
  `2026-11-20-yagni-spec-design` (§ 6), repris d'EGM.
- Hors périmètre : les autres agents (`pr-reviewer` de `/pr review`, `recette-runner`, `feedback-triager`,
  `lessons-extractor`, `todo-verifier`, `bug-worker`), absents de la demande.

## 7. Dette du code touché

Le paragraphe « Exécution » de `feature` a des lignes de plus de 120 colonnes : elles ne se réécrivent pas, la
phrase s'ajoute sur ses propres lignes (CLAUDE.md du projet). Aucune autre dette.
