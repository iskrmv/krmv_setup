#!/bin/sh
# Force-kill the focused application (used by SUPER + K).
# Kills the whole app, not only one helper process. Steam and Waydroid get special treatment
# because both restart their helper processes and a single PID kill is not enough.
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
  waydroid*)
    # The focused PID is only the shell window; stop the whole Android session.
    waydroid session stop >/dev/null 2>&1 || {
      pkill -9 -f 'waydroid session' 2>/dev/null
      pkill -9 -f 'waydroid show-full-ui' 2>/dev/null
      kill -9 "$pid" 2>/dev/null
    }
    ;;
  *)
    pkill -9 -P "$pid" 2>/dev/null     # its child processes first
    kill -9 "$pid"
    ;;
esac
