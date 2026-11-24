#!/bin/sh
# krmv-stretch <command ...>   (installed as /usr/local/bin/krmv-stretch)
# Stretched resolution for games on Wayland. Steam launch option:   krmv-stretch %command%
# Switch it on and off in Settings > Display > Stretched resolution (no need to touch the launch option again).
#
#   OFF : the command simply runs.
#   ON  : two ways (Settings > Display > Method):
#     wayland   (default, recommended)  the game runs as a native Wayland window: SDL_VIDEO_DRIVER=wayland, the same thing
#               as putting  SDL_VIDEO_DRIVER=wayland %command%  in the launch options. Pick the 4:3 resolution INSIDE the
#               game; Hyprland stretches it over the whole screen. Full speed, normal mouse. The Steam overlay does not
#               work in this mode (it needs X11).
#     gamescope the game runs inside gamescope at the chosen size, which stretches it. Steam overlay works, but some
#               games feel different (refresh rate is set from your monitor; mouse capture can differ).
#
# Only ONE game: put the launch option on that game only (the other games never get it).
# Per game, independent of the global switch:
#   KRMV_STRETCH=1280x960 krmv-stretch %command%       use that size (gamescope method)
#   KRMV_STRETCH=wayland  krmv-stretch %command%       native Wayland stretch for this game
#   KRMV_STRETCH=off      krmv-stretch %command%       never stretch this game
STATE="${KRMV_STATE:-$HOME/.local/state/krmv-setup}"
CONF="$STATE/stretch.conf"
get() { sed -n "s/^$1=//p" "$CONF" 2>/dev/null | head -n1; }
enabled="$(get enabled)"; w="$(get width)"; h="$(get height)"; method="$(get method)"
[ -n "$method" ] || method=wayland
case "${KRMV_STRETCH:-}" in
  off|OFF|0)  enabled=0 ;;
  wayland)    enabled=1; method=wayland ;;
  gamescope)  enabled=1; method=gamescope ;;
  [0-9]*x[0-9]*) enabled=1; method=gamescope; w="${KRMV_STRETCH%x*}"; h="${KRMV_STRETCH#*x}" ;;
esac
[ "$enabled" = 1 ] || exec "$@"

if [ "$method" = wayland ] || ! command -v gamescope >/dev/null 2>&1; then
  export SDL_VIDEO_DRIVER=wayland
  exec "$@"
fi

# ---- gamescope method ----
[ -n "$w" ] && [ -n "$h" ] || { w=1440; h=1080; }
info="$(hyprctl monitors -j 2>/dev/null | jq -r '(map(select(.focused == true)) + .)[0] | "\(.width) \(.height) \(.refreshRate | round)"' 2>/dev/null)"
set -- "$@"
nw="$(echo "$info" | cut -d' ' -f1)"; nh="$(echo "$info" | cut -d' ' -f2)"; rate="$(echo "$info" | cut -d' ' -f3)"
case "$nw$nh" in ''|*[!0-9]*) nw=1920; nh=1080 ;; esac
case "$rate" in ''|*[!0-9]*) rate=60 ;; esac
# -r: the refresh rate of the gamescope window (it is 60 by default, which is the 60 fps cap you may have seen)
# KRMV_GAMESCOPE_ARGS: any extra gamescope options, e.g. "--force-grab-cursor" if the mouse does not capture
# shellcheck disable=SC2086
exec gamescope -W "$nw" -H "$nh" -w "$w" -h "$h" -r "$rate" -S stretch -f $KRMV_GAMESCOPE_ARGS -- "$@"
