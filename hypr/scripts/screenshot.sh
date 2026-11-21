#!/bin/sh
# Screenshots with grim. Every mode saves to ~/Pictures/Screenshots AND copies the image to the clipboard.
# Usage: screenshot.sh [region|monitor|all|window]
#   region   select an area with the mouse (the screen FREEZES while you select)   (SUPER + SHIFT + S)
#   monitor  the focused monitor, instantly           (Print)
#   all      every monitor, instantly                 (CTRL + Print)
#   window   the focused window, instantly            (CTRL + SHIFT + Print)
#
# Region mode: hyprpicker draws an exact copy of the screen on top of everything (the freeze), slurp
# draws the selection on it, grim captures the frozen copy. The selection overlay is gone (and has no fade,
# see rules.lua) before grim runs, so the picture never contains the blue selection tint.
mode="${1:-region}"
dir="$HOME/Pictures/Screenshots"
mkdir -p "$dir"
file="$dir/$(date +%Y-%m-%d_%H-%M-%S).png"
freeze_pid=""
cleanup() { [ -n "$freeze_pid" ] && kill "$freeze_pid" 2>/dev/null; }
trap cleanup EXIT HUP INT TERM

case "$mode" in
  region)
    pidof slurp >/dev/null 2>&1 && exit 0
    if command -v hyprpicker >/dev/null 2>&1; then
      hyprpicker -r -z -q >/dev/null 2>&1 &
      freeze_pid=$!
      sleep 0.25                      # let the frozen copy appear
    fi
    # transparent selection fill, thin cyan border: nothing that could tint the result
    geom=$(slurp -d -b '#1a1b2680' -c '#0db9d7ff' -s '#00000000' -w 2) || exit 0
    [ -n "$geom" ] || exit 0
    sleep 0.15                        # the selection overlay is gone; the frozen copy still hides the live screen
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

cleanup; freeze_pid=""
wl-copy < "$file"
notify-send -i "$file" "Screenshot saved" "$file"
