#!/bin/sh
# Mouse for games (SUPER + I > Mouse): flat acceleration profile and zero sensitivity offset for every real mouse,
# so a fast flick moves the cursor exactly as far as the mouse moved. The touchpad is never touched.
#   mouse.sh toggle | on | off | restore (used at login) | status
STATE="${KRMV_STATE:-$HOME/.local/state/krmv-setup}"
FLAG="$STATE/gaming-mouse"
mkdir -p "$STATE"
note() { notify-send "Mouse" "$1" 2>/dev/null; }

mice() {    # names of the real mice (no touchpads, no trackpoints that are part of a keyboard)
  hyprctl devices -j 2>/dev/null | jq -r '.mice[].name' | grep -viE 'touchpad|trackpad|synaptics|elan|glidepoint|virtual|power|ydotool'
}
apply() {   # apply <flat|adaptive>
  profile="$1"
  mice | while IFS= read -r n; do
    [ -n "$n" ] || continue
    hyprctl eval "hl.device({ name = \"$n\", accel_profile = \"$profile\", sensitivity = 0 })" >/dev/null 2>&1
  done
}

case "${1:-toggle}" in
  on)      : > "$FLAG"; apply flat;     note "Mouse for games: ON (flat, no acceleration)" ;;
  off)     rm -f "$FLAG"; apply adaptive; note "Mouse for games: OFF (normal acceleration)" ;;
  toggle)  if [ -e "$FLAG" ]; then sh "$0" off; else sh "$0" on; fi ;;
  restore) [ -e "$FLAG" ] && { sleep 2; apply flat; } ;;
  status)  if [ -e "$FLAG" ]; then echo ON; else echo OFF; fi ;;
  *) echo "Usage: $0 [toggle|on|off|restore|status]"; exit 1 ;;
esac
