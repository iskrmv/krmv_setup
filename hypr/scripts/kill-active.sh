#!/bin/sh
# Force-kill the focused application (used by SUPER + K).
# Kills the whole app, not only one helper process. Steam gets special treatment because it restarts its own parts.
info=$(hyprctl activewindow -j 2>/dev/null)
pid=$(printf '%s' "$info" | jq -r '.pid // empty')
class=$(printf '%s' "$info" | jq -r '.class // empty' | tr '[:upper:]' '[:lower:]')
[ -n "$pid" ] || exit 0

case "$class" in
  steam)
    # launcher script + client + web helpers, together (games started by Steam are not touched)
    pkill -9 -f 'steam\.sh'
    pkill -9 -x steam
    pkill -9 -f 'ubuntu12_32/steam'
    pkill -9 -f steamwebhelper
    ;;
  *)
    pkill -9 -P "$pid" 2>/dev/null     # its child processes first
    kill -9 "$pid"
    ;;
esac
