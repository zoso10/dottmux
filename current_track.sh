#!/usr/bin/env bash

# exclude tandem
tandem_identifier=$(busctl --user list | grep -i mpris | grep tandem | awk '{print $1}' | awk -F. '{print $NF}')
tandem_player="chromium.${tandem_identifier}"

player_status=$(playerctl --ignore-player=${tandem_player} status 2>/dev/null)

if [[ "$player_status" == "Playing" ]]; then
  artist=$(playerctl metadata artist 2>/dev/null)
  song=$(playerctl metadata title 2>/dev/null)

  echo "${song} - #[bold]${artist}#[nobold]"
else
  echo "Nothing playing ☹️ "
fi
