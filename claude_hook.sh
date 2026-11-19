#!/usr/bin/env bash

# Called from Claude Code hooks to record whether the Claude in this tmux pane
# is waiting on you. The state lives in the @claude_waiting pane option, and
# when it started waiting (epoch seconds) in @claude_since, so both disappear
# with the pane.
#
#   usage: claude_hook.sh <working|input|done|resume|idle|clear>
#          claude_hook.sh seen <window>
#          claude_hook.sh unread [pane]
#
#   working started a turn
#   input   blocked on a question or permission prompt
#   done    finished its turn and you haven't looked yet; skipped when the
#           window is already on screen. Also records how many background
#           subagents are still running, from the Stop hook's input on stdin
#   resume  working again after a prompt, turns input back into working but
#           leaves done alone
#   idle    sitting at the prompt, clears working in case the turn was
#           interrupted (Stop doesn't fire then) but leaves done alone
#   clear   not waiting
#   seen    clears done on every pane in <window>; tmux calls this when you
#           switch to a window
#   unread  marks [pane] (default: this one) done again, as if you hadn't
#           looked; left alone while it is working or blocked. The timer
#           picks up from when Claude finished, or now if it hasn't since
#           your last prompt (or it isn't a Claude pane)
#
# @claude_done_at holds when Claude last finished a turn, even after you've
# seen it, so unread can restore the original timer.
#
# @claude_bg holds how many background subagents were still running when
# Claude last finished a turn; it is unset when there are none and whenever a
# new turn starts. Claude wakes itself when they finish, which starts a turn.

# set_state <pane> <state>, keeping @claude_since if the state isn't changing
set_state() {
  if [[ "$(tmux show-options -pqv -t "$1" @claude_waiting)" != "$2" ]]; then
    tmux set-option -p -t "$1" @claude_since "$(date +%s)"
  fi
  tmux set-option -p -t "$1" @claude_waiting "$2"
}

# set_bg <pane> <count>, unset unless count is a positive number
set_bg() {
  if [[ "$2" =~ ^[1-9][0-9]*$ ]]; then
    tmux set-option -p -t "$1" @claude_bg "$2"
  else
    tmux set-option -p -u -t "$1" @claude_bg
  fi
}

clear_state() {
  tmux set-option -p -u -t "$1" @claude_waiting
  tmux set-option -p -u -t "$1" @claude_since
}

{
  case "$1" in
    seen)
      [[ -n "$2" ]] || exit 0
      tmux list-panes -t "$2" -F $'#{pane_id}\t#{@claude_waiting}' |
        while IFS=$'\t' read -r pane state; do
          [[ "$state" == "done" ]] && clear_state "$pane"
        done
      ;;
    input)
      [[ -n "$TMUX_PANE" ]] || exit 0
      set_state "$TMUX_PANE" input
      ;;
    done)
      [[ -n "$TMUX_PANE" ]] || exit 0
      tmux set-option -p -t "$TMUX_PANE" @claude_done_at "$(date +%s)"
      set_bg "$TMUX_PANE" "$(jq '[.background_tasks[]? | select(.type == "subagent" and .status == "running")] | length')"
      if [[ "$(tmux display-message -p -t "$TMUX_PANE" '#{&&:#{window_active},#{session_attached}}')" == 1 ]]; then
        clear_state "$TMUX_PANE"
      else
        set_state "$TMUX_PANE" done
      fi
      ;;
    working)
      [[ -n "$TMUX_PANE" ]] || exit 0
      set_state "$TMUX_PANE" working
      tmux set-option -p -u -t "$TMUX_PANE" @claude_done_at
      set_bg "$TMUX_PANE"
      ;;
    resume)
      [[ -n "$TMUX_PANE" ]] || exit 0
      if [[ "$(tmux show-options -pqv -t "$TMUX_PANE" @claude_waiting)" == "input" ]]; then
        set_state "$TMUX_PANE" working
      fi
      ;;
    idle)
      [[ -n "$TMUX_PANE" ]] || exit 0
      if [[ "$(tmux show-options -pqv -t "$TMUX_PANE" @claude_waiting)" == "working" ]]; then
        clear_state "$TMUX_PANE"
      fi
      ;;
    unread)
      pane="${2:-$TMUX_PANE}"
      [[ -n "$pane" ]] || exit 0
      case "$(tmux show-options -pqv -t "$pane" @claude_waiting)" in
        working|input) exit 0 ;;
      esac
      since="$(tmux show-options -pqv -t "$pane" @claude_done_at)"
      tmux set-option -p -t "$pane" @claude_since "${since:-$(date +%s)}"
      tmux set-option -p -t "$pane" @claude_waiting done
      ;;
    clear)
      [[ -n "$TMUX_PANE" ]] || exit 0
      clear_state "$TMUX_PANE"
      tmux set-option -p -u -t "$TMUX_PANE" @claude_done_at
      set_bg "$TMUX_PANE"
      ;;
  esac

  # redraw now instead of waiting for status-interval
  tmux refresh-client -S
} > /dev/null 2>&1

exit 0
