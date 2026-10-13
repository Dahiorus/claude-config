# Contributing

## Commits

- Write in **English**
- Briefly describe the change
- Justify why it was done this way

### Format: by example

The format adapts [gitmoji](https://gitmoji.dev/) and git's official recommendations.

```Markdown
✨ skills: Add the livrer skill

 Shipping a branch (squash, push, PR, merge) was repeated by hand in every
project and drifted between sessions, so:

 - [X] Squash the branch into a single commit following CONTRIBUTING.md
 - [X] Push with the account that owns the remote
 - [ ] Wait for CI before merging (later)
```

### Format: specification

#### The commit subject is

1. mandatory
2. short: **50 characters at most**, area label excluded
    - ✔ `Chain build-brief and rtk in the Bash hook`
    - ✗ `Make the Bash hook call build-brief first and then pass the result to rtk`
3. a title: it starts with a capital letter and does not end with punctuation
    - ✔ `Harden the dependency installers`
    - ✗ `harden the dependency installers`
    - ✗ `Harden the dependency installers.`
4. in the imperative mood: it tells the patch to do something
    - ✔ `Harden the dependency installers`
    - ✗ `Hardens the dependency installers` (present)
    - ✗ `Hardened the dependency installers` (past)
    - ✗ `Hardening of the dependency installers` (noun)
5. self-contained: the idea is clear without context
    - ✔ `Fall back to gh for the PR number`
    - ✗ `Fix the status line bug` (which bug?)
    - ✗ `Fix #12` (fix what?)
6. prefixed by an **optional** area label, lowercase, naming the part touched (`cli`, `skills`, `hooks`,
   `statusline`, `settings`, `deps`, `templates`, `tests`, `docs`…), separated from the title by `: `. The
   separator helps tools that parse messages; the label does not count in the 50 characters.
    - ✔ `✨ skills: Add the developper-une-feature skill`
    - ✔ `🔧 Capture the ponytail plugin` (cross-cutting change: no label)
    - ✗ `Skills: …` (lowercase)
    - ✗ `skills Add…` (missing `: `)
7. categorized by a [Unicode](https://unicode-table.com/en) emoji, placed first

    > Do not use GitHub markdown emoji codes (`:sparkles:`) in the subject: they are unreadable in `git log`.
    > Keep them for the body.

    - `🐛 statusline: Show the branch outside a repo`
    - `♻️ cli: Extract the symlink helpers`
    - `🔥 Remove the unused gecco template`

    Categories:

    ✨ : introduce a feature.
    🐛 : fix a bug.
    ♻️ : refactor code.
    🔥 : remove code or files.
    📝 : add or update documentation.
    ✅ : add or fix tests.
    🔧 : configuration, settings, tooling.
    ⬆️ : upgrade dependencies.

#### The commit body is

0. concise: it is not a novel
1. in [Markdown](https://guides.github.com/features/mastering-markdown/): task lists, tables and
   `code blocks` are welcome
2. focused on the *why*, not the *what*: the diff already shows what changes
    - justify the decision, and point out what the code does not say (workaround, limit, machine-specific
      behavior)
    - ✗ `Add a function to back up existing files`
    - ✔ `Back up existing files before replacing them: install used to overwrite hand-edited settings`
3. ended by `Closes #<number>` on the last line when the commit is the final state of a pull request
    - ✔ `Closes #7`
    - Omit it for an intermediate commit of a pull request still open.

#### AI-assisted commits

A commit written with an agent ends with the agent's `Co-Authored-By` trailer, after the body, with the name and
version of the model actually used:

```
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
```
