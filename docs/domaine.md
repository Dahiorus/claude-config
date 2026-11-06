# Glossaire du domaine

## Contexte : Profils

Responsabilité : dire quels réglages (plugins, skills, compte gh) valent pour un projet · Dans le code : `global/profile.sh`, `global/profiles.json`, skill `/profile` · Dépend de : rien (source amont des comptes gh)

| Terme | Définition métier | Dans le code | À ne pas dire |
|---|---|---|---|
| Profil | Ensemble de réglages propre à une famille de projets (vidal, perso) : plugins, skills, compte gh | clé de `profiles.json`, `env.CLAUDE_PROFILE` | configuration, environnement |
| Propriétaire du dépôt | Compte ou organisation GitHub qui possède le dépôt `origin` du projet | `origin_owner`, `owners` | organisation (seule), auteur |
| Profil détecté | Profil que désigne le propriétaire du dépôt | `profile.sh detect` | profil courant |
| Profil appliqué | Profil écrit dans les réglages locaux du projet, au démarrage ou à la main | `profile.sh current`, `CLAUDE_PROFILE` | profil actif |
| Compte du profil | Compte gh avec lequel on agit sur un projet, déduit du profil détecté | `profile.sh account`, `.account` | compte actif, compte courant |
| Compte actif | Compte gh par défaut de la machine, celui de `gh auth switch` | `gh auth status` (Active account) | compte du projet |
| Jeton ponctuel | Jeton d'un compte donné, passé à une seule commande ou un seul processus sans changer le compte actif | `GH_TOKEN=$(gh auth token -u <compte>)` | switch de compte |
| Projet sans profil | Projet dont le propriétaire n'est dans aucun profil, ou sans `origin` GitHub | `account` vide | projet inconnu |

Invariants : le compte du profil suit le propriétaire du dépôt, jamais le profil appliqué ; le compte actif n'est jamais changé ; un projet sans profil garde la configuration globale.

## Contexte : Statusline

Responsabilité : afficher l'état du projet (branche, PR, revue, CI, consommation) sans jamais bloquer · Dans le code : `global/statusline-command.sh`, appels `gh` dans `global/statusline-gh.sh` · Dépend de : Profils (en aval, via `profile.sh account`), GitHub (via `gh`)

| Terme | Définition métier | Dans le code | À ne pas dire |
|---|---|---|---|
| Compte de la statusline | Compte gh dont la statusline prend le jeton pour lire les PR du dépôt | `gh_user`, cache `ghuser-<dépôt>` | compte actif |
| Compte qui voit le dépôt | Repli quand le compte du profil manque (projet sans profil, compte invalide ou non connecté dans gh) : premier compte connecté de gh qui peut lire le dépôt. Sa recherche s'appelle la *sonde* | `probe_gh_user` (boucle sur `gh auth status` + `gh api repos/<dépôt>`), cache `ghuser-<dépôt>` | compte du profil |

Invariants : la statusline ne lit pas `profiles.json` elle-même, elle demande le compte à Profils ; elle ne change pas le compte actif (jeton ponctuel pour son seul processus).

## Contexte : Relecture de PR

Responsabilité : relire une PR (la sienne ou celle d'un autre) et publier une seule review : ses remarques, ou une approbation quand rien n'est nouveau sur une PR où sa relecture est demandée ; jamais un refus · Dans le code : `global/skills/pr/review.md` · Dépend de : Criticité (`pr-risk`, en parallèle, publie son propre commentaire), grille qualité de `feature` (en aval, recopiée dans le brief faute de grille du projet)

| Terme | Définition métier | Dans le code | À ne pas dire |
|---|---|---|---|
| Relecture | Lecture critique du diff d'une PR contre sa base, du code touché et de son contexte (description, spec, issue) | `/pr review` | revue de code (ambigu avec la review finale de `/feature`) |
| Agent de relecture | Le relecteur unique qui produit les remarques, hors de la session | agent `general-purpose`, `opus` | reviewer Opus (c'est celui de `/feature`) |
| Grille | Règles contre lesquelles une remarque se justifie : celle du projet, sinon la grille qualité de `feature` | `WORKFLOW.md`, `AGENTS.md`, `CONTRIBUTING.md`, § « Grille qualité » | checklist, bonnes pratiques |
| Remarque | Écart vérifié dans le code, avec sa nature et sa gravité, publié comme commentaire de ligne ou dans la synthèse | `{path, line, inDiff, nature, gravite, texte}` | finding, suggestion |
| Nature | Ce que la remarque touche : bug, sécurité, performance, test, lisibilité, doc, question | `nature`, gitmoji | catégorie, aspect |
| Gravité | Poids de la remarque pour le merge : bloquant, non-bloquant, question | `gravite` | sévérité, criticité |
| Review publiée | L'unique review d'une relecture : `COMMENT` avec la synthèse et toutes les remarques, ou `APPROVE` quand rien n'est nouveau | `gh api …/reviews`, `event: "COMMENT"` ou `"APPROVE"` | — |
| Erreur avalée | Échec masqué (catch vide ou trop large, erreur journalisée puis ignorée, repli silencieux) sur une opération dont l'échec compte | nature `bug` | silent failure |
| Test absent | Code de production modifié qui porte une règle (branche, boucle, calcul, parseur) sans test qui l'exerce, ni dans la PR ni dans les tests existants | nature `test` | couverture manquante |
| Correctif de bug | PR qui corrige un défaut : branche `fix/…`, commit `fix` ou 🐛, ou issue de bug liée | `fix/…`, 🐛 | hotfix |
| Projet sans suite de tests | Projet sans fichier de test (dossier de tests, `*.test.*`, `*.spec.*`) ni commande de test (CLAUDE.md, AGENTS.md, README, `package.json`, Makefile) | — | projet non testé |
| Criticité | Danger de la PR et nombre de relectures humaines qu'elle demande, dans un commentaire à part | skill `pr-risk` | gravité |
| Agent spécialisé | Relecteur limité à un angle (tests, erreurs avalées, commentaires, types), fourni par le plugin `pr-review-toolkit`. Non utilisé : ses deux angles utiles sont des règles de l'agent de relecture | `pr-test-analyzer`, `silent-failure-hunter`, `comment-analyzer`, `type-design-analyzer` | sous-reviewer |
| Soi | Le compte du profil du projet, celui avec lequel `/pr` publie | `profile.sh account`, jeton ponctuel | moi, compte actif |
| Remarque déjà faite | Remarque qu'un relecteur (soi compris) a déjà publiée sur le même point, en fil, dans le `body` d'une review ou en commentaire de la conversation (hors `pr-risk` et bots), résolue ou non | fils, `body` des reviews et commentaires de la conversation de la PR | doublon |
| Dernière relecture | La plus récente review de soi au `body` non vide et d'état autre que `PENDING` (les réponses aux fils créent des reviews vides, un brouillon est `PENDING`), et le commit qu'elle a relu | `reviews[].commit_id` | dernière review |
| Demande de relecture | PR ouverte dont la relecture est demandée à soi ou à une de ses équipes | `review-requested:@me` sous jeton ponctuel | PR à valider |

Invariants : une relecture publie au plus une review, jamais `REQUEST_CHANGES` ; `APPROVE` seulement sans remarque nouvelle, sur une PR d'un autre où soi est relecteur demandé, sans remarque bloquante de soi ouverte ; une remarque de goût sans règle de la grille derrière n'est pas publiée ; chaque remarque est vérifiée dans le code ; la criticité ne se répète pas dans la review ; la session ne reçoit que les remarques, jamais le diff ; une remarque déjà faite n'est pas republiée ; le périmètre incrémental (depuis la dernière relecture) ne vaut que sans push forcé, squash, rebase ni merge de la base depuis, sinon diff complet contre la base : le code des PR déjà mergées n'est pas relu.

## Contexte : Retours de PR

Responsabilité : traiter ce que les relecteurs ont écrit sur une PR (corriger, écarter, faire trancher) et leur répondre · Dans le code : `global/skills/pr/comments.md` · Dépend de : Relecture de PR (en amont : ses remarques hors diff arrivent dans le `body` de sa review, préfixées de `fichier:ligne`), tri de `feature` (§ « Tri des retours »), Profils (soi = compte du profil)

| Terme | Définition métier | Dans le code | À ne pas dire |
|---|---|---|---|
| Fil | Discussion attachée à une ligne du diff, que seul le relecteur résout | `reviewThreads`, `isResolved` | commentaire (seul) |
| Fil en attente de soi | Fil non résolu, pas ouvert par un bot, dont le dernier commentaire n'est pas de soi, ou fil de soi seul, sans aucune réponse | `comments(first: 1)`, `comments(last: 1)`, `totalCount` | fil non résolu (plus large) |
| Retour hors fil | Remarque écrite ailleurs que dans un fil : commentaire de la conversation de la PR ou `body` d'une review, dont les remarques hors diff de `/pr review` ; un commentaire de conversation de soi est une réponse, pas un retour | `issues/<n°>/comments`, `reviews[].body` | commentaire général |
| Retour | Fil en attente de soi ou retour hors fil, à trier | — | feedback |

Invariants : un fil n'est jamais résolu par soi ; un retour hors fil se rattache à `fichier:ligne` quand son texte le permet, sinon il vaut pour toute la PR ; le commentaire de criticité (`<!-- pr-risk -->`) et ceux des bots ne sont pas des retours.

## Contexte : Livraison

Responsabilité : merger une PR et garder ce qui servira aux sessions suivantes · Dans le code : `global/skills/pr/merge.md` · Dépend de : Profils (compte du profil pour pousser)

| Terme | Définition métier | Dans le code | À ne pas dire |
|---|---|---|---|
| Mémoire du projet | Notes que les sessions futures relisent, hors dépôt : pièges et décisions seulement | `~/.claude/projects/<projet>/memory/` | historique, journal |
| Piège | Comportement inattendu d'un outil ou du dépôt, avec le contournement | ligne « Pièges » de la mémoire | leçon (celle-ci va dans `lecons.md`) |
| Décision | Choix de l'utilisateur à ne pas reproposer, avec sa raison | ligne « Décisions » de la mémoire | préférence |

Invariants : la mémoire ne recopie pas ce que git ou GitHub savent déjà (n° de PR, SHA, date de merge, commits) ; ce qui reste à faire va dans le reste à faire versionné s'il existe ; sinon un bug ou un point hors périmètre devient une issue GitHub, proposée puis créée après accord, jamais la mémoire.

## Contexte : Réglages

Responsabilité : écrire `~/.claude/settings.json` depuis le dépôt · Dans le code : `settings/base.json`, `bin/claude-config install|capture` · Dépend de : rien

Invariants : `install` n'écrit que `base.json` (+ `local.json`), donc tout hook voulu sur la machine y figure, sonar-secrets compris (PreToolUse `Read` et UserPromptSubmit), chacun sans effet quand son script manque.
