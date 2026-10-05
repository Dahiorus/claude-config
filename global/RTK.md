# RTK - Rust Token Killer

**Usage**: Token-optimized CLI proxy (cuts up to 90% of bash output)

## Meta Commands (always use rtk directly)

```bash
rtk gain              # Show token savings analytics
rtk gain --history    # Show command usage history with savings
rtk discover          # Analyze Claude Code history for missed opportunities
rtk proxy <cmd>       # Execute raw command without filtering (for debugging)
```

## Installation Verification

```bash
rtk --version         # Should show: rtk X.Y.Z
rtk gain              # Should work (not "command not found")
which rtk             # Verify correct binary
```

⚠️ **Name collision**: If `rtk gain` fails, you may have reachingforthejack/rtk (Rust Type Kit) installed instead.

## Hook-Based Usage

All other commands are automatically rewritten by the Claude Code hook.
Example: `git status` → `rtk git status` (transparent, 0 tokens overhead)

## Pipes: write `rtk` yourself

The hook does not rewrite commands containing a pipe `|`. When the output is meant to be read,
prefix the first command with `rtk` explicitly:

```bash
rtk git show <sha> | head -120      # not: git show <sha> | head -120
rtk git show <sha> --stat | tail -8
rtk grep -rn "pattern" src | head -40
rtk gh pr diff 12 | head -200
```

Keep the raw command when the output is consumed by a program or must be exact: counting
(`| wc -l`), parsing (`| jq`, `| awk`, `$(…)`), redirection to a file (`git show sha:path > file`),
patches (`git diff | git apply`). RTK compacts headers and may drop lines.

Refer to CLAUDE.md for full command reference.
