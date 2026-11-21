#!/bin/sh
# ALT + TAB: list every open window (last used first) and jump to the one you pick.
# Press ALT + TAB again (or Down / Tab) to move down the list, Enter to switch, Esc to cancel.
data="$(hyprctl clients -j 2>/dev/null | jq -c '[.[] | select(.mapped == true and (.class | length) > 0)] | sort_by(.focusHistoryID)')"
[ -n "$data" ] && [ "$data" != "[]" ] || { notify-send "Windows" "No open windows"; exit 0; }
count="$(printf '%s' "$data" | jq 'length')"
sel=0; [ "$count" -gt 1 ] && sel=1
# (the icon hint contains NUL bytes, so the list is piped straight into rofi, never stored in a variable)
idx="$(printf '%s' "$data" | jq -r '.[] | "\(.class)  -  \(.title | .[0:70])   [workspace \(.workspace.name)]\u0000icon\u001f\(.class | ascii_downcase)"' \
  | rofi -dmenu -i -no-custom -format i -p "Windows" -selected-row "$sel" \
  -kb-row-down "Down,Control+j,Alt+Tab,Tab" -kb-row-up "Up,Control+k,Alt+ISO_Left_Tab,Alt+Shift+Tab,ISO_Left_Tab" \
  -kb-element-next "" -kb-element-prev "")" || exit 0
[ -n "$idx" ] || exit 0
addr="$(printf '%s' "$data" | jq -r ".[$idx].address")"
out="$(hyprctl dispatch "hl.dsp.focus({ window = \"address:$addr\" })" 2>&1)"
case "$out" in
  ok*) exit 0 ;;
  *)   hyprctl dispatch focuswindow "address:$addr" >/dev/null 2>&1 ;;
esac
