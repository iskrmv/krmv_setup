#!/bin/sh
# Shows the key name Hyprland sees when you press a key (use it for the HP Omen key). Ctrl+C to stop.
# Put the name it prints (the part after "sym:") into hypr/conf/keybinds.lua.
command -v wev >/dev/null 2>&1 || { echo "wev is not installed: sudo pacman -S wev"; exit 1; }
echo "Press the key now. Look for:  sym: <KeyName>   (Ctrl+C to stop)"
wev 2>&1 | grep --line-buffered "sym:"
