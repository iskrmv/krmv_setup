#!/bin/sh
# Runs a command typed in the rofi launcher.
# Terminal (TUI) programs open inside your default terminal; everything else starts directly.
# Installed as /usr/local/bin/run-cmd by install.sh.
cmd="$*"
[ -n "$cmd" ] || exit 0
first="${cmd%% *}"
case "$first" in
  btop|htop|top|impala|bluetui|nmtui|nvim|vim|vi|nano|yazi|ranger|lazygit|ncdu|mc|fastfetch|cmus|ncspot|weechat|irssi|tmux|zellij|journalctl|man|less|bmon|iftop|nethogs|duf|dust|cava|calcurse|k9s|lazydocker)
    exec sh "$HOME/.config/hypr/scripts/run-in-terminal.sh" sh -c "$cmd; echo; read -r -p 'Press Enter to close ' _" ;;
esac
if ! command -v "$first" >/dev/null 2>&1; then
  notify-send -u critical "Launcher" "No such command: $first" 2>/dev/null
  exit 1
fi
exec setsid sh -c "$cmd" >/dev/null 2>&1
