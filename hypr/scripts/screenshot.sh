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
    # 1. grab the whole screen FIRST: grim never draws the mouse pointer, and nothing is on top yet
    full="$(mktemp --suffix=.png)"
    grim "$full" || { rm -f "$full"; exit 1; }
    # 2. freeze the screen while you select (the frozen copy is only for your eyes, it is not what gets saved)
    if command -v hyprpicker >/dev/null 2>&1; then
      hyprpicker -r -z -q >/dev/null 2>&1 &
      freeze_pid=$!
      sleep 0.25
    fi
    geom=$(slurp -d -b '#1a1b2680' -c '#0db9d7ff' -s '#00000000' -w 2)
    cleanup; freeze_pid=""
    [ -n "$geom" ] || { rm -f "$full"; exit 0; }
    # 3. cut the selection out of the first capture
    if command -v magick >/dev/null 2>&1 || command -v convert >/dev/null 2>&1; then
      IM=magick; command -v magick >/dev/null 2>&1 || IM=convert
      # slurp reports layout pixels; the capture is at the highest monitor scale and starts at the top-left monitor
      # shellcheck disable=SC2046
      set -- $(printf '%s' "$geom" | sed 's/[,x ]/ /g')
      X=$1; Y=$2; W=$3; H=$4
      info=$(hyprctl monitors -j | jq -r '[ (map(.x) | min), (map(.y) | min), (map(.scale) | max) ] | @tsv')
      set -- $info
      MINX=$1; MINY=$2; SC=$3
      cx=$(awk -v a="$X" -v b="$MINX" -v s="$SC" 'BEGIN{printf "%d", (a-b)*s + 0.5}')
      cy=$(awk -v a="$Y" -v b="$MINY" -v s="$SC" 'BEGIN{printf "%d", (a-b)*s + 0.5}')
      cw=$(awk -v a="$W" -v s="$SC" 'BEGIN{printf "%d", a*s + 0.5}')
      ch=$(awk -v a="$H" -v s="$SC" 'BEGIN{printf "%d", a*s + 0.5}')
      $IM "$full" -crop "${cw}x${ch}+${cx}+${cy}" +repage "$file" || { rm -f "$full"; exit 1; }
    else
      # no ImageMagick: capture the selection directly (the pointer may show on some setups)
      sleep 0.15
      grim -g "$geom" "$file" || { rm -f "$full"; exit 1; }
    fi
    rm -f "$full"
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
