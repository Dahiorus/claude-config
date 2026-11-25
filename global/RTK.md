# RTK - Rust Token Killer

A Claude Code hook rewrites plain commands (`git status` → `rtk git status`) to compact their output.
In auto mode the hook rewrites nothing, because auto mode refuses a call the hook changed
(« a hook changed this call's input »): there, type `rtk` yourself on every command whose output is read.

## Pipes: write `rtk` yourself

The hook does not rewrite commands containing a pipe `|`. When the output is meant to be read,
prefix the first command with `rtk` explicitly:

```bash
rtk git show <sha> | head -120      # not: git show <sha> | head -120
rtk git show <sha> --stat | tail -8
rtk grep -rn "pattern" src | head -40
rtk gh pr diff 12 | head -200
```

Inside a git worktree session (after `EnterWorktree`, or as an agent started with `isolation: "worktree"`),
never write `rtk git …`: Claude Code refuses it.
Run plain `git …` there; the hook leaves it unwrapped.

Keep the raw command when the output is consumed by a program or must be exact: counting
(`| wc -l`), parsing (`| jq`, `| awk`, `$(…)`), redirection to a file (`git show sha:path > file`),
patches (`git diff | git apply`). RTK compacts headers and may drop lines.

## Write commands: write `rtk` yourself

Outside auto mode, a write command the hook rewrote can still be refused. For `gh` commands
that write (`gh issue close --comment …`, `gh pr edit`) and for `git push`, type the `rtk` prefix yourself so
the hook has nothing to change. Inside a worktree session, keep plain `git …` (see Pipes).
