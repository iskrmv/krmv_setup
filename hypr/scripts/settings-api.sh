#!/bin/sh
# Backend of the Settings app (theme/quickshell/SettingsApp.qml). The app only draws; this script reads and changes things.
#   settings-api.sh state                 print everything the app shows, as one JSON object
#   settings-api.sh <action> [arguments]  do one thing (toggle-night, toggle-mouse, polkit, stretch, dns, display, geo,
#                                         wifi, audio, open); the app asks for the state again afterwards
STATE="${KRMV_STATE:-$HOME/.local/state/krmv-setup}"
CFG="${HYPR_CFG:-$HOME/.config/hypr}"
S="$CFG/scripts"
mkdir -p "$STATE"

sget() { sed -n "s/^$1=//p" "$STATE/stretch.conf" 2>/dev/null | head -n1; }
sput() { touch "$STATE/stretch.conf"; if grep -q "^$1=" "$STATE/stretch.conf"; then sed -i "s|^$1=.*|$1=$2|" "$STATE/stretch.conf"; else echo "$1=$2" >> "$STATE/stretch.conf"; fi; }

state() {
  night=false; case "$(sh "$S/nightmode.sh" status 2>/dev/null)" in *[Oo][Nn]*|*true*|*active*) night=true ;; esac
  [ "$(sh "$S/mouse.sh" status 2>/dev/null)" = ON ] && mouse=true || mouse=false
  [ -e "$STATE/polkit-stock" ] && classic=true || classic=false
  [ "$(sget enabled)" = 1 ] && st_on=true || st_on=false
  sw="$(sget width)"; sh_="$(sget height)"; [ -n "$sw" ] || { sw=1440; sh_=1080; }
  st_method="$(sget method)"; [ -n "$st_method" ] || st_method=wayland
  iget() { v="$(sed -n "s/^$1=//p" "$STATE/input.conf" 2>/dev/null | head -n1)"; echo "${v:-$2}"; }
  input="$(jq -n -c --arg ms "$(iget mouse_sens 0)" --arg ma "$(iget mouse_accel adaptive)" --arg mn "$(iget mouse_natural false)" \
      --arg msc "$(iget mouse_scroll 1)" --arg lh "$(iget left_handed false)" --arg tn "$(iget tp_natural true)" \
      --arg tt "$(iget tp_tap true)" --arg td "$(iget tp_dwt true)" --arg ts "$(iget tp_scroll 0.5)" \
      '{mouseSens: ($ms | tonumber), mouseAccel: $ma, mouseNatural: ($mn == "true"), mouseScroll: ($msc | tonumber), leftHanded: ($lh == "true"),
        tpNatural: ($tn == "true"), tpTap: ($tt == "true"), tpDwt: ($td == "true"), tpScroll: ($ts | tonumber)}')"
  layouts="$(cat "$STATE/layouts" 2>/dev/null)"; [ -n "$layouts" ] || layouts="us,ru"

  monitors="$(hyprctl monitors -j 2>/dev/null | jq -c '[.[] | {name, make, model, width, height, x, y, transform,
      rate: (.refreshRate * 100 | round / 100), scale: (.scale * 100 | round / 100),
      modes: ([.availableModes[] | sub("Hz$"; "")] | reduce .[] as $m ([]; if index($m) then . else . + [$m] end))}]' 2>/dev/null)"
  [ -n "$monitors" ] || monitors='[]'

  geo="$(sh "$S/settings.sh" geo-list 2>/dev/null | jq -R -s -c 'split("\n") | map(select(length > 0) | split("\t") | {app: .[0], allowed: (.[1] == "true")})' 2>/dev/null)"
  [ -n "$geo" ] || geo='[]'

  active="$(nmcli -t -f UUID connection show --active 2>/dev/null)"
  wifi="$(nmcli -t -f UUID,TYPE,AUTOCONNECT,AUTOCONNECT-PRIORITY,NAME connection show 2>/dev/null | while IFS=: read -r uuid type auto prio name; do
      case "$type" in *wireless*|*wifi*) ;; *) continue ;; esac
      name="$(printf '%s' "$name" | sed 's/\\:/:/g')"
      on=0; printf '%s\n' "$active" | grep -qx "$uuid" && on=1
      printf '%s\t%s\t%s\t%s\t%s\n' "$uuid" "$auto" "$prio" "$on" "$name"
    done | jq -R -s -c 'split("\n") | map(select(length > 0) | split("\t") | {uuid: .[0], auto: (.[1] == "yes"), prio: (.[2] | tonumber? // 0), active: (.[3] == "1"), name: .[4]})' 2>/dev/null)"
  [ -n "$wifi" ] || wifi='[]'

  sinks="$(pactl --format=json list sinks 2>/dev/null | jq -c '[.[] | {name, desc: .description}]' 2>/dev/null)"
  [ -n "$sinks" ] || sinks='[]'
  defsink="$(pactl get-default-sink 2>/dev/null)"
  dns="$(dns status 2>&1 | head -60)"

  jq -n -c --argjson night "$night" --argjson mouse "$mouse" --argjson classic "$classic" \
    --argjson stOn "$st_on" --arg stW "$sw" --arg stH "$sh_" --arg stM "$st_method" --argjson input "$input" --arg layouts "$layouts" \
    --argjson monitors "$monitors" --argjson geo "$geo" --argjson wifi "$wifi" \
    --argjson sinks "$sinks" --arg defsink "$defsink" --arg dns "$dns" \
    '{night: $night, mouse: $mouse, polkitClassic: $classic,
      stretch: {enabled: $stOn, width: ($stW | tonumber), height: ($stH | tonumber), method: $stM}, layouts: $layouts,
      monitors: $monitors, input: $input, geo: $geo, wifi: $wifi, sinks: $sinks, defaultSink: $defsink, dns: $dns}'
}

case "${1:-state}" in
  state)         state ;;
  input)         # input set <key> <value>
    [ "$2" = set ] || exit 1
    key="$3"; val="$4"
    case "$val" in true|false|adaptive|flat) ;; ''|*[!0-9.-]*) exit 1 ;; esac
    case "$key" in
      mouse_sens)    lua="sensitivity = $val" ;;
      mouse_accel)   lua="accel_profile = \"$val\"" ;;
      mouse_natural) lua="natural_scroll = $val" ;;
      mouse_scroll)  lua="scroll_factor = $val" ;;
      left_handed)   lua="left_handed = $val" ;;
      tp_natural)    lua="touchpad = { natural_scroll = $val }" ;;
      tp_tap)        lua="touchpad = { tap_to_click = $val }" ;;
      tp_dwt)        lua="touchpad = { disable_while_typing = $val }" ;;
      tp_scroll)     lua="touchpad = { scroll_factor = $val }" ;;
      *) exit 1 ;;
    esac
    touch "$STATE/input.conf"
    if grep -q "^$key=" "$STATE/input.conf"; then sed -i "s|^$key=.*|$key=$val|" "$STATE/input.conf"; else echo "$key=$val" >> "$STATE/input.conf"; fi
    hyprctl eval "hl.config({ input = { $lua } })" >/dev/null 2>&1 ;;
  toggle-night)  sh "$S/nightmode.sh" toggle >/dev/null 2>&1 ;;
  toggle-mouse)  sh "$S/mouse.sh" toggle >/dev/null 2>&1 ;;
  polkit)        # polkit themed|classic
    SHELL_QML="$CFG/theme/quickshell/shell.qml"
    if [ "$2" = classic ]; then : > "$STATE/polkit-stock"; qs -p "$SHELL_QML" ipc call polkit classic >/dev/null 2>&1
    else rm -f "$STATE/polkit-stock"; qs -p "$SHELL_QML" ipc call polkit themed >/dev/null 2>&1; fi ;;
  stretch)       # stretch enabled 0|1   |   stretch size 1440x1080   |   stretch copy
    case "$2" in
      enabled) sput enabled "$3"; [ -n "$(sget width)" ] || { sput width 1440; sput height 1080; } ;;
      method)  sput method "$3" ;;
      size)    sput width "${3%x*}"; sput height "${3#*x}" ;;
      copy)    printf '%s' 'krmv-stretch %command%' | wl-copy 2>/dev/null; notify-send "Stretch" "Copied: krmv-stretch %command%  (paste it into the game's Steam Launch Options)" 2>/dev/null ;;
    esac ;;
  dns)           # dns <host> | stop | test
    case "$2" in
      stop) dns stop >/dev/null 2>&1 ;;
      *)    dns "$2" >/dev/null 2>&1 ;;
    esac ;;
  display)       sh "$S/display.sh" "$2" "$3" ;;
  geo)           sh "$S/settings.sh" geo-set "$2" "$3" ;;
  apps)          case "$2" in list) sh "$S/settings.sh" apps-json ;; set) sh "$S/settings.sh" app-set "$3" "$4" ;; esac ;;
  mime)          case "$2" in list) sh "$S/settings.sh" mimes-json ;; candidates) sh "$S/settings.sh" mime-candidates "$3" ;; set) sh "$S/settings.sh" mime-set "$3" "$4" ;; esac ;;
  binds)         case "$2" in list) sh "$S/settings.sh" binds-json ;; fixed) sh "$S/settings.sh" binds-fixed ;; set) sh "$S/settings.sh" bind-set "$3" "$4" ;; reset) sh "$S/settings.sh" binds-reset ;; esac ;;
  camera)        # camera state | block | unblock | portal <app> yes|no
    case "$2" in
      state)
        blocked=false; [ -e /etc/modprobe.d/krmv-camera-block.conf ] && blocked=true
        present=false; ls /dev/video* >/dev/null 2>&1 && present=true
        [ "$blocked" = true ] && present=true
        inuse="$(find /proc/[0-9]*/fd -lname '/dev/video*' 2>/dev/null | sed 's|/proc/\([0-9]*\)/.*|\1|' | sort -u \
                 | while read -r pid; do cat "/proc/$pid/comm" 2>/dev/null; done | sort -u | jq -R -s -c 'split("\n") | map(select(length > 0))')"
        [ -n "$inuse" ] || inuse='[]'
        portal="$(command -v flatpak >/dev/null 2>&1 && flatpak permissions devices camera 2>/dev/null \
                 | awk '$1 == "devices" && $2 == "camera" { print $3 "\t" $4 }' \
                 | jq -R -s -c 'split("\n") | map(select(length > 0) | split("\t") | {app: .[0], allowed: (.[1] == "yes")})')"
        [ -n "$portal" ] || portal='[]'
        jq -n -c --argjson present "$present" --argjson blocked "$blocked" --argjson inuse "$inuse" --argjson portal "$portal" \
          '{present: $present, blocked: $blocked, inUse: $inuse, portal: $portal}' ;;
      block)   pkexec sh -c 'printf "install uvcvideo /bin/false\n" > /etc/modprobe.d/krmv-camera-block.conf; modprobe -r uvcvideo' \
                 || notify-send "Camera" "Could not switch the camera off (is an app using it?)" ;;
      unblock) pkexec sh -c 'rm -f /etc/modprobe.d/krmv-camera-block.conf; modprobe uvcvideo' ;;
      portal)  flatpak permission-set devices camera "$3" "$4" ;;
    esac ;;
  wifi)          # wifi connect <uuid> | forget <uuid> | auto <uuid> yes|no
    case "$2" in
      scan)
        nmcli -t -f IN-USE,SIGNAL,SECURITY,SSID device wifi list --rescan yes 2>/dev/null | sed 's/\\:/\x01/g' \
          | jq -R -s -c 'split("\n") | map(select(length > 0) | split(":") | {inUse: (.[0] == "*"), signal: (.[1] | tonumber? // 0), secure: (.[2] != ""), ssid: (.[3:] | join(":") | gsub("\u0001"; ":"))})
                        | map(select(.ssid != "")) | group_by(.ssid) | map(max_by(.signal)) | sort_by(-.signal)' ;;
      join)    # wifi join <ssid> <password>   prints {"ok":true|false,"msg":"..."}
        ssid="$3"; pass="$4"
        saved=0; nmcli -t -f NAME connection show 2>/dev/null | grep -qxF "$ssid" && saved=1
        if [ "$saved" = 1 ]; then
          [ -n "$pass" ] && nmcli connection modify id "$ssid" wifi-sec.psk "$pass" >/dev/null 2>&1
          out="$(nmcli connection up id "$ssid" 2>&1)"; rc=$?
        elif [ -n "$pass" ]; then
          out="$(nmcli device wifi connect "$ssid" password "$pass" 2>&1)"; rc=$?
        else
          out="$(nmcli device wifi connect "$ssid" 2>&1)"; rc=$?
        fi
        if [ "$rc" = 0 ]; then
          nmcli connection modify id "$ssid" connection.autoconnect yes >/dev/null 2>&1
          jq -n -c '{ok: true, msg: "Connected"}'
        else
          # a profile that was just created with a wrong password must not stay behind
          [ "$saved" = 0 ] && nmcli connection delete id "$ssid" >/dev/null 2>&1
          case "$out" in
            *[Ss]ecrets*|*"(7)"*|*"(4)"*|*assword*|*handshake*|*authentication*) msg="Wrong password. Try again." ;;
            *"No network with SSID"*|*"not found"*) msg="That network is not in range right now." ;;
            *) msg="Could not connect: $(printf '%s' "$out" | head -n1)" ;;
          esac
          jq -n -c --arg msg "$msg" '{ok: false, msg: $msg}'
        fi ;;
      connect) nmcli connection up uuid "$3" >/dev/null 2>&1 || notify-send "Wi-Fi" "Could not connect. Is the password still right?" ;;
      forget)  nmcli connection delete uuid "$3" >/dev/null 2>&1 || pkexec nmcli connection delete uuid "$3" ;;
      auto)    nmcli connection modify uuid "$3" connection.autoconnect "$4" >/dev/null 2>&1 || pkexec nmcli connection modify uuid "$3" connection.autoconnect "$4" ;;
    esac ;;
  audio)         # audio boost | diagnostics | sink <name>
    case "$2" in
      boost) sh "$S/audio.sh" boost ;;
      diagnostics) sh "$S/audio.sh" diagnostics ;;
      sink)  pactl set-default-sink "$3" ;;
    esac ;;
  open)          # open apps | shortcuts | wifi-new | layouts | cleanup
    case "$2" in
      apps)       sh "$S/settings.sh" apps ;;
      shortcuts)  sh "$S/settings.sh" shortcuts ;;
      wifi-new)   sh "$S/network.sh" connect ;;
      layouts)    sh "$S/layout.sh" ;;
      cleanup)    sh "$S/run-in-terminal.sh" bash -c "sh $S/cleanup.sh; echo; read -r -p 'Press Enter to close ' _" ;;
    esac ;;
  *) echo "Usage: $0 state | toggle-night | toggle-mouse | polkit | stretch | dns | display | geo | wifi | audio | open"; exit 1 ;;
esac
