#!/bin/sh
# Phone (MTP) automount: plug the phone in, unlock it and choose "File transfer" - it appears in ~/Phone, ready for yazi.
#   phone-mount.sh watch      the background watcher (started at login by conf/autostart.lua)
#   phone-mount.sh mount      mount now            phone-mount.sh umount     unmount (safe to unplug afterwards)
#   phone-mount.sh toggle     switch the automatic mounting on / off          phone-mount.sh status     on | off
#   phone-mount.sh diagnose   collect everything needed to find out why it does not work (copied to the clipboard)
# USB sticks are NOT touched: only phones, tablets and players that speak MTP.
# The phone is mounted with jmtpfs (package jmtpfs) in ~/Phone; there is one folder per storage inside it.
# Log: ~/.local/state/krmv-setup/phone-mount.log
STATE="${KRMV_STATE:-$HOME/.local/state/krmv-setup}"
MP="$HOME/Phone"
FLAG="$STATE/phone-automount-off"
LOG="$STATE/phone-mount.log"
mkdir -p "$STATE"
log()  { printf '%s  %s\n' "$(date '+%F %T')" "$*" >> "$LOG"; }
note() { notify-send -i phone "Phone" "$1" 2>/dev/null; echo "$1"; log "$1"; }
mounted() { mountpoint -q "$MP" 2>/dev/null; }
healthy() { mounted && ls "$MP" >/dev/null 2>&1; }
probe()   { jmtpfs -l 2>/dev/null | grep -Eq '^[0-9]+, [0-9]+, 0x'; }       # is there an MTP device right now?

do_umount() {
  if ! mounted; then log "umount: nothing mounted"; return 0; fi
  out="$(fusermount -u "$MP" 2>&1 || fusermount3 -u "$MP" 2>&1)" && { log "unmounted"; return 0; }
  log "umount failed: $out - trying a lazy unmount"
  fusermount -uz "$MP" 2>/dev/null || fusermount3 -uz "$MP" 2>/dev/null || umount -l "$MP" 2>/dev/null
}

# gvfs (installed with many file managers) can hold the phone for itself; jmtpfs then cannot open it
free_phone() {
  pkill -f gvfs-mtp-volume-monitor 2>/dev/null
  pkill -f gvfsd-mtp 2>/dev/null
  sleep 1
}

do_mount() {         # do_mount [quiet]
  command -v jmtpfs >/dev/null 2>&1 || { note "jmtpfs is not installed. Run the setup installer again."; return 1; }
  exec 8>"${XDG_RUNTIME_DIR:-/tmp}/krmv-phone-mount.lock"
  flock -n 8 || { log "another mount is running"; return 0; }
  healthy && { log "already mounted"; return 0; }
  mounted && do_umount                              # a stale mount of a phone that was pulled out
  if ! probe; then
    [ "$1" = quiet ] || note "No phone found. Connect it, unlock it and choose File transfer (MTP)."
    return 1
  fi
  mkdir -p "$MP"
  tries=0; told=0
  while [ "$tries" -lt 8 ]; do
    out="$(jmtpfs "$MP" 2>&1)"; rc=$?
    log "jmtpfs rc=$rc: $(printf '%s' "$out" | tr '\n' ' ' | cut -c1-300)"
    if [ "$rc" = 0 ] && mounted; then
      note "Phone mounted in ~/Phone. Open it with:  yazi ~/Phone"
      return 0
    fi
    case "$out" in
      *"open raw device"*|*busy*|*BUSY*|*"Unable to open"*) free_phone ;;          # gvfs probably holds it
      *ermission*|*ACCESS*) note "No permission to use the phone. Install libmtp (udev rules), replug the phone."; return 1 ;;
    esac
    if [ "$told" = 0 ]; then note "Unlock the phone and allow file access (File transfer / MTP)."; told=1; fi
    tries=$((tries + 1)); sleep 3
  done
  note "Could not open the phone's files. Run  phone-mount.sh diagnose  and send the result."
  return 1
}

# a USB device appeared: wait a moment for the phone to settle, and mount it if it really is an MTP device
auto_try() {
  [ -e "$FLAG" ] && return 0
  sleep 2
  n=0; while [ "$n" -lt 4 ]; do probe && break; n=$((n + 1)); sleep 2; done
  probe || { log "usb device added, but it is not an MTP device (yet)"; return 0; }
  do_mount quiet
}

watch() {
  exec 9>"${XDG_RUNTIME_DIR:-/tmp}/krmv-phone-watch.lock"
  flock -n 9 || exit 0
  log "watcher started"
  [ -e "$FLAG" ] || ( sleep 6; probe && do_mount quiet ) &          # a phone that is already plugged in at login
  action=""; devtype=""
  udevadm monitor --udev --subsystem-match=usb --property 2>/dev/null | while IFS= read -r line; do
    case "$line" in
      ACTION=*)  action="${line#ACTION=}" ;;
      DEVTYPE=*) devtype="${line#DEVTYPE=}" ;;
      "")
        if [ "$devtype" = usb_device ] && [ ! -e "$FLAG" ]; then
          if [ "$action" = add ]; then
            log "usb device added"
            auto_try &
          elif [ "$action" = remove ] && mounted; then
            ( sleep 1; healthy || { do_umount; note "Phone disconnected."; } ) &
          fi
        fi
        action=""; devtype="" ;;
    esac
  done
}

diagnose() {
  out="$STATE/phone-diagnose.txt"
  {
    echo "== jmtpfs ==";  command -v jmtpfs || echo "NOT INSTALLED"
    echo "== jmtpfs -l =="; jmtpfs -l 2>&1
    echo "== mounted? =="; mountpoint "$MP" 2>&1; ls "$MP" 2>&1 | head
    echo "== usb devices =="; lsusb 2>&1 | head -20
    echo "== fuse =="; ls -l /dev/fuse 2>&1; command -v fusermount fusermount3
    echo "== libmtp udev rules =="; for r in /usr/lib/udev/rules.d/*mtp*; do [ -e "$r" ] && echo "$r"; done
    echo "== processes that can hold the phone =="; pgrep -a gvfs 2>&1 | head
    echo "== watcher =="; pgrep -af "phone-mount.sh watch" 2>&1
    echo "== automount flag =="; if [ -e "$FLAG" ]; then echo "OFF"; else echo "on"; fi
    echo "== last log lines =="; tail -n 30 "$LOG" 2>&1
  } > "$out" 2>&1
  wl-copy < "$out" 2>/dev/null
  note "Diagnostics saved to $out and copied to the clipboard."
}

case "${1:-status}" in
  watch)  watch ;;
  mount)  do_mount ;;
  umount|unmount) if mounted; then do_umount; mounted && note "Could not unmount: a program is using ~/Phone. Close it and try again." || note "Phone unmounted. You can unplug it."; else note "No phone is mounted."; fi ;;
  toggle) if [ -e "$FLAG" ]; then rm -f "$FLAG"; note "Phones will be mounted automatically."; else : > "$FLAG"; note "Automatic phone mounting is OFF."; fi ;;
  status) if [ -e "$FLAG" ]; then echo off; else echo on; fi ;;
  diagnose) diagnose ;;
  *) echo "Usage: $0 [watch|mount|umount|toggle|status|diagnose]"; exit 1 ;;
esac
