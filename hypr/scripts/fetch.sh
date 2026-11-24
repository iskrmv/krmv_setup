#!/bin/sh
# fastfetch sized for your terminal: a small logo when the terminal is wide enough, no logo when it is narrow.
# This keeps the information from wrapping onto the next line in a small window.
command -v fastfetch >/dev/null 2>&1 || exit 0
cols="$(tput cols 2>/dev/null || echo "${COLUMNS:-80}")"
if [ "$cols" -ge 76 ]; then
  fastfetch
else
  fastfetch --logo none
fi
