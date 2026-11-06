#!/bin/sh
# Fn brightness keys: 5% steps, never below 1% (so the screen cannot go black).
# The bar updates itself through udev events; the IPC call at the end is only a backup path.
# Usage: brightness.sh up|down
IFS=, read -r _ _ cur _ max <<EOF
$(brightnessctl -m)
EOF
step=$((max * 5 / 100)); [ "$step" -lt 1 ] && step=1
min=$(((max + 99) / 100))                      # 1% of the maximum, rounded up
case "$1" in
  up)   new=$((cur + step)); [ "$new" -gt "$max" ] && new=$max ;;
  down) new=$((cur - step)); [ "$new" -lt "$min" ] && new=$min ;;
  *)    exit 1 ;;
esac
brightnessctl -q set "$new"
qs -p "$HOME/.config/hypr/theme/quickshell/shell.qml" ipc call bar brightness >/dev/null 2>&1 &
