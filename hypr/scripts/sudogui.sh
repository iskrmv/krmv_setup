#!/bin/sh
# Run a graphical app as root on Wayland (Ventoy GUI, PINCE, GParted, ...).
#   sudogui <command> [args]     Wayland first; if the app fails within 4 seconds, the X11 way (XWayland)
#   sudogui --wayland <command>  only the Wayland way
#   sudogui --x11 <command>      only the X11 way
#   sudogui --polkit <command>   ask for the password in a graphical dialog (pkexec) instead of the terminal: for launchers
#   sudogui --check              shows what is missing if root GUI apps do not open
#
# Root cannot draw on your desktop by default. This allows it and passes the right variables to the app.
# Errors of the app stay visible in the terminal.

if [ "$1" = "--check" ] || [ $# -eq 0 ]; then
  echo "DISPLAY=$DISPLAY  WAYLAND_DISPLAY=$WAYLAND_DISPLAY  XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR"
  command -v xhost >/dev/null 2>&1 && echo "xhost: ok" || echo "xhost: MISSING (sudo pacman -S xorg-xhost)"
  command -v Xwayland >/dev/null 2>&1 && echo "Xwayland: installed" || echo "Xwayland: MISSING (sudo pacman -S xorg-xwayland)"
  [ -n "$DISPLAY" ] && xhost 2>&1 | sed 's/^/xhost list: /'
  for p in xcb-util-cursor qt5-wayland qt6-wayland; do pacman -Qi "$p" >/dev/null 2>&1 && echo "$p: ok" || echo "$p: MISSING (sudo pacman -S $p)"; done
  pgrep -f hyprpolkitagent >/dev/null 2>&1 && echo "polkit agent: running" || echo "polkit agent: NOT running (start it: /usr/lib/hyprpolkitagent/hyprpolkitagent &)"
  id -nG | tr ' ' '\n' | grep -qx wheel && echo "group wheel: yes" || echo "group wheel: NO (polkit/pkexec only accepts admins from the wheel group: sudo usermod -aG wheel $USER, then log in again)"
  [ $# -eq 0 ] && echo && echo "Usage: sudogui [--wayland|--x11|--polkit] <command> [args]"
  exit 0
fi

modes="wayland x11"
polkit=0
while [ $# -gt 0 ]; do
  case "$1" in
    --wayland) modes="wayland"; shift ;;
    --x11)     modes="x11"; shift ;;
    --polkit)  polkit=1; shift ;;
    *) break ;;
  esac
done
[ $# -gt 0 ] || { echo "sudogui: no command given"; exit 1; }
# a launcher (--polkit) uses the X11 way unless you choose otherwise: it is the one that works for every app
[ "$polkit" = 1 ] && [ "$modes" = "wayland x11" ] && modes="x11"

command -v xhost >/dev/null 2>&1 && xhost +SI:localuser:root >/dev/null 2>&1
if [ "$polkit" = 1 ]; then runner="pkexec env"; else runner="sudo env"; fi

# run_mode <name> <VAR=value ...> <command> [args]: 0 = the app ran (or ended normally), 1 = it failed at once
run_mode() {
  name="$1"; shift
  # shellcheck disable=SC2086
  $runner "$@" &
  pid=$!
  i=0
  while [ $i -lt 40 ]; do                       # 4 seconds to prove that it started
    sleep 0.1
    if ! kill -0 "$pid" 2>/dev/null; then
      wait "$pid"; code=$?
      [ "$code" -eq 0 ] && return 0
      echo "sudogui: $name way failed (exit code $code)" >&2
      return 1
    fi
    i=$((i + 1))
  done
  wait "$pid"
  return 0
}

for m in $modes; do
  case "$m" in
    wayland)
      run_mode "Wayland" WAYLAND_DISPLAY="$WAYLAND_DISPLAY" XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
        QT_QPA_PLATFORM=wayland GDK_BACKEND=wayland "$@" && exit 0 ;;
    x11)
      run_mode "X11 (XWayland)" DISPLAY="${DISPLAY:-:0}" XAUTHORITY="${XAUTHORITY:-$HOME/.Xauthority}" \
        QT_QPA_PLATFORM=xcb GDK_BACKEND=x11 "$@" && exit 0 ;;
  esac
  [ "$m" = "${modes##* }" ] || echo "sudogui: trying the next way..." >&2
done
echo "sudogui: it did not work. Run  sudogui --check  and send the output together with the messages above." >&2
exit 1
