#!/bin/sh
# Desktop wallpaper: still images (swaybg) and ANIMATED wallpapers (mpvpaper: mp4, webm, mkv, mov, gif).
#   wallpaper.sh                 restore the last wallpaper (random one on the very first run)
#   wallpaper.sh next            random wallpaper from  wallpapers/desktop  +  wallpapers/animated
#   wallpaper.sh /path/to/file   use this file
#   wallpaper.sh stop-animated   go back to a still wallpaper
# The choice is remembered in ~/.local/state/krmv-setup/wallpaper. Animated wallpapers are paused by mpvpaper
# while a fullscreen window covers them (saves battery) and never play sound.
desktop_dir="$HOME/.config/hypr/wallpapers/desktop"
animated_dir="$HOME/.config/hypr/wallpapers/animated"
STATE="${KRMV_STATE:-$HOME/.local/state/krmv-setup}"
mkdir -p "$STATE"
exts='\( -iname *.jpg -o -iname *.jpeg -o -iname *.png -o -iname *.webp -o -iname *.gif -o -iname *.mp4 -o -iname *.webm -o -iname *.mkv -o -iname *.mov \)'

pick_random() {
  # shellcheck disable=SC2086
  eval find "\"$desktop_dir\"" "\"$animated_dir\"" -type f $exts 2>/dev/null | shuf -n1
}

img="$1"
case "$img" in
  "")      [ -f "$STATE/wallpaper" ] && img="$(cat "$STATE/wallpaper")"; [ -f "$img" ] || img="$(pick_random)" ;;
  next)    img="$(pick_random)" ;;
  stop-animated) img="$(eval find "\"$desktop_dir\"" -type f $exts 2>/dev/null | grep -viE '\.(gif|mp4|webm|mkv|mov)$' | shuf -n1)" ;;
esac
[ -n "$img" ] && [ -f "$img" ] || exit 0
printf '%s' "$img" > "$STATE/wallpaper"

old_swaybg=$(pgrep -x swaybg 2>/dev/null)
old_mpv=$(pgrep -x mpvpaper 2>/dev/null)

case "$(printf '%s' "${img##*.}" | tr '[:upper:]' '[:lower:]')" in
  gif|mp4|webm|mkv|mov)
    if ! command -v mpvpaper >/dev/null 2>&1; then
      notify-send "Wallpaper" "mpvpaper is missing (AUR). Run the setup installer again."
      exit 1
    fi
    # every monitor by name (works with all mpvpaper versions)
    outs="$(hyprctl monitors -j 2>/dev/null | jq -r '[.[].name] | join(" ")')"
    [ -n "$outs" ] || outs='*'
    mpvpaper -f -p -o "no-audio loop-file=inf hwdec=auto panscan=1.0 vo=gpu" "$outs" "$img" >/dev/null 2>&1
    ;;
  *)
    swaybg -i "$img" -m fill >/dev/null 2>&1 &
    ;;
esac
sleep 0.5
# old wallpaper processes go only after the new one is on screen (no flash)
for p in $old_swaybg $old_mpv; do kill "$p" 2>/dev/null; done
exit 0
