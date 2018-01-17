#!/usr/bin/env bash
MAC_NOW_PLAYING=$(osascript <<EOF
set spotify_state to false
set itunes_state to false

if is_app_running("Spotify") then
  tell application "Spotify" to set spotify_state to (player state as text)
end if
if is_app_running("iTunes") then
  tell application "iTunes" to set itunes_state to (player state as text)
end if
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
  return "Nothing playing :("
end if

on is_app_running(app_name)
  tell application "System Events" to (name of processes) contains app_name
end is_app_running
EOF)

LINUX_NOW_PLAYING=$(ruby -e '
require "dbus"

bus = DBus.session_bus
service = bus["org.mpris.MediaPlayer2.spotify"]
object = service["/org/mpris/MediaPlayer2"]
interface = object["org.mpris.MediaPlayer2.Player"]
status = interface["PlaybackStatus"]
song = interface["Metadata"]["xesam:title"]
artist = interface["Metadata"]["xesam:artist"].first
if status == "Playing"
  puts "#{song} - #[bold]#{artist}#[nobold]"
else
  puts "Nothing playing :("
end
')

if [[ $IS_MAC ]]; then
  echo $MAC_NOW_PLAYING
else
  echo $LINUX_NOW_PLAYING
fi
