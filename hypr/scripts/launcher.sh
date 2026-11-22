#!/bin/sh
# App launcher (ALT + SPACE, or the button in the bar).
#   - type letters: apps that START with them come first, looser guesses below
#   - TAB: switch to the list of command-line / terminal programs (btop, tork, nvim ...); TAB again goes back to apps
#   - or type  run <command>  in the app list and press Enter
# In the command list: Enter runs GUI programs directly and known terminal programs in your terminal;
# Shift+Enter always opens the command in the terminal and keeps the window until you press Enter.
exec rofi -show drun -modes "drun,run" \
  -kb-mode-next "Tab,Shift+Right" -kb-element-next "Alt+Down" \
  -run-command "run-cmd {cmd}" -run-shell-command "run-cmd run {cmd}" \
  -mesg "Tab: command-line programs   |   not an app? type: run <command>"
