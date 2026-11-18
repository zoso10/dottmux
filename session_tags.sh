#!/usr/bin/env bash

# Tags tmux sessions from the session_tags file, e.g. with the organization
# they belong to.
#
#   usage: session_tags.sh [apply|groups]
#
#   apply  Sets the @tags option on every session: the tag names, each wrapped
#          in its colour's #[fg=...] style. Sessions that match no line have
#          @tags unset. tmuxconf runs it on load and whenever a session is
#          created or renamed.
#   groups Prints "<tag>\t<colour>\t<session id>" for every session, grouped
#          by tag in the order the tags appear in session_tags, sessions by
#          name within a tag, then untagged sessions with an empty tag. A
#          session with several tags is printed under each of them.

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
file="${dir}/session_tags"
shopt -s nocasematch

# tag_names, tag_colours and tag_patterns[i] (space-separated) from the file
tag_names=()
tag_colours=()
tag_patterns=()
if [[ -r "$file" ]]; then
  while IFS= read -r line; do
    [[ -z "${line//[[:space:]]/}" || "$line" == \#* || "$line" != *:* ]] && continue
    read -r tag colour _ <<< "${line%%:*}"
    tag_names+=("$tag")
    tag_colours+=("$colour")
    tag_patterns+=("${line#*:}")
  done < "$file"
fi

# styled <tag index>: the tag name in its colour
styled() {
  local colour="${tag_colours[$1]}"
  if [[ -n "$colour" ]]; then
    echo "#[fg=${colour}]${tag_names[$1]}#[fg=default]"
  else
    echo "${tag_names[$1]}"
  fi
}

# matches <tag index> <session name>
matches() {
  local pattern patterns
  read -ra patterns <<< "${tag_patterns[$1]}"
  for pattern in "${patterns[@]}"; do
    # shellcheck disable=SC2053 # the pattern is meant to glob
    [[ "$2" == $pattern ]] && return 0
  done
  return 1
}

cmd_apply() {
  local id name tags i
  tmux list-sessions -F $'#{session_id}\t#{session_name}' 2>/dev/null |
    while IFS=$'\t' read -r id name; do
      tags=""
      for i in "${!tag_names[@]}"; do
        matches "$i" "$name" && tags="${tags:+$tags }$(styled "$i")"
      done
      if [[ -n "$tags" ]]; then
        tmux set-option -t "$id" @tags "$tags"
      else
        tmux set-option -u -t "$id" @tags 2>/dev/null
      fi
    done
}

cmd_groups() {
  local ids=() names=() id name i s tagged=()
  while IFS=$'\t' read -r id name; do
    ids+=("$id")
    names+=("$name")
  done < <(tmux list-sessions -F $'#{session_id}\t#{session_name}' | sort -t$'\t' -k2,2f)

  for i in "${!tag_names[@]}"; do
    for s in "${!names[@]}"; do
      if matches "$i" "${names[$s]}"; then
        printf '%s\t%s\t%s\n' "${tag_names[$i]}" "${tag_colours[$i]}" "${ids[$s]}"
        tagged[s]=1
      fi
    done
  done
  for s in "${!names[@]}"; do
    [[ -n "${tagged[$s]}" ]] || printf '\t\t%s\n' "${ids[$s]}"
  done
}

case "${1:-apply}" in
  apply) cmd_apply ;;
  groups) cmd_groups ;;
  *) echo "usage: session_tags.sh [apply|groups]" >&2; exit 1 ;;
esac
