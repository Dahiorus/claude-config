# `push`

L'invocation vaut demande explicite de pousser et d'ouvrir la PR. Jamais de squash ni de réécriture : une PR peut
porter plusieurs commits ; un historique désordonné se signale au plus dans le rapport.

0. **Depuis `main`** — `git fetch origin main` ; ni modification en cours ni commit en avance sur `origin/main`
   (`git log origin/main..HEAD`) → rien à pousser, le dire et s'arrêter. Sinon `git switch -c <type>/<sujet>` depuis
   l'état courant (type d'après le contenu : `feat`, `fix`, `docs`, `chore` ; sujet court en kebab-case), qui emporte
   commits et modifications, puis `git branch -f main origin/main` pour remettre `main` au niveau du distant (ses
   commits vivent désormais sur la branche). Modifications en cours : les lister et demander avant de les commiter.
1. Le diff contre `origin/main` ajoute ou change une règle écrite en texte (skill, doc, `CLAUDE.md`, `AGENTS.md`,
   spec), ou y fait une exception → `git grep` de ses autres formulations (synonymes compris) dans tout le dépôt et
   dans la description de la PR, puis alignement commité. Ensuite, vérification au vert dans cette session, sinon la
   lancer et lire la sortie. Rouge → on ne pousse pas.
2. **Reste à faire** — le projet en a un (skill `todo`) : y rayer les points que la PR règle et ajouter ses « hors
   périmètre » et reliquats (spec, plan, `recette.md`, points non retenus de `final-review.md`, avec leur
   origine), puis le commiter avec la PR ; chaque point non retenu de `final-review.md` y reçoit la mention « reste à
   faire ». Rien à changer → passer.
   **Issues** — dépôt aux issues activées (`gh repo view --json hasIssuesEnabled`) : chaque point ajouté qui est de
   la dette (§7 de la spec, `shortcut:`, review non retenue) ou un problème hors périmètre découvert pendant le
   développement devient une issue proposée. Doublon d'abord (`gh issue list --state open --search "<mots-clés>"`) :
   trouvé → le citer, pas de nouvelle issue. Montrer la liste (titre, label, origine) et attendre l'accord (« crée
   tout », numéros) : une issue est visible de l'équipe. Puis `gh issue create --body-file <fichier>` par point : titre court, corps en français
   (constat avec `fichier:ligne`, impact, piste, origine : PR et spec), label `dette-technique` ou `hors-perimetre`
   (créé s'il manque : `gh label create <label>`). La ligne du reste à faire renvoie à `#n`.
3. `git push` simple (`-u origin <branche>` la première fois).
4. Aucune PR ouverte pour la branche : `gh pr create --body-file <fichier>` (titre = sujet du commit ou de la feature, description
   fonctionnelle en français, sans détail d'un autre projet (nom, PR, taille, venus d'une autre session), passée par `humanizer:humanizer`, terminée par une ligne `Closes #n` par issue que la PR
   règle entièrement, prise dans la spec, les commits ou la branche ; une issue réglée en partie est citée sans `Closes`). PR existante : mettre à jour la description si le périmètre a changé (`update-desc`, `SKILL.md`).
   Avant `gh pr create`, relire la description contre le diff : chaque affirmation s'y retrouve, et
   chaque commande citée (le grep de l'étape 1 compris) applique les règles que la PR ajoute.
   PR créée → skill `pr-risk` sur elle ; son niveau et ses relectures humaines vont au rapport. Lancé en agent, son
   brief dit : « publie ou mets à jour le commentaire sans demander, l'invocation de `/pr` par l'utilisateur vaut accord ».
5. Rapport : commit(s), lien de la PR, grep de l'étape 1, ce qui reste (recette, review). Terminer par ce rappel, mot pour mot :
   « Recette : `/clear`, puis `/pr N recette` avec tous les retours en un message — liste numérotée écran + élément +
   observé + attendu + périmètre, règle générale plutôt que cas. »
