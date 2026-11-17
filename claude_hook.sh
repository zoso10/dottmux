#!/usr/bin/env bash

# Called from Claude Code hooks to record whether the Claude in this tmux pane
# is waiting on you. The state lives in the @claude_waiting pane option, so it
# disappears with the pane.
#
#   usage: claude_hook.sh <input|done|resume|clear>
#          claude_hook.sh seen <window>
#
#   input   blocked on a question or permission prompt
#   done    finished its turn and you haven't looked yet; skipped when the
#           window is already on screen
#   resume  working again after a prompt, clears input but leaves done alone
#   clear   not waiting
#   seen    clears done on every pane in <window>; tmux calls this when you
#           switch to a window

{
  case "$1" in
    seen)
      [[ -n "$2" ]] || exit 0
      tmux list-panes -t "$2" -F $'#{pane_id}\t#{@claude_waiting}' |
        while IFS=$'\t' read -r pane state; do
          [[ "$state" == "done" ]] && tmux set-option -p -u -t "$pane" @claude_waiting
        done
      ;;
    input)
      [[ -n "$TMUX_PANE" ]] || exit 0
      tmux set-option -p -t "$TMUX_PANE" @claude_waiting input
      ;;
    done)
      [[ -n "$TMUX_PANE" ]] || exit 0
      if [[ "$(tmux display-message -p -t "$TMUX_PANE" '#{&&:#{window_active},#{session_attached}}')" == 1 ]]; then
        tmux set-option -p -u -t "$TMUX_PANE" @claude_waiting
      else
        tmux set-option -p -t "$TMUX_PANE" @claude_waiting done
      fi
      ;;
    resume)
      [[ -n "$TMUX_PANE" ]] || exit 0
      if [[ "$(tmux show-options -pqv -t "$TMUX_PANE" @claude_waiting)" == "input" ]]; then
        tmux set-option -p -u -t "$TMUX_PANE" @claude_waiting
      fi
      ;;
    clear)
      [[ -n "$TMUX_PANE" ]] || exit 0
      tmux set-option -p -u -t "$TMUX_PANE" @claude_waiting
      ;;
  esac

  # redraw now instead of waiting for status-interval
  tmux refresh-client -S
} > /dev/null 2>&1

exit 0
