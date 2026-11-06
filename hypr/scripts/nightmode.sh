#!/bin/sh
# Night mode (blue light filter) with hyprsunset. Usage: nightmode.sh on|off|toggle|status|restore
# The warmth is NIGHT_TEMP (Kelvin, default 4000; lower = warmer).
STATE="${KRMV_STATE:-$HOME/.local/state/krmv-setup}"
TEMP="${NIGHT_TEMP:-4000}"
is_on() { pgrep -x hyprsunset >/dev/null 2>&1; }
start() { is_on || { hyprsunset -t "$TEMP" >/dev/null 2>&1 & } ; mkdir -p "$STATE"; echo on > "$STATE/nightmode"; }
stop()  { pkill -x hyprsunset 2>/dev/null; mkdir -p "$STATE"; echo off > "$STATE/nightmode"; }
case "$1" in
  on) start ;;
  off) stop ;;
  toggle) if is_on; then stop; else start; fi ;;
  status) if is_on; then echo on; else echo off; fi ;;
  restore) [ "$(cat "$STATE/nightmode" 2>/dev/null)" = on ] && start ;;
  *) echo "Usage: nightmode.sh on|off|toggle|status|restore"; exit 1 ;;
esac
exit 0
