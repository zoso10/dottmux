#!/usr/bin/env bash

# Runs one script from scripts/ and prints its output for the status bar.
#
#   usage: status.sh [default_script]
#
# $TMUX_STATUS_SCRIPT picks the script, falling back to the argument. Either
# the filename or the filename without its extension works. Only scripts
# listed in approved_scripts will run.

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
wanted="${TMUX_STATUS_SCRIPT:-${1:-current_track}}"

script=""
while IFS= read -r line; do
  [[ -z "$line" || "$line" == \#* ]] && continue
  if [[ "$line" == "$wanted" || "${line%.*}" == "$wanted" ]]; then
    script="$line"
    break
  fi
done < "${dir}/approved_scripts"

if [[ -z "$script" ]]; then
  echo "#[fg=red]${wanted} is not in approved_scripts#[default]"
elif [[ ! -x "${dir}/scripts/${script}" ]]; then
  echo "#[fg=red]scripts/${script} is missing or not executable#[default]"
else
  exec "${dir}/scripts/${script}"
fi
