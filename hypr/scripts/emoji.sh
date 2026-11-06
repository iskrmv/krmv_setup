#!/bin/sh
# Emoji picker (rofi). The bundled list has every emoji (with skin tones, flags, ZWJ sequences)
# plus search keywords, so "laugh", "lol", "heart", "fire" ... all work. The chosen emoji is copied to the clipboard.
list="$HOME/.config/hypr/data/emoji.txt"
[ -f "$list" ] || { notify-send "Emoji picker" "Missing $list"; exit 1; }
sel=$(rofi -dmenu -i -p "Emoji" < "$list") || exit 0
emoji=$(printf '%s' "$sel" | awk '{print $1}')
[ -n "$emoji" ] && printf '%s' "$emoji" | wl-copy && notify-send -t 2000 "Copied" "$emoji"
