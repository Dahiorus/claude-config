# Rappel humanizer : hook aux points de publication

## 1. Demande initiale

> **Hook qui rappelle `humanizer`** : la consigne du `CLAUDE.md` global (commits finaux d'une PR, description de PR,
> réponse de review) s'oublie. Un hook ajouterait un rappel au contexte, sans réécrire la commande, avant
> `gh pr create`, `gh pr edit` et le commit d'un squash. (mémoire du projet)

Origine : `docs/reste-a-faire.md`, point 5 (*défaut ancien* : consigne oubliée en session, relevée en mémoire).

La consigne visée, `global/CLAUDE.md` § Humanizer : « Before publishing the final commit(s) of a PR (squashed, or a
single commit merged as is), a PR description or a review comment you wrote, run it through the
`humanizer:humanizer` skill, then use the rewritten text. » Amendée par #167 : les commentaires d'issue aussi.

## Constat qui oriente la conception

Sonde jouée dans cette session (hook PreToolUse temporaire dans `.claude/settings.local.json`, Claude Code 2.1.329) :
le `additionalContext` d'un hook PreToolUse arrive dans le contexte **après** la sortie de la commande. Un rappel pur
sur `gh pr create` tombe donc quand la PR est déjà créée, et les relecteurs déjà notifiés avec le texte non relu.
Le seul moyen pour un hook d'agir **avant** l'envoi sans réécrire l'appel est de le refuser (`permissionDecision:
"deny"`) avec la consigne pour raison. Un refus n'est pas une réécriture : le mode auto ne le traite pas comme
« a hook changed this call's input ».

Décision : **refus avant l'envoi**, sauf si `humanizer:humanizer` a déjà été appelé depuis le dernier message de
l'utilisateur. Le rappel au contexte après l'envoi est écarté (le texte non relu serait publié et notifié), comme le
refus du seul premier essai (Claude pourrait relancer sans relire).

## 2. Portée de chaque règle

### Règle R1 : un point de publication sans passage humanizer récent est refusé

**Point de publication** : appel Bash dont une commande envoie un texte publié vers GitHub.

Liste fermée des points de publication (décision de relecture) :

- `gh pr create` : description et titre ;
- `gh pr edit` avec `--body`, `--body-file` ou `--title` (`-b`, `-F`, `-t`) ; `--add-reviewer` seul passe ;
- `gh pr comment` ; `gh pr review` avec `-b`/`--body` ou `-F`/`--body-file` ; `gh pr close` avec `-c`/`--comment` ;
- `gh issue comment` ; `gh issue close` avec `-c`/`--comment` (fermeture d'issue de l'étape 4 de `merge.md`) ;
- `gh api` qui écrit (`-f`, `-F`, `--field`, `--raw-field`, `--input` ou `-X POST`) vers un chemin en `…/reviews`,
  `…/replies` ou `…/comments`, suivi ou non d'un segment (`issues/comments/<id>`) : commentaire de relecture
  (`pulls/N/comments`) ou de conversation (`issues/N/comments`, l'API de `gh pr comment` ; un commentaire d'issue
  envoyé par `gh api` est refusé aussi) ; la lecture
  `gh api …/reviews --paginate` passe ;
- une option courte compte aussi collée à sa valeur ou groupée (`-b"x"`, `-Fbody=@f`, `-cb "x"`) ;
- `git push --force-with-lease` (commit final d'un squash, ou message réécrit à l'étape 3 de `merge.md`) et
  `gh pr merge` (commit unique mergé tel quel).

La demande cite `gh pr create`, `gh pr edit` et « le commit d'un squash » : ce commit ne se distingue pas d'un commit
ordinaire au moment du `git commit` (appel séparé de `git reset --soft`, imposé par le `CLAUDE.md` du projet), c'est
le push forcé qui le publie et `gh pr merge --rebase` qui le pose sur main. Les réponses de review s'ajoutent parce
que la consigne les cite.

**Marqueurs** : un commentaire présent n'importe où dans l'appel dispense du passage récent.

- `# humanizer: sans objet` : le texte envoyé n'est pas de la prose (titre changé d'un identifiant, corps vide), ou
  l'appel ne publie aucun texte. `/pr rebase` l'ajoute à son push forcé, que le hook ne distingue pas de celui d'un
  squash ; `pr-risk` l'ajoute à son commentaire (ci-dessous).
- `# humanizer: déjà relu` : le texte est passé par humanizer, puis l'utilisateur l'a approuvé tel quel avant l'envoi
  (`pr comments` publie « après accord ») ; un second passage changerait le texte approuvé.

**Passage humanizer récent** : le transcript de la session (`transcript_path` de l'entrée du hook) contient un appel
de l'outil `Skill` avec `skill: "humanizer:humanizer"` postérieur au dernier message tapé par l'utilisateur. Ne
comptent pas comme message de l'utilisateur : les retours d'outil (`tool_result`), les messages méta (`isMeta`,
contenu de skill chargé), les notifications système et les messages d'un plugin (`origin.kind` autre que
`human`), le résumé écrit après une compaction (`isCompactSummary`).

**Refus** : `hookSpecificOutput.permissionDecision: "deny"`, raison en français qui cite la consigne : passer le texte
par `humanizer:humanizer`, reprendre le texte réécrit, relancer l'appel ; elle cite aussi les deux marqueurs et leur sens.

**Passage sans jugement** (*fail-open*, l'outil ne bloque jamais un travail faute de pouvoir lire) : entrée illisible,
`transcript_path` absent ou illisible, jq absent → rien n'est émis, l'appel part. L'un des deux marqueurs présent →
l'appel part.

Endroits touchés :

| Endroit | Ce qu'il devient |
|---|---|
| `global/humanizer-hook.sh` | nouveau : lit l'appel et le transcript, refuse ou se tait |
| `settings/base.json`, `PreToolUse` | nouvelle entrée `matcher: "Bash"`, `bash ~/.claude/humanizer-hook.sh`, après main-guard |
| `lib/links.sh` (`install_links`) | inchangé : il relie déjà tout `global/*` dans `~/.claude` |
| `global/bash-rewrite-hook.sh`, `global/main-guard-hook.sh` | inchangés : hooks indépendants ; un push vers main refusé par main-guard l'est quel que soit le rappel |
| `global/CLAUDE.md` § Humanizer | la consigne reste la référence, la raison du refus la cite ; phrase ajoutée pour les commentaires d'issue (#167) |
| `global/skills/pr/push.md`, `squash.md`, `merge.md`, `comments.md`, `review.md`, `SKILL.md` | inchangés : ils demandent déjà le passage humanizer avant ces appels ; le hook les rattrape quand l'étape est sautée |
| `global/skills/bugfix/SKILL.md` (étape 9), `global/skills/release/SKILL.md` | inchangés : leur commit atteint main par `/pr merge` (push forcé de `squash.md` ou `gh pr merge`), donc par les points ci-dessus |
| `global/skills/pr/rebase.md` (push forcé) | `# humanizer: sans objet` ajouté à son push |
| `global/skills/pr/comments.md` (réponses publiées après accord, étape 4) | réponse proposée passée par humanizer avant d'être montrée (décision de relecture du plan), puis `# humanizer: déjà relu` ajouté aux appels qui publient le texte approuvé tel quel |
| `global/skills/pr/review.md` (remarques publiées par `gh api …/reviews --input`) | inchangé : passage humanizer prescrit juste avant l'envoi (étape 4), sans accord de l'utilisateur entre les deux |
| `gh issue create` (`push.md`) | inchangé, hors des points : la consigne ne cite que les commentaires d'issue (#167) |
| `global/skills/pr-risk/SKILL.md` (`gh pr comment`, `gh api …/comments` PATCH) | `# humanizer: sans objet` ajouté au script qui publie son commentaire (décision ci-dessous) |
| Agents (`sdd-implementer`, `bug-worker`) | inchangés : ils commitent sans pousser en force ni publier sur GitHub |
| `docs/domaine.md`, contexte « Garde humanizer » | glossaire aligné sur les décisions de cette spec |
| `docs/reste-a-faire.md`, point 5 | rayé |
| `tests/test_humanizer_hook.sh` | nouveau |
| `tests/test_settings.sh` | vérifie que `base.json` déclare le hook |

Décision : le commentaire de `pr-risk` est **exclu** des textes publiés. Il sort d'un gabarit (niveau, dangers,
tableau) qu'un passage humanizer abîmerait : `pr-risk` ajoute le marqueur `# humanizer: sans objet` à l'appel qui
le publie.

Lecture de l'appel : un motif sur le texte de la commande (comme `bash-rewrite`), pas l'arbre shfmt de main-guard :
un faux refus coûte un appel au skill, un faux passage ne fait que rater un rappel. Préfixe `rtk` toléré. Limite
assumée, en `shortcut:` en tête du hook : une commande cachée dans une variable, un alias ou `eval` n'est pas vue.

## 3. Données existantes

Sans objet : aucune donnée stockée ; le hook ne garde pas d'état entre deux appels.

## 4. Critères d'acceptation

Une seule story : la demande ne se découpe pas.

**P1 — Un texte non relu ne part pas vers GitHub**

Nominaux :
- `gh pr create --body-file f` sans appel humanizer depuis le dernier message de l'utilisateur → refus, raison qui
  cite `humanizer:humanizer` et le marqueur.
- Même appel après un `Skill humanizer:humanizer` postérieur au dernier message → aucune sortie, l'appel part.
- `rtk gh pr edit 12 --body-file f`, `gh pr edit 12 -t "…"` → refus ; `gh pr edit 12 --add-reviewer bob` → passe.
- `gh pr comment 12 --body-file f`, `gh api repos/o/r/pulls/12/comments/34/replies -F body=@f`,
  `gh api repos/o/r/pulls/12/reviews --input f` → refus sans passage récent.
- `git push --force-with-lease=b:sha origin b`, `gh pr merge 12 --rebase` → refus sans passage récent.
- `gh pr review 12 --comment -b "…"` → refus sans passage récent.
- `gh pr close 12 --comment "…"`, `gh pr close 12 -dc "…"` → refus ; `gh pr close 12` → passe.
- `gh issue comment 167 --body-file f`, `gh issue close 167 -c "…"` → refus ; `gh issue close 167 -r completed` →
  passe.
- `gh api repos/o/r/pulls/12/comments -f body=x`, `gh api repos/o/r/issues/12/comments -F body=@f`,
  `gh api -X PATCH repos/o/r/issues/comments/9 -F body=@f` → refus ; `gh api repos/o/r/issues/12/comments --paginate`
  (lecture) → passe.
- `gh pr edit 12 -b"x"`, `gh pr review 12 -cb "x"`, `gh api repos/o/r/pulls/12/comments -fbody=x` → refus.
- `git push origin feat/x`, `git commit -m wip`, `gh pr view 12`, `gh api repos/o/r/pulls/12/comments` (lecture),
  `gh api repos/o/r/pulls/12/reviews --paginate` (lecture) → aucune sortie.

Refus de jugement (fail-open) :
- `transcript_path` absent, fichier absent, JSON d'entrée invalide → aucune sortie, code 0.

Cas combinés :
- Humanizer appelé, **puis** un nouveau message de l'utilisateur, puis `gh pr create` → refus (le passage date d'avant
  le message).
- Message de l'utilisateur suivi d'un `tool_result` et d'un message méta (skill chargé), puis humanizer, puis
  `gh pr create` → passe (seul le message tapé compte comme borne).
- `git add f && git commit -m x && git push --force-with-lease …` dans un même appel → refus (un seul point suffit).
- `gh pr create … # humanizer: sans objet` sans passage → passe.
- `git push --force-with-lease=b:sha origin b # humanizer: sans objet` (rebase) sans passage → passe.
- Humanizer appelé, puis message « ok » de l'utilisateur, puis `gh pr comment 12 --body-file f # humanizer: déjà relu`
  → passe ; le même appel sans marqueur → refus.
- Marqueur sur une ligne de commentaire au milieu d'un script de plusieurs lignes (`pr-risk`) → passe.
- Marqueur inconnu (`# humanizer: plus tard`) → refus.
- Humanizer appelé par un sous-agent (absent du transcript principal) → ne compte pas.

## 5. Filet sur l'existant

`settings/base.json` : `tests/test_settings.sh` couvre déjà la génération ; le test ajouté vérifie la nouvelle entrée
sans changer les autres. Les hooks `bash-rewrite` et `main-guard` ne sont pas modifiés : leurs tests restent tels
quels. Aucun test de caractérisation à ajouter.

## 6. Origine

- Point traité : `docs/reste-a-faire.md` point 5, *défaut ancien* (consigne oubliée).
- Points de publication ajoutés après la review (`gh pr close --comment`, `gh api …/comments`, option courte
  collée) : *défaut ancien* de la liste fermée relevé par `code-review` R3, repris de l'issue #167 sur décision de
  l'utilisateur.
- `gh issue comment` et `gh issue close --comment` : ajoutés par l'issue #167 (cas réel : fermeture d'issue de
  `merge.md`), la consigne citant désormais les commentaires d'issue.
- Hors périmètre : un texte publié par un autre outil que Bash (MCP GitHub), une commande cachée (variable, alias,
  `eval`), un message de commit relu mais poussé sans force (premier push d'une branche : la PR le reprend au squash).

## 7. Dette du code touché

Aucune méthode existante n'est modifiée (nouveau script, nouvelle entrée de réglage). Sans objet.
