# Grille qualité

Lue au plan, à l'implémentation et en review (`feature`, `bugfix`, `pr`), faute de grille du projet.

But : du code qu'un humain relit sans effort. Entrée de la review : `git diff main...HEAD` et les fichiers qu'il
touche. Grille du projet (WORKFLOW.md, ou un AGENTS.md qui en tient une complète) si elle existe, sinon celle-ci,
adaptée au langage et amendée par les conventions de l'`AGENTS.md` du projet (mapper champ à champ toléré au-delà de
20 lignes, par exemple) :

- **SOLID, KISS, DRY**, en particulier : branchement exhaustif sur un type fermé plutôt qu'une chaîne de tests de
  type ; une règle métier remontée dans le module partagé plutôt que copiée entre features, mais deux lignes
  semblables par hasard ne sont pas un doublon. Un doublon corrigé : chercher ses autres copies par grep (SQL, JS,
  gabarits) et les remplacer dans le même correctif.
  Un type plus large que les valeurs réellement produites (map, retour, paramètre), qui oblige un `when` à des
  branches inatteignables, se restreint au sous-type scellé produit. Si la spec impose le type large, on amende la
  spec plutôt que de garder les branches mortes.
- **Object calisthenics** :
  1. un seul niveau de contrôle par fonction (`if`, `when`/`switch`, boucles, `try`, toute lambda passée à une
     fonction d'ordre supérieur : `map`, `filter`, `forEach`, `let`…) : pas de `if` dans une boucle, on extrait une
     fonction nommée ; les blocs d'échafaudage d'une bibliothèque ou d'un framework (par exemple coroutine
     `launch`/`withContext`, mise en page Compose `Column`/`Row`/`Box`) ne comptent pas. Exemple : `for (card in
     cards) { if (card.isOwned) total += card.price }` devient `cards.sumOf(::ownedValue)`, avec `ownedValue` qui
     porte le `if` ;
  2. pas de `else` après un `return` : retour anticipé ou branchement exhaustif ;
  3. une primitive qui porte une règle métier devient un type ;
  4. une collection qui porte une règle devient un type à elle ;
  5. un seul point par ligne pour traverser des objets (`a.b.c.d`) ; chaînes de transformations permises, une étape
     par ligne. La règle vaut aussi pour les noms et les accès que la spec fixe : un renommage qui donne
     `$a->b->b->value` se règle par une méthode (`storedCode()`) que la spec nomme (écrite dès la spec, sinon amendée
     par le contrôleur
     comme tout écart, `feature` étape 4), et une chaîne corrigée sur un champ se corrige sur
     ses voisins de même forme (`->face?->value`) ;
  6. pas d'abréviation dans les noms (`qty`, `cfg`, `mgr`) hors vocabulaire du domaine ; aucun nom (variable,
     paramètre, méthode, test, aide de test) ne reprend un mot de la colonne « À ne pas dire » du glossaire du projet,
     ni le terme du
     glossaire d'une autre notion (`$value` qui porte une notation) ; vérifié par grep de chaque mot de la colonne
     sur les lignes ajoutées (`git diff main...HEAD -U0 | grep '^+'`), chaque occurrence jugée à son sens (« série »
     pour une volée), jamais à la lecture ;
  7. fonction ≤ 20 lignes (composant d'interface ≤ 40), fichier ≤ 200 lignes (fichier de test ou de fixtures : pas
     de seuil de taille, découpé seulement s'il mêle plusieurs rôles) ; un fichier déjà au-delà avant la
     branche ne se signale que s'il grossit de plus de deux lignes, et part au reste à faire plutôt qu'en découpage
     imposé ;
  8. ≤ 4 dépendances par constructeur ;
  9. pas d'état mutable exposé : objets immuables, flux en lecture seule, *Tell, don't ask*.

  Script shell : 3, 4, 5, 8 et 9 sans objet ; 1 assoupli (un `if` dans une boucle reste, une fonction extraite
  rendrait son résultat par `$( )` ou une globale) ; fichier sans seuil de 200 lignes, découpé seulement s'il mêle
  plusieurs rôles (un `source` de plus est un chemin de plus à résoudre).
- **Texte (skills, spec, docs)** : un nombre annoncé (« deux règles », « 3 commandes ») est égal au nombre d'éléments
  listés.
  Un seuil de taille promis au plan (« fichiers sous 200 lignes ») s'établit sur la somme des lignes réellement
  déplacées, commentaires de documentation, imports et annotations compris, mesurée avant de fixer le découpage.
  Une affirmation sur le comportement actuel du code (plan, Review Focus, brief) se vérifie dans
  `git show origin/main:<fichier>`, pas de mémoire (une garde mal lue avait fait écrire un écart inexistant).
  Un chiffre mesuré (lignes d'un fichier, nombre de tests) cité dans la spec ou la PR se remesure après le dernier
  correctif. Un extrait que le plan recopie de la spec (ligne d'état, table, liste ordonnée, message) lui est
  identique, ordre compris : relu contre la spec, pas seulement contre le code ; un code conforme au plan mais pas à
  la spec est un écart, jamais justifié par « le code suit le plan ». Une requête d'API (GraphQL, REST, SQL) ou une
  commande (grep, git, pathspec) écrite dans un skill, le plan ou le code se lance dès le plan, contre l'API ou un
  dépôt d'essai ; une commande suggérée en review aussi, avant de la recopier.
  Une commande prescrite dont un fragment varie se joue avec un fragment en tête `-` (il faut alors `-e`), une
  apostrophe et un backtick.
  Une liste dans une règle ou une définition dit si elle est fermée ou ne donne que des exemples (« par exemple »,
  « … ») ; fermée, elle couvre tous les cas de la portée annoncée, et un mot de portée (« du langage », « de Java »)
  ne restreint pas une règle voulue générale. Un pronom ou une incise (« il », « celle-ci », « qui ») dont deux noms
  de la phrase précédente peuvent être le référent se remplace par le nom. Un fichier, un skill ou une étape se cite
  par son nom ou son chemin complet, jamais par « il » ou « celles » loin de son antécédent ; pas de parenthèses
  imbriquées ni de deux parenthèses accolées. Une contrainte chiffrée imposée à un agent (« 2 à 5 phrases ») se
  fait compter avant de rendre : sans cela elle n'est pas tenue. Un paragraphe ajouté à un texte existant s'insère
  entre deux paragraphes, jamais au milieu : relire les phrases qui suivent (« Ses », « d'abord » perdent leur repère).
  Une règle ou une définition reprise dans plusieurs fichiers (skills, `docs/domaine.md`, spec) dit la même chose
  partout : chercher sa formulation par grep et signaler chaque copie absente ou divergente. Une règle ajoutée à une
  étape vaut aussi pour les autres étapes qui produisent le même objet (description de PR, commit, worktree) : les
  trouver par grep.
  Une exception à une règle générale se reporte sur chaque copie de cette règle, dans le même fichier compris : grepper
  toutes ses formulations (synonymes compris : traçabilité, « rien que la spec ne demande ») avant le premier push.
  Une liste ou un critère déjà défini dans un autre fichier (gravité, filtre, requête) se cite par son chemin et son
  étape, jamais par une copie abrégée : elle dérive, et ne couvre pas les cas que la recette simule. Un renvoi à une
  commande ou à une donnée (« comme `approvals` ») se vérifie en relisant la commande citée : rend-elle bien
  le champ dont la règle a besoin (une date, pas seulement un login) ?
  Une règle qui porte sur un ensemble (fil de commentaires, liste, lot) dit si elle vaut pour le premier élément ou
  pour chacun. La recette prévoit un cas où l'élément qui décide n'est pas le premier (bloquant ajouté dans un fil).
  Ce que la description de PR ou un message de commit annonce se retrouve dans le diff, et chaque commande qu'elle cite
  (grep de vérification) applique les règles que la PR ajoute. Un exemple qu'une règle donne (motif, commande,
  renommage) se lance sur son propre cas avant le push : il fait ce que la règle annonce. Après un `sed -i` ou un
  remplacement en masse, vérifier le diff (`git diff --stat`) : un motif absent ne remplace rien, sans erreur ; un
  motif sans borne de mot touche aussi les noms qui le contiennent (`$value` → `$notation` change aussi `$values` en
  `$notations`) : `\b` après le nom (`\$value\b`), devant seulement si le motif commence par une lettre (`$` n'est
  pas un caractère de mot), ou `git grep -w`.
  Étape de skill qui ajoute une commande `gh`, `git` ou une API : l'écrire avec ce qui se passe quand elle échoue
  (tout le lot refusé ? reprise ? message cité), qui elle vise quand « l'auteur », « le relecteur » ou « chaque
  retour » a plusieurs lectures (fil, bot, soi-même), et ce que le rapport dit de son effet, y compris quand rien
  n'est parti.

Ne pas signaler : code généré, longueur d'un test, taille d'un fichier de test ou de fixtures (point 7),
largeur des lignes, écart imposé par le framework ou une API externe, dépassement
d'une ou deux lignes des seuils du point 7. Sortie : écarts classés par gravité, avec `fichier:ligne`, principe
enfreint et correctif attendu ; ou « conforme ».
