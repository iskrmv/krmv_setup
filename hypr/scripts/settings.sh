#!/bin/sh
# Settings (SUPER + I): default apps, keyboard shortcuts, desktop widgets, night mode.
CFG="${HYPR_CFG:-$HOME/.config/hypr}"
STATE="${KRMV_STATE:-$HOME/.local/state/krmv-setup}"
APP_DIRS="${APP_DIRS:-$HOME/.local/share/applications /usr/local/share/applications /usr/share/applications /var/lib/flatpak/exports/share/applications $HOME/.local/share/flatpak/exports/share/applications}"
DEF="$CFG/data/binds.tsv"
USER_OV="$STATE/binds.user.tsv"
TAB="$(printf '\t')"

# ------------------------------------------------------------------ helpers
menu() {     # menu <prompt> [message]  (reads the choices from stdin)
  rofi -dmenu -i -no-custom -p "$1" ${2:+-mesg "$2"}
}
note() { notify-send "Settings" "$1" 2>/dev/null; }

# ------------------------------------------------------------------ default apps
role_label() {
  case "$1" in
    browser) echo "Web browser" ;; files) echo "File manager" ;; terminal) echo "Terminal" ;;
    editor) echo "Text editor" ;; video) echo "Video player" ;; audio) echo "Music player" ;;
    image) echo "Image viewer" ;; pdf) echo "PDF reader" ;;
  esac
}
role_mimes() {
  case "$1" in
    browser) echo "x-scheme-handler/http x-scheme-handler/https text/html" ;;
    files)   echo "inode/directory" ;;
    editor)  echo "text/plain text/markdown text/x-python text/x-shellscript" ;;
    video)   echo "video/mp4 video/x-matroska video/webm video/x-msvideo video/quicktime" ;;
    audio)   echo "audio/mpeg audio/flac audio/ogg audio/x-wav audio/mp4" ;;
    image)   echo "image/png image/jpeg image/gif image/webp image/svg+xml" ;;
    pdf)     echo "application/pdf" ;;
  esac
}
first_mime() { role_mimes "$1" | cut -d' ' -f1; }

desktop_name() {   # desktop_name <file.desktop>: the app's name
  for d in $APP_DIRS; do
    [ -f "$d/$1" ] && { grep -m1 '^Name=' "$d/$1" | cut -d= -f2-; return 0; }
  done
  echo "${1%.desktop}"
}
candidates() {     # candidates <mime>: "Name<TAB>file.desktop" of every app that can open it
  for d in $APP_DIRS; do
    for f in "$d"/*.desktop; do
      [ -f "$f" ] || continue
      grep -q '^NoDisplay=true' "$f" && continue
      awk -F= -v m="$1" '/^MimeType=/ { n = split($2, a, ";"); for (i = 1; i <= n; i++) if (a[i] == m) ok = 1 } END { exit !ok }' "$f" || continue
      printf '%s\t%s\n' "$(grep -m1 '^Name=' "$f" | cut -d= -f2-)" "$(basename "$f")"
    done
  done | sort -u
}
current_app() {    # current_app <role>: the name of the current default
  case "$1" in
    terminal)
      t=""; [ -f "$STATE/apps.conf" ] && t="$(grep -m1 '^TERMINAL=' "$STATE/apps.conf" | cut -d= -f2-)"
      echo "${t:-kitty}" ;;
    *)
      d="$(xdg-mime query default "$(first_mime "$1")" 2>/dev/null)"
      if [ -n "$d" ]; then desktop_name "$d"; else echo "not set"; fi ;;
  esac
}
set_pref() {       # set_pref KEY value: writes to apps.conf
  mkdir -p "$STATE"; touch "$STATE/apps.conf"
  grep -v "^$1=" "$STATE/apps.conf" > "$STATE/apps.conf.tmp"
  printf '%s=%s\n' "$1" "$2" >> "$STATE/apps.conf.tmp"
  mv "$STATE/apps.conf.tmp" "$STATE/apps.conf"
}
set_default() {    # set_default <role> <file.desktop>
  case "$1" in
    browser) xdg-settings set default-web-browser "$2" 2>/dev/null || for m in $(role_mimes browser); do xdg-mime default "$2" "$m"; done ;;
    *) for m in $(role_mimes "$1"); do xdg-mime default "$2" "$m"; done ;;
  esac
}
choose_app() {     # choose_app <role>
  role="$1"
  if [ "$role" = terminal ]; then
    list=""
    for t in kitty alacritty foot wezterm ghostty konsole gnome-terminal xterm; do
      command -v "$t" >/dev/null 2>&1 && list="$list$t
"
    done
    pick="$(printf '%s' "$list" | menu "Terminal" "Now: $(current_app terminal)")" || return
    [ -n "$pick" ] && { set_pref TERMINAL "$pick"; note "Terminal: $pick"; }
    return
  fi
  cands="$(candidates "$(first_mime "$role")")"
  if [ -z "$cands" ]; then note "No installed app can open this kind of file."; return; fi
  pick="$(printf '%s\n' "$cands" | cut -f1 | menu "$(role_label "$role")" "Now: $(current_app "$role")")" || return
  [ -n "$pick" ] || return
  file="$(printf '%s\n' "$cands" | awk -F'\t' -v n="$pick" '$1 == n { print $2; exit }')"
  set_default "$role" "$file"
  note "$(role_label "$role"): $pick"
}
default_apps_menu() {
  while :; do
    list=""
    for r in browser files terminal editor video audio image pdf; do
      list="$list$(printf '%-16s %s' "$(role_label $r)" "$(current_app $r)")$TAB$r
"
    done
    line="$(printf '%s' "$list" | rofi -dmenu -i -no-custom -display-columns 1 -p "Default apps" -mesg "Choose one to change it. Esc goes back.")" || return
    role="$(printf '%s' "$line" | cut -f2)"
    [ -n "$role" ] && choose_app "$role"
  done
}

# ------------------------------------------------------------------ keyboard shortcuts
effective_binds() {   # id<TAB>keys<TAB>description, your changes applied
  awk -F'\t' -v ov="$USER_OV" '
    BEGIN { while ((getline l < ov) > 0) { split(l, p, "\t"); if (p[1] != "") o[p[1]] = p[2] } }
    /^#/ || NF < 4 { next }
    { k = ($1 in o) ? o[$1] : $2; printf "%s\t%s\t%s\n", $1, k, $3 }' "$DEF"
}
norm_keys() {         # norm_keys "super+shift+t": prints SUPER + SHIFT + T, fails if it is not a valid combination
  printf '%s' "$1" | awk '
    BEGIN { m["/"]="slash"; m["."]="period"; m[","]="comma"; m[";"]="semicolon"; m["-"]="minus"; m["="]="equal"
            m["["]="bracketleft"; m["]"]="bracketright"; m["`"]="grave"; m["\\"]="backslash"; m["'"'"'"]="apostrophe"
            c["return"]="Return"; c["enter"]="Return"; c["print"]="Print"; c["tab"]="Tab"; c["escape"]="Escape"; c["esc"]="Escape"
            c["backspace"]="BackSpace"; c["delete"]="Delete"; c["space"]="space"; c["home"]="Home"; c["end"]="End"
            c["left"]="Left"; c["right"]="Right"; c["up"]="Up"; c["down"]="Down"; c["pageup"]="Prior"; c["pagedown"]="Next" }
    { n = split($0, parts, "+")
      for (i = 1; i <= n; i++) {
        p = parts[i]; gsub(/^[ \t]+|[ \t]+$/, "", p)
        if (p == "") exit 1
        u = toupper(p)
        if (u == "WIN" || u == "META" || u == "SUPER") u = "SUPER"
        if (u == "CONTROL") u = "CTRL"
        if (u == "SUPER" || u == "CTRL" || u == "ALT" || u == "SHIFT") { if (i == n) exit 1; has[u] = 1 }
        else { if (i != n) exit 1; key = (p in m) ? m[p] : ((tolower(p) in c) ? c[tolower(p)] : ((length(p) == 1) ? toupper(p) : p)) }
      }
      if (key == "") exit 1
      out = ""
      split("SUPER CTRL ALT SHIFT", order, " ")
      for (i = 1; i <= 4; i++) if (has[order[i]]) out = out order[i] " + "
      print out key }'
}
reserved() {          # keys that are taken by the fixed shortcuts
  case "$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')" in
    "SUPER + Q"|"SUPER + F"|"SUPER + T"|"ALT + SHIFT"|"SUPER + LEFT"|"SUPER + RIGHT"|"SUPER + UP"|"SUPER + DOWN") return 0 ;;
    "SUPER + SHIFT + LEFT"|"SUPER + SHIFT + RIGHT"|"SUPER + SHIFT + UP"|"SUPER + SHIFT + DOWN") return 0 ;;
    "SUPER + "[0-9]|"SUPER + SHIFT + "[0-9]) return 0 ;;
  esac
  return 1
}
save_override() {     # save_override <id> <keys>
  mkdir -p "$STATE"; touch "$USER_OV"
  grep -v "^$1$TAB" "$USER_OV" > "$USER_OV.tmp"
  printf '%s\t%s\n' "$1" "$2" >> "$USER_OV.tmp"
  mv "$USER_OV.tmp" "$USER_OV"
  sh "$CFG/scripts/gen-binds.sh" && hyprctl reload >/dev/null 2>&1
}
change_shortcut() {   # change_shortcut <id> <current keys> <description>
  id="$1"; cur="$2"; desc="$3"
  while :; do
    typed="$(printf '' | rofi -dmenu -p "New keys" -filter "$cur" \
      -mesg "$desc. Type the keys, for example:  SUPER + SHIFT + T   or   CTRL + ALT + Return. Enter saves, Esc cancels.")" || return
    keys="$(norm_keys "$typed")" || { note "That is not a valid combination: $typed"; continue; }
    if reserved "$keys"; then note "$keys is used by a fixed shortcut. Pick another one."; continue; fi
    other="$(effective_binds | awk -F'\t' -v k="$keys" -v me="$id" 'tolower($2) == tolower(k) && $1 != me { print $3; exit }')"
    if [ -n "$other" ]; then note "$keys is already used by: $other"; continue; fi
    save_override "$id" "$keys"
    note "$desc: $keys"
    return
  done
}
shortcuts_menu() {
  while :; do
    list="$(effective_binds | awk -F'\t' '{ printf "%-22s %s\t%s\t%s\t%s\n", $2, $3, $1, $2, $3 }')"
    list="$list
Reset all shortcuts to the defaults$TAB@reset"
    line="$(printf '%s\n' "$list" | rofi -dmenu -i -no-custom -display-columns 1 -p "Shortcuts" -mesg "Choose a shortcut to change it. Esc goes back.")" || return
    id="$(printf '%s' "$line" | cut -f2)"
    case "$id" in
      '') ;;
      @reset) rm -f "$USER_OV"; sh "$CFG/scripts/gen-binds.sh" && hyprctl reload >/dev/null 2>&1; note "All shortcuts are back to the defaults" ;;
      *) change_shortcut "$id" "$(printf '%s' "$line" | cut -f3)" "$(printf '%s' "$line" | cut -f4)" ;;
    esac
  done
}

# ------------------------------------------------------------------ main menu
main() {
  while :; do
    pick="$(printf 'Default apps\nKeyboard shortcuts\nDesktop widgets (move or hide the clock)\nNight mode (on / off)\n' | menu "Settings")" || exit 0
    case "$pick" in
      "Default apps") default_apps_menu ;;
      "Keyboard shortcuts") shortcuts_menu ;;
      "Desktop widgets"*) qs -p "$CFG/theme/quickshell/shell.qml" ipc call widgets move; exit 0 ;;
      "Night mode"*) sh "$CFG/scripts/nightmode.sh" toggle ;;
    esac
  done
}

[ -n "$KRMV_SOURCE_ONLY" ] && return 0 2>/dev/null
main
