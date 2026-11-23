# Collecte des leçons sans règle qui grossit

## 1. Demande initiale

Issue #180 (« Collecte des leçons sans règle qui grossit »), citée telle quelle :

> ## Constat
> L'audit des `lecons.md` et du `CLAUDE.md` (PR #179) compte environ 135 leçons : environ 35 % sont ponctuelles et
> 20 % déjà couvertes. 8 groupes de frictions sur 10 sont revenus malgré une règle écrite. Chaque PR ajoutait des
> lignes au `CLAUDE.md` sans empêcher les récidives.
>
> ## Piste
> À faire avec `/feature`. Les fichiers touchés sont `global/skills/pr/merge.md` (étape 2), `lessons-extractor` et
> `tests/`.
> - Chaque ligne de `lecons.md` reçoit une étiquette `méca`, `jugement` ou `ponctuel`. Une ligne `ponctuel` ne produit
>   pas de règle.
> - Une friction mécanisable devient un test, un hook ou un script, jamais une phrase.
> - Une récidive met la règle en cause au lieu de la reformuler.
> - Un test vérifie le budget de lignes du `CLAUDE.md`.
> - Quand une friction revient, `lecons.md` cite la règle concernée, ce qui permet de retirer celles qu'on ne cite
>   plus.
>
> ## Origine
> PR #179 (condensation du `CLAUDE.md`), `docs/reste-a-faire.md`, Features, point 8.

Vocabulaire : contexte « Leçons » de `docs/domaine.md` (friction, leçon, étiquette, règle, garde mécanique,
proposition, récidive, règle citée, budget de lignes).

## Approches

| Approche | Ce qu'elle fait | Coût | Retenue |
|---|---|---|---|
| A. Format de la leçon + extracteur + test de budget | La leçon porte son étiquette et, en récidive, la règle citée ; `lessons-extractor` trie par étiquette et propose une garde, une règle ou un retrait ; un test borne le `CLAUDE.md` | 4 fichiers de texte, 1 test | oui |
| B. A + script qui analyse les `lecons.md` | Un script compte étiquettes et citations dans les 69 dossiers de suivi et rend les règles citées deux fois | un parseur de plus, ses entrées hostiles et ses tests, pour ~170 lignes qu'un agent lit déjà | non : l'extracteur fait ce comptage en lisant |
| C. A + hook qui refuse une leçon sans étiquette | Un hook PreToolUse sur l'écriture de `lecons.md` vérifie le format de chaque ligne ajoutée | un hook, ses mutations et ses scripts adverses (règles du `CLAUDE.md`, « Hooks ») | non pour l'instant : la règle de cette spec l'appelle seulement si l'oubli d'étiquette revient (§2, règle R3) |

## 2. Portée de chaque règle

### R1. Format d'une leçon

Une leçon s'écrit `- <date> (<action>) [<étiquette>] : <friction>`, où `(<action>)` est facultatif et garde la
précision qu'ont déjà les lignes existantes (`- 2026-11-04 (merge #84) : …`). L'étiquette vaut `méca`, `jugement`
ou `ponctuel`. `pr/SKILL.md` définit les trois étiquettes en une ligne chacune, et `lessons-extractor.md` les
reprend : `docs/domaine.md` n'est pas relié dans `~/.claude`, une session d'un autre projet ne le lit pas.
Une leçon de récidive finit par
`(récidive : <fichier> « <fragment> »)`, où le fragment tient sur une ligne du fichier et se retrouve par
`git grep -nF` : un numéro de ligne casse dès qu'on édite le fichier.

La session qui écrit la leçon pose l'étiquette : elle connaît le contexte de la friction. L'extracteur corrige une
étiquette fausse en le disant dans sa réponse.

| Endroit | Ce qu'il devient |
|---|---|
| `global/skills/pr/SKILL.md`, « Dossier de suivi », puce `lecons.md` | donne le format R1, les trois étiquettes définies en une ligne chacune et la citation de récidive ; reste la seule définition du format |
| `global/skills/feature/SKILL.md` étape 7, `global/skills/bugfix/SKILL.md` étape 8 | renvoient au format : « frictions de la session dans `lecons.md`, avec leur étiquette (format : skill `pr`, « Dossier de suivi ») » ; ils écrivent la plupart des leçons, et sans renvoi l'étiquette ne serait posée qu'au merge (correctif de review P1) |
| `global/skills/pr/merge.md` étapes 2 et 7, `rebase.md` étape 6, `comments.md` étape 5, `recette.md` étape 3 | inchangés : ils disent « frictions dans `lecons.md` » et renvoient de fait au format de `pr/SKILL.md` |
| `push.md`, `squash.md` | inchangés : cités comme écrivains par `pr/SKILL.md`, sans phrase propre |
| `docs/domaine.md`, contexte « Leçons » | ajouté par `ddd` ; les colonnes « Dans le code » marquées « proposé » deviennent le format R1 et le test R4 |

### R2. Tri des leçons par étiquette (`lessons-extractor`)

- `ponctuel` → aucune proposition. La même friction trouvée dans une autre PR n'est pas ponctuelle : l'extracteur
  la ré-étiquette dans sa réponse.
- Leçon sans étiquette (les leçons existantes, ou un oubli) → l'extracteur l'étiquette à la lecture, en le disant.

L'extracteur n'étiquette que les leçons de la PR, plus les anciennes qui forment une récidive ou une répétition avec
elles : rien n'est réécrit dans les `lecons.md`, et étiqueter toutes les leçons lues referait à chaque merge ~170
lignes d'étiquetage dans sa réponse.

- `méca` → proposition d'une garde mécanique (test, hook, script, ou changement qui supprime le piège), jamais d'une
  phrase. Si la garde se fait dans la PR (un test), le diff est proposé ; sinon (hook, script), elle devient une
  issue ou un point du reste à faire, jamais une phrase en attendant : un hook demande des mutations et des scripts
  adverses avant le push (règles du `CLAUDE.md`, « Hooks »), ce n'est pas un diff qu'on applique d'un accord.
  Aucune garde possible → la leçon n'est pas `méca` : l'extracteur la ré-étiquette `jugement`, en le disant.
- `jugement` sans règle existante → proposition d'une règle, comme aujourd'hui.
- `méca` ou `jugement` avec une règle existante (trouvée par grep, ou citée dans la leçon) → récidive : R3 ; un
  `méca` y prend la suite 1, garde et retrait de la phrase dans le même diff. Une règle ajoutée par la PR elle-même
  n'est pas une règle existante : la friction l'a fait écrire, elle ne l'a pas empêchée. Une garde en issue ou au
  reste à faire (hook, script) laisse la phrase en place jusqu'à elle, et l'issue ou le point demande son retrait
  (correctif de review C1).

Chaque leçon traitée hors `ponctuel` reçoit une proposition : aucune ne reste « à trancher » dans la réponse.
Une leçon couverte par une règle que la PR ajoute a pour proposition « couverte par la PR », avec le fichier et le
fragment de la règle, sans diff (correctif de recette A2). Le diff de la PR et sa base se lisent dans l'arbre de
la PR du brief (`git -C <arbre>`, `cd <arbre> && gh pr view`), pas dans le dossier de la session.

### R3. Récidive

Une récidive ne produit jamais une reformulation seule. L'extracteur propose l'une de ces trois suites, liste
fermée :
1. **mécaniser** la règle (une garde, qui remplace la phrase) ;
2. **déplacer** la règle à l'étape du skill où l'action a lieu, si la phrase était lue ailleurs ;
3. **retirer** la règle, si elle n'a rien empêché et qu'aucune garde n'est possible.

Déplacer reste une suite possible : la phrase peut être juste mais lue au mauvais moment.

La règle citée sert à repérer les récidives, pas à retirer les règles jamais citées : une règle n'est citée que
quand elle a échoué, et une règle qui marche ne l'est jamais. D'où un palier : à la première récidive d'une règle,
les trois suites sont ouvertes ; à partir de la deuxième (règle citée deux fois, dans cette PR ou entre deux PR),
seules mécaniser et retirer le sont.

### R4. Budget de lignes du `CLAUDE.md`

Un test de `tests/test_rules.sh` échoue quand le `CLAUDE.md` dépasse son budget. Le budget s'écrit dans le test ; il
ne se relève jamais pour faire passer une règle (une règle ajoutée au-delà en retire ou en déplace une autre), et se
baisse à la main quand le fichier rétrécit.

Deux fichiers sont bornés à leur taille actuelle : `CLAUDE.md` du dépôt ≤ 73 lignes et `global/CLAUDE.md`
(consignes de tous les projets) ≤ 26 lignes. `global/CLAUDE.md` est lu par toutes les sessions et grossit de la
même façon ; `global/RTK.md` (29 lignes, inclus par lui) n'est pas borné. Un plafond égal à la taille actuelle
arrête la croissance sans imposer de tri maintenant.

Hors de `claude-config`, le budget ne vaut pas : le test ne voit que ce dépôt, et l'`AGENTS.md` d'un autre projet
n'a pas de test ici. L'extracteur n'applique donc le budget que pour `claude-config` : une proposition de règle qui
ferait dépasser le budget vient avec la ligne qu'elle retire ou déplace.

### Portée de R2 à R4 dans les fichiers

| Endroit | Ce qu'il devient |
|---|---|
| `global/agents/lessons-extractor.md`, « Retenir » | remplacé par le tri R2 et la règle de récidive R3 ; un point de `final-review.md` vu deux fois, retenu aujourd'hui, se traite comme une leçon sans étiquette (comportement gardé) |
| `global/agents/lessons-extractor.md`, « Cible » | ajoute la cible « garde mécanique » : `tests/` ou hook du projet (pour `claude-config` : `tests/`, `global/*-hook.sh`), et le retrait d'une règle ; note le budget R4 pour `claude-config` |
| `global/agents/lessons-extractor.md`, « Réponse » | le tableau gagne la colonne « Étiquette » et le type de proposition (règle, garde, déplacement, retrait, issue pour une garde trop grosse) ; ré-étiquetages listés ; une règle qui ne tient au budget qu'avec un retrait cite la ligne de ce retrait |
| `global/agents/lessons-extractor.md`, « Cible » (suite) | la cible suit la portée, jamais le budget (correctif de recette E1) |
| `global/agents/lessons-extractor.md`, « Réponse » (suite) | type de proposition « couverte par la PR » aussi (correctif de recette A2) |
| `global/agents/lessons-extractor.md`, `description` | dit qu'il propose aussi gardes et retraits (règle du `CLAUDE.md` : agent dont le rôle change) |
| `global/skills/pr/merge.md` étape 2 | sa phrase qui recopie les critères de l'extracteur (« une friction qu'une règle écrite aurait évitée… devient une règle proposée ») renvoie à l'agent au lieu de les recopier, et cite gardes et retraits ; une garde trop grosse devient une issue ou un point du reste à faire, proposé puis créé par la session après accord (l'extracteur n'écrit rien) ; le reste de l'étape (accord, commit dans la PR, `notify`) inchangé |
| `tests/test_rules.sh` | nouveau test du budget R4 |
| `CLAUDE.md` l. 3 (« Une règle vérifiable par un programme va dans `tests/` ou un hook ») | inchangé : R2 l'applique à l'extracteur |
| `docs/reste-a-faire.md`, Features, point 8 | rayé à la livraison (étape 5 de `feature`) |
| Mémoire `lecon-evaluer-avant-regle` | inchangée : R2 (`méca`) en reprend l'esprit |

Ce qui n'est plus lu : rien. L'extracteur lit les mêmes fichiers (`lecons.md`, `final-review.md`, cibles).

## 3. Données existantes

Les ~170 leçons, dans les `lecons.md` de 53 des 69 dossiers de `.superpowers/sdd/`, n'ont ni étiquette ni
citation. Elles sont tolérées sans migration : l'extracteur étiquette à la lecture celles que R2 retient
(récidive ou répétition avec une leçon de la PR), sans les réécrire (il n'écrit rien). Le `CLAUDE.md` (73 lignes)
et `global/CLAUDE.md` (26) respectent le budget au jour du test.

## 4. Critères d'acceptation

### Story P1 — Une leçon triée et un `CLAUDE.md` borné

Une seule story : la demande ne se découpe pas en parcours livrables séparément.

Cas nominaux :
1. `pr/SKILL.md` donne le format R1 avec l'étiquette et la citation de récidive.
2. Sur un dossier de suivi réel, l'extracteur rend un tableau où chaque leçon de la PR, et chaque leçon ancienne
   retenue par R2, a une étiquette, et aucune proposition ne vient d'une leçon `ponctuel`.
3. Une leçon `méca` donne une proposition de garde (test dans la PR, ou issue ou point du reste à faire pour un
   hook ou un script), jamais une phrase.
4. Une leçon `jugement` dont la règle existe donne l'une des suites de R3 (palier compris), jamais une
   reformulation seule.
5. `bash tests/run.sh` passe avec le `CLAUDE.md` actuel.

Refus :
6. Un `CLAUDE.md` d'une ligne de plus que son budget fait échouer le test, avec un message qui nomme le fichier,
   sa taille et le budget.
7. Même cas pour `global/CLAUDE.md` (budget 26).

Cas combinés :
8. Une leçon étiquetée `ponctuel` dont la friction revient dans une autre PR : ré-étiquetée et traitée, pas ignorée.
9. Une leçon `jugement` sans étiquette ni citation, dont la règle existe : étiquetée, puis traitée en récidive.
10. Une proposition de règle pour le `CLAUDE.md` de `claude-config` alors que le budget est atteint : elle vient avec
    la ligne retirée ou déplacée.
11. Les deux fichiers au-dessus du budget à la fois : le test les nomme tous les deux.

## 5. Filet sur l'existant

`lessons-extractor.md`, `merge.md` et `pr/SKILL.md` sont du texte lu par une session : aucun test ne les fige, leur
recette est un agent neuf qui exécute l'extracteur sur un dossier de suivi réel (étape 6 de `feature`). Le test de
largeur (`test_branch_respects_rules`) couvre déjà la prose ajoutée. Aucun test de caractérisation à écrire.

## 6. Origine

| Point | Origine |
|---|---|
| Tout le périmètre | *défaut ancien* : audit des `lecons.md` (2026-11-21), commit `ed6332a` de la PR #179, `docs/reste-a-faire.md` Features point 8 |
| Hook de format des leçons (approche C) | *hors périmètre* de cette spec, appelé par R3 si l'oubli d'étiquette revient |
| Nettoyage des 69 dossiers de suivi relus à chaque merge (signalé par `ddd`) | *hors périmètre* de cette spec |
| Budget pour l'`AGENTS.md` d'un autre projet | *hors périmètre* de cette spec |

## 7. Dette du code touché

Aucune méthode modifiée : les changements portent sur du texte et un test ajouté. Sans objet.
