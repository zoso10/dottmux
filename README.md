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
