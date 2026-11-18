# Reste à faire

Mis à jour le 2026-11-18.

## Features

1. ~~**Paraphrase en tête de `ddd revue spec`** (repris d'EGM, `agents/comprehension.md` de
   google/elephant-goldfish-model) : le relecteur réécrit d'abord en 2 à 5 phrases « ce que la spec propose » et
   « comment marche l'existant selon elle ». Une paraphrase fausse est un défaut. Elle repère une spec dont chaque
   terme est défini mais dont les parties ne s'enchaînent pas. L'auteur la compare à son intention avant
   Plannotator.~~ (PR #135)
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
5. **Hook qui rappelle `humanizer`** : la consigne du `CLAUDE.md` global (commits finaux d'une PR, description de
   PR, réponse de review) s'oublie. Un hook ajouterait un rappel au contexte, sans réécrire la commande, avant
   `gh pr create`, `gh pr edit` et le commit d'un squash. (mémoire du projet)
6. **`/pr list toutes` limité à 30 PR** : `gh pr list` s'arrête à 30 par défaut ; passer `-L 100` pour
   `--state all` et `--state closed` (`global/skills/pr/SKILL.md`). (mémoire du projet)

## Corrections

1. ~~**Dossier de suivi : `feature` et `pr` à aligner** : `feature` réutilise le dossier existant et prend la
   définition de `<sujet>` du skill `pr`.~~ (PR #134)
2. ~~**Briefs et paquets de review hors du dossier de suivi** en PR unique ou en P1 : `feature` les met dans le
   dossier de suivi de `pr` pour toute PR.~~ (PR #134)
3. ~~**Télémétrie des projets déjà en vidal** : le hook de démarrage n'applique un profil qu'aux projets qui n'en ont
   pas (`profile.sh`, `session_start`) ; un projet passé en vidal avant la PR #136 attend `/profile vidal`.~~ (#137)
   Décision (#144) : pas de réapplication au démarrage ; `/profile <profil>` à la main dans chaque dépôt déjà
   profilé, pour la coupure perso et le retrait du jeton vidal.
4. ~~**Endpoint Exploradora en `http://`** (`settings/local.json`, réglages utilisateur) : en-tête Bearer et nom du
   dépôt en clair ; à vérifier côté Exploradora (réseau interne ou `https://`).~~ (#138) Risque accepté : collecteur
   docker interne à Vidal (IP privée, absent du DNS public), sans TLS sur le 443.
5. ~~**Jeton Exploradora recopié dans chaque `settings.local.json`** : piste `otelHeadersHelper` qui lit
   `~/.claude/exploradora.token`.~~ (#139) Caduc : le profil ne pose plus le jeton et `apply` le retire. (#144)
6. ~~**Préfixe `GH_TOKEN=$(gh auth token -u …)` des skills** (`pr`, `notify`, `release`, `todo`, `pr-risk`,
   `CLAUDE.md`) : à retirer une fois le hook du plugin `profile` éprouvé, il sert encore quand le hook n'a pas
   tourné. (spec 2026-11-17-profile-plugin) (#140)~~ Fait : jeton de session (spec 2026-11-18-jeton-session-skills).
7. ~~**Découper `mods/profile/scripts/profile.sh`** (260 lignes depuis `require_token`, seuil 200). (spec
   2026-11-17-profile-plugin, § 7) (#141)~~ Caduc : la grille de `feature` ne fixe plus de seuil de fichier aux
   scripts shell ; `profile.sh` n'a qu'un rôle, le profil du projet.
8. ~~**Code non nul de `profile.sh account` dans les skills** (`pr`, `notify`, `release`, `todo`, `pr-risk`) : ils
   ne disent que « vide sans profil : compte actif » ; depuis la validation, `account` peut échouer (code 1,
   message) et le skill devrait s'arrêter. (review finale de feat/profile-plugin, M7) (#142)~~ Fait : règle R1
   (spec 2026-11-18-jeton-session-skills).
9. ~~**Variables OTEL des profils ignorées** : Claude Code refuse la télémétrie d'un `settings.local.json` ; elle part
   de `~/.claude/settings.json`, dépôts perso compris. Retirer OTEL et `secretEnv` du profil vidal, couper en perso
   par `OTEL_METRICS_EXPORTER=none`, adapter `/profile`. Après #143. (session krema, recette de #143)~~ (#144)
10. ~~**Clés de télémétrie dupliquées** : les cinq clés que retire `apply` sont écrites dans `merge_profile`
    (`profile.sh`) et dans le skill `/profile`, sans test qui compare les deux listes. (reliquats de #145)~~ Fait :
    `test_profile_skill_lists_merge_telemetry_keys` (#146).
11. ~~**`GH_TOKEN` hérité du shell** : compte du profil non connecté, `session-start` n'exporte rien et un `GH_TOKEN`
    du shell passe le test des skills ; fermer en comparant `gh api user --jq .login` au compte. (spec
    2026-11-18-jeton-session-skills, R7)~~ Fait : `profile.sh require-token` (spec 2026-11-18-jeton-session-skills,
    R8).
12. **Jeton d'un `cd` annulé** : un `cd` hors des répertoires de travail est annulé par Claude Code, mais
    `cwd_changed` (`profile.sh`) a déjà posé le jeton du dossier cible ; `gh` hors skills part avec le mauvais
    compte. Les skills sont gardés par `require-token`. (recette de feat/jeton-session, R-1)
13. **Divergences de `pr-risk` à reporter dans harnais** : la copie locale (softwarevidal/harnais@f2dc722) ajoute
    `context: fork` et le compte gh du profil (`require-token` avant la recherche de son commentaire). Ce
    passage n'a pas été rejoué sur une PR qui avait déjà un commentaire de `pr-risk`. (mémoire du projet)
14. **Chemins `assets/vendor/` et `vendor/` du brief de `bug-worker`** (`bugfix`, « Plusieurs bugs en parallèle », et
    `agents/bug-worker.md`) : repris tels quels d'un autre projet. À généraliser en « dossiers ignorés par git dont
    les tests ont besoin », et à vérifier que la copie depuis le dépôt principal n'est pas refusée dans le
    worktree. (reliquat de cette PR)
