#!/bin/sh
# Screenshots with grim. Every mode saves to ~/Pictures/Screenshots AND copies the image to the clipboard.
# Usage: screenshot.sh [region|monitor|all|window]
#   region   select an area with the mouse            (SUPER + SHIFT + S)
#   monitor  the focused monitor, instantly           (Print)
#   all      every monitor, instantly                 (CTRL + Print)
#   window   the focused window, instantly            (CTRL + SHIFT + Print)
mode="${1:-region}"
dir="$HOME/Pictures/Screenshots"
mkdir -p "$dir"
file="$dir/$(date +%Y-%m-%d_%H-%M-%S).png"

case "$mode" in
  region)
    pidof slurp >/dev/null 2>&1 && exit 0
    geom=$(slurp -b '#1a1b26cc' -c '#0db9d7ff' -s '#0db9d720' -w 2) || exit 0
    grim -g "$geom" "$file" || exit 1
    ;;
  monitor)
    out=$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .name' | head -n1)
    [ -n "$out" ] || { notify-send "Screenshot" "Could not find the focused monitor"; exit 1; }
    grim -o "$out" "$file" || exit 1
    ;;
  all)
    grim "$file" || exit 1
    ;;
  window)
    geom=$(hyprctl activewindow -j | jq -r 'select(.address != null) | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')
    [ -n "$geom" ] || { notify-send "Screenshot" "No focused window"; exit 1; }
    grim -g "$geom" "$file" || exit 1
    ;;
  *)
    echo "Usage: $0 [region|monitor|all|window]"; exit 1
    ;;
esac

wl-copy < "$file"
notify-send -i "$file" "Screenshot saved" "$file"
