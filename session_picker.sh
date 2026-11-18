#!/usr/bin/env bash

# A session picker in a popup, built on fzf. Sessions are grouped by their
# session_tags tags, each followed by its windows, which are coloured by
# Claude state like the window tabs. Type to filter, enter switches to the
# highlighted session or window, esc cancels. The bottom shows the
# highlighted session or window's active pane.
#
#   usage: session_picker.sh <client>
#
# tmuxconf binds it to prefix s, falling back to tmux's own choose-tree when
# fzf isn't installed.

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
self="${dir}/session_picker.sh"

# rows <client>: "<session id>\t<window id or ->\t<text>" for fzf, followed by
# a last line holding the row number of the client's current session
rows() {
  local current
  current="$(tmux list-clients -F $'#{client_name}\t#{session_id}' | awk -F'\t' -v c="$1" '$1 == c { print $2 }')"
  {
    "${dir}/session_tags.sh" groups | sed 's/^/G\t/'
    tmux list-sessions -F $'S\t#{session_id}\t#{session_name}\t#{session_windows}\t#{session_attached}'
    tmux list-windows -a -F $'W\t#{session_id}\t#{window_id}\t#{window_index}\t#{window_name}\t#{window_active}'
    tmux list-panes -a -F $'P\t#{window_id}\t#{@claude_waiting}'
  } | awk -F'\t' -v current="$current" '
    function hex(s) { return (index("0123456789abcdef", tolower(substr(s, 1, 1))) - 1) * 16 + index("0123456789abcdef", tolower(substr(s, 2, 1))) - 1 }
    # the ANSI escape for a tmux colour: #rrggbb, colourN, or a colour name
    function ansi(c,   i, n) {
      if (length(c) == 7 && c ~ /^#[0-9a-fA-F]+$/)
        return sprintf("\033[38;2;%d;%d;%dm", hex(substr(c, 2, 2)), hex(substr(c, 4, 2)), hex(substr(c, 6, 2)))
      if (c ~ /^colou?r[0-9]+$/) { sub(/^colou?r/, "", c); return "\033[38;5;" c "m" }
      n = split("black red green yellow blue magenta cyan white", names, " ")
      for (i = 1; i <= n; i++) {
        if (c == names[i]) return "\033[" (29 + i) "m"
        if (c == "bright" names[i]) return "\033[" (89 + i) "m"
      }
      return ""
    }
    function pad(s, w) { return sprintf("%-" w "s", s) }
    $1 == "G" { order[++groups] = $4; tag[groups] = $2; colour[groups] = $3; if (length($2) > tagw) tagw = length($2) }
    $1 == "S" { name[$2] = $3; nwin[$2] = $4; attached[$2] = $5; if (length($3) > namew) namew = length($3) }
    $1 == "W" { win[$2, ++wins[$2]] = $3; widx[$3] = $4; wname[$3] = $5; wactive[$3] = $6 }
    # a blocked pane outranks a finished one, which outranks a working one
    $1 == "P" && $3 != "" {
      rank = ($3 == "input") ? 3 : ($3 == "done") ? 2 : ($3 == "working") ? 1 : 0
      if (rank > wrank[$2]) wrank[$2] = rank
    }
    END {
      B = "\033[1m"; D = "\033[2m"; R = "\033[0m"
      for (g = 1; g <= groups; g++) {
        s = order[g]
        t = tag[g] == "" ? pad("", tagw) : B ansi(colour[g]) pad(tag[g], tagw) R
        line = t "  " B pad(name[s], namew) R "  " D nwin[s] " window" (nwin[s] == 1 ? "" : "s")
        if (s == current) line = line " (here)"
        else if (attached[s] != 0) line = line " (attached)"
        print s "\t-\t" line R
        row++
        if (s == current && !here) here = row
        for (i = 1; i <= wins[s]; i++) {
          w = win[s, i]
          style = wrank[w] == 3 ? "\033[31;1m" : wrank[w] == 2 ? "\033[33m" : ""
          line = pad("", tagw) "    " style widx[w] ":" wname[w] (wrank[w] == 1 ? "…" : "") R
          if (wactive[w]) line = line D " *" R
          print s "\t" w "\t" line
          row++
        }
      }
      print (here ? here : 1)
    }
  '
}

preview() {
  # the visible part of the pane, without the blank lines under the prompt
  tmux capture-pane -ep -t "$1" | awk '{ lines[NR] = $0 } /[^[:space:]]/ { last = NR } END { for (i = 1; i <= last; i++) print lines[i] }'
}

pick() {
  local client="$1" list here choice session window
  list="$(rows "$client")"
  here="$(tail -n 1 <<< "$list")"
  choice="$(head -n -1 <<< "$list" | fzf --ansi --no-sort --cycle --layout=reverse \
    --delimiter=$'\t' --with-nth=3.. --prompt='switch to ' --info=inline-right \
    --bind "load:pos(${here})" \
    --preview "'${self}' preview \"\$(test {2} = - && echo {1} || echo {2})\"" \
    --preview-window='down,60%,follow,border-top')" || exit 0
  IFS=$'\t' read -r session window _ <<< "$choice"
  tmux switch-client -c "$client" -t "$session"
  [[ "$window" == - ]] || tmux select-window -t "$window"
}

case "${1:-}" in
  pick) shift; pick "$@" ;;
  preview) shift; preview "$@" ;;
  "") echo "usage: session_picker.sh <client>" >&2; exit 1 ;;
  *) tmux display-popup -c "$1" -E -w 90% -h 85% -T ' sessions ' "'${self}' pick '$1'" ;;
esac
