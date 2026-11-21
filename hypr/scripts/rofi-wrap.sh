#!/bin/sh
# Installed as /usr/local/bin/rofi (it calls the real /usr/bin/rofi).
# Why: rofi on Wayland scrolls the opposite way from every other app when a touchpad uses natural scrolling,
# and rofi cannot tell a touchpad from a mouse. So while a rofi window is open the touchpad uses normal
# scrolling (a regular mouse is never affected) and natural scrolling is restored when rofi closes.
REAL=/usr/bin/rofi
[ -x "$REAL" ] || REAL="$(command -v -p rofi 2>/dev/null)"
case " $* " in
  *" -dump-"*|*" -help "*|*" -h "*|*" -v "*|*" -version "*|*" -e "*|*" -list-"*) exec "$REAL" "$@" ;;
esac
flag="${XDG_RUNTIME_DIR:-/tmp}/krmv-rofi-scroll"
owner=0
if command -v hyprctl >/dev/null 2>&1 && mkdir "$flag" 2>/dev/null; then
  owner=1
  hyprctl eval 'hl.config({ input = { touchpad = { natural_scroll = false } } })' >/dev/null 2>&1
fi
restore() {
  if [ "$owner" = 1 ]; then
    hyprctl eval 'hl.config({ input = { touchpad = { natural_scroll = true } } })' >/dev/null 2>&1
    rmdir "$flag" 2>/dev/null
    owner=0
  fi
}
trap 'restore' EXIT HUP INT TERM
"$REAL" "$@"
rc=$?
restore
exit $rc
