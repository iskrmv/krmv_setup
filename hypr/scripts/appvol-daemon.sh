#!/bin/sh
# Keeps your per-app volumes: the moment an app opens a NEW audio stream, the volume / mute you chose for it in the bar's
# mixer is applied to that stream. This is what makes short sounds work (Telegram, Discord and Steam notifications):
# a new stream is created for every sound, and without this it would play at the old level first.
# Started at login (conf/autostart.lua); the remembered values live in ~/.local/state/krmv-setup/app-volumes.json
FILE="${KRMV_STATE:-$HOME/.local/state/krmv-setup}/app-volumes.json"
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/krmv-appvol.lock"
flock -n 9 || exit 0

apply() {
  [ -f "$FILE" ] || return 0
  pactl --format=json list sink-inputs 2>/dev/null | jq -r --slurpfile prefs "$FILE" '
    .[] as $s
    | ([$s.properties["application.name"], $s.properties["application.process.binary"], $s.properties["application.id"]]
        | map((. // "") | ascii_downcase | gsub("[^a-z0-9]"; "")) | join(" ")) as $hay
    | ($prefs[0] // {}) | to_entries[]
    | select(((.key | ascii_downcase | gsub("[^a-z0-9]"; "")) as $k | ($k != "") and ($hay | contains($k))))
    | "\($s.index) \(((.value.vol // 1) * 100) | round) \(if .value.muted then 1 else 0 end)"' \
  | while read -r idx vol mute; do
      pactl set-sink-input-volume "$idx" "${vol}%" 2>/dev/null
      pactl set-sink-input-mute "$idx" "$mute" 2>/dev/null
    done
}

apply
pactl subscribe 2>/dev/null | grep --line-buffered "'new' on sink-input" | while read -r _; do apply; done
