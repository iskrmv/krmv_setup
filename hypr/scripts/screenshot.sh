#!/bin/sh
# Screenshots with grim. Every mode saves to ~/Pictures/Screenshots AND copies the image to the clipboard.
# Usage: screenshot.sh [region|monitor|all|window]
#   region   select an area with the mouse (the screen FREEZES while you select)   (SUPER + SHIFT + S)
#   monitor  the focused monitor, instantly           (Print)
#   all      every monitor, instantly                 (CTRL + Print)
#   window   the focused window, instantly            (CTRL + SHIFT + Print)
#
# The mouse pointer is never in the picture: it is hidden for the fraction of a second the screen is captured
# (some drivers, NVIDIA especially, draw the pointer into the capture even though grim does not ask for it).
#
# Region mode: the whole screen is captured FIRST (no pointer, no selection overlay on top), hyprpicker then freezes
# the screen while you select, and the selection is cut out of the first capture. The selection overlay has no fade
# (see rules.lua), so it can never tint the picture.
mode="${1:-region}"
dir="$HOME/Pictures/Screenshots"
mkdir -p "$dir"
file="$dir/$(date +%Y-%m-%d_%H-%M-%S).png"
SCRIPTS="$(dirname "$0")"
freeze_pid=""
tmp=""
cursor_hidden=0

hide_cursor() { hyprctl eval 'hl.config({ cursor = { invisible = true } })' >/dev/null 2>&1 && cursor_hidden=1; sleep 0.06; }
show_cursor() { [ "$cursor_hidden" = 1 ] && hyprctl eval 'hl.config({ cursor = { invisible = false } })' >/dev/null 2>&1; cursor_hidden=0; }
cleanup() {
  [ -n "$freeze_pid" ] && kill "$freeze_pid" 2>/dev/null
  freeze_pid=""
  show_cursor
  [ -n "$tmp" ] && rm -f "$tmp"
}
trap cleanup EXIT HUP INT TERM

case "$mode" in
  region)
    pidof slurp >/dev/null 2>&1 && exit 0
    # 1. grab the whole screen FIRST, with the pointer hidden
    tmp="$(mktemp --suffix=.ppm)"
    hide_cursor
    grim -t ppm "$tmp" || exit 1
    show_cursor
    # 2. freeze the screen while you select (the frozen copy is only for your eyes, it is not what gets saved)
    if command -v hyprpicker >/dev/null 2>&1; then
      hyprpicker -r -z -q >/dev/null 2>&1 &
      freeze_pid=$!
      sleep 0.25
    fi
    geom=$(slurp -d -b '#1a1b2680' -c '#0db9d7ff' -s '#00000000' -w 2)
    [ -n "$freeze_pid" ] && kill "$freeze_pid" 2>/dev/null
    freeze_pid=""
    [ -n "$geom" ] || exit 0
    # 3. cut the selection out of the first capture
    # shellcheck disable=SC2046
    set -- $(printf '%s' "$geom" | sed 's/[,x ]/ /g')
    X=$1; Y=$2; W=$3; H=$4
    info=$(hyprctl monitors -j | jq -r '[ (map(.x) | min), (map(.y) | min), (map(.scale) | max) ] | @tsv')
    # shellcheck disable=SC2046
    set -- $info
    MINX=$1; MINY=$2; SC=$3
    # slurp reports layout pixels; the capture is at the highest monitor scale and starts at the top-left monitor
    cx=$(awk -v a="$X" -v b="$MINX" -v s="$SC" 'BEGIN{printf "%d", (a-b)*s + 0.5}')
    cy=$(awk -v a="$Y" -v b="$MINY" -v s="$SC" 'BEGIN{printf "%d", (a-b)*s + 0.5}')
    cw=$(awk -v a="$W" -v s="$SC" 'BEGIN{printf "%d", a*s + 0.5}')
    ch=$(awk -v a="$H" -v s="$SC" 'BEGIN{printf "%d", a*s + 0.5}')
    if command -v magick >/dev/null 2>&1; then
      magick "$tmp" -crop "${cw}x${ch}+${cx}+${cy}" +repage "$file" || exit 1
    elif command -v convert >/dev/null 2>&1; then
      convert "$tmp" -crop "${cw}x${ch}+${cx}+${cy}" +repage "$file" || exit 1
    elif command -v python3 >/dev/null 2>&1; then
      python3 "$SCRIPTS/crop-ppm.py" "$tmp" "$file" "$cx" "$cy" "$cw" "$ch" || exit 1
    else
      # nothing can cut the picture: capture the selection directly, pointer hidden
      hide_cursor
      grim -g "$geom" "$file" || exit 1
    fi
    ;;
  monitor)
    out=$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .name' | head -n1)
    [ -n "$out" ] || { notify-send "Screenshot" "Could not find the focused monitor"; exit 1; }
    hide_cursor
    grim -o "$out" "$file" || exit 1
    ;;
  all)
    hide_cursor
    grim "$file" || exit 1
    ;;
  window)
    geom=$(hyprctl activewindow -j | jq -r 'select(.address != null) | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')
    [ -n "$geom" ] || { notify-send "Screenshot" "No focused window"; exit 1; }
    hide_cursor
    grim -g "$geom" "$file" || exit 1
    ;;
  *)
    echo "Usage: $0 [region|monitor|all|window]"; exit 1
    ;;
esac

show_cursor
wl-copy < "$file"
notify-send -i "$file" "Screenshot saved" "$file"
