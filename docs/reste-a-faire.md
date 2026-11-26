# Reste à faire

Mis à jour le 2026-11-26.

## Features

1. ~~**Paraphrase en tête de `ddd revue spec`** (repris d'EGM, `agents/comprehension.md` de
   google/elephant-goldfish-model) : le relecteur réécrit d'abord en 2 à 5 phrases « ce que la spec propose » et
   « comment marche l'existant selon elle ». Une paraphrase fausse est un défaut. Elle repère une spec dont chaque
   terme est défini mais dont les parties ne s'enchaînent pas. L'auteur la compare à son intention avant
   Plannotator.~~ (PR #135)
2. ~~**Relecteur YAGNI sur la spec** (EGM, `agents/zoom_out.md`) : à l'étape 1 ou 1b de `feature`, en parallèle de
   `ddd revue`, un agent neuf cherche dans le code un utilitaire qui fait déjà le travail, une option spéculative ou
   une optimisation prématurée. Aujourd'hui, ce contrôle n'existe qu'en fin de feature, sur le code
   (`ponytail-review`).~~ Fait : agent `spec-yagni-checker`, à l'étape 1 de `feature`. Hors périmètre (spec
   `2026-11-20-yagni-spec-design`) : les autres axes d'EGM (contexte insuffisant, détail d'implémentation, impasse
   d'architecture) et le contrôle du plan.
3. ~~**Relecteur en échec = « non lancé »** (EGM, `agents/synthesizer.md`) : un agent de review, de convergence,
   `spec-yagni-checker` ou `ddd revue` qui expire ou ne rend rien est relancé une fois. S'il échoue encore, son
   rapport l'affiche « non lancé », jamais « aucun défaut ». Une phrase dans « Exécution » de `feature`,
   à reporter dans `bugfix`.~~ Fait : paragraphe « non lancé » dans « Exécution » de `feature`, renvoi dans
   `bugfix`. Hors périmètre (spec `2026-11-24-relecteur-non-lance-design`) : les autres agents (`pr-reviewer` de
   `/pr review`, `recette-runner`, `feedback-triager`, `lessons-extractor`, `todo-verifier`, `bug-worker`).
4. **Rapport de dérive doc/code** (EGM, `skills/egm-drift-report`) : confronter `CLAUDE.md`, `docs/domaine.md` et les
   `AGENTS.md` au code, et ne lister que les écarts (champ absent, valeur codée en dur, autre bibliothèque que
   prévu). Un mode de `todo` ou un petit skill, lancé à la demande.
5. ~~**Hook qui rappelle `humanizer`** : la consigne du `CLAUDE.md` global (commits finaux d'une PR, description de
   PR, réponse de review) s'oublie. Un hook ajouterait un rappel au contexte, sans réécrire la commande, avant
   `gh pr create`, `gh pr edit` et le commit d'un squash. (mémoire du projet)~~ Fait : `humanizer-hook.sh` refuse
   l'envoi sans passage récent. Hors périmètre (spec `2026-11-20-rappel-humanizer`) : texte publié par le MCP GitHub,
   commande cachée (variable, alias, `eval`), message de commit poussé sans force, option d'écriture après un `|`,
   `;` ou `&` entre guillemets (lecture par motif : passer à l'arbre shfmt de main-guard).
6. **`/pr list toutes` limité à 30 PR** : `gh pr list` s'arrête à 30 par défaut ; passer `-L 100` pour
   `--state all` et `--state closed` (`global/skills/pr/SKILL.md`). (mémoire du projet)
7. **Jamais `git stash` pour voir un test rouge** : le brief de `sdd-implementer` et de `bug-worker`, et le rôle de
   contrôleur de `feature` et `bugfix`, disent d'utiliser `git checkout <rév> -- <fichiers>` (puis remettre) ou un
   worktree sur `main`, comme l'`AGENTS.md` du projet s'il le demande. `git stash` échoue sur les fichiers en
   intention d'ajout et met de côté un test déjà suivi. (leçon d'une session d'un autre projet, revenue sur
   plusieurs de ses PR)
   Le rouge par mutation de `bugfix` (issue de couverture) restaure déjà le code par `git checkout`, sans `git stash`.
8. ~~**Collecte des leçons sans règle qui grossit** (audit de `lecons.md` et du `CLAUDE.md`, 2026-11-21) : sur ~135
   leçons, ~35 % sont ponctuelles, ~20 % déjà couvertes, et 8 groupes de frictions sur 10 sont revenus malgré leur
   règle. À faire avec `/feature` (touche `merge.md` étape 2, `lessons-extractor`, `tests/`) : étiquette `méca`,
   `jugement` ou `ponctuel` sur chaque ligne de `lecons.md` (un `ponctuel` ne produit pas de règle) ; une friction
   mécanisable devient un test, un hook ou un script, jamais une phrase ; une récidive met la règle en cause au lieu de
   la reformuler ; budget de lignes du `CLAUDE.md` vérifié par un test ; règle citée dans `lecons.md` quand la
   friction revient, pour retirer celles qu'on ne cite plus.~~ Fait : leçons étiquetées, tri et récidive dans
   `lessons-extractor`, test `line_budget_overruns`. Hors périmètre (spec) : hook de format des leçons, nettoyage des
   dossiers de suivi, budget d'un autre projet. Écarté (spec, R3) : retirer les règles qu'on ne cite plus, car une
   règle qui marche n'est jamais citée ; la citation sert à repérer les récidives. (#180)
9. ~~**Récidive d'une règle globale entre projets** (question en revue de #184, 2026-11-23) : `lessons-extractor` ne
   lit que les dossiers de suivi de son dépôt. Une règle d'un skill ou d'un agent global citée une fois dans un projet
   et une fois dans un autre n'est jamais vue comme citée deux fois, alors que la deuxième citation impose de mécaniser
   ou de retirer. Piste : pour une règle globale, l'extracteur de `claude-config` lit aussi les `lecons.md` des
   autres dépôts (`~/IdeaProjects/*/.superpowers/sdd/*/`, liste à fixer). Écarté : demander aux sessions des projets
   d'analyser leurs leçons à la main (le merge de chaque projet le fait déjà, réponses à fusionner sans règle).
   À vérifier : que tous les projets vivent sous `~/IdeaProjects`.~~ Fait : tout extracteur cherche le fragment
   d'une règle globale dans les `lecons.md` de tous les projets (`find ~`), sans rien d'un autre projet dans un texte
   publié. Hors périmètre (spec `2026-11-23-recidive-entre-projets-design`) : dédoublonner deux
   `notify` reçus pour la même règle, normaliser le chemin du format de citation, lire les `final-review.md` des
   autres projets.
10. **Repointer une PR posée sur une branche sans être une pile GitHub** (une pile, GitHub la repointe au
    merge-async, `merge.md` étape 4) : `/pr merge` (étape 5, `merge.md`) supprime la branche
    distante sans toucher aux PR ouvertes qui la visent ; `gh pr edit --base main` reste à la main. `rebase.md`
    (étape 2) sait déjà rebaser une PR repointée. Plusieurs façons (repointer avant la suppression, ou seulement
    avertir), et une écriture sur la PR d'un autre auteur. (« Limites » de la PR #186)
    Cas voisin (review de #187) : la condition « visée par une PR ouverte » de `merge.md` étape 4 envoie en
    merge-async une PR visée hors pile GitHub, et le nettoyage attendrait un repointage qui n'arrive pas. À trancher
    par un essai GitHub (`merge-async` accepte-t-il ce cas ?). Il ajoute un garde (toujours sur `<headRefName>` une
    minute après `MERGED` : ne pas supprimer la branche, signaler la PR suivante) ou restreint la condition, avec
    l'item corrigé.
11. **Hook humanizer : deux écritures d'API de relecture non vues** (`global/humanizer-hook.sh`) : `gh api -X put`
    en minuscules (`API_WRITE` ne lit que `POST|PUT`, à vérifier : `gh` accepte-t-il la casse ?) et
    `-X PUT …/reviews/<id>/dismissals -f message=…`, qui publie du texte sans contrôle (`API_PATH` ne connaît pas
    `/dismissals`). Chaque garde reçoit son test qui échoue avant le correctif. (Hors périmètre de #187, relecture)

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
    compte. Les skills sont gardés par `require-token`. (recette de feat/jeton-session, R-1) Reste après le
    correctif de `fix/profile-cwd-reset` (un dossier hors dépôt, `/tmp` ou scratchpad, garde le compte du dossier
    quitté) : le `cd` annulé vers un dépôt, d'un autre profil ou sans profil, laisse son jeton au retour
    (`shortcut:` de `cwd_changed`). Gardé aussi (décision de la PR #160) : un `cd` qui tient d'un dossier hors
    dépôt vers un autre, ajouté par `/add-dir`, vide le jeton, l'ancien dossier n'ayant pas de compte.
13. **Divergences de `pr-risk` à reporter dans harnais** : la copie locale (softwarevidal/harnais@f2dc722) ajoute
    `context: fork` et le compte gh du profil (`require-token` avant la recherche de son commentaire). Ce
    passage n'a pas été rejoué sur une PR qui avait déjà un commentaire de `pr-risk`. (mémoire du projet)
14. **Chemins `assets/vendor/` et `vendor/` du brief de `bug-worker`** (`bugfix`, « Plusieurs bugs en parallèle », et
    `agents/bug-worker.md`) : repris tels quels d'un autre projet. À généraliser en « dossiers ignorés par git dont
    les tests ont besoin », et à vérifier que la copie depuis le dépôt principal n'est pas refusée dans le
    worktree. (reliquat de cette PR)
15. **Règle `pr-risk` de `feature` (« Dosage des reviews »), reçue d'un autre projet par `/notify`** : appliquée telle
    quelle, avec trois écarts à la grille. Vocabulaire d'un projet PHP/SQL (« docblock », « alias », « schéma SQL »)
    à généraliser ; « le dire dans son brief » alors que `pr-risk` se lance sans argument (« Dosage des reviews »,
    première puce) : dire comment lui passer l'information ; la vérification des dangers avant de les relayer
    manque aussi à `pr/push.md` (étape 4) et à `pr/review.md` (étape 3), qui lancent aussi `pr-risk`. (relecture
    de cette PR)
16. ~~**Règles de l'audit du `CLAUDE.md` restées en prose** (2026-11-21) : deux contrôles proposés n'ont pas été
    écrits. Agents qui citent `git grep` sans `git -C <racine>` : trois exceptions (`todo-verifier` et
    `sdd-task-reviewer` cherchent dans une révision ; le brief de `sdd-final-reviewer` ne donne pas de racine, sa
    review rejoue dans un dépôt jetable). `jq … | hook` dans un test : `guard_raw` (`tests/test_main_guard.sh`) passe
    par un pipe vers un hook qui lit son entrée, donc le motif signalerait un cas sûr. Les règles restent en une ligne
    du `CLAUDE.md`. Le troisième, `fromjson?` sans `type == "object"`, est `test_jq_fromjson_selects_objects`.~~
    Fait : `test_agents_with_root_run_git_from_it` (#180) ; les tests passent leur entrée à un script en here-string,
    `test_tests_feed_scripts_by_here_string`. (#181)
17. ~~**`md_long_lines` compte les lignes longues d'un bloc de code** (`tests/test_rules.sh`) : `git diff -U0` ne dit
    pas si la ligne est dans un bloc. À lire le fichier entier si un cas réel gêne. Les tableaux et la ligne
    `description:` du frontmatter sont exemptés : 8 des 15 derniers commits en ajoutaient.~~ Fait : diff à contexte
    complet, clôtures ``` et ~~~ suivies. (#182)
18. ~~**Écritures git réécrites par `bash-rewrite-hook.sh`** : le mode auto refuse `git add` devenu `rtk git add`. Le
    hook laisserait les écritures git intactes, puis les phrases « Refus du mode auto » partiraient. (leçons de #188,
    #189)~~ Fait : le hook ne réécrit plus rien en mode auto (76e6070), les phrases « Refus du mode auto » sont
    retirées des agents et de `feature`. (#189)
19. ~~**Marques de fin de `ponytail-review` et `pr-risk` en dur dans `feature`** (`Verdict:`, `Looks good. Ship.`,
    `Not read:`) : à revérifier à chaque montée de version du plugin, sinon faux « non lancé ». (reliquat de #188)~~
    Fait : `test_external_controls_keep_end_markers` lit le skill `pr-risk` et le cache de ponytail, vérifié au
    lancement des tests. (#190)
20. **Issues Sonar : suites hors périmètre** de `/pr comments` : security hotspots ;
    SonarQube Server (autre que Cloud) ; compteur de la statusline. (hors périmètre de la spec
    `2026-11-24-pr-comments-sonar-design.md`)
21. **Recette réelle des issues Sonar : correctif poussé sans réponse, statut `accept` posé dans Sonar.** Jouée en
    partie sur renoshield PR 324 (lecture des issues, doublon review/comments trouvé et corrigé) ; ces deux étapes
    n'ont pas été confirmées. À rejouer au premier `/pr <n°> comments` sur une PR de soi analysée par Sonar. (recette
    de la PR des issues Sonar)
22. **`Recommended:` désigné par sa lettre dans les `:::question`** : Plannotator ne reconnaît que le libellé entier
    du choix (skill `plannotator`, « Asking the reviewer questions ») ; « Recommended: A. » s'affiche comme une
    option de plus « A. » marquée Recommended, et « Accept recommended » choisit cette option vide. Règle à ajouter
    dans `feature` (étape 1, ligne 20) : recopier le libellé, jamais la lettre ; garde possible (test ou hook) sur un
    `Recommended:` qui ne reprend aucun `- [ ]` du bloc. (défaut ancien, vu en recette Plannotator le 2026-11-24)
23. **`install` ne retire pas les liens orphelins de `~/.claude`** : après un revert ou la suppression d'un fichier de
    `global/`, le lien mort se retire à la main. Vu pour le skill `profile` et pour le retour arrière de la grille
    qualité. (#197, leçons de la PR de la grille qualité)
