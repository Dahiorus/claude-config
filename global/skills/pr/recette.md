# `recette`

Exécuter la recette sur l'environnement de recette indiqué dans la description de la PR ou, par défaut, en local sur
l'application lancée depuis l'arbre de la PR, puis corriger. Les retours de l'utilisateur viennent avec l'invocation
ou dans le message qui suit (liste numérotée écran + élément + observé + attendu + périmètre).

1. **Scénarios** — les retours de l'utilisateur, plus la recette prévue par la PR (description, plan commité sur la
   branche). Aucun des deux → déduire les scénarios de la description et du diff, les lister et attendre l'accord.
   Pour chaque scénario, nommer les données qui le rendent jouable (objet, mode, volume) et les vérifier en base avant
   de le lancer ; données absentes → les créer ou marquer le scénario « non joué, données absentes », jamais conforme.
2. **Environnement** — chercher dans la description de la PR un environnement de recette : lien d'un environnement
   déployé pour la PR, par exemple le bloc ajouté par le déploiement d'une PR titrée `[DEPLOY_PR][<env-id>]`
   (convention de renoshield : `:heavy_check_mark: … http://…-<env-id>…`). Lien présent, déploiement réussi →
   recetter sur ce lien, sans lancement local. Aucun environnement dans la description → recette en local, par
   défaut, sans demander. Environnement indiqué mais en échec ou injoignable → le dire, puis recette en local. En
   local : démarrer l'application dans l'arbre de la PR (commande du CLAUDE.md du projet, dépendances installées si
   le worktree est neuf), en arrière-plan (`run_in_background` ; noter l'identifiant de la tâche et le port).
   Port déjà pris ou service injoignable : le diagnostiquer, ne pas recetter une autre instance.
3. **Exécution** — dans un agent `general-purpose` (modèle `sonnet` passé explicitement), pour que snapshots et
   captures restent hors de la session. Un seul agent pour tous les scénarios, pas un par scénario en parallèle : ils
   partagent le navigateur et l'application. Brief : URL de l'environnement, scénarios numérotés avec leur attendu,
   consigne ci-dessous. Chaque scénario étape par étape, avec observé et attendu. Interface web : un scénario = un seul
   appel `browser_run_code_unsafe` de Playwright qui enchaîne ses étapes et renvoie l'observé de chacune ; snapshot
   et capture seulement sur un écart. L'agent ne corrige rien et rend un tableau scénario → conforme / non conforme,
   avec pour chaque écart l'observé, l'attendu et le chemin de la capture. Les rejeux de l'étape 4 passent par le même
   agent (`SendMessage`).
4. **Correctifs** — les retours de l'utilisateur valent demande de correction ; les écarts trouvés par un scénario
   déduit se trient comme dans `feature` (« Tri des retours ») : « à corriger » corrigés d'office, « à trancher »
   rapportés. Appliquer la règle générale plutôt que le cas, sur tout le périmètre indiqué. Intention ambiguë ou
   changement de comportement non prévu par la spec → « à trancher ». Puis contrôle des copies d'une règle changée (étape 1 de `push.md`), vérification du projet et nouvelle exécution
   des scénarios touchés, en local : rouge → ne pas pousser, rapporter. Sur environnement dédié, les rejouer aussi
   après le push, une fois le build du nouveau SHA au vert (redéploiement).
5. **Push** — nouveaux commits au format de `CONTRIBUTING.md`, `push` simple, sans réécriture ni squash. PR de fork ou
   `state` ≠ `OPEN` → corriger dans l'arbre de la PR sans pousser, et le dire.
6. **Arrêt** — arrêter ce que l'étape 2 a lancé : `TaskStop` sur sa tâche, `docker compose down` pour une pile Docker ;
   à défaut, le PID qui écoute sur le port (`ss -ltnp`, vide pour un processus d'un autre compte ou `docker-proxy`).
   Jamais `pkill -f <motif>` : il tue aussi le shell dont la ligne de commande contient le motif. Écrire `recette.md` et `lecons.md` (dossier de suivi). Rapport : environnement recetté (lien ou local), scénarios et
   résultat, correctifs (SHA), ce qui reste.
