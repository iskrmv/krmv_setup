#!/bin/sh
# Color picker (SUPER + SHIFT + P): the screen freezes with a zoom lens; click a pixel and its hex value
# is copied to the clipboard. Uses hyprpicker (native Wayland).
if ! command -v hyprpicker >/dev/null 2>&1; then
  notify-send "Color picker" "hyprpicker is not installed. Run the setup installer again."
  exit 1
fi
color="$(hyprpicker -a -r -f hex -l -q 2>/dev/null)"
[ -n "$color" ] || exit 0
notify-send "Color picker" "$color copied to the clipboard"
