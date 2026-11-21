#!/bin/sh
# Keyboard layouts: right-click the keyboard chip in the bar (EN / RU).
#   - switch to a layout, add a new one (any language), remove one.
# The list is saved in ~/.local/state/krmv-setup/layouts and applied immediately; conf/input.lua reads it at login.
STATE="${KRMV_STATE:-$HOME/.local/state/krmv-setup}"
FILE="$STATE/layouts"
mkdir -p "$STATE"
[ -s "$FILE" ] || echo "us,ru" > "$FILE"
note() { notify-send "Keyboard layout" "$1" 2>/dev/null; }

apply() {            # apply <comma list>: save + tell Hyprland now
  echo "$1" > "$FILE"
  hyprctl eval "hl.config({ input = { kb_layout = \"$1\" } })" >/dev/null 2>&1 \
    || note "Saved. It will be applied after you log in again (live apply failed)."
}

list="$(cat "$FILE")"
while :; do
  cur="$(hyprctl devices -j 2>/dev/null | jq -r '.keyboards[] | select(.main == true) | .active_keymap' 2>/dev/null | head -n1)"
  menu="Add a layout
Remove a layout
Switch to the next layout"
  pick="$(printf '%s\n' "$menu" | rofi -dmenu -i -no-custom -p "Layouts" -mesg "Now: ${cur:-?}   |   Installed: $list")" || exit 0
  case "$pick" in
    "Add a layout")
      new="$(localectl list-x11-keymap-layouts 2>/dev/null | rofi -dmenu -i -no-custom -p "Add" -mesg "Type to search (us, ru, de, fr, uz, tr ...)")" || continue
      [ -n "$new" ] || continue
      case ",$list," in *",$new,"*) note "$new is already added"; continue ;; esac
      list="$list,$new"; apply "$list"; note "Added $new. ALT + SHIFT cycles through: $list" ;;
    "Remove a layout")
      old="$(printf '%s\n' "$list" | tr ',' '\n' | rofi -dmenu -i -no-custom -p "Remove")" || continue
      [ -n "$old" ] || continue
      rest="$(printf '%s\n' "$list" | tr ',' '\n' | grep -vx "$old" | paste -sd, -)"
      [ -n "$rest" ] || { note "At least one layout must stay"; continue; }
      list="$rest"; apply "$list"; note "Removed $old" ;;
    "Switch to the next layout") hyprctl switchxkblayout all next >/dev/null 2>&1; exit 0 ;;
    *) exit 0 ;;
  esac
done
