# `review`

L'invocation vaut demande de relire et de publier. PR dont on est l'auteur → relire quand même, en regard critique
sur son propre code : chercher ce qu'on a raté, pas justifier ce qu'on a écrit.

Étapes 1 et 2 dans un agent, en même temps que l'étape 3 (un seul message) : la lecture du diff et du code reste
hors de la session, qui ne reçoit que les remarques.

0. **Déjà fait** — lire les remarques déjà faites (fils de la PR : `path`, `line`, texte, `isResolved` ; `body` des
   reviews ; commentaires de la conversation, `gh api repos/<o/r>/issues/<n°>/comments --paginate`), hors commentaire
   contenant `<!-- pr-risk -->` et auteurs de type `Bot` (fil dont le premier commentaire est d'un `Bot`), comme à
   l'étape 1 de `comments.md`, et la dernière relecture de soi (`commit_id` de sa review la plus récente au `body` non vide et d'`state` autre que `PENDING`,
   `gh api repos/<o/r>/pulls/<n°>/reviews --paginate` : les réponses aux fils créent des reviews vides, son brouillon
   est `PENDING`). Périmètre : `git diff <commit_id>...HEAD` si `git merge-base --is-ancestor <commit_id> HEAD`
   réussit dans l'arbre de la PR **et** que `git rev-list --merges <commit_id>..HEAD` est vide, sinon (aucune
   relecture, push forcé, squash, rebase, merge de la base) le diff complet contre la base : le code des PR déjà
   mergées sur la base n'est pas relu.
1. **Agent de relecture** (`general-purpose`, modèle `opus` passé explicitement). Son brief donne le n° de PR, le
   chemin de l'arbre de la PR, la consigne de périmètre, l'auteur si c'est soi (regard critique) et la consigne
   ci-dessous. Il lit le diff contre la base (`git diff origin/<baseRefName>...HEAD`), les fichiers touchés et le
   contexte (description, spec ou issue liée). Il reçoit aussi le périmètre de l'étape 0 et les remarques déjà
   faites ; les fichiers touchés hors périmètre servent de contexte, sans remarque. Il reçoit enfin les remarques
   bloquantes de soi encore ouvertes et dit pour chacune, vérifié dans le code, si elle est corrigée ou toujours là.
2. Grille, à recopier dans le brief : celle du projet (WORKFLOW.md, AGENTS.md, CONTRIBUTING.md), sinon la section
   « Grille qualité » de `~/.claude/skills/feature/SKILL.md`. Diff qui touche une API Angular → skill `angular-developer` aussi, comme dans
   `feature`. Bugs et sécurité d'abord, puis lisibilité ; chaque remarque est vérifiée dans le code, pas supposée.
   Pas de remarque de goût sans règle du projet derrière.
   Une remarque sur le même point qu'une remarque déjà faite (même fichier, ligne proche ou même symbole, même
   problème) n'est pas rendue, résolue ou non ; une remarque résolue dont le code a régressé est nouvelle.

   Quelle que soit la grille, deux règles s'appliquent toujours :
   - **Erreur avalée** (nature `bug`) : `catch` vide ou trop large, erreur journalisée puis ignorée, repli silencieux
     qui masque un échec (valeur par défaut, `|| true`, `2>/dev/null` sur une commande dont l'échec compte).
     Bloquant si l'échec perd ou corrompt des données, non-bloquant sinon.
   - **Test absent** (nature `test`) : code de production modifié qui porte une règle (branche, boucle, calcul,
     parseur) sans test qui l'exerce, ni dans la PR ni dans les tests existants. Non-bloquant ; bloquant pour le test
     de non-régression du défaut corrigé, absent d'un correctif de bug (branche `fix/…`, commit `fix` ou 🐛, issue de
     bug liée) sans vérification manuelle décrite dans la PR ou le rapport (décrite : question), les autres tests
     absents du correctif restant non-bloquants ; question dans un projet sans suite de
     tests (ni fichier de test : dossier de tests, `*.test.*`, `*.spec.*` ; ni commande de test dans le CLAUDE.md,
     l'AGENTS.md, le README, le `package.json` ou le Makefile), correctif de bug compris.

   Une ligne qui relève des deux règles donne une seule remarque `bug`, qui cite le test manquant, avec la plus
   forte des deux gravités (bloquant > non-bloquant > question).

   L'agent rend une liste JSON, sans rien publier :
   `{path, line, inDiff, nature, gravite, texte}` (`nature` : bug, sécurité, performance, test, lisibilité, doc,
   question ; `gravite` : bloquant, non-bloquant, question).
3. Criticité : skill `pr-risk` sur la PR (il tourne dans son propre agent), qui publie (ou met à jour) son
   commentaire de risque : niveau, nombre de relectures humaines, dangers à vérifier.
4. Publier au plus une review, jamais `REQUEST_CHANGES`. Remarques nouvelles → une review `COMMENT` :
   `gh api repos/<owner/repo>/pulls/<n°>/reviews --input <fichier>` avec `event: "COMMENT"`, un `body` de synthèse
   (la criticité reste dans le seul commentaire de `pr-risk`, ne pas la répéter), et un `comments` par remarque
   (`path`, `line` du nouveau fichier, `side: "RIGHT"`), en français, préfixé du gitmoji de sa nature (🐛 bug,
   🔒️ sécurité, ⚡️ performance, ✅ test, ♻️ lisibilité, 📝 doc, 💬 question) puis de `**[bloquant]**`,
   `**[non-bloquant]**` ou `**[question]**`, puis problème + suggestion (ou la question). `body` et commentaires passés par `humanizer:humanizer`, qui garde
   tels quels le gitmoji et le préfixe de gravité (l'`APPROVE` en dépend), comme les identifiants. Ligne hors du
   diff → dans le `body`, avec `fichier:ligne` et le même préfixe.
   Aucune remarque nouvelle → `APPROVE` seulement si la PR est d'un autre, que soi est relecteur demandé
   (`gh pr view <n°> --json reviewRequests` : son login, ou une équipe dont il est membre,
   `gh api orgs/<org>/teams/<slug>/memberships/<soi>` qui répond `active`) et qu'aucune remarque bloquante de soi
   (préfixe `**[bloquant]**`) n'est ouverte (fil non résolu, point hors fil qu'aucune réponse d'un autre ne cite).
   Corps court, passé par `humanizer:humanizer`. Commande de demande en échec (portée `read:org` manquante) : rien
   n'est publié, le rapport cite l'erreur. Sinon rien n'est publié : sa propre PR, pas de demande en cours (GitHub la retire à
   chaque review de soi, l'auteur la redemande), ou bloquantes ouvertes,
   listées dans le rapport, chacune marquée « corrigée, fil à résoudre » ou « toujours là ».
5. Rapport : verdict de `pr-risk` (niveau, relectures, dangers), lien de la review, remarques par gravité ; aussi le
   périmètre relu (depuis `<sha court>` ou complet), le nombre de remarques écartées comme déjà faites, et ce qui a
   été publié (review, approbation ou rien, avec la raison).
