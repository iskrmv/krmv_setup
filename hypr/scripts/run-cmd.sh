#!/bin/sh
# Runs what you typed in the rofi launcher (installed as /usr/local/bin/run-cmd).
#   run btop        "run" + a command: opens it in your terminal and keeps the window open afterwards
#   btop            a bare command: terminal programs (btop, tork, nvim ...) open in the terminal, GUI programs start directly
cmd="$*"
[ -n "$cmd" ] || exit 0
in_terminal() {
  exec sh "$HOME/.config/hypr/scripts/run-in-terminal.sh" bash -c "$1; echo; read -r -p 'Press Enter to close ' _"
}
case "$cmd" in
  "run "*) in_terminal "${cmd#run }" ;;
esac
first="${cmd%% *}"
case "$first" in
  btop|htop|top|tork|bluetui|nmtui|nvim|vim|vi|nano|yazi|ranger|lazygit|ncdu|mc|fastfetch|cmus|ncspot|weechat|irssi|tmux|zellij|journalctl|man|less|bmon|iftop|nethogs|duf|dust|cava|calcurse|k9s|lazydocker|rtorrent|aria2c|stig)
    in_terminal "$cmd" ;;
esac
if ! command -v "$first" >/dev/null 2>&1; then
  notify-send -u critical "Launcher" "No such command: $first" 2>/dev/null
  exit 1
fi
exec setsid sh -c "$cmd" >/dev/null 2>&1
