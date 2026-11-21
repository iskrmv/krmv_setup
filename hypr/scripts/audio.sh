#!/bin/sh
# Audio helpers (SUPER + I > Audio).
#   audio.sh boost        laptop speakers too quiet (but headphones fine)? raise every hidden ALSA playback
#                         control (Master, Speaker, PCM, Front ...) to 100% and save it for the next boot
#   audio.sh select       choose the output device (speakers / headphones / HDMI / Bluetooth)
#   audio.sh diagnostics  save the audio state to a file and copy it to the clipboard (send it to get help)
#
# Why "boost": PipeWire's volume slider only moves ONE level. Laptops have several chained levels in ALSA
# (Master, Speaker, PCM ...). If "Speaker" sits at 40% after boot, the speakers are quiet even at 100%,
# while headphones (a different control) are normal. This script lifts all of them.
STATE="${KRMV_STATE:-$HOME/.local/state/krmv-setup}"
say() { notify-send "Audio" "$1" 2>/dev/null; echo "$1"; }

alsa_cards() { sed -n 's/^ *\([0-9]\+\) \[.*/\1/p' /proc/asound/cards 2>/dev/null; }

boost() {
  command -v amixer >/dev/null 2>&1 || { say "amixer is missing: sudo pacman -S alsa-utils"; exit 1; }
  mkdir -p "$STATE"
  for card in $(alsa_cards); do
    amixer -c "$card" scontrols 2>/dev/null | sed -n "s/^Simple mixer control '\([^']*\)',.*/\1/p" | while IFS= read -r ctl; do
      case "$ctl" in
        Mic*|Capture*|*Boost*|Beep*|Digital|Internal*|Line*|Auto-Mute*|Loopback*|Input*|Headset*|Dock*) continue ;;
      esac
      # only controls that can play sound (have a playback volume)
      amixer -c "$card" sget "$ctl" 2>/dev/null | grep -q 'pvolume' || continue
      amixer -c "$card" -q sset "$ctl" 100% unmute 2>/dev/null && echo "card $card: $ctl -> 100%"
    done
  done | tee "$STATE/audio-boost.log" >/dev/null 2>&1
  mkdir -p "$STATE"
  # keep the new levels after a reboot (alsa-restore.service reads this)
  if command -v alsactl >/dev/null 2>&1; then
    if [ -t 0 ]; then sudo alsactl store 2>/dev/null; else pkexec alsactl store 2>/dev/null; fi
  fi
  sink="$(pactl get-default-sink 2>/dev/null)"
  [ -n "$sink" ] && pactl set-sink-mute "$sink" 0 2>/dev/null && pactl set-sink-volume "$sink" 100% 2>/dev/null
  say "All speaker volume levels raised to 100%. Details: $STATE/audio-boost.log"
}

case "${1:-boost}" in
  boost|speakers) boost ;;
  select)
    command -v pactl >/dev/null 2>&1 || { say "pactl is missing (pipewire-pulse)"; exit 1; }
    list="$(pactl list short sinks 2>/dev/null | awk '{ print $2 }')"
    [ -n "$list" ] || { say "No outputs found"; exit 1; }
    pick="$(printf '%s\n' "$list" | rofi -dmenu -i -no-custom -p "Output" -mesg "Choose the audio output")" || exit 0
    [ -n "$pick" ] && pactl set-default-sink "$pick" && say "Output: $pick"
    ;;
  diagnostics)
    mkdir -p "$STATE"
    out="$STATE/audio-diagnostics.txt"
    {
      echo "=== date ==="; date
      echo "=== pactl info ==="; pactl info 2>&1
      echo "=== sinks ==="; pactl list sinks 2>&1
      for card in $(alsa_cards); do
        echo "=== amixer card $card ==="; amixer -c "$card" 2>&1
      done
      echo "=== wpctl status ==="; wpctl status 2>&1
    } > "$out"
    wl-copy < "$out" 2>/dev/null || true
    say "Saved to $out and copied to the clipboard"
    ;;
  *) echo "Usage: $0 [boost|select|diagnostics]"; exit 1 ;;
esac
