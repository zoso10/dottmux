#!/usr/bin/env bash

# Lists the tmux windows where a Claude Code is waiting on you, each with how
# long it has been waiting. Windows blocked on a question or permission prompt
# are red, ones that just finished are plain.
#
# Reads the @claude_waiting and @claude_since pane options, which
# claude_hook.sh sets.

tmux list-panes -a -F $'#{@claude_waiting}\t#{session_name}\t#{window_index}\t#{window_name}\t#{@claude_since}' 2>/dev/null |
  awk -F'\t' -v now="$(date +%s)" '
    function age(s,   d) {
      if (s == "") return ""
      d = now - s
      if (d < 60) return d "s"
      if (d < 3600) return int(d / 60) "m"
      return int(d / 3600) "h" (int(d % 3600 / 60) ? int(d % 3600 / 60) "m" : "")
    }
    { sessions[$2] = 1 }
    $1 == "" || $1 == "working" { next }
    {
      key = $2 "\t" $3
      if (!(key in state)) order[++n] = key
      # a blocked pane outranks a finished one; within a state, the oldest wins
      if (state[key] != "input" || $1 == "input") {
        if (state[key] != $1 || since[key] == "" || ($5 != "" && $5 < since[key])) since[key] = $5
        state[key] = $1
      }
      name[key] = $4
    }
    END {
      many = 0
      for (s in sessions) many++
      for (i = 1; i <= n; i++) {
        split(order[i], part, "\t")
        label = part[2] ":" name[order[i]]
        if (many > 1) label = part[1] "/" label
        a = age(since[order[i]])
        if (a != "") label = label " " a
        if (state[order[i]] == "input") label = "#[fg=red,bold]" label "#[default]"
        out = out (i > 1 ? "  " : "") label
      }
      print (n ? out : "No claudes waiting")
    }
  '
