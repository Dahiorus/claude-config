# Contribuer

Les conventions de code, d'architecture et de tests sont dans [AGENTS.md](AGENTS.md). Ce document fixe uniquement
la rédaction des commits.

## Format des commits

- Écrire en **français** (langue du produit et de la documentation), vocabulaire métier du domaine
- Décrire brièvement le changement
- Justifier pourquoi il a été fait ainsi

### Format : par l'exemple

Le format adapte [gitmoji](https://gitmoji.dev/) et les recommandations officielles de git.

```Markdown
✨ domain: Refuser une quantité négative

 `Quantity::parse` acceptait les valeurs négatives ; le formulaire ne les
produit pas, mais un import de fichier le rendrait possible, pour :

 - [X] Afficher « Quantité invalide » au lieu d'enregistrer
 - [X] Couvrir zéro et les négatifs dans le test
 - [ ] Signaler la ligne fautive de l'import (plus tard)
```

### Format : spécification

#### Le sujet du commit est

1. obligatoire
2. court : **50 caractères au plus**, étiquette de zone exclue
    - ✔ `Refuser une quantité négative`
    - ✗ `Refuser une quantité lorsque la valeur saisie est inférieure à zéro`
3. un titre : il commence par une majuscule et ne se termine pas par une ponctuation
    - ✔ `Corriger le tri de la liste vide`
    - ✗ `corriger le tri de la liste vide`
    - ✗ `Corriger le tri de la liste vide.`
4. à l'impératif : il ordonne au patch de faire quelque chose
    - ✔ `Corriger le tri de la liste vide`
    - ✗ `Corrige le tri…` (présent)
    - ✗ `Corrigé le tri…` (passé)
    - ✗ `Correction du tri…` (nom)
5. autoportant : on comprend l'idée sans contexte
    - ✔ `Corriger le tri de la liste vide`
    - ✗ `Corriger le bug de la liste` (quel bug ?)
    - ✗ `Corriger #134` (que corrige-t-on ?)
6. délimité par une étiquette de zone **facultative**, en minuscules, qui nomme le module ou le contexte touché
   (`domain`, `data`, `ui`, `app`, `docs`, `build`…), séparée du titre par `: `. Le séparateur sert aux outils
   qui analysent les messages ; l'étiquette ne compte pas dans les 50 caractères.
    - ✔ `✨ domain: Ajouter la limite de quantité par article`
    - ✔ `♻️ Unifier les conversions de montants` (changement transverse : pas d'étiquette)
    - ✗ `Domain: …` (minuscules)
    - ✗ `domain Ajouter…` (il manque le `: `)

   Il n'y a pas de gestionnaire de tickets : ne pas inventer de référence.
7. catégorisé par un emoji [Unicode](https://unicode-table.com/en), placé en tête
> Ne pas utiliser les codes emoji markdown de GitHub (`:sparkles:`) dans le sujet : ils sont illisibles dans
> `git log`. Les réserver au corps.

    - `🐛 domain: Corriger l'arrondi des totaux`
    - `♻️ domain: Extraire la validation des identifiants`
    - `🔥 Supprimer le squelette Initializr inutilisé`

    Catégories possibles :

    ✨ : introduire une fonctionnalité.
    🐛 : corriger un bug.
    ♻️ : refactorer du code.
    🔥 : supprimer du code ou des fichiers.
    📝 : ajouter ou mettre à jour de la documentation.
    ✅ : ajouter ou corriger des tests.
    🔧 : build, outillage, configuration.
    ⬆️ : mettre à jour des dépendances.

#### Le corps du commit est

0. concis : ce n'est pas un roman
1. en [Markdown](https://guides.github.com/features/mastering-markdown/) : listes de cases, tableaux et
   `blocs de code` sont les bienvenus
2. centré sur le *pourquoi*, pas sur le *quoi* : le diff montre déjà ce qui change
    - justifier la décision, et signaler ce que le code ne dit pas (état simulé, contournement, limite,
      écart assumé)
    - formulation métier plutôt que technique quand le changement touche l'utilisateur
    - ✗ `Ajouter une méthode pour filtrer les doublons`
    - ✔ `Refuser les doublons au lieu de les ignorer : l'abandon silencieux masquait les erreurs de saisie`
3. terminé par `Closes #<numéro>` en dernière ligne quand le commit est l'état final d'une pull request : GitHub
   ferme alors la PR ou l'issue à la fusion, et `git log` renvoie à la discussion de relecture
    - ✔ `Closes #67`
    - À omettre pour un commit intermédiaire d'une PR encore ouverte.

#### Commits assistés par IA

Un commit rédigé avec un agent se termine par le trailer `Co-Authored-By` de l'agent, après le corps, avec le nom et la version du modèle réellement utilisé :

```
Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
```

## Branches

Une branche par sujet, créée depuis `main`. Commits et pushes uniquement à la demande de l'auteur du dépôt.
