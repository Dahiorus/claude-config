---
name: notify
description: Use when the user invokes /notify, or asks to warn, notify or tell another Claude session or project (« préviens la session android », « notifie claude-config », « dis à la session gecco de… », « transmets à android »).
argument-hint: "<projet|session> <message>"
---

# Notify

La session qui reçoit n'a aucun contexte : le message doit se comprendre seul.

1. **Trouver la session** — `ListAgents` (le charger par `ToolSearch`, comme `SendMessage`, s'il est différé). Une
   session s'appelle `<projet>-<suffixe>` (`gecco-00`, `geccoandroid-e4`) ; la session courante n'est jamais une
   cible. Comparer la cible au nom sans son suffixe : égalité d'abord (`gecco` → `gecco-00`, pas
   `geccoandroid-e4`), puis inclusion dans un sens ou dans l'autre (`android` → `geccoandroid-e4`, `GECCO-php` →
   `gecco-00`), casse ignorée. Plusieurs candidates →
   demander laquelle. Aucune, ou `ListAgents` indisponible → le dire et afficher le message prêt à coller dans la
   session, sans rien envoyer.
2. **Rédiger** — le message de la demande ; sans message (`/notify <projet>` seul), le déduire de ce que la
   conversation vient de proposer pour ce projet, ou le demander si rien n'en ressort. En français, dans cet ordre :
   - **De** : le nom de cette session, son projet et sa branche.
   - **Fait** : ce qui a changé (PR mergée ou déployée, contrat d'API, spec approuvée), avec les liens des PR et les
     chemins **absolus** des fichiers cités (spec, plan). Rien n'a changé (simple demande) → omettre la ligne.
   - **Attendu** : ce que la session doit faire, ou « pour information, rien à faire ».
   - **Réponse** : si une action est attendue, « confirme par `SendMessage` à `<nom de cette session>` une fois
     fait ».

   Pour lire une PR, `gh` passe par le compte de la mémoire du projet (`GH_TOKEN=$(gh auth token -u <compte>)`),
   jamais par `gh auth switch`.
3. **Envoyer** avec `SendMessage` (`to` = nom exact de la ligne), puis rapport : la session visée et le message
   envoyé.

Une condition dans la demande (« quand la PR est mergée », « une fois le plan approuvé ») se respecte : envoyer
seulement quand elle est remplie, pas avant.
