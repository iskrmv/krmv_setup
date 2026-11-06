#!/bin/sh
# Clipboard history (cliphist + rofi). The chosen entry becomes the current clipboard content.
sel=$(cliphist list | rofi -dmenu -i -p "Clipboard" -display-columns 2) || exit 0
[ -n "$sel" ] && printf '%s' "$sel" | cliphist decode | wl-copy
