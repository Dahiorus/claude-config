# Relecture et retours de PR : sans doublon ni oubli

## But

`/pr comments` ne lit que les fils de discussion et retraite ceux où l'on a déjà répondu. `/pr review` republie des
remarques déjà faites. Rien ne liste les PR qui attendent notre relecture. `/pr merge` remplit la mémoire avec ce que
git sait déjà. Enfin, aucun test n'empêche les hooks sonar-secrets de disparaître de `settings/base.json`.

## 1. Demande initiale

Analyse du workflow, puis réponses de l'utilisateur, tels quels :

> #3 ok pour alléger la mémoire du merge
> #4 ok pour le test
> #6 ok pour les commentaires hors-fils mais essayer d'associer les commentaires à des fichiers
> #7 ok pour le fix
> #8 ok pour tenir compte des reviews précédentes
> #9 je veux bien une action qui liste les pr qui demandent ma review
> #-- ok pour Opus

Les points proposés, auxquels ces réponses renvoient :

- #3 : l'étape « Mémoire » de `/pr merge` recopie n° de PR, SHA et date, déjà dans git ; n'y garder que pièges et décisions.
- #4 : aucun test ne vérifie que `settings/base.json` garde les hooks sonar-secrets (PR #83).
- #6 : `/pr comments` ignore les commentaires de la conversation et le `body` des reviews, où `/pr review` met ses
  remarques hors diff.
- #7 : `/pr comments` ne filtre que sur `isResolved` : un fil où l'on a déjà répondu est retraité.
- #8 : chaque `/pr review` publie une review complète sans tenir compte des précédentes.
- #9 : rien ne liste les PR où l'on est relecteur demandé.
- « #-- » : le tri de plus de 3 retours dans `/pr comments` passe par un agent Opus, plus par `Explore`.

Écartés par l'utilisateur : #1 (hook `commit-msg`, les conventions changent d'un projet à l'autre), #2 (reste à faire
versionné, les projets vidal suivent leurs besoins dans Jira), #5 (évals de skills), #10 (réponse dans les issues).

## 2. Portée

« Soi » désigne le compte du profil du projet (`bash ~/.claude/profile.sh account`), celui avec lequel `/pr` publie,
pas le compte actif ; sous le jeton ponctuel que `/pr` passe à chaque commande `gh`, `@me` le désigne (glossaire, `docs/domaine.md`).

### R1 — Mémoire au merge (#3)

| Endroit | Devient |
|---|---|
| `global/skills/pr/SKILL.md` § `merge`, étape 6 | N'écrit dans la mémoire qu'un piège ou une décision nouvelle de la PR, avec sa raison ; jamais n° de PR, SHA, date, état du déploiement. Rien de nouveau → rien. Ce qui reste à faire va dans le reste à faire versionné s'il existe ; sinon un bug ou un point hors périmètre devient une issue (Q12), jamais la mémoire. Le rapport de l'étape 7 garde SHA et lien |
| § Aide, ligne `merge` | « mémoire » → « pièges et décisions en mémoire » |
| `bugfix`, `feature` (livraison par `pr`) | inchangés : ils délèguent à `/pr merge` |
| Mémoire `depot-livraison.md` | nettoyée une fois (Q7) : les lignes « Mergée le … » partent, pièges et décisions restent |

Décision (Q12) : sans reste à faire versionné, un bug ou un point hors périmètre devient une issue GitHub, proposée puis créée après accord comme à l'étape « Issues » de `push` (doublon d'abord, liste montrée, accord, label `hors-perimetre`, ou `bug` pour un bug) ; jamais dans la mémoire.

Décision (Q7) : la mémoire existante de ce dépôt (`depot-livraison.md`) est nettoyée une fois, en ne gardant que pièges et décisions.


### R2 — Hooks sonar-secrets protégés (#4)

| Endroit | Devient |
|---|---|
| `tests/test_settings.sh`, `test_base_settings_profile_hook` | vérifie aussi que le vrai `base.json` (`$REPO/settings/base.json`, copie du dépôt, ce que lit déjà ce test) contient `pretool-secrets.sh` en `PreToolUse` et `prompt-secrets.sh` en `UserPromptSubmit` |
| `settings/base.json` | inchangé |

### R3 — Retours hors fil (#6)

| Endroit | Devient |
|---|---|
| § `comments`, étape 1 | collecte aussi les retours hors fil : commentaires de la conversation (`gh api repos/<o/r>/issues/<n°>/comments --paginate`) et `body` non vide des reviews (`gh api repos/<o/r>/pulls/<n°>/reviews --paginate`). Exclus : commentaire contenant `<!-- pr-risk -->`, auteurs de type `Bot`, commentaires de conversation de soi (ce sont des réponses), points déjà cités par un commentaire de soi (Q2) |
| § `comments`, étape 1 (rattachement) | chaque retour hors fil est découpé en points (puce, paragraphe, ou remarque préfixée de `/pr review`). Un point qui cite `fichier:ligne`, `fichier` seul, ou un symbole qu'un grep trouve dans un seul fichier du diff, est rattaché à ce fichier (et cette ligne) ; sinon il vaut pour toute la PR |
| § `comments`, étape 4 (réponse) | points hors fil corrigés : un seul commentaire de conversation (`gh pr comment <n°> --body-file <fichier>`) qui cite chaque point (`> …`) avec ce qui a changé et le SHA, passé par `humanizer:humanizer` ; points non corrigés : réponse proposée dans le rapport et `final-review.md`, publiée après accord, comme pour les fils |
| § `comments`, étape 5 | `final-review.md` note pour chaque retour hors fil son origine (commentaire ou review, id) et son rattachement |
| § Aide, ligne `comments` | « traite les commentaires non résolus » → « traite les fils et commentaires en attente » |
| `global/skills/feature/SKILL.md` § « Tri des retours » | inchangé : le tri s'applique tel quel aux retours hors fil |

Décision (Q2) : un point hors fil est traité quand un commentaire de soi le cite (`> …`) ; le commentaire de criticité (`<!-- pr-risk -->`) ne compte pas comme commentaire de soi. La réponse est un seul commentaire de conversation qui cite chaque point traité, avec ce qui a changé et le SHA. Un point « à trancher » ou écarté, pas encore cité, reste en attente.


### R4 — Fils déjà répondus ignorés (#7)

| Endroit | Devient |
|---|---|
| § `comments`, étape 1 | ne garde que les fils en attente de soi (non résolus, dont le dernier commentaire n'est pas de soi, et dont le premier n'est pas d'un bot ; un fil de soi seul, sans réponse, reste en attente : Q1). Requête : `comments { totalCount }`, `comments(first: 1)` et `comments(last: 1)` en plus des `comments(first: 100)` déjà lus |
| § `comments`, étape 1, liste vide | « aucun retour en attente » (au lieu de « aucun fil ») et arrêt |
| `global/statusline-command.sh`, `fetch_threads_count` | compte les fils en attente du compte de la statusline (`gh_user`) : non résolus, premier commentaire pas d'un bot, et dernier commentaire d'un autre ou fil de `gh_user` seul (Q3) ; la requête lit `comments { totalCount }`, `comments(first: 1) { nodes { author { __typename } } }` et `comments(last: 1) { nodes { author { login } } }` |

Décision (Q1, étendue par Q10 à la relecture du plan) : sur toute PR, la sienne comme celle d'un autre, un fil ou une review de soi sans aucune réponse est un retour. Un fil est ignoré quand son dernier commentaire est de soi et qu'il compte au moins deux commentaires.


Décision (Q3) : la statusline compte les fils en attente avec la même règle que `/pr comments`, jugée avec son propre compte (`gh_user`, le compte de la statusline).


### R5 — Tri par Opus (« #-- »)

| Endroit | Devient |
|---|---|
| § `comments`, étape 2 | « plus de 3 fils » → « plus de 3 retours » (fils et points hors fil) ; l'agent `Explore` devient un agent `general-purpose` au modèle `opus` passé explicitement, même brief et même rendu |
| En-tête du skill (étapes de jugement par Opus) | ajoute « tri de plus de 3 retours (`comments`) » à la liste |

### R6 — Relecture incrémentale (#8)

| Endroit | Devient |
|---|---|
| § `review`, avant l'étape 1 | la session lit les remarques déjà faites (fils de la PR avec leur `path`, `line`, texte et état résolu ; `body` des reviews ; commentaires de la conversation, Q13) et la dernière relecture (`commit_id` de la review la plus récente de soi au `body` non vide, hors brouillon `PENDING`, Q4 : les réponses aux fils créent des reviews vides) |
| § `review`, étape 1 (brief) | reçoit les remarques déjà faites, à ne pas republier, et le périmètre : `git diff <commit_id>...HEAD` si ce commit est un ancêtre de HEAD (`git merge-base --is-ancestor <commit_id> HEAD`) et que `git rev-list --merges <commit_id>..HEAD` est vide, sinon le diff complet contre la base (push forcé, squash, rebase ou merge de la base depuis, Q14). Les fichiers touchés hors de ce périmètre servent de contexte, sans remarque |
| § `review`, étape 2 | ajoute : une remarque qui porte sur le même point qu'une remarque déjà faite (même fichier, ligne proche ou même symbole, même problème) n'est pas rendue, qu'elle soit résolue ou non ; une remarque résolue dont le code a régressé est une remarque nouvelle |
| § `review`, étape 4 | « une seule review `COMMENT`, jamais `APPROVE` ni `REQUEST_CHANGES` » devient : une seule review par invocation, `COMMENT` quand elle porte des remarques ; sans remarque nouvelle, `APPROVE` sur la PR d'un autre si soi est relecteur demandé (Q9) et qu'aucune bloquante de soi n'est ouverte (Q8), rien sinon ni sur sa propre PR ; jamais `REQUEST_CHANGES` |
| § Aide, ligne `review` | « publie les commentaires (statut « commenté ») » → « publie les commentaires, ou approuve s'il n'y a rien de nouveau » |
| `docs/domaine.md`, contexte Relecture de PR | responsabilité et invariant « jamais `APPROVE` » réécrits selon Q5 |
| § `review`, étape 5 | le rapport dit le périmètre relu (depuis `<sha court>` ou complet) et le nombre de remarques écartées comme déjà faites |
| `pr-risk` | inchangé : il met déjà à jour son commentaire au lieu d'en poster un autre |
| `docs/domaine.md` | invariant « une remarque déjà faite n'est pas republiée », ajouté par l'analyse |

Décision (Q13) : les remarques déjà faites incluent les commentaires de la conversation de la PR (`gh api repos/<o/r>/issues/<n°>/comments --paginate`), hors commentaire contenant `<!-- pr-risk -->` et auteurs de type `Bot` ; cette exclusion vaut aussi pour les fils (premier commentaire d'un `Bot`) et le `body` des reviews, comme à l'étape 1 de `comments` (décidé à la relecture de la PR #88).

Décision (Q14) : le périmètre incrémental (`git diff <commit_id>...HEAD`) ne vaut que si `git merge-base --is-ancestor <commit_id> HEAD` réussit et que `git rev-list --merges <commit_id>..HEAD` est vide. Un commit de merge depuis la dernière relecture (la base, `main`, mergée dans la branche) donne le diff complet contre la base, comme après un push forcé, un squash ou un rebase. Le code des PR déjà mergées sur la base, arrivé par ce merge ou par un rebase, n'a pas à être relu ; le diff contre la base ne contient que celui de la PR, et les remarques déjà faites ne sont pas republiées.

Décision (Q4) : le périmètre incrémental part de la dernière review de soi ; le dédoublonnage porte sur les remarques de tous les relecteurs.


Décision (Q5, réponse de l'utilisateur : « Si une relecture ne retrouve rien de nouveau, en tout cas sur une pr que je dois relire, approve la pr ») : sur une PR d'un autre, une relecture sans remarque nouvelle publie une review `APPROVE`, aux conditions de Q8 et Q9. Sur sa propre PR (GitHub refuse l'approbation par son auteur), rien n'est publié et le rapport le dit.

Décision (Q8) : l'approbation n'est publiée que si aucune remarque bloquante de soi n'est ouverte (fil non résolu, ou point hors fil sans réponse qui le cite) ; sinon rien n'est publié et le rapport liste ces bloquantes, chacune vérifiée dans le code et marquée « corrigée, fil à résoudre » ou « toujours là » (décidé à la relecture de la PR #88) : la relecture ne résout aucun fil, c'est au relecteur.


Décision (Q9) : seulement sur une PR où soi est relecteur demandé, seul ou par une de ses équipes (« les PR pour lesquelles j'ai une request review »), lu par `gh pr view <n°> --json reviewRequests` sous jeton ponctuel (une équipe compte si soi en est membre). GitHub retire la demande dès qu'une review de soi est publiée : au passage suivant, l'approbation suppose que l'auteur l'a redemandée. Pas de demande en cours → rien n'est publié, le rapport le dit.



### R7 — PR qui demandent ma relecture (#9)

| Endroit | Devient |
|---|---|
| § Actions sans arbre, `list` | filtre de `list`, dépôt courant seulement (Q6) ; même tableau que `list`, consigne « à relire » → `--search "review-requested:@me"`, en jeton ponctuel comme les autres commandes (`@me` = soi) |
| § Aide | ligne de l'action, exemple `/pr list à relire` |
| `description` du skill | ajoute « list the PRs awaiting my review » pour le déclenchement |
| Aucune PR | « aucune PR ne demande ta relecture » |

Décision (Q6) : filtre `/pr list à relire`, sur le dépôt courant seulement (« pour éviter une trop grande exploration ») ; pas de recherche dans tous les dépôts.


## 3. Données existantes

- Fils déjà répondus sur des PR ouvertes : ignorés au prochain `/pr comments` (R4), sans action.
- Reviews publiées avant cette feature : servent de remarques déjà faites dès la prochaine relecture (R6).
- Mémoire : seuls les prochains merges suivent R1 ; la mémoire actuelle selon Q7.

## 4. Critères d'acceptation

Une seule story : les règles sont indépendantes et chacune livre seule. La recette se fait sur une vraie PR.

**P1 — retours, relecture, liste, mémoire, test**

- R2 : `bash tests/run.sh` passe ; retirer un des deux hooks sonar de `base.json` fait échouer `test_base_settings_profile_hook`.
- Q1 : sur sa propre PR, une review de soi sans réponse → ses remarques sont des retours ; un fil de soi auquel un autre a répondu puis soi en dernier → ignoré.
- R3 : une PR avec un commentaire de conversation qui cite `lib/x.sh:12` → `/pr comments` le traite, `final-review.md` le rattache à `lib/x.sh:12`. Un point qui cite seulement un symbole présent dans un seul fichier du diff → rattaché à ce fichier. Un commentaire sans fichier → rattaché à la PR. Le commentaire `pr-risk` et un commentaire de bot → absents du tri.
- R4 : un fil dont soi a écrit le dernier commentaire en réponse à un autre → absent du tri. Combiné avec R3 : un retour hors fil suivi d'une réponse de soi → absent ; un fil répondu puis relancé par le relecteur → présent.
- Q2 : la réponse publiée est un seul commentaire de conversation qui cite chaque point traité, avec le SHA. Un point « à trancher » pas encore répondu → toujours présent au passage suivant.
- R5 : plus de 3 retours → un agent `general-purpose` `opus` trie, pas `Explore`.
- R6 : deuxième `/pr review` sans nouveau commit → aucune remarque republiée ; PR d'un autre où soi est relecteur demandé, sans bloquante de soi ouverte → review `APPROVE` ; sa propre PR, ou PR sans demande en cours → rien de publié, le rapport le dit. Combiné : rien de nouveau mais une bloquante de soi ouverte → rien de publié, le rapport la liste, marquée « corrigée, fil à résoudre » si le code l'a corrigée, « toujours là » sinon ; un fil ouvert par un bot ne compte pas comme remarque déjà faite. Nouveau commit → seul `<commit_id>...HEAD` reçoit des remarques. Après un push forcé, ou un merge de la base dans la branche → diff complet, aucune remarque déjà faite republiée. Une review d'un autre relecteur après celle de soi ne déplace pas le périmètre (Q4).
- R7 : `/pr list à relire` liste les PR où le compte du profil est relecteur demandé ; aucune → message dédié. Une demande adressée à une équipe dont soi est membre apparaît ; une PR d'un autre dépôt n'apparaît jamais.
- R1 : après `/pr merge`, la mémoire ne gagne aucune ligne « Mergée le » ; un piège rencontré y entre ; un bug hors périmètre sans reste à faire versionné → issue proposée, pas ligne de mémoire.

## 5. Filet sur l'existant

Le code modifié est `tests/test_settings.sh` (R2, 2 lignes de test) et `global/statusline-command.sh` (Q3, +9 -3). Les skills n'ont pas de tests automatiques
(décision : recette sur les autres projets) ; leur filet est la recette de §4. Statusline (Q3) : `tests/test_statusline.sh` n'a aucun test du compte des fils ; un test du nouveau filtre s'y ajoute ; la requête de
`fetch_threads_count` lit alors le dernier auteur et `totalCount` de chaque fil.

## 6. Origine

| Point | Origine |
|---|---|
| R1 | défaut ancien : étape 6 de `/pr merge` depuis la PR #76 |
| R2 | hors périmètre de la PR #83 (« pas de test qui vérifie ces hooks », mémoire) |
| R3 | défaut ancien : `/pr comments` (PR #76), aggravé par les remarques hors diff de `/pr review` (PR #77) |
| R4 | défaut ancien de `/pr comments` |
| R5 | question laissée ouverte par la PR #76 (mémoire) |
| R6 | défaut ancien de `/pr review` ; même défaut que `pr-risk`, réglé par la PR #78 |
| R7 | besoin nouveau |

Hors périmètre : #1, #2, #5, #10 (écartés par l'utilisateur, §1).

## 7. Dette du code touché

| Méthode | Écart | Décision |
|---|---|---|
| `global/skills/pr/SKILL.md` | 361 lignes avant la branche, au-delà de 200 (grille, point 7) ; la feature l'allonge de 47 lignes (408) | reporté : un skill se lit d'une traite, le découper demanderait une spec à part |
| `global/statusline-command.sh`, `fetch_threads_count` | fichier à 266 lignes avant la branche (272 après, +6), dette déjà notée par la PR #74 | reporté |
| `test_base_settings_profile_hook` | test, longueur libre | — |
