#!/bin/sh
# NetworkManager helper (Wi-Fi autoconnect).
#   network.sh autoconnect   enable autoconnect for every saved Wi-Fi profile (used by install.sh)
#   network.sh menu          rofi menu: autoconnect, connect or list saved networks
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
    priv nmcli connection modify "$ssid" connection.autoconnect yes connection.autoconnect-priority 10 >/dev/null 2>&1 || true
    note "Connected to $ssid"
  elif nmcli device wifi connect "$ssid" >/dev/null 2>&1; then
    priv nmcli connection modify "$ssid" connection.autoconnect yes connection.autoconnect-priority 10 >/dev/null 2>&1 || true
    note "Connected to $ssid"
  else
    rofi_msg "Could not connect to $ssid. Check the password and try again."
  fi
}

menu() {
  while :; do
    pick="$(printf 'Enable autoconnect for saved Wi-Fi\nConnect to a Wi-Fi network\nShow saved connections\n' \
      | rofi -dmenu -i -no-custom -p '' -mesg 'NetworkManager is the network manager on this system.')" || return 0
    case "$pick" in
      "Enable "*) autoconnect ;;
      "Connect "*) connect_wifi ;;
      "Show "*) rofi_msg "$(list_connections)" ; return 0 ;;
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
