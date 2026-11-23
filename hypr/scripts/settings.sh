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
    list="$list
More (choose by file format)$TAB@more
"
    line="$(printf '%s' "$list" | rofi -dmenu -i -no-custom -display-columns 1 -p "Default apps" -mesg "Simple: pick a role. More: pick an exact file type. Esc goes back.")" || return
    role="$(printf '%s' "$line" | cut -f2)"
    case "$role" in
      @more) mime_menu ;;
      '') ;;
      *) choose_app "$role" ;;
    esac
  done
}

all_mimes() {         # every MIME type advertised by an installed, visible app
  for d in $APP_DIRS; do
    [ -d "$d" ] || continue
    for f in "$d"/*.desktop; do
      [ -f "$f" ] || continue
      grep -q '^NoDisplay=true' "$f" && continue
      awk -F= '/^MimeType=/ { n = split($2, a, ";"); for (i = 1; i <= n; i++) if (a[i] != "") print a[i] }' "$f"
    done
  done | sort -u
}

mime_menu() {         # precise mode: choose the default app for one exact file type
  while :; do
    list=""
    for m in $(all_mimes); do
      cur="$(xdg-mime query default "$m" 2>/dev/null)"
      list="$list$(printf '%-42s %s' "$m" "${cur:-not set}")$TAB$m
"
    done
    [ -n "$list" ] || { note "No file types were found in the installed apps."; return; }
    line="$(printf '%s' "$list" | rofi -dmenu -i -no-custom -display-columns 1 -p "Default by file type" -mesg "Pick an exact MIME type, then pick its app. Esc goes back.")" || return
    mime="$(printf '%s' "$line" | cut -f2)"
    [ -n "$mime" ] || return
    cands="$(candidates "$mime")"
    [ -n "$cands" ] || { note "No installed app declares support for $mime."; continue; }
    pick="$(printf '%s\n' "$cands" | cut -f1 | menu "$mime" "Now: $(xdg-mime query default "$mime" 2>/dev/null)")" || continue
    [ -n "$pick" ] || continue
    file="$(printf '%s\n' "$cands" | awk -F'\t' -v n="$pick" '$1 == n { print $2; exit }')"
    xdg-mime default "$file" "$mime" && note "$mime: $pick"
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

# ------------------------------------------------------------------ desktop widgets
SHELL_QML="$CFG/theme/quickshell/shell.qml"
widget_ipc() { qs -p "$SHELL_QML" ipc call widgets "$1" 2>&1; }
widget_state() {      # widget_state <id>: ON or OFF, read from the saved file
  if grep -q "\"$1\":true" "$STATE/widgets.json" 2>/dev/null; then echo ON; else echo OFF; fi
}
widgets_menu() {
  while :; do
    pick="$(printf 'Move the clock / widget editor\nNet speed in the top bar  [%s]\nNet speed on the desktop  [%s]\nMedia output on the desktop  [%s]\n' \
      "$(widget_state netspeedbar)" "$(widget_state netspeed)" "$(widget_state mediaout)" \
      | menu "Desktop widgets" "Pick one to switch it on or off. All three are OFF by default.")" || return
    case "$pick" in
      "Move "*)  widget_ipc move >/dev/null; exit 0 ;;
      *"top bar"*) out="$(widget_ipc netspeedbar)" || { note "The bar did not answer: $out"; continue; }; note "Net speed in the top bar: $(widget_state netspeedbar)" ;;
      "Net speed on"*) out="$(widget_ipc netspeed)" || { note "The bar did not answer: $out"; continue; }; note "Net speed on the desktop: $(widget_state netspeed)" ;;
      "Media output"*) out="$(widget_ipc mediaout)" || { note "The bar did not answer: $out"; continue; }; note "Media output on the desktop: $(widget_state mediaout)" ;;
      *) return ;;
    esac
  done
}

# ------------------------------------------------------------------ audio
audio_menu() {
  while :; do
    pick="$(printf 'Laptop speakers too quiet? Raise all levels to 100%%\nSelect an output (speakers / headphones)\nCollect audio diagnostics\n' \
      | menu "Audio" "Speakers quiet but headphones fine = a hidden ALSA level is low.")" || return
    case "$pick" in
      "Laptop "*) sh "$CFG/scripts/audio.sh" boost ;;
      "Select "*) sh "$CFG/scripts/audio.sh" select ;;
      "Collect "*) sh "$CFG/scripts/audio.sh" diagnostics ;;
      *) return ;;
    esac
  done
}

# ------------------------------------------------------------------ network
network_menu() {
  sh "$CFG/scripts/network.sh" menu
}

# ------------------------------------------------------------------ geolocation
# GeoClue is the location service of Linux. Which apps may ask it for your position is written in
# /etc/geoclue/geoclue.conf, one [app-id] section per app with allowed=true/false. Changing it needs root.
GEOCLUE_CONF="${GEOCLUE_CONF:-/etc/geoclue/geoclue.conf}"
geo_priv() { if [ -t 0 ]; then sudo "$@"; else pkexec "$@"; fi; }
geo_rows() {          # prints "app<TAB>true|false" for every app section of geoclue.conf
  [ -r "$GEOCLUE_CONF" ] || return 0
  awk '
    /^\[/ { sec = $0; gsub(/[\[\]]/, "", sec); next }
    /^[ \t]*allowed[ \t]*=/ {
      v = $0; sub(/^[^=]*=[ \t]*/, "", v); sub(/[ \t\r]+$/, "", v)
      if (sec !~ /^(agent|wifi|3g|cdma|modem-gps|network-nmea|static-source|compass)$/) print sec "\t" v
    }' "$GEOCLUE_CONF"
}
geo_set() {           # geo_set <app-id> true|false   (adds the app if it is not in the file yet)
  app="$1"; val="$2"
  [ -n "$app" ] || return 0
  case "$app" in *[!A-Za-z0-9._-]*) note "Invalid app id: $app"; return 1 ;; esac
  tmp="$(mktemp)"
  if [ -r "$GEOCLUE_CONF" ] && grep -q "^\[$app\]" "$GEOCLUE_CONF"; then
    awk -v app="$app" -v val="$val" '
      /^\[/ { insec = ($0 == "[" app "]") }
      insec && /^[ \t]*allowed[ \t]*=/ { print "allowed=" val; next }
      { print }' "$GEOCLUE_CONF" > "$tmp"
  else
    { [ -r "$GEOCLUE_CONF" ] && cat "$GEOCLUE_CONF"; printf '\n[%s]\nallowed=%s\nsystem=false\nusers=\n' "$app" "$val"; } > "$tmp"
  fi
  if geo_priv install -Dm644 "$tmp" "$GEOCLUE_CONF"; then
    geo_priv systemctl restart geoclue 2>/dev/null || true
    if [ "$val" = true ]; then note "Location for $app: ALLOWED"; else note "Location for $app: DENIED"; fi
  else
    note "Could not write $GEOCLUE_CONF (password dialog cancelled?)"
  fi
  rm -f "$tmp"
}
location_menu() {
  if [ ! -r "$GEOCLUE_CONF" ]; then
    note "GeoClue is not installed. Run the setup installer again (package: geoclue)."
    return 0
  fi
  while :; do
    list="Add an app$TAB@add
"
    rows="$(geo_rows)"
    if [ -n "$rows" ]; then
      while IFS="$TAB" read -r app val; do
        [ -n "$app" ] || continue
        if [ "$val" = true ]; then label="ALLOWED"; else label="DENIED "; fi
        list="$list$(printf '%-7s %s' "$label" "$app")$TAB$app$TAB$val
"
      done <<ROWS
$rows
ROWS
    fi
    line="$(printf '%s' "$list" | rofi -dmenu -i -no-custom -display-columns 1 -p "Location" \
      -mesg "Pick an app to switch it between ALLOWED and DENIED. Esc goes back.")" || return
    app="$(printf '%s' "$line" | cut -f2)"
    val="$(printf '%s' "$line" | cut -f3)"
    case "$app" in
      @add)
        typed="$(printf '' | rofi -dmenu -p "App id" -mesg "Desktop file name without .desktop, e.g. firefox or org.gnome.Maps")" || continue
        geo_set "$typed" true ;;
      '') return ;;
      *)  if [ "$val" = true ]; then geo_set "$app" false; else geo_set "$app" true; fi ;;
    esac
  done
}

# ------------------------------------------------------------------ dns
# Uses the "dns" command (DNS-over-TLS switcher). It asks for the password itself (graphical dialog from rofi).
dns_show() { rofi -e "$1"; }
dns_menu() {
  command -v dns >/dev/null 2>&1 || { note "The dns command is not installed. Run the setup installer again."; return 0; }
  while :; do
    pick="$(printf 'Show current DNS\nAdGuard DNS (blocks ads)\nAdGuard DNS (no filtering)\nAdGuard Family\nCloudflare 1.1.1.1\nGoogle DNS\nQuad9\nCustom server (type it)\nTest DNS\nTurn OFF (restore the original DNS)\n' \
      | menu "DNS" "Encrypted DNS-over-TLS for the whole system.")" || return
    server=""
    case "$pick" in
      "Show current"*) dns_show "$(dns status 2>&1)"; continue ;;
      "AdGuard DNS (blocks"*) server="dns.adguard-dns.com" ;;
      "AdGuard DNS (no"*) server="unfiltered.adguard-dns.com" ;;
      "AdGuard Family"*) server="family.adguard-dns.com" ;;
      "Cloudflare"*) server="cloudflare-dns.com" ;;
      "Google"*) server="dns.google" ;;
      "Quad9"*) server="dns.quad9.net" ;;
      "Custom"*) server="$(printf '' | rofi -dmenu -p "DNS server" -mesg "A host or IP, e.g. dns.adguard.com or 1.1.1.1")" || continue ;;
      "Test"*) dns_show "$(dns test 2>&1)"; continue ;;
      "Turn OFF"*) dns_show "$(dns stop 2>&1)"; continue ;;
      *) return ;;
    esac
    [ -n "$server" ] || continue
    dns_show "$(dns "$server" 2>&1)"
  done
}

# ------------------------------------------------------------------ main menu
main() {
  while :; do
    if [ -e "$STATE/polkit-stock" ]; then pdmode=CLASSIC; else pdmode=THEMED; fi
    pick="$(printf 'Default apps\nKeyboard shortcuts\nDesktop widgets (move, net speed, media output)\nDisplay (resolution, scale, stretch, position)\nNetwork (Wi-Fi autoconnect)\nDNS (change or turn off)\nLocation (geolocation permissions)\nAudio (outputs and laptop speakers)\nMouse for games: %s (flat, no acceleration)\nPassword dialog: %s (click to switch)\nNight mode (on / off)\n' "$(sh "$CFG/scripts/mouse.sh" status)" "$pdmode" | menu "Settings")" || exit 0
    case "$pick" in
      "Default apps") default_apps_menu ;;
      "Keyboard shortcuts") shortcuts_menu ;;
      "Desktop widgets"*) widgets_menu ;;
      "Display"*) sh "$CFG/scripts/display.sh" menu ;;
      "Network"*) network_menu ;;
      "DNS"*) dns_menu ;;
      "Location"*) location_menu ;;
      "Audio"*) audio_menu ;;
      "Mouse for games"*) sh "$CFG/scripts/mouse.sh" toggle ;;
      "Password dialog"*)
        if [ -e "$STATE/polkit-stock" ]; then
          rm -f "$STATE/polkit-stock"
          if qs -p "$SHELL_QML" ipc call polkit themed >/dev/null 2>&1; then note "Password dialog changed to: THEMED (the Tokyo Night one)"
          else note "Password dialog changed to: THEMED. Log out and in to apply."; fi
        else
          mkdir -p "$STATE"; : > "$STATE/polkit-stock"
          if qs -p "$SHELL_QML" ipc call polkit classic >/dev/null 2>&1; then note "Password dialog changed to: CLASSIC (hyprpolkitagent)"
          else note "Password dialog changed to: CLASSIC. Log out and in to apply."; fi
        fi ;;
      "Night mode"*) sh "$CFG/scripts/nightmode.sh" toggle ;;
    esac
  done
}

[ -n "$KRMV_SOURCE_ONLY" ] && return 0 2>/dev/null
main
