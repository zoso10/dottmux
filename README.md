tmux
====

## Installation
```shell
git clone https://github.com/zoso10/dottmux.git ~/.tmux
```

## Setup
Create symlink to the conf file in home directory
```shell
ln -s ~/.tmux/tmuxconf ~/.tmux.conf
```

## Status scripts
The first segment of the status bar is the output of one script from
`scripts/`. `status.sh` picks which one and only runs scripts listed in
`approved_scripts`.

| Script | Shows |
|--------|-------|
| `current_track` (default) | The track `playerctl` says is playing |
| `claude_input` | The windows where a Claude Code is waiting on you |

Choose one when starting the tmux server
```shell
TMUX_STATUS_SCRIPT=claude_input tmux
```
or switch while it is running
```shell
tmux setenv -g TMUX_STATUS_SCRIPT claude_input
```
To change the default, edit the argument to `status.sh` in `tmuxconf`.

### Adding a script
1. Put an executable file in `scripts/`. Whatever it prints lands in the
   status bar, tmux styles like `#[bold]` included.
2. Add its filename to `approved_scripts`.
3. Select it by filename, with or without the extension.

### claude_input
Claude Code reports its state through hooks that call `claude_hook.sh`, which
sets a `@claude_waiting` option on the tmux pane Claude is running in. Windows
blocked on a question or permission prompt show in red, windows where Claude
finished its turn show plain.

The window tabs use the same state: red when a Claude in the window is blocked
on you, yellow when one finished and you haven't looked. Switching to a window
marks it seen, and a Claude that finishes in the window you're already on
doesn't mark it at all. These work without `claude_input` being the status
script.

Add the hooks to `~/.claude/settings.json`
```json
{
  "hooks": {
    "Notification": [
      {
        "matcher": "permission_prompt|elicitation_dialog",
        "hooks": [{ "type": "command", "command": "~/.tmux/claude_hook.sh input", "async": true }]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "AskUserQuestion|ExitPlanMode",
        "hooks": [{ "type": "command", "command": "~/.tmux/claude_hook.sh input", "async": true }]
      }
    ],
    "PostToolUse": [
      { "hooks": [{ "type": "command", "command": "~/.tmux/claude_hook.sh resume", "async": true }] }
    ],
    "PostToolUseFailure": [
      { "hooks": [{ "type": "command", "command": "~/.tmux/claude_hook.sh resume", "async": true }] }
    ],
    "Stop": [
      { "hooks": [{ "type": "command", "command": "~/.tmux/claude_hook.sh done", "async": true }] }
    ],
    "UserPromptSubmit": [
      { "hooks": [{ "type": "command", "command": "~/.tmux/claude_hook.sh clear", "async": true }] }
    ],
    "SessionStart": [
      { "hooks": [{ "type": "command", "command": "~/.tmux/claude_hook.sh clear", "async": true }] }
    ],
    "SessionEnd": [
      { "hooks": [{ "type": "command", "command": "~/.tmux/claude_hook.sh clear", "async": true }] }
    ]
  }
}
```

## Tasks
`task.sh` gives each task its own git worktree and tmux window running
`claude`. Keep the editor and app server in one window on the main checkout;
tasks share that server.

| Key | Does |
|-----|------|
| `prefix N` | Prompts for a branch, creates `<repo>/.claude/worktrees/<branch>`, opens a window named after the branch's last segment and starts `claude` |
| `prefix X` | Removes the worktree the current pane is in and closes the windows that live entirely inside it. The branch is kept |

Both work from anywhere in the repo, or from the shell
```shell
~/.tmux/task.sh new feature/kai-1234 [--from <ref>]
~/.tmux/task.sh done [--force]
```
`new` checks out an existing local or `origin` branch, otherwise branches from
the main checkout's `HEAD`. Running it for a worktree that already exists just
opens a window there. `done` refuses when there are uncommitted changes or
commits that aren't on a remote or the main checkout's branch; `--force`
removes the worktree anyway.
