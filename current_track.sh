#!/usr/bin/env bash
NOW_PLAYING=$(osascript <<EOF
tell application "Spotify" to set spotify_state to (player state as text)
tell application "iTunes" to set itunes_state to (player state as text)
(* Whatever other music applications you use *)

if spotify_state is equal to "playing" then
  tell application "Spotify"
    set track_name to name of current track
    set artist_name to artist of current track
    return track_name & " - #[bold]" & artist_name & "#[nobold]"
  end tell
else if itunes_state is equal to "playing" then
  tell application "iTunes"
    set track_name to name of current track
    set artist_name to artist of current track
    return track_name & " - #[bold]" & artist_name & "#[nobold]"
  end tell
else
  return "Nothing playing"
end if
EOF)

echo $NOW_PLAYING
