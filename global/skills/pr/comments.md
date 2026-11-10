# `comments`

L'invocation vaut demande de corriger, pousser et répondre.

1. Retours en attente de soi (soi : compte du profil), filtrés par auteur si la consigne le dit (« de alice ») :
   - **Fils** : `gh api graphql`, `reviewThreads` avec `isResolved`, `all: comments { totalCount }`,
     `first: comments(first: 1) { nodes { author { __typename } } }`,
     `last: comments(last: 1) { nodes { author { login } } }`,
     `comments(first: 100) { databaseId path line body author { __typename login } }`. Gardés : non résolus, dont le
     dernier commentaire (`last`) n'est pas de soi, ou, sur sa propre PR, fil de soi seul, sans réponse
     (`totalCount` 1 : sa propre review est un retour ; sur la PR d'un autre, c'est l'auteur qui la traite). Exclus : fils dont le premier commentaire (`first`) est d'un auteur de type `Bot`.
   - **Hors fil** : commentaires de la conversation (`gh api repos/<o/r>/issues/<n°>/comments --paginate`) et `body`
     non vide des reviews (`gh api repos/<o/r>/pulls/<n°>/reviews --paginate`). Exclus : commentaire contenant
     `<!-- pr-risk -->`, auteur de type `Bot`, commentaire de conversation de soi (c'est une réponse ; seul le
     `body` d'une review de soi reste un retour, sur sa propre PR seulement). Chacun est découpé en points (puce, paragraphe, remarque préfixée
     de `/pr review`) ; un point est traité, donc exclu, quand un commentaire de soi autre que `pr-risk` le cite
     (`> …`, mot pour mot). Rattachement : un point qui cite `fichier:ligne`, un `fichier`, ou un symbole qu'un grep trouve dans
     un seul fichier du diff, est rattaché à ce fichier (et cette ligne) ; sinon il vaut pour toute la PR.
   Aucun retour → « aucun retour en attente » et s'arrêter.
2. Pour chaque retour : vérifier le commentaire dans le code, puis le trier comme dans `feature` (« Tri des retours »).
   Plus de 3 retours (fils et points hors fil) : la vérification et le tri passent par un agent `general-purpose`
   (modèle `opus` passé explicitement), qui reçoit les retours (id, `path`, `line`, texte ; pour un point hors fil, son
   origine, commentaire ou review et id, et son rattachement), les critères du tri ci-dessous, le chemin de la grille
   du projet et la description de la PR (spec liée comprise), et rend, pour chacun, son tri, la preuve (`fichier:ligne`) et la correction envisagée ; la session corrige.
   Tri :
   « à corriger » → corrigé (règle générale plutôt que cas, comme pour l'action `recette` (`recette.md` du skill `pr`)) ; « écarté » (faux ou hors règle
   du projet) → raison, qui relit d'abord la source qu'elle invoque (issue, schéma, `origin/main`, avis de `pr-risk` ; `gh issue view <n>`,
   `git show origin/main:<fichier>`, `gh pr view <n°> --comments` pour le commentaire `<!-- pr-risk -->`) et cite ce qu'elle y a lu ; « à trancher » (ambigu, changement de comportement non prévu par la spec) → options et
   recommandation, rien n'est corrigé avant l'accord.
3. Contrôle des copies d'une règle changée (étape 1 de `push.md`), puis vérification du projet ; rouge → ne pas pousser. Commits au format de `CONTRIBUTING.md`, `push` simple.
   Correctif qui change ce que la description annonce (règle, chiffre, option retenue) : la mettre à jour
   (`update-desc`, `SKILL.md`) et la relire contre le diff comme à l'étape 4 de `push.md`, avant la review du tour suivant.
4. Répondre à chaque fil corrigé (`gh api repos/<owner/repo>/pulls/<n°>/comments/<databaseId>/replies -F body=@<fichier>`, corps écrit dans un fichier avec Write d'abord, pas `printf`/`echo`) :
   ce qui a changé, le SHA et le sujet du commit (un `squash` qui suit efface le SHA), passé par `humanizer:humanizer`. Ne pas résoudre les fils : c'est au relecteur. Fils non corrigés : réponse proposée
   dans le rapport et dans `final-review.md`, publiée après accord.
   Points hors fil corrigés : un seul commentaire de conversation (`gh pr comment <n°> --body-file <fichier>`) qui
   cite chaque point (`> …`, mot pour mot) avec ce qui a changé, le SHA et le sujet du commit, passé par `humanizer:humanizer`, qui garde
   les citations telles quelles. Points non corrigés :
   comme les fils, réponse proposée, publiée après accord ; tant qu'aucune réponse ne les cite, ils restent en attente.
5. Tri, SHA et, pour chaque point hors fil, origine et rattachement dans `final-review.md`, frictions dans `lecons.md`. Rapport : décompte corrigés (SHA) / écartés, puis seuls les « à trancher » détaillés, lien de la PR.
6. **Boucle**, sur sa propre PR seulement (sur celle d'un autre, c'est l'auteur qui corrige : une seule paire). Un
   tour est une paire `review` puis `comments` ; le premier est celui de l'invocation. Un tour en lance un autre si
   sa review a publié au moins une remarque `**[bloquant]**` nouvelle et que son `comments` a poussé un correctif.
   La review relancée ne relit que les correctifs (périmètre de l'étape 0 de `review.md`) ; le `comments` relancé ne
   traite que les remarques qu'elle vient de publier, les retours non corrigés des tours précédents gardent leur tri.
   Arrêt : review qui ne publie aucune bloquante (ou rien), aucun correctif poussé, « à trancher » en attente
   d'accord, vérification rouge, ou 3 tours, le premier compris. Le rapport dit le nombre de tours et ce qui reste
   ouvert : « à trancher », réponses en attente d'accord, bloquantes que la review dit « toujours là ».
