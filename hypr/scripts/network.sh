#!/bin/sh
# NetworkManager helper (Wi-Fi autoconnect).
#   network.sh autoconnect   enable autoconnect for every saved Wi-Fi profile (used by install.sh)
#   network.sh menu          rofi menu: manage saved networks, connect, autoconnect
#   network.sh list          show saved connections and their autoconnect state
#   network.sh connect       pick a visible Wi-Fi network and connect once with a password

if ! command -v nmcli >/dev/null 2>&1; then
  notify-send "Network" "nmcli is not installed. Run the setup installer again." 2>/dev/null
  exit 1
fi

note() { notify-send "Network" "$1" 2>/dev/null; }
rofi_msg() { rofi -e "$1" 2>/dev/null || note "$1"; }

# Privileged helper: from a menu there is no terminal for a sudo prompt, so use the polkit dialog.
priv() {
  if [ ! -t 0 ] && command -v pkexec >/dev/null 2>&1; then pkexec "$@"; else sudo "$@"; fi
}

autoconnect() {
  nmcli networking on >/dev/null 2>&1 || priv nmcli networking on >/dev/null 2>&1 || true
  nmcli radio wifi on >/dev/null 2>&1 || true

  saved="$(nmcli -t -f TYPE,UUID connection show 2>/dev/null \
    | awk -F: 'tolower($1) ~ /wireless|wifi/ { print $2 }')"
  [ -n "$saved" ] || { note "No saved Wi-Fi networks yet. Connect once, then autoconnect is enabled."; return 0; }

  # One dialog for all profiles instead of one per network.
  # shellcheck disable=SC2086
  if priv sh -c '
    for uuid do
      nmcli connection modify "$uuid" connection.autoconnect yes connection.autoconnect-priority 10 >/dev/null 2>&1 || exit 1
    done
  ' sh $saved >/dev/null 2>&1; then
    note "Wi-Fi autoconnect enabled for saved networks. It will connect on the next boot or after a reconnect."
  else
    note "Could not change autoconnect. Check polkit/sudo and try again."
  fi
}

list_connections() {
  nmcli -t -f TYPE,NAME,AUTOCONNECT connection show 2>/dev/null \
    | awk -F: '{ printf "%-14s %-6s %s\n", $1, $3, $2 }'
}

# nmcli: try as the logged-in user first (allowed for local sessions), then with the password dialog
nm() { nmcli "$@" 2>/dev/null || priv nmcli "$@" 2>/dev/null; }

# ---- saved Wi-Fi networks: connect / autoconnect / password / priority / forget
saved_rows() {   # prints: uuid <TAB> autoconnect <TAB> priority <TAB> name   (Wi-Fi profiles only)
  nmcli -t -f UUID,TYPE,AUTOCONNECT,AUTOCONNECT-PRIORITY,NAME connection show 2>/dev/null \
    | while IFS=: read -r uuid type auto prio name; do
        case "$type" in *wireless*|*wifi*) ;; *) continue ;; esac
        name="$(printf '%s' "$name" | sed 's/\\:/:/g')"
        printf '%s\t%s\t%s\t%s\n' "$uuid" "$auto" "$prio" "$name"
      done
}
saved_menu() {
  while :; do
    rows="$(saved_rows)"
    [ -n "$rows" ] || { note "No saved Wi-Fi networks yet."; return 0; }
    labels="$(printf '%s\n' "$rows" | awk -F'\t' '{ printf "%-10s %s\n", ($2 == "yes" ? "[auto]" : "[manual]"), $4 }')"
    i="$(printf '%s\n' "$labels" | rofi -dmenu -i -no-custom -format i -p 'Saved' \
          -mesg 'Pick a network to manage it. [auto] = connects by itself.')" || return 0
    [ -n "$i" ] || return 0
    line="$(printf '%s\n' "$rows" | sed -n "$((i + 1))p")"
    uuid="$(printf '%s' "$line" | cut -f1)"; auto="$(printf '%s' "$line" | cut -f2)"
    prio="$(printf '%s' "$line" | cut -f3)"; name="$(printf '%s' "$line" | cut -f4)"
    if [ "$auto" = yes ]; then toggle="Turn autoconnect OFF"; else toggle="Turn autoconnect ON"; fi
    act="$(printf 'Connect now\n%s\nChange password\nSet priority (now %s)\nForget this network\n' "$toggle" "$prio" \
          | rofi -dmenu -i -no-custom -p "$name")" || continue
    case "$act" in
      "Connect now")
        if nmcli connection up uuid "$uuid" >/dev/null 2>&1; then note "Connected to $name"
        else note "Could not connect to $name. If the password changed, use Change password."; fi ;;
      "Turn autoconnect OFF") nm connection modify uuid "$uuid" connection.autoconnect no && note "$name: autoconnect OFF" ;;
      "Turn autoconnect ON")  nm connection modify uuid "$uuid" connection.autoconnect yes && note "$name: autoconnect ON" ;;
      "Change password")
        pass="$(printf '' | rofi -dmenu -password -p "New password" -mesg "$name")" || continue
        [ -n "$pass" ] || continue
        if nm connection modify uuid "$uuid" wifi-sec.psk "$pass"; then
          if nmcli connection up uuid "$uuid" >/dev/null 2>&1; then note "Password saved, connected to $name"
          else note "Password saved, but connecting failed. Is the password right?"; fi
        else note "Could not change the password"; fi ;;
      "Set priority"*)
        p="$(printf '' | rofi -dmenu -p "Priority" -mesg "Higher number = preferred when several known networks are in range (now $prio)")" || continue
        case "$p" in ''|*[!0-9-]*) note "Priority must be a number"; continue ;; esac
        nm connection modify uuid "$uuid" connection.autoconnect-priority "$p" && note "$name: priority $p" ;;
      "Forget"*)
        ok="$(printf 'No, keep it\nYes, forget %s\n' "$name" | rofi -dmenu -i -no-custom -p 'Forget?')" || continue
        case "$ok" in Yes*) nm connection delete uuid "$uuid" && note "Forgot $name" ;; esac ;;
    esac
  done
}

connect_wifi() {
  nmcli radio wifi on >/dev/null 2>&1 || true
  nmcli device wifi rescan >/dev/null 2>&1 || true
  sleep 1
  ssids="$(nmcli -t -f SSID device wifi list 2>/dev/null | sed '/^$/d' | sort -u)"
  [ -n "$ssids" ] || { rofi_msg "No Wi-Fi networks were found nearby."; return 0; }
  ssid="$(printf '%s\n' "$ssids" | rofi -dmenu -i -p '' -mesg 'Pick a Wi-Fi network')" || return 0
  [ -n "$ssid" ] || return 0
  pass="$(printf '' | rofi -dmenu -p "Password for $ssid" -password)" || return 0
  if [ -n "$pass" ] && nmcli device wifi connect "$ssid" password "$pass" >/dev/null 2>&1; then
    nm connection modify "$ssid" connection.autoconnect yes connection.autoconnect-priority 10 >/dev/null 2>&1 || true
    note "Connected to $ssid"
  elif nmcli device wifi connect "$ssid" >/dev/null 2>&1; then
    nm connection modify "$ssid" connection.autoconnect yes connection.autoconnect-priority 10 >/dev/null 2>&1 || true
    note "Connected to $ssid"
  else
    rofi_msg "Could not connect to $ssid. Check the password and try again."
  fi
}

menu() {
  while :; do
    pick="$(printf 'Saved networks (connect, forget, password, priority)\nConnect to a new Wi-Fi network\nEnable autoconnect for all saved Wi-Fi\n' \
      | rofi -dmenu -i -no-custom -p '' -mesg 'NetworkManager is the network manager on this system.')" || return 0
    case "$pick" in
      "Saved "*) saved_menu ;;
      "Connect "*) connect_wifi ;;
      "Enable "*) autoconnect ;;
      *) return 0 ;;
    esac
  done
}

case "${1:-menu}" in
  autoconnect) autoconnect ;;
  list)        list_connections ;;
  connect)     connect_wifi ;;
  menu)        menu ;;
  *) echo "Usage: $0 [autoconnect|list|connect|menu]"; exit 1 ;;
esac
