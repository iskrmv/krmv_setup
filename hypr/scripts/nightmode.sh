#!/bin/sh
# Night mode (blue light filter) with hyprsunset. Usage: nightmode.sh on|off|toggle|status|restore
# The colors change smoothly (about a second) instead of jumping. NIGHT_TEMP is the warmth in Kelvin (default 4000, lower = warmer).
STATE="${KRMV_STATE:-$HOME/.local/state/krmv-setup}"
TEMP="${NIGHT_TEMP:-4000}"
NEUTRAL=6500
STEPS=20

mkdir -p "$STATE"
running() { pgrep -x hyprsunset >/dev/null 2>&1; }
# ctl <args>: talk to the running hyprsunset; fails when it does not answer
ctl() {
  out="$(hyprctl hyprsunset "$@" 2>&1)" || return 1
  case "$out" in *[Ee]rror*|*nvalid*|*nknown*|*"not found"*) return 1 ;; esac
  return 0
}
ensure_daemon() {   # hyprsunset in "identity" mode (no filter yet) that we steer through its socket
  running && return 0
  hyprsunset -i >/dev/null 2>&1 &
  i=0
  while [ "$i" -lt 20 ]; do sleep 0.1; ctl temperature "$NEUTRAL" && return 0; i=$((i + 1)); done
  return 1
}
ramp() {            # ramp <from> <to>
  i=1
  while [ "$i" -le "$STEPS" ]; do
    ctl temperature $(($1 + ($2 - $1) * i / STEPS)) || return 1
    sleep 0.03
    i=$((i + 1))
  done
}
on() {
  if ensure_daemon && ramp "$NEUTRAL" "$TEMP"; then :
  else pkill -x hyprsunset 2>/dev/null; hyprsunset -t "$TEMP" >/dev/null 2>&1 & fi      # fallback: no smooth ramp
  echo on > "$STATE/nightmode"
}
off() {
  if running && ramp "$TEMP" "$NEUTRAL" && ctl identity; then :
  else pkill -x hyprsunset 2>/dev/null; fi
  echo off > "$STATE/nightmode"
}
is_on() { [ "$(cat "$STATE/nightmode" 2>/dev/null)" = on ]; }

case "$1" in
  on) on ;;
  off) off ;;
  toggle) if is_on; then off; else on; fi ;;
  status) if is_on; then echo on; else echo off; fi ;;
  restore) if is_on; then ensure_daemon && ctl temperature "$TEMP" || { hyprsunset -t "$TEMP" >/dev/null 2>&1 & }; fi ;;
  *) echo "Usage: nightmode.sh on|off|toggle|status|restore"; exit 1 ;;
esac
exit 0
