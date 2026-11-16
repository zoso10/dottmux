#!/usr/bin/env bash

# Called from Claude Code hooks to record whether the Claude in this tmux pane
# is waiting on you. The state lives in the @claude_waiting pane option, so it
# disappears with the pane.
#
#   usage: claude_hook.sh <input|done|resume|clear>
#
#   input   blocked on a question or permission prompt
#   done    finished its turn
#   resume  working again after a prompt, clears input but leaves done alone
#   clear   not waiting

[[ -n "$TMUX_PANE" ]] || exit 0

{
  case "$1" in
    input | done)
      tmux set-option -p -t "$TMUX_PANE" @claude_waiting "$1"
      ;;
    resume)
      if [[ "$(tmux show-options -pqv -t "$TMUX_PANE" @claude_waiting)" == "input" ]]; then
        tmux set-option -p -u -t "$TMUX_PANE" @claude_waiting
      fi
      ;;
    clear)
      tmux set-option -p -u -t "$TMUX_PANE" @claude_waiting
      ;;
  esac

  # redraw now instead of waiting for status-interval
  tmux refresh-client -S
} > /dev/null 2>&1

exit 0
