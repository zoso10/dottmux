#!/usr/bin/env bash

# Lists the tmux windows where a Claude Code is waiting on you. Windows blocked
# on a question or permission prompt are red, ones that just finished are plain.
#
# Reads the @claude_waiting pane option, which claude_hook.sh sets.

tmux list-panes -a -F $'#{@claude_waiting}\t#{session_name}\t#{window_index}\t#{window_name}' 2>/dev/null |
  awk -F'\t' '
    { sessions[$2] = 1 }
    $1 == "" { next }
    {
      key = $2 "\t" $3
      if (!(key in state)) order[++n] = key
      if (state[key] != "input") state[key] = $1
      name[key] = $4
    }
    END {
      many = 0
      for (s in sessions) many++
      for (i = 1; i <= n; i++) {
        split(order[i], part, "\t")
        label = part[2] ":" name[order[i]]
        if (many > 1) label = part[1] "/" label
        if (state[order[i]] == "input") label = "#[fg=red,bold]" label "#[default]"
        out = out (i > 1 ? "  " : "") label
      }
      print (n ? out : "No claudes waiting")
    }
  '
