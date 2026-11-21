#!/bin/sh
# Open a command in the default terminal chosen in Settings > Default apps.
# Usage: run-in-terminal.sh <command> [args...]
STATE="${KRMV_STATE:-$HOME/.local/state/krmv-setup}"
term="kitty"
[ -f "$STATE/apps.conf" ] && term="$(grep -m1 '^TERMINAL=' "$STATE/apps.conf" | cut -d= -f2-)"
[ -n "$term" ] || term="kitty"
command -v "$term" >/dev/null 2>&1 || term="$(command -v kitty foot alacritty wezterm xterm 2>/dev/null | head -n1)"
[ -n "$term" ] || { notify-send "Terminal" "No terminal emulator found"; exit 1; }

case "$(basename "$term")" in
  kitty)      exec "$term" "$@" ;;
  foot)       exec "$term" "$@" ;;
  alacritty)  exec "$term" -e "$@" ;;
  wezterm)    exec "$term" start -- "$@" ;;
  ghostty)    exec "$term" -e "$@" ;;
  konsole)    exec "$term" -e "$@" ;;
  gnome-terminal) exec "$term" -- "$@" ;;
  xterm)      exec "$term" -e "$@" ;;
  *)          exec "$term" -e "$@" ;;
esac
