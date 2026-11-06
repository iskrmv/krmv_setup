#!/bin/sh
# Prints what Hyprland knows about every window and monitor. Run it while a window looks wrong
# (for example it sticks out of its border) and send the output.  Alias: winfo
echo "== Monitors"
hyprctl monitors -j | jq -r '.[] | "\(.name)  \(.width)x\(.height)@\(.refreshRate|floor)  scale \(.scale)  workspace \(.activeWorkspace.id)"'
echo
echo "== Windows (class | size | position | xwayland | floating | workspace)"
hyprctl clients -j | jq -r '.[] | "\(.class) | \(.size[0])x\(.size[1]) | \(.at[0]),\(.at[1]) | \(if .xwayland then "XWayland" else "Wayland" end) | \(if .floating then "floating" else "tiled" end) | ws \(.workspace.id)"'
