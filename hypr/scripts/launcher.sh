#!/bin/sh
# App launcher (ALT + SPACE, or the button in the bar).
#   - type letters: apps that START with them come first, looser guesses below
#   - TAB: switch to the list of command-line / terminal programs (btop, tork, nvim ...), TAB again goes back
#   - or type  run <command>  in the app list and press Enter
# Enter on a command opens GUI programs directly and known terminal programs in your terminal;
# Shift+Enter always opens the command in the terminal and keeps the window until you press Enter.
mode=drun
while :; do
  if [ "$mode" = drun ]; then
    rofi -show drun -kb-element-next "Alt+Down" -kb-custom-1 "Tab" \
      -mesg "Tab: command-line programs   |   not an app? type: run <command>"
    rc=$?
    [ "$rc" = 10 ] && { mode=run; continue; }
  else
    rofi -show run -kb-element-next "Alt+Down" -kb-custom-1 "Tab" \
      -run-command "run-cmd {cmd}" -run-shell-command "run-cmd run {cmd}" \
      -mesg "Commands   |   Enter: run   |   Shift+Enter: in a terminal   |   Tab: back to apps"
    rc=$?
    [ "$rc" = 10 ] && { mode=drun; continue; }
  fi
  exit 0
done
