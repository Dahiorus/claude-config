import type { Register } from 'claude-code'

const PANE = 'shortcuts'
const TITLE = 'Raccourcis'

// shortcut: raccourcis par défaut des contextes Global, Chat et Pane (source : skill keybindings-help), ~/.claude/keybindings.json ignoré
const SECTIONS: readonly [string, readonly [string, string][]][] = [
  ['Saisie', [
    ['?', 'aide raccourcis'],
    ['/  @  !', 'commandes, fichier, bash'],
    ['enter', 'envoyer'],
    ['ctrl+j', 'nouvelle ligne'],
    ['ctrl+x enter', 'mettre en file'],
    ['ctrl+enter', 'envoyer maintenant'],
    ['up / down', 'historique'],
    ['ctrl+r', 'rechercher historique'],
    ['ctrl+_', 'annuler la saisie'],
    ['ctrl+s', 'mettre de côté (stash)'],
    ['ctrl+l', 'vider la saisie'],
    ['ctrl+g', 'éditer dans $EDITOR'],
    ['ctrl+v', 'coller une image'],
    ['space', 'push-to-talk (voix)'],
  ]],
  ['Session', [
    ['esc', 'interrompre'],
    ['esc esc', 'revenir en arrière'],
    ['shift+tab', 'cycler les modes'],
    ['alt+p', 'changer de modèle'],
    ['alt+o', 'mode fast'],
    ['alt+t', 'thinking'],
    ['alt+w', 'mot-clé workflow'],
    ['ctrl+y', 'modèle plus récent'],
    ['ctrl+b', 'tâche en arrière-plan'],
    ['ctrl+x ctrl+k', 'tuer les agents'],
    ['ctrl+c', 'interrompre / quitter'],
    ['ctrl+d', 'quitter'],
  ]],
  ['Affichage', [
    ['ctrl+o', 'transcript détaillé'],
    ['ctrl+t', 'liste des tâches'],
    ['ctrl+shift+b', 'mode brief'],
    ['cmd+k', "effacer l'écran"],
    ['ctrl+]', 'dernier artifact'],
  ]],
  ['Panneaux', [
    ['ctrl+x tab', 'focus panneau'],
    ['ctrl+x ctrl+a', 'afficher/masquer bandeau'],
    ['ctrl+x ←/↑', 'agrandir'],
    ['ctrl+x →/↓', 'réduire'],
    ['ctrl+x x', 'fermer'],
  ]],
]

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({ name: 'shortcuts', description: 'Afficher le panneau des raccourcis' })
    void $.ui.open({ id: PANE, title: TITLE })

    return next(e)
  })

  on('command.run', { command: 'shortcuts' }, async $ => {
    await $.ui.open({ id: PANE, title: TITLE })

    return { text: 'Panneau des raccourcis ouvert.' }
  })

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const { Box, Text } = $.ui.resolve(e)

    return (
      <Box flexDirection="column">
        {SECTIONS.map(([title, rows]) => (
          <Box key={title} flexDirection="column" marginBottom={1}>
            <Text bold underline>{title}</Text>
            {rows.map(([keys, label]) => (
              <Text key={keys}>
                <Text bold>{keys.padEnd(15)}</Text>
                <Text dimColor>{label}</Text>
              </Text>
            ))}
          </Box>
        ))}
      </Box>
    )
  })
}
