#!/bin/sh
# Focus the window that belongs to a tray app. Usage: focus-app.sh <tray id> <tray title>
# Exit code 0 = a window was focused, 1 = no matching window (the bar then asks the app to open one).
command -v jq >/dev/null 2>&1 || exit 1
addr=$(hyprctl clients -j | jq -r --arg id "$1" --arg t "$2" '
  def n: ascii_downcase | gsub("[^a-z0-9]"; "");
  ($id|n) as $i | ($t|n) as $tt |
  [ .[] | select(.mapped == true) | (.class|n) as $c | (.initialClass|n) as $ic
    | select(
        (($i|length) >= 3 and (($c|contains($i)) or ($ic|contains($i))))
        or (($c|length) >= 3 and ($i|contains($c)))
        or (($tt|length) >= 3 and ($c|contains($tt)))
      ) ] | .[0].address // empty')
[ -z "$addr" ] && exit 1
out=$(hyprctl dispatch "hl.dsp.focus({ window = \"address:$addr\" })" 2>&1)
case "$out" in
  ok*) exit 0 ;;
  *)   hyprctl dispatch focuswindow "address:$addr" >/dev/null 2>&1 && exit 0 || exit 1 ;;
esac
