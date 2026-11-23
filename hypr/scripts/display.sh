#!/bin/sh
# Display settings (SUPER + I > Display): resolution and refresh rate, scale, rotation, position, mirroring.
# Changes apply at once and are saved in ~/.local/state/krmv-setup/monitors.tsv, which conf/display.lua reads at login.
# After a change you get 12 seconds to confirm; if you do nothing (black screen?) the old settings come back.
STATE="${KRMV_STATE:-$HOME/.local/state/krmv-setup}"
FILE="$STATE/monitors.tsv"
REAL_ROFI=/usr/bin/rofi
[ -x "$REAL_ROFI" ] || REAL_ROFI=rofi
mkdir -p "$STATE"
note() { notify-send "Display" "$1" 2>/dev/null; }
menu() { rofi -dmenu -i -no-custom -p "$1" -mesg "$2"; }

monitors_json() { hyprctl monitors -j 2>/dev/null; }

pick_monitor() {
  json="$(monitors_json)"
  n="$(printf '%s' "$json" | jq 'length')"
  [ "$n" -gt 0 ] 2>/dev/null || { note "No monitor found"; return 1; }
  if [ "$n" = 1 ]; then printf '%s' "$json" | jq -r '.[0].name'; return 0; fi
  line="$(printf '%s' "$json" | jq -r '.[] | "\(.name)   \(.width)x\(.height)   scale \(.scale)   \(.make) \(.model)"' | menu "Screen" "Which screen?")" || return 1
  printf '%s' "$line" | awk '{ print $1 }'
}

# one saved line per screen: name <TAB> mode <TAB> position <TAB> scale <TAB> transform <TAB> mirror
current_record() {   # current_record <name>  -> the saved line, or one built from the live state
  rec="$(awk -F'\t' -v n="$1" '$1 == n' "$FILE" 2>/dev/null | head -n1)"
  if [ -z "$rec" ]; then
    rec="$(monitors_json | jq -r --arg n "$1" '.[] | select(.name == $n) | [ .name, "\(.width)x\(.height)@\(.refreshRate * 100 | round / 100)", "\(.x)x\(.y)", (.scale * 100 | round / 100 | tostring), (.transform | tostring), "" ] | join("\t")')"
  fi
  printf '%s' "$rec"
}

save_record() { # save_record <record>
  name="$(printf '%s' "$1" | cut -f1)"
  tmp="$(mktemp)"
  { awk -F'\t' -v n="$name" '$1 != n' "$FILE" 2>/dev/null; printf '%s\n' "$1"; } > "$tmp"
  mv "$tmp" "$FILE"
}

lua_for() {     # lua_for <record> -> the hl.monitor() call
  printf '%s' "$1" | awk -F'\t' '{
    s = $4; if (s != "auto") s = s + 0
    printf "hl.monitor({ output = \"%s\", mode = \"%s\", position = \"%s\", scale = %s, transform = %d", $1, $2, $3, s, $5
    if ($6 != "") printf ", mirror = \"%s\"", $6
    printf " })"
  }'
}

apply_record() { hyprctl eval "$(lua_for "$1")" >/dev/null 2>&1; }

# change <name> <new record>: apply, ask for confirmation, keep or go back
change() {
  name="$1"; new="$2"
  old="$(current_record "$name")"
  apply_record "$new"
  sleep 1
  ans="$(printf 'Keep these settings\nGo back\n' | timeout 12 "$REAL_ROFI" -dmenu -i -no-custom -p "Display" -mesg "Keeping the new settings in 12 seconds... Pick Go back (or do nothing) to undo." 2>/dev/null)"
  case "$ans" in
    "Keep these settings") save_record "$new"; note "Saved" ;;
    *) apply_record "$old"; note "Went back to the previous settings" ;;
  esac
}

set_field() {   # set_field <name> <field number 2-6> <value>
  rec="$(current_record "$1")"
  new="$(printf '%s' "$rec" | awk -F'\t' -v OFS='\t' -v f="$2" -v v="$3" '{ $f = v; print }')"
  change "$1" "$new"
}

resolution_menu() {
  name="$1"
  modes="$(monitors_json | jq -r --arg n "$name" '.[] | select(.name == $n) | .availableModes[]' | sed 's/Hz$//' | awk '!seen[$0]++')"
  [ -n "$modes" ] || { note "No modes reported"; return; }
  pick="$( { echo 'Custom resolution...'; printf '%s\n' "$modes"; } | menu "Resolution" "Resolution @ refresh rate for $name")" || return
  case "$pick" in
    Custom*)
      cur="$(current_record "$name" | cut -f2)"
      pick="$(printf '' | rofi -dmenu -p "Custom" -mesg "WIDTHxHEIGHT or WIDTHxHEIGHT@HZ, e.g. 1440x1080 or 1280x960@60. Now: $cur")" || return
      case "$pick" in
        *@*) ;;
        *) rate="${cur#*@}"; [ "$rate" = "$cur" ] && rate=60; pick="$pick@$rate" ;;
      esac
      printf '%s' "$pick" | grep -Eq '^[0-9]{3,5}x[0-9]{3,5}@[0-9]+(\.[0-9]+)?$' || { note "That does not look like 1440x1080 or 1440x1080@60"; return; } ;;
  esac
  [ -n "$pick" ] && set_field "$name" 2 "$pick"
}

scale_menu() {
  name="$1"
  pick="$(printf '1\n1.25\n1.5\n1.75\n2\nauto\ncustom...\n' | menu "Scale" "1 = sharpest and smallest, 2 = twice as big")" || return
  case "$pick" in
    custom*) pick="$(printf '' | rofi -dmenu -p "Scale" -mesg "A number between 0.5 and 4, e.g. 1.33")" || return ;;
  esac
  case "$pick" in auto) ;; ''|*[!0-9.]*) note "Not a number"; return ;; esac
  set_field "$name" 4 "$pick"
}

rotation_menu() {
  name="$1"
  pick="$(printf 'Normal\nRotate 90 degrees\nRotate 180 degrees\nRotate 270 degrees\n' | menu "Rotation" "$name")" || return
  case "$pick" in
    Normal) t=0 ;; *"90 "*) t=1 ;; *"180 "*) t=2 ;; *"270 "*) t=3 ;; *) return ;;
  esac
  set_field "$name" 5 "$t"
}

position_menu() {
  name="$1"
  json="$(monitors_json)"
  [ "$(printf '%s' "$json" | jq 'length')" -gt 1 ] || { note "Only one screen is connected"; return; }
  other="$(printf '%s' "$json" | jq -r --arg n "$name" '.[] | select(.name != $n) | .name' | menu "Next to" "Place $name next to which screen?")" || return
  side="$(printf 'Right of it\nLeft of it\nAbove it\nBelow it\n' | menu "Side" "$name goes ...")" || return
  pos="$(printf '%s' "$json" | jq -r --arg me "$name" --arg o "$other" --arg side "$side" '
    def lw: ((if (.transform % 2) == 1 then .height else .width end) / .scale | floor);
    def lh: ((if (.transform % 2) == 1 then .width else .height end) / .scale | floor);
    (.[] | select(.name == $me)) as $m | (.[] | select(.name == $o)) as $t |
    if   $side | startswith("Right") then "\($t.x + ($t | lw))x\($t.y)"
    elif $side | startswith("Left")  then "\($t.x - ($m | lw))x\($t.y)"
    elif $side | startswith("Above") then "\($t.x)x\($t.y - ($m | lh))"
    else "\($t.x)x\($t.y + ($t | lh))" end')"
  [ -n "$pos" ] && set_field "$name" 3 "$pos"
}

mirror_menu() {
  name="$1"
  json="$(monitors_json)"
  [ "$(printf '%s' "$json" | jq 'length')" -gt 1 ] || { note "Only one screen is connected"; return; }
  pick="$( { echo 'Stop mirroring'; printf '%s' "$json" | jq -r --arg n "$name" '.[] | select(.name != $n) | .name'; } | menu "Mirror" "Show the picture of which screen on $name?")" || return
  case "$pick" in "Stop mirroring") pick="" ;; esac
  set_field "$name" 6 "$pick"
}

# ---- stretched resolution for games (gamescope), see krmv-stretch.sh
STRETCH="$STATE/stretch.conf"
sget() { sed -n "s/^$1=//p" "$STRETCH" 2>/dev/null | head -n1; }
sput() {   # sput key value
  touch "$STRETCH"
  if grep -q "^$1=" "$STRETCH"; then sed -i "s|^$1=.*|$1=$2|" "$STRETCH"; else echo "$1=$2" >> "$STRETCH"; fi
}
stretch_menu() {
  while :; do
    on="$(sget enabled)"; w="$(sget width)"; h="$(sget height)"
    [ -n "$w" ] || { w=1440; h=1080; }
    if [ "$on" = 1 ]; then state="ON"; else state="OFF"; fi
    pick="$(printf 'Stretch is %s (click to switch)\nResolution to stretch: %sx%s\nCopy the Steam launch option\n' "$state" "$w" "$h" \
      | menu "Stretch" "Games run at that resolution (e.g. 4:3) and are stretched over the whole 16:9 screen.")" || return
    case "$pick" in
      "Stretch is"*)
        if [ "$on" = 1 ]; then sput enabled 0; note "Stretch is now OFF"; else sput enabled 1; sput width "$w"; sput height "$h"; note "Stretch is now ON ($w x $h). Games started with krmv-stretch use it. Per game: KRMV_STRETCH=1280x960 krmv-stretch %command%"; fi ;;
      "Resolution to"*)
        r="$(printf '1280x960\n1440x1080\n1600x1200\n1024x768\n1920x1440\n1280x1024\ncustom...\n' | menu "Resolution" "The size the game renders at")" || continue
        case "$r" in custom*) r="$(printf '' | rofi -dmenu -p "WxH" -mesg "e.g. 1440x1080")" || continue ;; esac
        printf '%s' "$r" | grep -Eq '^[0-9]{3,5}x[0-9]{3,5}$' || { note "Use the form 1440x1080"; continue; }
        sput width "${r%x*}"; sput height "${r#*x}"; note "Stretch resolution: $r" ;;
      "Copy"*)
        printf '%s' 'krmv-stretch %command%' | wl-copy 2>/dev/null
        note "Copied: krmv-stretch %command%  (paste it into the game's Steam Launch Options, once)" ;;
      *) return ;;
    esac
  done
}

reset_all() {
  ok="$(printf 'No\nYes, reset all screens\n' | menu "Reset" "Back to each screen's preferred mode, scale 1")" || return
  case "$ok" in Yes*) rm -f "$FILE"; hyprctl eval 'hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })' >/dev/null 2>&1; note "Display settings reset" ;; esac
}

main_menu() {
  while :; do
    pick="$(printf 'Resolution and refresh rate\nScale (size of everything)\nRotation\nPosition (several screens)\nMirror a screen\nStretched resolution for games (gamescope)\nReset all display settings\n' | menu "Display" "Changes can be undone: you get 12 seconds to confirm.")" || return 0
    case "$pick" in
      Reset*) reset_all; continue ;;
      Stretched*) stretch_menu; continue ;;
    esac
    name="$(pick_monitor)" || continue
    case "$pick" in
      Resolution*) resolution_menu "$name" ;;
      Scale*)      scale_menu "$name" ;;
      Rotation*)   rotation_menu "$name" ;;
      Position*)   position_menu "$name" ;;
      Mirror*)     mirror_menu "$name" ;;
      *) return 0 ;;
    esac
  done
}

case "${1:-menu}" in
  menu) main_menu ;;
  *) echo "Usage: $0 [menu]"; exit 1 ;;
esac
