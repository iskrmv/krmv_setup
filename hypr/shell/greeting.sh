# shellcheck shell=sh
# ~/.config/hypr/shell/greeting.sh - sourced by ~/.bashrc: fastfetch when a terminal opens
case "$-" in
  *i*) if [ -z "$FASTFETCH_DONE" ] && command -v fastfetch >/dev/null 2>&1; then fastfetch; export FASTFETCH_DONE=1; fi ;;
esac
