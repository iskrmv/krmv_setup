#!/bin/sh
# Shows every shortcut in a rofi list (SUPER + /). Edit hypr/data/shortcuts.txt to change the list.
list="$HOME/.config/hypr/data/shortcuts.txt"
[ -f "$list" ] || { notify-send "Shortcuts" "Missing $list"; exit 1; }
rofi -dmenu -i -no-custom -p "Shortcuts" -mesg "Esc to close" \
  -theme-str 'window { width: 820px; } listview { lines: 14; }' < "$list" >/dev/null
