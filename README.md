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
Lists every window, across all sessions, where a Claude Code is waiting on
you, with how long it has been waiting (`1:api 12m`). Blocked windows show in
red. It reads the same pane state as the window tabs below, so it needs the
same hooks; the tabs already show all of this per window, so it is mostly
useful for spotting Claudes in other sessions.

## Session tags
The right of the status bar starts with the current session's tags, e.g. which
organization it belongs to, each in its own colour. List them in
`session_tags`, one tag per line with an optional colour, followed by the
session names it covers
```
KaiPod #268bd2: kairos drachma dployd
Ductwork #b58900: DW-* OSS Pro website docs
```
The colour is any tmux colour (`#268bd2`, `green`, `colour208`); hex colours
look the same whatever your terminal theme.
Names may be globs and match case-insensitively; a session under several tags
shows them all. `session_tags.sh` stores them in each session's `@tags` option
when the config loads and whenever a session is created or renamed, so after
editing the file, reload with `prefix r`. To tag one session by hand until the
next of those, run `tmux set @tags '#[fg=green]Whatever'`.

## Session picker
`prefix s` opens `session_picker.sh` in a popup: sessions grouped by tag, in
the order the tags appear in `session_tags` with untagged sessions last, each
followed by its windows. Windows are coloured by Claude state like the tabs.
Type to filter, `enter` switches to the highlighted session or window, `esc`
cancels. The bottom half previews the highlighted pane.

It needs [fzf](https://github.com/junegunn/fzf) (`apt install fzf`). Without
it, `prefix s` opens tmux's own picker instead, which is always on `prefix S`
(and `prefix w` for windows) and shows the tags before each session's window
count. To go back to tmux's picker on `prefix s` for good, replace the
`bind s if-shell ...` block in `tmuxconf` with
```
bind s choose-tree -Zs -F "#{E:@tree_format}"
```

## Claude Code window tabs
Claude Code reports its state through hooks that call `claude_hook.sh`, which
sets a `@claude_waiting` option on the tmux pane Claude is running in, and
`@claude_since` to when it entered that state.

The window tabs show that state: red when a Claude in the window is blocked on
you, yellow when one finished and you haven't looked, and a `…` after the name
while one is working, followed by how long it has been that way
(`1:api… 4m`). Switching to a window marks it seen, and a Claude that finishes
in the window you're already on doesn't mark it at all.

`prefix u` marks the current pane unread again, so its tab goes yellow once you
switch away. The timer picks up from when Claude finished rather than
restarting; if Claude hasn't finished since your last prompt, or the pane
isn't running Claude, it starts from now. It does nothing while Claude is
working or blocked.

Claude Code doesn't fire `Stop` when you interrupt a turn, so the `idle_prompt`
hook clears a leftover `…` once Claude has sat at the prompt for about a
minute.

Use the same hooks in any other Claude config directory you run, e.g. one set
with `CLAUDE_CONFIG_DIR`.

Add the hooks to `~/.claude/settings.json`
```json
{
  "hooks": {
    "Notification": [
      {
        "matcher": "permission_prompt|elicitation_dialog",
        "hooks": [{ "type": "command", "command": "~/.tmux/claude_hook.sh input", "async": true }]
      },
      {
        "matcher": "idle_prompt",
        "hooks": [{ "type": "command", "command": "~/.tmux/claude_hook.sh idle", "async": true }]
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
      { "hooks": [{ "type": "command", "command": "~/.tmux/claude_hook.sh working", "async": true }] }
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
