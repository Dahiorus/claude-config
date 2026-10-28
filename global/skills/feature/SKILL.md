---
name: feature
description: Use when the user invokes /feature, asks to build, implement or ship a feature end to end (spec, plan, implementation, review, PR, merge), starts designing one (« on attaque… », « commence la spec », « rédige la spec », « écris le plan », « nouvelle feature »), or says « implémente le plan », « fais une review », « corrige 1 et M3 », « squash », « pousse la PR », « merge » on feature work. Not for fixing a bug or a regression (use bugfix).
---

# Feature

## Principe

Une feature suit toujours le même cycle, dans cet ordre. Chaque étape a son outil et son modèle. La pression
(« démo dans une heure ») ne raccourcit aucune étape : elle se signale à l'utilisateur, qui décide.

**Respecter la lettre du cycle, c'est en respecter l'esprit.**

## Le cycle

| # | Étape | Comment |
|---|---|---|
| 1 | Conception | Feature multi-couches : avant les questions, 2-3 agents `Explore` en parallèle (angles distincts : features voisines, flux de données entre couches, tests existants), chacun rend 5-10 fichiers clés à lire. Puis `superpowers:brainstorming` → spec dans `docs/superpowers/specs/`, avec les sections de fidélité (ci-dessous), **toujours** ouverte dans Plannotator (`plannotator-annotate` avec les arguments `<fichier de la spec> --gate --json`, mode approbation) : appliquer chaque annotation, rouvrir jusqu'à l'approbation. Les questions de clarification du brainstorming ne se posent pas dans le chat : la spec est rédigée tout de suite, chaque point que seul l'utilisateur peut trancher y devient un bloc `:::question` à l'endroit qu'il touche, avec contexte, choix et `Recommended:` (syntaxe et règles : skill `plannotator`, § « Asking the reviewer questions »). Les réponses reviennent en tête du retour : remplacer chaque bloc par la décision en prose, adapter la spec, rouvrir ; une question `Skipped` garde son bloc au tour suivant |
| 1b | Passage au plan | Dès `"decision": "approved"`, **sans demander** : (a) relire les annotations et les réponses aux questions jointes à l'approbation, appliquer chacune à la spec (aucun bloc `:::question` ne reste : une question non répondue prend la recommandation, notée comme telle) et commiter ; une annotation qui change le comportement ou la portée → rouvrir Plannotator (`--gate`) ; (b) vérifier chaque fichier de la section « Portée » : il existe, la signature ou le champ cité correspond au code actuel ; (c) chercher dans tout le dépôt (grep, LSP) les usages de chaque symbole, route, champ ou concept modifié : un usage absent de « Portée » → amender la spec et rouvrir Plannotator, sinon le noter pour le plan. Tout est cohérent → étape 2 dans la foulée. La spec change un contrat partagé avec un autre dépôt (API, format d'échange ; dépôt lié cité par AGENTS.md, CLAUDE.md ou la mémoire) → prévenir sa session avec le skill `notify` : ce qui change et le chemin absolu de la spec |
| 2 | Plan | `superpowers:writing-plans`, **fidèle à la spec** : aucun écart de signature, de champ d'API ni de code d'erreur. Table de traçabilité obligatoire (ci-dessous), avec les usages vérifiés à l'étape 1b ; chaque tâche cite les § de spec qu'elle implémente. Tâches sans fichier commun ni dépendance entre elles → regroupées en lot marqué « parallélisable », avec la liste des fichiers de chacune. Le code du plan respecte la grille qualité (ci-dessous). Si la spec tient mal face au code, proposer d'amender la spec. Plan commité **sur la branche `feat/…`** (il fait partie de la PR). Puis relecture du plan dans Plannotator (`plannotator-annotate` avec les arguments `<fichier du plan> --gate --json`, mode approbation) : appliquer chaque annotation, commiter, rouvrir jusqu'à l'approbation |
| 3 | `/clear` | Plan approuvé dans Plannotator, écrit dans cette session (ou session déjà utilisée) → **s'arrêter** et demander `/clear`, en donnant la commande de relance prête à copier : `/feature implémente @<chemin du plan>`. Ne jamais enchaîner |
| 4 | Exécution | `superpowers:subagent-driven-development`. Implémenteur **Sonnet**, dont le brief rappelle la grille qualité (ci-dessous). Contrôle par tâche **Haiku, effort low** : compilation + **tests du contexte borné entier** (`tests/<Contexte>`, pas seulement ceux de la tâche) + présence de chaque test nommé dans le brief et de la preuve du rouge dans le rapport, rien d'autre. Un écart de l'implémenteur au brief, même « pratique », revient au contrôleur, qui amende la spec ou fait corriger : jamais accepté en silence. Agents `sdd-implementer` / `sdd-task-reviewer` / `sdd-final-reviewer` du projet s'ils existent. Toujours passer le modèle explicitement. Lot « parallélisable » du plan : contrairement à la règle de `subagent-driven-development`, ses implémenteurs partent dans un même message, chacun avec `isolation: "worktree"` ; puis leurs commits se reportent sur la branche dans l'ordre du plan (`cherry-pick`) et le contrôle Haiku passe sur le résultat, tâche par tâche. Conflit au report ou fichier touché hors de sa liste → reprendre les tâches restantes du lot une par une |
| 5 | Vérification | Suite complète de tests + analyse statique, sortie lue. Une erreur d'environnement (base injoignable, port) se diagnostique, elle ne s'ignore pas |
| 6 | Recette | Si le plan en prévoit une : la faire soi-même dans le navigateur (Playwright), un appel par scénario comme dans `/pr recette` |
| 7 | Reviews | **Automatiques**, sans attendre de demande, dès la vérification (et la recette) au vert : `ponytail:ponytail-review` et review complète par **Opus** (`sdd-final-reviewer`, modèle passé explicitement) sur toute la branche, en parallèle. La review Opus vérifie d'abord la fidélité (demande initiale → spec → plan → code, ci-dessous) puis applique la grille qualité. Écrire les deux dans `.superpowers/sdd/<feature>/final-review.md`, numérotées une fois pour toutes (`P1…` pour ponytail, `C1…`, `I1…`, `M1…` par gravité pour Opus), puis **trier les points** (ci-dessous) : corriger d'office les « à corriger », rapporter les « à trancher », puis corriger ce que l'utilisateur retient (« corrige 1 et M3 », « corrige tout » = suivre les recommandations, y compris après un `/clear` : relire ce fichier) ; chaque point corrigé y reçoit son SHA. Un correctif qui change le comportement amende la spec d'abord. Les correctifs retenus faits, **sans attendre de demande** : le projet a un reste à faire (skill `todo`) → y rayer ce que la feature règle, ajouter les « hors périmètre » de la spec et les points de review non retenus (avec leur origine, §6 de la spec), commiter ; chaque point non retenu de `final-review.md` y reçoit la mention « reste à faire » |
| 8 | PR | Pousser la branche et ouvrir la PR avec le compte gh indiqué par la mémoire du projet (jeton ponctuel, sans changer le compte actif). La PR peut porter plusieurs commits, poussés tels quels. Reste à faire déjà à jour depuis l'étape 7 ; ce qui a changé depuis s'y reporte avant de pousser, comme le fait `/pr push` (étape 2) |
| 9 | Correctifs | Correctifs après la PR (review, recette) : retours triés comme à l'étape 7, puis nouveaux commits, `push` simple, sans réécriture |
| 10 | Squash | Avant le merge seulement, reste à faire à jour (étape 7) : un seul commit par feature (spec + plan + code), message qui résume la feature, `git reset --soft <merge-base>`. PR de plus de ~30-40 fichiers modifiés : un commit par pan fonctionnel métier. Puis `push --force-with-lease=<branche>:<sha attendu>` |
| 11 | Merge | `gh pr merge --rebase` (ou `--squash`), **jamais** `--merge`. Si un push sur main déploie : suivre le run jusqu'au succès |
| 12 | Nettoyage | Supprimer la branche distante, les branches locales de la feature (`feat/…`, `docs/…`) après avoir vérifié que main contient leur contenu ; repasser sur main à jour |
| 13 | Mémoire | Mettre à jour la mémoire du projet : PR, SHA de merge, déploiement. Ce qui reste à faire va dans le reste à faire versionné s'il existe, pas dans la mémoire |

Une demande peut couvrir plusieurs étapes (« implémente, squash »). L'exécution enchaîne d'elle-même vérification,
recette et reviews (étapes 5 à 7) : ne jamais demander s'il faut lancer les reviews. Pousser, ouvrir la PR et
merger attendent toujours une demande explicite de l'utilisateur.

## Fidélité à la demande

La demande de l'utilisateur est la référence ; la spec la précise, le plan l'argumente, le code l'exécute. Rien ne
s'ajoute ni ne se perd en route.

**Spec** — sept sections obligatoires, relues dans Plannotator :
1. **Demande initiale** : les mots de l'utilisateur, cités tels quels (et la recette ou le ticket d'origine s'il y en
   a). Toute exigence de la spec s'y rattache ; ce qui ne s'y rattache pas est retiré ou validé par l'utilisateur.
2. **Portée de chaque règle** : pour chaque règle nouvelle ou modifiée, la liste de tous les endroits qu'elle touche
   (écrans, boutons, champs, routes d'API, commandes, exports), établie en cherchant dans le code les usages de la
   donnée ou du concept, pas de mémoire. Chaque endroit dit ce qu'il devient, y compris « inchangé, parce que… ».
   Pour chaque donnée, colonne ou signature ajoutée ou modifiée : **tous ses lecteurs et écrivains**, dans le code
   serveur, l'interface, les gabarits et les exports, et dans les autres contextes ou modules qui la consomment
   (requêtes qui doivent la sélectionner, présentateurs, feuilles, imports). Un champ ajouté qu'un lecteur ne
   sélectionne pas, ou qu'un autre module ignore, est un oubli classique.
3. **Données existantes** : pour chaque validation ou contrainte ajoutée, ce que deviennent les enregistrements déjà
   en base qui ne la respectent pas (bloqués à l'enregistrement, corrigés par migration, tolérés).
4. **Critères d'acceptation** : cas nominaux, refus, et **cas combinés** (deux champs en erreur ensemble, deux règles
   qui se croisent, statut × état des données).
5. **Filet sur l'existant** : pour chaque fichier modifié dont le comportement actuel n'est couvert par aucun test,
   les tests de caractérisation à écrire **avant** de le modifier (comportement actuel figé, vert sur `main`), pour
   qu'une régression sur ce qui ne devait pas changer se voie. Le plan en fait sa première tâche.
6. **Origine** : chaque point traité (repris du reste à faire, d'une recette, d'une review) et chaque point laissé
   « hors périmètre » porte son origine : *régression* introduite par une PR (la citer), *défaut ancien* découvert,
   ou *hors périmètre* d'une spec (la citer). Le reste à faire reprend cette origine.
7. **Dette du code touché** : pour chaque méthode que la feature modifie, ses écarts à la grille qualité (longueur,
   dépendances du constructeur, absence de tests…), relevés en même temps que la portée. Chaque écart reçoit une
   décision dans Plannotator : *corrigé dans cette PR* ou *reporté au reste à faire*. Seulement les méthodes
   modifiées, jamais le fichier entier.

**Plan** — une table de traçabilité en tête : chaque exigence de la spec (§) → tâche → test qui la prouve ; pour
chaque fichier touché, les usages trouvés à l'étape 1b et ce qu'ils deviennent. Une
exigence sans test, ou une tâche sans exigence, est un défaut du plan. Les tests du plan couvrent les cas combinés
des critères d'acceptation. Un test existant que le plan rend faux est nommé dans la tâche qui le casse. Les tâches
s'enchaînent dans cet ordre, un commit chacune : tests de caractérisation (§5), refacto sans changement de
comportement (écarts *corrigés* du §7), puis la feature. Tout code du plan (classe, test, commande, extrait de
configuration) est présenté dans un bloc de code délimité par ```` ``` ```` et étiqueté avec son langage (`kotlin`,
`typescript`, `php`, `sql`, `bash`, `yaml`…), jamais en ligne dans la prose ni dans un bloc sans langage ; le chemin
du fichier précède le bloc.

**Exécution** — l'implémenteur prouve le rouge (sortie du test qui échoue, dans son rapport) avant d'écrire le code,
et lance les tests du contexte borné entier avant de commiter. Ce que le brief ne dit pas ne s'invente pas :
NEEDS_CONTEXT. Un test existant modifié est signalé avec sa raison.

**PHP : outil `LSP` (plugin `php-lsp`, Intelephense)** — dans un projet PHP, l'outil `LSP` sert à chaque étape qui
cherche ou modifie un symbole : portée de la spec et usages de l'étape 1b (`findReferences`, `incomingCalls`,
`workspaceSymbol`), implémentation (signature et type réels par `hover`/`goToDefinition` avant d'appeler une classe,
appelants par `findReferences` avant de changer une signature ou de supprimer une classe), review finale (lecteurs
oubliés). Le brief de l'implémenteur et la consigne du reviewer Opus le rappellent. Il **complète le grep sans le
remplacer** : il manque les appels dynamiques (`$this->{$m}()`, routes, chaînes, gabarits, JS) et les propriétés non
typées. Il n'indexe que le dépôt où la session a démarré : feature dans un worktree → session lancée depuis le
worktree, sinon `LSP` lit le code de `main` sans le dire (vérifier qu'un symbole de la branche est trouvé). Erreur
« no server » → `volta install intelephense` (ou `npm install -g intelephense`), puis redémarrer la session.

**Angular : skill `angular-developer`** — dans un projet Angular, l'invoquer au plan, à l'implémentation et à la
review finale dès que le code front touche une API Angular (signals, `linkedSignal`, `resource`, formulaires, DI,
routage, ARIA, tests de composants) ; le brief de l'implémenteur et la consigne du reviewer Opus le rappellent. Une
retouche de CSS ou de libellé n'en a pas besoin. Les conventions du projet (`AGENTS.md` du front) priment : ses
consignes `ng generate` et `ng build` cèdent à la vérification du projet.

**Review finale** — avant la grille qualité, Opus vérifie la chaîne : chaque phrase de la demande initiale est
couverte par la spec, chaque exigence de la spec par du code et un test, et le diff ne contient rien que la spec ne
demande. Un écart (ajout, omission, règle appliquée à une partie seulement de sa portée) est au moins Important.

## Tri des retours (review, recette, commentaires)

L'utilisateur ne lit que ce qui demande son avis. Avant de rapporter, chaque point est vérifié dans le code (esprit
`superpowers:receiving-code-review` : la review peut se tromper) et classé dans `final-review.md` :

- **À corriger** : point confirmé, correctif sans effet sur le comportement ni la portée, une seule façon raisonnable
  de faire. Corrigé d'office, un commit par point ou groupe cohérent, SHA reporté.
- **Écarté** : faux positif, écart imposé par le framework, hors grille. Une ligne de raison, rien à faire.
- **À trancher** : le correctif change le comportement ou la portée, touche la spec, ou plusieurs options se valent.
  2-3 lignes : impact concret, options, recommandation.

Le rapport dans le chat ne détaille que les « à trancher » ; les deux autres catégories tiennent en une ligne de
décompte avec renvoi au fichier. « Corrige tout » vaut « suis tes recommandations ». Dans le doute entre deux
catégories, « à trancher ».

## Grille qualité (plan, implémentation, review Opus)

But : du code qu'un humain relit sans effort. Entrée de la review : `git diff main...HEAD` et les fichiers qu'il
touche. Grille du projet (WORKFLOW.md, AGENTS.md) si elle existe, sinon celle-ci, adaptée au langage :

- **SOLID, KISS, DRY**, en particulier : branchement exhaustif sur un type fermé plutôt qu'une chaîne de tests de
  type ; une règle métier remontée dans le module partagé plutôt que copiée entre features, mais deux lignes
  semblables par hasard ne sont pas un doublon.
- **Object calisthenics** :
  1. un niveau d'indentation par fonction, deux au plus ;
  2. pas de `else` après un `return` : retour anticipé ou branchement exhaustif ;
  3. une primitive qui porte une règle métier devient un type ;
  4. une collection qui porte une règle devient un type à elle ;
  5. un seul point par ligne pour traverser des objets (`a.b.c.d`) ; chaînes de transformations permises, une étape
     par ligne ;
  6. pas d'abréviation dans les noms (`qty`, `cfg`, `mgr`) hors vocabulaire du domaine ;
  7. fonction ≤ 20 lignes (composant d'interface ≤ 40), fichier ≤ 200 lignes ;
  8. ≤ 4 dépendances par constructeur ;
  9. pas d'état mutable exposé : objets immuables, flux en lecture seule, *Tell, don't ask*.

Ne pas signaler : code généré, tests (longueur libre), écart imposé par le framework ou une API externe, dépassement
d'une ou deux lignes des seuils du point 7. Sortie : écarts classés par gravité, avec `fichier:ligne`, principe
enfreint et correctif attendu ; ou « conforme ».

## Excuses et réalité

| Excuse | Réalité |
|---|---|
| « Le contexte est frais, pas besoin de /clear » | Le `/clear` est exigé. On s'arrête et on le demande. |
| « Les commits sont propres, je les merge tels quels » | Au merge, une feature = un commit (un par pan fonctionnel métier au-delà de ~30-40 fichiers). On squash avant de merger. |
| « Pas le temps, je fais une review courte » | Review complète, ou on dit que ce n'est pas prêt. |
| « Les tests DB échouent, c'est l'environnement » | Diagnostiquer (port, conteneur) et relancer jusqu'au vert. |
| « Haiku peut aussi juger la qualité » | Non : compilation et tests seulement. La qualité, c'est Opus à la fin. |
| « Petit écart pratique au plan, je le signale » | Pas d'écart. On amende la spec. |
| « Le plan est clair, je le résume dans le chat » | Le plan passe par Plannotator, approuvé avant le `/clear`. |
| « Le code est court, je l'écris dans la phrase » | Tout code du plan va dans un bloc délimité, étiqueté avec son langage. |
| « La spec est courte, l'utilisateur la lira dans le chat » | La spec s'ouvre toujours dans Plannotator. |
| « Je pose d'abord mes questions dans le chat, une par une » | Non : elles vont dans la spec en blocs `:::question`, répondues dans Plannotator. |
| « Spec approuvée, je demande si je passe au plan » | Non : l'approbation déclenche l'étape 1b puis le plan. |
| « Approuvée, donc les annotations jointes ne comptent pas » | Si : elles s'appliquent à la spec avant d'écrire le plan. |
| « Fermé sans annotation, c'est approuvé » | Non : seul `"decision": "approved"` (bouton Approuver de `--gate`) vaut approbation. Une session fermée (`dismissed`) se rouvre ou se confirme dans le chat. |
| « La règle ne touche que ce champ » | Chercher ses usages dans le code et lister toute sa portée dans la spec. |
| « La nouvelle validation ne concerne que les nouvelles saisies » | Elle s'applique aussi aux données en base au prochain enregistrement : la spec dit ce qu'elles deviennent. |
| « La méthode était déjà longue avant moi » | La spec dit ce qu'elle devient (corrigée ou reportée au reste à faire). |
| « Les tests du plan passent, la tâche est finie » | Le contexte borné entier passe, et le rouge a été vu avant le code. |
| « Tests et code écrits d'un jet, c'est pareil » | Non : sans rouge constaté, le test ne prouve rien. |
| « Les retours de review sont dans le chat, ça suffit » | Ils vont dans `final-review.md` : le `/clear` les efface du chat. |
| « J'attends qu'on me dise de mettre à jour le reste à faire » | Non : il se met à jour seul dès les correctifs de review faits. |
| « L'utilisateur a dit « corrige tout », j'applique chaque point » | Chaque point est vérifié puis trié ; « tout » = les recommandations, les écartés restent écartés. |
| « Je rapporte tous les points, l'utilisateur triera » | Je trie ; seuls les « à trancher » demandent sa lecture. |
| « Je demande si l'utilisateur veut une review » | Non : ponytail-review et Opus se lancent seuls à la fin du développement. |

## Signaux d'alarme

- Implémenter dans la session qui a écrit le plan.
- Écrire le plan sans avoir cherché les usages des symboles modifiés.
- Lancer en parallèle des tâches que le plan n'a pas marquées « parallélisable », ou sans worktree isolé.
- Merger une PR à plusieurs commits, hors découpage par pan fonctionnel métier d'une PR de plus de ~30-40 fichiers.
- `gh pr merge --merge`, ou un `push --force` sans `--force-with-lease`.
- Supprimer ou déplacer un fichier de `src/` quand le déploiement ne supprime pas (rsync sans `--delete`) : le signaler avant le merge.
- Terminer sans mettre à jour la mémoire.
