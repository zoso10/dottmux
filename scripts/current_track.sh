#!/usr/bin/env bash

# exclude tandem
tandem_identifier=$(busctl --user list | grep -i mpris | grep tandem | awk '{print $1}' | awk -F. '{print $NF}')
tandem_player="chromium.${tandem_identifier}"

player_status=$(playerctl --ignore-player=${tandem_player} status 2>/dev/null)

max_song=${TMUX_TRACK_MAX_SONG:-40}
max_artist=${TMUX_TRACK_MAX_ARTIST:-30}

# Cut to $2 characters, ending in an ellipsis when shortened, and escape
# '#' so tmux doesn't treat it as a format sequence.
truncate() {
  local text="$1" max="$2"
  if (( ${#text} > max )); then
    text="${text:0:max-1}"
    text="${text%"${text##*[![:space:],]}"}…"
  fi
  printf '%s' "${text//#/##}"
}

if [[ "$player_status" == "Playing" ]]; then
  artist=$(playerctl metadata artist 2>/dev/null)
  song=$(playerctl metadata title 2>/dev/null)

  echo "$(truncate "$song" "$max_song") - #[bold]$(truncate "$artist" "$max_artist")#[nobold]"
else
  echo "Nothing playing ☹️ "
fi
