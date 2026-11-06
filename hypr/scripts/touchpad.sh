#!/bin/sh
# Touchpad on / off with the touchpad key. Usage: touchpad.sh toggle|on|off
# Shows an info box (the bar's on-screen display) with the new state.
flag="${XDG_RUNTIME_DIR:-/tmp}/touchpad-disabled"
names="$(hyprctl devices -j | jq -r '.mice[] | select(.name | test("touchpad|trackpad|synaptics|elan"; "i")) | .name')"
[ -n "$names" ] || { notify-send "Touchpad" "No touchpad found"; exit 1; }
want="$1"
if [ "$want" = toggle ]; then if [ -e "$flag" ]; then want=on; else want=off; fi; fi
if [ "$want" = off ]; then enabled=false; else enabled=true; fi
printf '%s\n' "$names" | while IFS= read -r n; do
  hyprctl eval "hl.device({ name = \"$n\", enabled = $enabled })" >/dev/null 2>&1
done
if [ "$want" = off ]; then
  : > "$flag"; icon="touchpad-off"; text="Touchpad off"
else
  rm -f "$flag"; icon="touchpad"; text="Touchpad on"
fi
qs -p "$HOME/.config/hypr/theme/quickshell/shell.qml" ipc call osd message "$icon" "$text" "" >/dev/null 2>&1 || notify-send "Touchpad" "$text"
