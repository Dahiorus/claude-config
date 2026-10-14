import { test, expect } from 'claude-code/testing'

test('le panneau liste les raccourcis', async $ => {
  for (const surface of ['terminal', 'desktop'] as const) {
    const ui = await $.ui.mount({ plugin: 'shortcuts', surface, component: 'Pane', requestId: 'shortcuts', props: {} })
    expect(await ui.find({ type: 'Text', text: /cycler les modes/ })).toBeDefined()
    await ui.unmount()
  }
})
