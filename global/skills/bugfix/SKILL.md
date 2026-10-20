---
name: bugfix
description: Use when the user invokes /bugfix, reports a bug, crash, regression or unexpected behaviour to fix (« corrige le bug… », « ça plante quand… », « régression sur… », a ticket or an error trace), or says « corrige 1 et P2 », « pousse la PR », « merge » on bug-fix work.
argument-hint: "[description | ticket | trace]"
---

# Bugfix

## Principe

Un bug se corrige à sa cause, et un test qui échouait avant le prouve. Pas de spec ni de plan : la référence est le
comportement attendu, donné par l'utilisateur ou le ticket. La pression ne raccourcit aucune étape : elle se signale
à l'utilisateur, qui décide.

## Bascule vers `/feature`

S'arrêter, le dire avec le constat et proposer `/feature` dès que la correction :

- change un comportement voulu par une spec ou par les utilisateurs (le « bug » est une règle à changer) ;
- modifie un contrat partagé avec un autre dépôt (API, format d'échange) ;
- touche plusieurs couches, ou plus de ~5 fichiers hors tests.

Comportement attendu absent ou ambigu → le demander, ne pas le choisir.

## Le cycle

| # | Étape | Comment |
|---|---|---|
| 1 | Constat | Citer la demande telle quelle (ticket, trace, retour de recette) : observé, attendu, périmètre |
| 2 | Branche | `fix/<sujet>` depuis `origin/main` à jour (`git fetch origin main`), jamais sur `main` ni sur la branche d'une autre PR. Arbre pas propre → le dire et s'arrêter |
| 3 | Cause | `superpowers:systematic-debugging` : reproduire (test, commande, Playwright) avant de corriger, remonter à la cause racine, puis chercher (grep, LSP) tous les appelants du code fautif et les autres occurrences du même défaut. Non reproductible → rapporter ce qui a été essayé, ne rien corriger à l'aveugle |
| 4 | Rouge | Un test qui reproduit le bug au plus près de la cause, lancé et vu échouer pour la bonne raison ; sortie gardée pour le rapport. Bug impossible à tester automatiquement → le dire et décrire la vérification manuelle |
| 5 | Correctif | À la cause, une seule fois, dans le code partagé ; le même défaut ailleurs se corrige aussi (règle générale plutôt que cas). Rien d'autre : ni refactor ni amélioration en passant. Test au vert |
| 6 | Vérification | Suite complète de tests + analyse statique, sortie lue. Rouge ailleurs → diagnostiquer, pas ignorer |
| 7 | Recette | Bug visible dans une interface : rejouer le scénario du constat sur l'application locale (Playwright) |
| 8 | Review | **Automatique** : `ponytail:ponytail-review`. Correctif de plus de ~50 lignes hors tests, ou code sensible (sécurité, argent, données) → aussi Opus (`sdd-final-reviewer`, modèle passé explicitement, grille qualité du skill `feature`), en parallèle. Écrites dans `.superpowers/sdd/<fix>/final-review.md`, numérotées comme dans `feature` ; corriger ce que l'utilisateur retient, chaque point avec son SHA |
| 9 | Livraison | Commit `🐛` au format de `CONTRIBUTING.md` : la cause et le correctif. Puis skill `pr` (`push`, `recette`, `merge`) sur demande explicite ; reste à faire, `notify` et mémoire comme dans `feature` |

Les étapes 1 à 8 s'enchaînent sans demander. Rapport à la fin de l'étape 8 : cause, correctif (`fichier:ligne`),
sortie du test rouge puis verte, vérification, reviews, ce qui reste.

## Excuses et réalité

| Excuse | Réalité |
|---|---|
| « Le correctif est évident, pas besoin de reproduire » | Sans reproduction, on ne sait pas qu'on corrige le bon défaut. |
| « J'écris le test après le correctif » | Un test jamais vu rouge ne prouve rien. |
| « Je protège ce seul appel » | Corriger la cause dans le code partagé, et les autres occurrences. |
| « Tant que j'y suis, je nettoie ce fichier » | Hors périmètre : une autre PR. |
| « L'attendu est sûrement celui-ci » | Le demander. |
| « Ça touche trois couches mais reste un bug » | C'est une feature : `/feature`. |

## Signaux d'alarme

- Modifier le code avant d'avoir reproduit le bug.
- Un `try/catch`, un `if (x != null)` ou un délai ajouté sans cause identifiée.
- Un test existant modifié pour passer au vert sans raison écrite.
- Pousser ou merger sans demande explicite.
