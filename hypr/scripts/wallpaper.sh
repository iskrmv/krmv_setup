#!/bin/sh
# Sets the desktop wallpaper with swaybg.
# No argument or "next" -> random image from ~/.config/hypr/wallpapers/desktop
# Specific image:         sh wallpaper.sh /path/to/image.png
dir="$HOME/.config/hypr/wallpapers/desktop"
img="$1"
[ "$img" = "next" ] && img=""
[ -z "$img" ] && img=$(find "$dir" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | shuf -n1)
[ -z "$img" ] && exit 0
old=$(pgrep -x swaybg)
swaybg -i "$img" -m fill >/dev/null 2>&1 &
sleep 0.4
[ -n "$old" ] && kill $old
