---
name: feature
description: Use when the user invokes /feature, asks to build a feature end to end (spec, plan, implementation, review, then delivery through /pr), starts designing one (« commence la spec », « écris le plan »), says « implémente le plan », « corrige 1 et M3 » on feature work, or asks for the feature's report (`/feature report`, « fais un bilan de la feature »). Not for fixing a bug (use bugfix).
argument-hint: "[report] [consigne]"
---

# Feature

## Principe

Une feature suit toujours le même cycle, dans cet ordre. Chaque étape a son outil et son modèle. La pression
(« démo dans une heure ») ne raccourcit aucune étape : elle se signale à l'utilisateur, qui décide.

**Respecter la lettre du cycle, c'est en respecter l'esprit.**

## Le cycle

| # | Étape | Comment |
|---|---|---|
| 1 | Conception | Feature multi-couches : avant les questions, 2-3 agents `Explore` en parallèle, lancés avec `model: "haiku"` (angles distincts : features voisines, flux de données entre couches, tests existants), chacun rend 5-10 fichiers clés à lire. Puis skill `ddd` (analyse) sur la demande, avec les fichiers clés rendus par les `Explore` : la spec reprend son langage, ses contextes bornés et ses questions. Puis `superpowers:brainstorming` → spec dans `docs/superpowers/specs/`, avec les sections de fidélité (ci-dessous), passée à la validation fonctionnelle (ci-dessous), puis **toujours** ouverte dans Plannotator (`plannotator-annotate` avec les arguments `<fichier de la spec> --gate --json`, mode approbation) : appliquer chaque annotation, rouvrir jusqu'à l'approbation. Les questions de clarification du brainstorming ne se posent pas dans le chat : la spec est rédigée tout de suite, chaque point que seul l'utilisateur peut trancher y devient un bloc `:::question` à l'endroit qu'il touche, avec contexte, choix et `Recommended:` (syntaxe et règles : skill `plannotator`, § « Asking the reviewer questions »). Les réponses reviennent en tête du retour : remplacer chaque bloc par la décision en prose, adapter la spec, rouvrir ; une question `Skipped` garde son bloc au tour suivant |
| 1b | Passage au plan | Dès `"decision": "approved"`, **sans demander** : (a) relire les annotations et les réponses aux questions jointes à l'approbation, appliquer chacune à la spec (aucun bloc `:::question` ne reste : une question non répondue prend la recommandation, notée comme telle) et commiter, avec le glossaire mis à jour par `ddd` ; une annotation qui change le comportement ou la portée → rouvrir Plannotator (`--gate`) ; (b) vérifier chaque fichier de la section « Portée » : il existe, la signature ou le champ cité correspond au code actuel ; (c) chercher dans tout le dépôt (grep, LSP) les usages de chaque symbole, route, champ ou concept modifié : un usage absent de « Portée » → amender la spec et rouvrir Plannotator, sinon le noter pour le plan. Tout est cohérent → étape 2 dans la foulée. La spec change un contrat partagé avec un autre dépôt (API, format d'échange ; dépôt lié cité par AGENTS.md, CLAUDE.md ou la mémoire) → prévenir sa session avec le skill `notify` : ce qui change et le chemin absolu de la spec |
| 2 | Plan | `superpowers:writing-plans`, **fidèle à la spec** : aucun écart de signature, de champ d'API ni de code d'erreur. Table de traçabilité obligatoire (ci-dessous), avec les usages vérifiés à l'étape 1b ; chaque tâche cite les § de spec qu'elle implémente (« — » pour la tâche de mise à jour de la doc, voir **Plan**). Tâches sans fichier commun ni dépendance entre elles → regroupées en lot marqué « parallélisable », avec la liste des fichiers de chacune. Le code du plan respecte la grille qualité (ci-dessous). Découpage en PR (ci-dessous) écrit en tête du plan, avant la table de traçabilité. Si la spec tient mal face au code, proposer d'amender la spec. Plan commité **sur la branche `feat/…`** (il fait partie de la PR). Puis validation fonctionnelle du plan (ci-dessous), puis relecture du plan dans Plannotator (`plannotator-annotate` avec les arguments `<fichier du plan> --gate --json`, mode approbation) : appliquer chaque annotation, commiter, rouvrir jusqu'à l'approbation |
| 3 | `/clear` | Plan approuvé dans Plannotator, écrit dans cette session (ou session déjà utilisée) → **s'arrêter** et demander `/clear`, en donnant la commande de relance prête à copier : `/feature implémente @<chemin du plan>`. Ne jamais enchaîner |
| 4 | Exécution | `superpowers:subagent-driven-development`. Implémenteur **Sonnet**, dont le brief rappelle la grille qualité (ci-dessous). Contrôle par tâche **Haiku, effort low** : compilation + **tests du contexte borné entier** (`tests/<Contexte>`, pas seulement ceux de la tâche) + présence de chaque test nommé dans le brief et de la preuve du rouge dans le rapport (sortie ou résumé, voir « Exécution »), rien d'autre. Un écart de l'implémenteur au brief, même « pratique », revient au contrôleur, qui amende la spec ou fait corriger : jamais accepté en silence. Agents `sdd-implementer` / `sdd-task-reviewer` / `sdd-final-reviewer` du projet s'ils existent. Toujours passer le modèle explicitement. Lot « parallélisable » du plan : contrairement à la règle de `subagent-driven-development`, ses implémenteurs partent dans un même message, chacun dans un worktree créé par le contrôleur sur la tête de la branche (`git worktree add -b wt/task-<n> <dossier> HEAD`, `<dossier>` sous le répertoire de travail pour que le sandbox laisse écrire, avec les fichiers ignorés que le build exige, comme `local.properties`) : `isolation: "worktree"` part de `main` et disparaît si l'agent s'arrête sans commit. Le brief donne le chemin absolu du worktree : l'implémenteur y lit, écrit et commite (chemins absolus, `git -C <dossier>`), jamais dans le dépôt principal. Il rend son rapport dans sa réponse, le contrôleur l'écrit dans le dossier de suivi. Puis leurs commits se reportent sur la branche dans l'ordre du plan (`cherry-pick`) et le contrôle Haiku passe sur le résultat, tâche par tâche. Conflit au report ou fichier touché hors de sa liste → reprendre les tâches restantes du lot une par une. Dans tous les cas, en fin de lot : `git worktree remove --force <dossier>` et `git branch -D wt/task-<n>` (le `cherry-pick` change les SHA, `-d` refuse) |
| 5 | Vérification | Suite complète de tests + analyse statique, sortie lue. Une erreur d'environnement (base injoignable, port) se diagnostique, elle ne s'ignore pas. Le projet a un reste à faire → le mettre à jour et le commiter ici, avant les reviews : rayer ce que la branche règle, ajouter le hors périmètre de la spec (les points non retenus en review s'y ajoutent à `/pr push`) |
| 5b | Convergence | Vérification au vert : un agent **Sonnet** neuf (modèle passé explicitement) confronte le code à la spec et au plan, sans la conversation : chaque ligne de la table de traçabilité, chaque critère d'acceptation, chaque fichier de la portée ; en PR multiples, seulement ceux des tâches communes et des stories de cette PR (les suivantes sont ignorées). Il ne touche ni au code ni à la spec : chaque exigence absente ou partielle devient une tâche ajoutée à la fin de la story en cours (en fin de plan pour une PR unique), sous « Convergence N » (N : numéro du tour), avec le § de spec et le test attendu, puis commitée. Tâches ajoutées → retour à l'étape 4 pour elles seules, puis 5 et 5b. Rien à ajouter → « convergé », plan inchangé. Toujours pas convergé après 3 tours → s'arrêter et rapporter les écarts restants |
| 6 | Recette | Si le plan en prévoit une : la faire soi-même dans le navigateur (Playwright), un appel par scénario comme dans `/pr recette` (`~/.claude/skills/pr/recette.md`, étape 3), résultat dans `recette.md` du dossier de suivi (skill `pr`, « Dossier de suivi ») |
| 7 | Reviews | **Automatiques**, sans attendre de demande, dès la vérification (et la recette) au vert : `ponytail:ponytail-review` et review complète par **Opus** (`sdd-final-reviewer`, modèle passé explicitement) sur toute la branche, en parallèle. La review Opus vérifie d'abord la fidélité (demande initiale → spec → plan → code, ci-dessous) puis applique la grille qualité. Grille du projet ou non, elle cherche aussi les erreurs avalées et les tests absents, avec les règles de `/pr review` (`~/.claude/skills/pr/review.md`, étape 2) ; ses gravités deviennent I pour bloquant (C si l'échec perd ou corrompt des données), M pour non-bloquant, M rédigé en question pour question. Écrire les deux dans `final-review.md` du dossier de suivi (skill `pr`, « Dossier de suivi » : `<racine>/.superpowers/sdd/<sujet>/`, `<sujet>` = nom de la branche sans `<type>/`, donc `<sujet>-p<n>` pour les PR suivantes d'une feature en PR multiples, un fichier par story), numérotées une fois pour toutes (`P1…` pour ponytail, `C1…`, `I1…`, `M1…` par gravité pour Opus), puis **trier les points** (ci-dessous) : corriger d'office les « à corriger », rapporter les « à trancher », puis corriger ce que l'utilisateur retient (« corrige 1 et M3 », « corrige tout » = suivre les recommandations, y compris après un `/clear` : relire ce fichier) ; chaque point corrigé y reçoit son SHA. Un correctif qui change le comportement amende la spec d'abord. Les points non retenus restent dans `final-review.md` : `/pr push` les reporte au reste à faire et en issues. Enfin, noter les frictions de la session dans `lecons.md` |
| 8 | Livraison | Skill `pr`, qui porte toutes les étapes de la PR, sur demande explicite : `/pr push` (reste à faire, issues, PR, `pr-risk`), `/pr <n°> recette` et `/pr <n°> comments` pour les correctifs après la PR (triés comme à l'étape 7, `push` simple), `/pr <n°> merge` (reliquats, leçons, squash, CI, merge, déploiement, nettoyage, mémoire). En PR multiples, `pr` marque la story livrée dans le plan |

Une demande peut couvrir plusieurs étapes (« implémente, puis pousse »). L'exécution enchaîne d'elle-même vérification, convergence,
recette et reviews (étapes 5 à 7) : ne jamais demander s'il faut lancer les reviews. Pousser, ouvrir la PR et
merger attendent toujours une demande explicite de l'utilisateur : ce sont les actions de `/pr`.

## `report` : bilan de la feature

`/feature report` (« fais un bilan de la feature ») décrit la branche `feat/…` courante, à n'importe quelle étape,
sans rien modifier ni commiter. Il tient même après un `/clear`.

**Sources, lues avant d'écrire :** `git log` et `git diff --stat main...HEAD` (commits, fichiers, +/−), état
poussé/en cours ; la spec et le plan de la branche ; `final-review.md` et `recette.md` du dossier de suivi ; le reste à faire ; la PR (`gh` avec le
compte du profil du projet ; projet sans profil : compte actif). Le fonctionnel et les refactorings se confirment dans le diff, pas seulement dans
la spec : ce qui n'a pas été relu se dit à la fin.

**Forme** (titres omis s'ils sont vides) :
1. **En une phrase** : ce que la feature apporte et pourquoi, puis l'état de la branche (commits, fichiers, +/−,
   poussée ou non, PR avec lien, dernier SHA). En PR multiples : stories livrées (avec leur PR) et restantes.
2. **Fonctionnel** : tableau orienté utilisateur, *Écran ou objectif | Avant | Après* (ou *Objectif | Livré*),
   libellés réels entre guillemets.
3. **Couche par couche** : tableau *Couche | Apport* (domaine, lecture serveur ou API, base et migration, écrans,
   tests avec leur nombre).
4. **Refactorings** : extractions, déplacements, types introduits, méthodes découpées (avant → après en lignes) ;
   la dette du §7 de la spec, corrigée ou reportée.
5. **Bugs corrigés en route** : chacun avec sa cause en une ligne.
6. **Robustesse** : données existantes (§3 de la spec), compatibilité avec un ancien serveur ou client, mode
   dégradé.
7. **Vérification** : dernier passage des tests et de l'analyse statique, recette faite (tableau scénario | ✅/❌),
   points de review à trancher restants. Rien n'est relancé : dire de quand date le résultat.
8. **Ce qui reste** : liste numérotée (points du reste à faire avec leur numéro, hors périmètre, recette, review,
   squash, merge).

Finir par une ligne sur ce qui n'a pas été vérifié, puis proposer en une ligne de le publier en page.

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
4. **Critères d'acceptation**, groupés par **user story** priorisée (P1, P2…) : chaque story est un parcours
   utilisateur livrable, testable et démontrable seule, P1 étant le plus petit incrément utile. Chacune dit
   ce que voit l'utilisateur tant que la suivante n'est pas livrée (écran visible, masqué, désactivé). Une seule story
   suffit quand la demande ne se découpe pas. Pour chacune : cas nominaux, refus, et **cas combinés** (deux champs en erreur ensemble, deux règles
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
des critères d'acceptation. Un test existant que le plan rend faux est nommé dans la tâche qui le casse. Une tâche dont le test vise un symbole
encore absent l'écrit : « rouge attendu : échec de compilation ». Le plan d'un
changement de règle métier, de route, de contrat d'API ou de schéma a sa tâche de mise à jour de la doc du projet
(AGENTS.md, README…), avec le grep des termes retirés : elle ne s'ajoute pas au moment de la PR. Elle figure dans
la table avec « — » à la place du §, sans être un défaut du plan, et ferme chaque story concernée (le socle, pour
un changement dans les tâches communes) : la convergence (5b) la vérifie comme les autres lignes, le grep des termes
retirés tenant lieu de test. Les tâches
s'enchaînent dans cet ordre, un commit chacune : tests de caractérisation (§5), refacto sans changement de
comportement (écarts *corrigés* du §7), puis la feature. Tout code du plan (classe, test, commande, extrait de
configuration) est présenté dans un bloc de code délimité par ```` ``` ```` et étiqueté avec son langage (`kotlin`,
`typescript`, `php`, `sql`, `bash`, `yaml`…), jamais en ligne dans la prose ni dans un bloc sans langage ; le chemin
du fichier précède le bloc.

**Validation fonctionnelle** — avant la première ouverture dans Plannotator de la spec, puis du plan : skill `ddd`
en mode `revue` sur le document (`revue spec <spec>`, `revue plan <plan> <spec>`), sans l'avis de l'auteur. Ses « à corriger » s'appliquent avant l'ouverture, ses « à trancher » deviennent
des blocs `:::question` à l'endroit qu'ils touchent. Les réouvertures suivantes ne le relancent pas, sauf si les
annotations changent le comportement ou la portée.

**Découpage en PR** — le plan regroupe ses tâches par story, dans l'ordre des priorités, après les tâches
communes (caractérisation, refacto, socle partagé). Il estime les fichiers touchés hors tests, spec et plan : plus de
~15 → une PR par story, sinon une seule PR. Une story seule au-delà de ~15 se découpe aussi, en stories techniques
sans effet visible : le socle (structure ajoutée, double écriture, lecteurs) avant la story, le retrait de l'ancienne
structure (DROP de colonnes ou de tables, fin des écritures de transition) après elle ; chacune a sa PR, est
titrée « Story technique : … » et se marque « livrée » comme une story. En PR multiples, la première porte spec, plan, tâches communes et P1 ;
chaque suivante part de `main` après le merge de la précédente, sur `feat/<sujet>-p<n>`, et refait les étapes 3 à
8 pour sa story (relance : `/feature implémente @<chemin du plan>`, qui reprend la première story non marquée « livrée » ;
`/feature report` liste les stories livrées et restantes). Une story qui ne compile ou ne se
teste pas sans la suivante est mal découpée : la fusionner avec elle.

**Exécution** — avant d'écrire le code, l'implémenteur prouve le rouge dans son rapport : la sortie du test qui échoue,
ou un résumé qui nomme chaque test en échec avec son assertion ou son erreur. Le résumé vaut pour les tests ajoutés
comme pour les tests existants modifiés, et le contrôle l'accepte. Un échec de compilation (symbole encore absent) prévu par le plan vaut rouge : le brief de l'implémenteur et celui du contrôle le disent, et le contrôle ne le refuse pas. L'implémenteur lance les tests du contexte borné entier avant de commiter. Ce que le brief ne dit pas ne s'invente pas :
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
couverte par la spec, chaque exigence de la spec par du code et un test (en PR multiples : celles des tâches communes et des stories livrées jusqu'à cette PR), et le diff ne contient rien que la spec ne
demande, hors la tâche de mise à jour de la doc (voir **Plan**). Un écart (ajout, omission, règle appliquée à une partie seulement de sa portée) est au moins Important.

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
  Un type plus large que les valeurs réellement produites (map, retour, paramètre), qui oblige un `when` à des
  branches inatteignables, se restreint au sous-type scellé produit. Si la spec impose le type large, on amende la
  spec plutôt que de garder les branches mortes.
- **Object calisthenics** :
  1. un niveau d'indentation par fonction, deux au plus ;
  2. pas de `else` après un `return` : retour anticipé ou branchement exhaustif ;
  3. une primitive qui porte une règle métier devient un type ;
  4. une collection qui porte une règle devient un type à elle ;
  5. un seul point par ligne pour traverser des objets (`a.b.c.d`) ; chaînes de transformations permises, une étape
     par ligne ;
  6. pas d'abréviation dans les noms (`qty`, `cfg`, `mgr`) hors vocabulaire du domaine ;
  7. fonction ≤ 20 lignes (composant d'interface ≤ 40), fichier ≤ 200 lignes ; un fichier déjà au-delà avant la
     branche ne se signale que s'il grossit de plus de deux lignes, et part au reste à faire plutôt qu'en découpage
     imposé ;
  8. ≤ 4 dépendances par constructeur ;
  9. pas d'état mutable exposé : objets immuables, flux en lecture seule, *Tell, don't ask*.
- **Texte (skills, spec, docs)** : un nombre annoncé (« deux règles », « 3 commandes ») est égal au nombre d'éléments listés.
  Un chiffre mesuré (lignes d'un fichier, nombre de tests) cité dans la spec ou la PR se remesure après le dernier
  correctif. Une requête d'API (GraphQL, REST, SQL) écrite dans un skill, le plan ou le code se lance contre l'API dès le plan.
  Une règle ou une définition reprise dans plusieurs fichiers (skills, `docs/domaine.md`, spec) dit la même chose
  partout : chercher sa formulation par grep et signaler chaque copie absente ou divergente. Une règle ajoutée à une
  étape vaut aussi pour les autres étapes qui produisent le même objet (description de PR, commit, worktree) : les trouver par grep.
  Une exception à une règle générale se reporte sur chaque copie de cette règle, dans le même fichier compris : grepper
  toutes ses formulations (synonymes compris : traçabilité, « rien que la spec ne demande ») avant le premier push.
  Ce que la description de PR ou un message de commit annonce se retrouve dans le diff. Après un `sed -i` ou un
  remplacement en masse, vérifier le diff (`git diff --stat`) : un motif absent ne remplace rien, sans erreur.

Ne pas signaler : code généré, tests (longueur libre), écart imposé par le framework ou une API externe, dépassement
d'une ou deux lignes des seuils du point 7. Sortie : écarts classés par gravité, avec `fichier:ligne`, principe
enfreint et correctif attendu ; ou « conforme ».

## Excuses et réalité

| Excuse | Réalité |
|---|---|
| « Le contexte est frais, pas besoin de /clear » | Le `/clear` est exigé. On s'arrête et on le demande. |
| « Pas le temps, je fais une review courte » | Review complète, ou on dit que ce n'est pas prêt. |
| « Les tests DB échouent, c'est l'environnement » | Diagnostiquer (port, conteneur) et relancer jusqu'au vert. |
| « Haiku peut aussi juger la qualité » | Non : compilation et tests seulement. La qualité, c'est Opus à la fin. |
| « Petit écart pratique au plan, je le signale » | Pas d'écart. On amende la spec. |
| « Les tests passent, tout le plan est implémenté » | La convergence (5b) compare le code à la spec ; tant qu'elle ajoute des tâches, ce n'est pas fini. |
| « Une seule grosse PR, c'est plus simple » | Plus de ~15 fichiers hors tests, spec et plan : une PR par story ; une story seule sépare son socle et le retrait de l'ancienne structure. |
| « J'ai écrit la spec, je sais qu'elle tient fonctionnellement » | `ddd revue` la déroule parcours par parcours avant Plannotator, puis le plan. |
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
| « L'utilisateur a dit « corrige tout », j'applique chaque point » | Chaque point est vérifié puis trié ; « tout » = les recommandations, les écartés restent écartés. |
| « Je rapporte tous les points, l'utilisateur triera » | Je trie ; seuls les « à trancher » demandent sa lecture. |
| « Je demande si l'utilisateur veut une review » | Non : ponytail-review et Opus se lancent seuls à la fin du développement. |

## Signaux d'alarme

- Implémenter dans la session qui a écrit le plan.
- Écrire le plan sans avoir cherché les usages des symboles modifiés.
- Lancer en parallèle des tâches que le plan n'a pas marquées « parallélisable », ou sans worktree isolé.
