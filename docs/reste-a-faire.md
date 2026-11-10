# Reste à faire

Mis à jour le 2026-11-10.

## Features

1. **Paraphrase en tête de `ddd revue spec`** (repris d'EGM, `agents/comprehension.md` de
   google/elephant-goldfish-model) : le relecteur réécrit d'abord en 2 à 5 phrases « ce que la spec propose » et
   « comment marche l'existant selon elle ». Une paraphrase fausse est un défaut. Elle repère une spec dont chaque
   terme est défini mais dont les parties ne s'enchaînent pas. L'auteur la compare à son intention avant Plannotator.
2. **Relecteur YAGNI sur la spec** (EGM, `agents/zoom_out.md`) : à l'étape 1 ou 1b de `feature`, en parallèle de
   `ddd revue`, un agent neuf cherche dans le code un utilitaire qui fait déjà le travail, une option spéculative ou
   une optimisation prématurée. Aujourd'hui, ce contrôle n'existe qu'en fin de feature, sur le code
   (`ponytail-review`).
3. **Relecteur en échec = « non lancé »** (EGM, `agents/synthesizer.md`) : un agent de review, de convergence ou
   `ddd revue` qui expire ou ne rend rien est relancé une fois. S'il échoue encore, son rapport l'affiche
   « non lancé », jamais « aucun défaut ». Une phrase dans « Exécution » de `feature`, à reporter dans `bugfix`.
4. **Rapport de dérive doc/code** (EGM, `skills/egm-drift-report`) : confronter `CLAUDE.md`, `docs/domaine.md` et les
   `AGENTS.md` au code, et ne lister que les écarts (champ absent, valeur codée en dur, autre bibliothèque que
   prévu). Un mode de `todo` ou un petit skill, lancé à la demande.

## Corrections
