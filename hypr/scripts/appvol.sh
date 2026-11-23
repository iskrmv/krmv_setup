#!/bin/sh
# Per-app volume through the PulseAudio/PipeWire "sink input" API (works with every app that plays sound).
#   appvol.sh <app name> <percent>      e.g.  appvol.sh firefox 40
#   appvol.sh <app name> mute|unmute
# The app name is matched against the application name, binary and id of every playing stream, ignoring case,
# spaces and punctuation ("Tor Browser" finds torbrowser, "org.mozilla.firefox" finds firefox).
needle="$(printf '%s' "$1" | tr 'A-Z' 'a-z' | sed 's/.*\.//; s/[^a-z0-9]//g')"
[ -n "$needle" ] || exit 0
case "$(printf '%s' "$1" | tr 'A-Z' 'a-z')" in *" "*) needle="$(printf '%s' "$1" | tr 'A-Z' 'a-z' | sed 's/[^a-z0-9]//g')" ;; esac
action="$2"
pactl --format=json list sink-inputs 2>/dev/null | jq -r --arg n "$needle" '
  .[] | select(
    ([.properties["application.name"], .properties["application.process.binary"], .properties["application.id"], .properties["media.name"]]
      | map((. // "") | ascii_downcase | gsub("[^a-z0-9]"; "")) | join(" ")) | contains($n)
  ) | .index' | while IFS= read -r idx; do
    case "$action" in
      mute)   pactl set-sink-input-mute "$idx" 1 ;;
      unmute) pactl set-sink-input-mute "$idx" 0 ;;
      *)      pactl set-sink-input-volume "$idx" "${action%\%}%" ;;
    esac
  done
