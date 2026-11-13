#!/bin/sh
# Opens your DEFAULT app for a role. The defaults are chosen in SUPER + I > Default apps.
# Usage: open-default.sh terminal|browser|files|editor|video|audio|image|pdf [arguments]
STATE="${KRMV_STATE:-$HOME/.local/state/krmv-setup}"
APP_DIRS="${APP_DIRS:-$HOME/.local/share/applications /usr/local/share/applications /usr/share/applications /var/lib/flatpak/exports/share/applications $HOME/.local/share/flatpak/exports/share/applications}"

role_mime() {
  case "$1" in
    browser) echo "x-scheme-handler/https" ;;
    files)   echo "inode/directory" ;;
    editor)  echo "text/plain" ;;
    video)   echo "video/mp4" ;;
    audio)   echo "audio/mpeg" ;;
    image)   echo "image/png" ;;
    pdf)     echo "application/pdf" ;;
  esac
}

terminal_cmd() {
  t=""
  [ -f "$STATE/apps.conf" ] && t="$(grep -m1 '^TERMINAL=' "$STATE/apps.conf" | cut -d= -f2-)"
  echo "${t:-kitty}"
}

find_desktop() {    # find_desktop <file.desktop>: prints the full path
  for d in $APP_DIRS; do
    [ -f "$d/$1" ] && { echo "$d/$1"; return 0; }
  done
  return 1
}

run_in_terminal() { # run_in_terminal <shell command>
  t="$(terminal_cmd)"
  case "$t" in
    gnome-terminal) exec gnome-terminal -- sh -c "$1" ;;
    wezterm)        exec wezterm start -- sh -c "$1" ;;
    *)              exec "$t" -e sh -c "$1" ;;
  esac
}

launch_desktop() {  # launch_desktop <file.desktop> [arguments]
  file="$(find_desktop "$1")" || return 1
  shift
  line="$(grep -m1 '^Exec=' "$file" | cut -d= -f2-)"
  [ -n "$line" ] || return 1
  cmd="$(printf '%s' "$line" | sed 's/ %[a-zA-Z]//g; s/%%/%/g')"     # drop the field codes (%u %F ...)
  term="$(grep -m1 '^Terminal=' "$file" | cut -d= -f2)"
  if [ "$term" = "true" ]; then
    [ $# -gt 0 ] && cmd="$cmd \"$*\""
    run_in_terminal "$cmd"
  else
    exec sh -c "$cmd \"\$@\"" sh "$@"
  fi
}

[ -n "$KRMV_SOURCE_ONLY" ] && return 0 2>/dev/null

role="$1"; [ $# -gt 0 ] && shift
case "$role" in
  terminal) t="$(terminal_cmd)"; exec "$t" "$@" ;;
  browser|files|editor|video|audio|image|pdf)
    mime="$(role_mime "$role")"
    desk="$(xdg-mime query default "$mime" 2>/dev/null)"
    if [ -n "$desk" ]; then launch_desktop "$desk" "$@" && exit 0; fi
    case "$role" in
      browser) exec xdg-open "https://" ;;
      files)   run_in_terminal "yazi $*" ;;
      *)       notify-send "Default apps" "No default $role app is set. Press SUPER + I to choose one."; exit 1 ;;
    esac
    ;;
  *) echo "Usage: open-default.sh terminal|browser|files|editor|video|audio|image|pdf [arguments]"; exit 1 ;;
esac
