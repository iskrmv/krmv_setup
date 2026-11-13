#!/bin/sh
# fastfetch sized for your terminal: big logo when the terminal is wide, small logo when it is medium, no logo when narrow.
# This keeps the information from wrapping onto the next line in a small window.
command -v fastfetch >/dev/null 2>&1 || exit 0
cols="$(tput cols 2>/dev/null || echo "${COLUMNS:-80}")"
if [ "$cols" -ge 100 ]; then
  fastfetch
elif [ "$cols" -ge 78 ]; then
  fastfetch --logo-type small
else
  fastfetch --logo none
fi
