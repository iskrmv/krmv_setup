#!/bin/sh
# The media keys: control the player, then show the info box (only for the keys, not for clicks inside the player).
# Usage: media-key.sh play-pause|pause|next|previous|stop
case "$1" in
  play-pause|pause|stop|next|previous) playerctl "$1" ;;
  *) echo "Usage: media-key.sh play-pause|pause|next|previous|stop"; exit 1 ;;
esac
qs -p "$HOME/.config/hypr/theme/quickshell/shell.qml" ipc call osd mediakey "$1" >/dev/null 2>&1 &
