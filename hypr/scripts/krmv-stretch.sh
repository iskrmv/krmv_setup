#!/bin/sh
# krmv-stretch <command ...>   (installed as /usr/local/bin/krmv-stretch)
# Stretched resolution for games on Wayland. Steam launch option:   krmv-stretch %command%
# Switch it on and off in Settings > Display > Stretched resolution (no need to touch the launch option again).
#   OFF: the command simply runs.
#   ON : the command runs inside gamescope at your chosen resolution (for example 1440x1080, 4:3) and gamescope
#        STRETCHES that picture over the whole screen (16:9), like "stretched" on Windows.
#
# Only ONE game: put the launch option on that game only (the other games never get it).
# Per-game size, independent of the global switch:   KRMV_STRETCH=1280x960 krmv-stretch %command%
# Never stretch this game, whatever the switch says: KRMV_STRETCH=off krmv-stretch %command%
STATE="${KRMV_STATE:-$HOME/.local/state/krmv-setup}"
CONF="$STATE/stretch.conf"
get() { sed -n "s/^$1=//p" "$CONF" 2>/dev/null | head -n1; }
enabled="$(get enabled)"; w="$(get width)"; h="$(get height)"
case "${KRMV_STRETCH:-}" in
  off|OFF|0) enabled=0 ;;
  [0-9]*x[0-9]*) enabled=1; w="${KRMV_STRETCH%x*}"; h="${KRMV_STRETCH#*x}" ;;
esac
if [ "$enabled" = 1 ] && command -v gamescope >/dev/null 2>&1; then
  [ -n "$w" ] && [ -n "$h" ] || { w=1440; h=1080; }
  size="$(hyprctl monitors -j 2>/dev/null | jq -r '(map(select(.focused == true)) + .)[0] | "\(.width) \(.height)"' 2>/dev/null)"
  set -- "$@"
  nw="${size% *}"; nh="${size#* }"
  case "$nw$nh" in ''|*[!0-9]*) nw=1920; nh=1080 ;; esac
  exec gamescope -W "$nw" -H "$nh" -w "$w" -h "$h" -S stretch -f -- "$@"
fi
exec "$@"
