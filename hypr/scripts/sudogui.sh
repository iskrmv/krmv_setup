#!/bin/sh
# Run a graphical app as root on Wayland (Ventoy GUI, PINCE, GParted, ...).
#   sudogui <command> [args]     Wayland first; if it cannot open a display, the X11 way (XWayland) is tried
#   sudogui --wayland <command>  only the Wayland way
#   sudogui --x11 <command>      only the X11 way
#   sudogui --polkit <command>   use the graphical password dialog (pkexec), for launchers
#   sudogui --check              shows what is missing if root GUI apps do not open
#
# If there is no terminal attached (for example when started from rofi), pkexec is used automatically,
# because a terminal sudo password prompt would be invisible. Root cannot draw on your desktop by default,
# so this passes X access and the right variables to the app. GTK/Qt are asked for the dark theme.
# Messages use the same Tokyo Night palette as the bar; the app's own errors stay visible.

BOLD=""; CYAN=""; GREEN=""; RED=""; DIM=""; RESET=""
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  BOLD='\033[1m'; CYAN='\033[38;2;13;185;215m'; GREEN='\033[38;2;158;206;106m'
  RED='\033[38;2;247;118;142m'; DIM='\033[38;2;120;124;153m'; RESET='\033[0m'
fi
title() { printf '%b\n' "\n${BOLD}${CYAN}==> $*${RESET}"; }
good()  { printf '%b\n' "  ${GREEN}ok${RESET}    $*"; }
bad()   { printf '%b\n' "  ${RED}!!${RESET}    $*"; }
info()  { printf '%b\n' "  ${DIM}--${RESET}    $*"; }
fail()  { printf '%b\n' "${BOLD}${RED}sudogui:${RESET} $*" >&2; }

if [ "$1" = "--check" ] || [ $# -eq 0 ]; then
  title "Root GUI diagnostics (Tokyo Night)"
  info "DISPLAY=$DISPLAY  WAYLAND_DISPLAY=$WAYLAND_DISPLAY  XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR"
  if [ -t 0 ]; then good "terminal attached: sudo password prompt works"; else info "no terminal: pkexec dialog will be used"; fi
  command -v xhost >/dev/null 2>&1 && good "xhost" || bad "xhost MISSING (sudo pacman -S xorg-xhost)"
  command -v Xwayland >/dev/null 2>&1 && good "Xwayland" || bad "Xwayland MISSING (sudo pacman -S xorg-xwayland)"
  command -v pkexec >/dev/null 2>&1 && good "pkexec" || bad "pkexec MISSING (sudo pacman -S polkit)"
  [ -n "${DISPLAY:-}" ] && xhost 2>&1 | sed "s/^/  --    xhost list: /"
  for p in xcb-util-cursor qt5-wayland qt6-wayland; do
    pacman -Qi "$p" >/dev/null 2>&1 && good "$p" || bad "$p MISSING (sudo pacman -S $p)"
  done
  pgrep -f hyprpolkitagent >/dev/null 2>&1 && good "polkit agent" || bad "polkit agent NOT running (start it: /usr/lib/hyprpolkitagent/hyprpolkitagent &)"
  id -nG | tr ' ' '\n' | grep -qx wheel && good "group wheel" || bad "group wheel: NO (sudo usermod -aG wheel $USER, then log in again)"
  [ $# -eq 0 ] && info "Usage: sudogui [--wayland|--x11|--polkit] <command> [args]"
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
[ $# -gt 0 ] || { fail "no command given"; exit 1; }

# No terminal means no visible sudo prompt. Use the polkit dialog in that case.
if [ "$polkit" = 0 ] && [ ! -t 0 ]; then
  info "no terminal attached: using the graphical password dialog"
  polkit=1
fi
# A launcher (--polkit) uses the X11 way unless you choose otherwise: it works for every app.
[ "$polkit" = 1 ] && [ "$modes" = "wayland x11" ] && modes="x11"

if [ "$polkit" = 1 ]; then
  command -v pkexec >/dev/null 2>&1 || { fail "pkexec is missing. Install polkit or run sudogui from a terminal."; exit 1; }
  runner="pkexec env"
else
  sudo -v >/dev/null 2>&1 || { fail "sudo authentication failed"; exit 1; }
  runner="sudo env"
fi

[ -n "${DISPLAY:-}" ] && xhost +SI:localuser:root >/dev/null 2>&1 || true

# run_mode <name> <VAR=value ...> <command> [args]: 0 = the app opened (or ended normally), 1 = it failed at once
run_mode() {
  name="$1"; shift
  err="$(mktemp)"
  # shellcheck disable=SC2086
  $runner "$@" 2>"$err" &
  pid=$!
  i=0
  while [ $i -lt 40 ]; do                       # 4 seconds to prove that it opened a display
    sleep 0.1
    if ! kill -0 "$pid" 2>/dev/null; then
      wait "$pid"; code=$?
      if [ "$code" -eq 0 ]; then rm -f "$err"; return 0; fi
      fail "$name way failed (exit code $code)"
      sed 's/^/    /' "$err" >&2
      rm -f "$err"; return 1
    fi
    if grep -Eiq 'qt\.qpa\.plugin|could not connect to display|could not find the qt platform plugin|cannot open display|failed to connect to the wayland display|gtk-warning.*cannot open display' "$err" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
      fail "$name way could not open a display"
      sed 's/^/    /' "$err" >&2
      rm -f "$err"; return 1
    fi
    i=$((i + 1))
  done
  wait "$pid"
  rm -f "$err"
  return 0
}

# The root app reads YOUR theme files (qt6ct/qt5ct palette, GTK settings), so every root window matches the desktop.
USER_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
for m in $modes; do
  case "$m" in
    wayland)
      run_mode "Wayland" WAYLAND_DISPLAY="$WAYLAND_DISPLAY" XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
        DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
        QT_QPA_PLATFORM=wayland GDK_BACKEND=wayland QT_QPA_PLATFORMTHEME="qt6ct:qt5ct" QT_STYLE_OVERRIDE=Fusion XDG_CONFIG_HOME="${USER_CONFIG:-$HOME/.config}" GTK_THEME=Adwaita:dark \
        XCURSOR_SIZE=24 \
        "$@" && exit 0 ;;
    x11)
      run_mode "X11 (XWayland)" DISPLAY="${DISPLAY:-:0}" XAUTHORITY="${XAUTHORITY:-$HOME/.Xauthority}" \
        XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
        QT_QPA_PLATFORM=xcb GDK_BACKEND=x11 QT_QPA_PLATFORMTHEME="qt6ct:qt5ct" QT_STYLE_OVERRIDE=Fusion XDG_CONFIG_HOME="${USER_CONFIG:-$HOME/.config}" GTK_THEME=Adwaita:dark \
        XCURSOR_SIZE=24 \
        "$@" && exit 0 ;;
  esac
  [ "$m" = "${modes##* }" ] || info "trying the next way..."
done
fail "it did not work. Run  sudogui --check  and send the output together with the messages above."
exit 1
