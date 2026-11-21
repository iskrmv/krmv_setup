#!/usr/bin/env bash
# sweep - deep clean for Arch Linux in ONE command.
#   Removes: old and uninstalled-package files from the pacman cache, the yay (AUR) build cache,
#   orphaned packages (asks first), old journal logs, core dumps, thumbnails, pip/npm caches, unused flatpaks.
#
# Usage:  sweep           safe deep clean (keeps the latest version of every installed package, so downgrades still work)
#         sweep --all     ALSO deletes every cached package file (you re-download if you ever need to reinstall/downgrade)
#         sweep -y        no questions (orphans are removed too)
set -u
ALL=0; YES=0
for a in "$@"; do
  case "$a" in
    --all) ALL=1 ;;
    -y|--yes) YES=1 ;;
    -h|--help) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown option: $a (try --help)"; exit 1 ;;
  esac
done

say() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
ask() { [ "$YES" = 1 ] && return 0; local r; read -r -p "$1 [y/N] " r; [[ "$r" =~ ^[Yy]$ ]]; }
size() { du -sh "$@" 2>/dev/null | awk '{print $1}' | head -n1; }

sudo -v || exit 1
before=$(df -B1 --output=avail / | tail -n1 | tr -d ' ')

say "Current usage"
printf '  pacman cache : %s\n  yay cache    : %s\n  journal logs : %s\n  thumbnails   : %s\n' \
  "$(size /var/cache/pacman/pkg)" "$(size "$HOME/.cache/yay")" "$(size /var/log/journal)" "$(size "$HOME/.cache/thumbnails")"

# 1. pacman cache
say "pacman cache"
if ! command -v paccache >/dev/null 2>&1; then sudo pacman -S --needed --noconfirm pacman-contrib; fi
# Directories inside the cache (download-XXXX left by interrupted downloads) are not package files:
# paccache and "pacman -Scc" complain about them. Remove them first, quietly, whatever their names are.
if [ -d /var/cache/pacman/pkg ]; then
  n=$(sudo find /var/cache/pacman/pkg -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
  sudo find /var/cache/pacman/pkg -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} + 2>/dev/null || true
  echo "  stale cache directories removed: $n"
fi
sudo paccache -ruk0 2>/dev/null || true  # cached files of packages that are NOT installed any more
if [ "$ALL" = 1 ]; then
  yes | sudo pacman -Scc >/dev/null 2>&1 || true   # everything that is left
  sudo find /var/cache/pacman/pkg -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true
else
  sudo paccache -rk1 2>/dev/null || true           # older versions of installed packages (keeps the newest one)
fi

# 2. AUR helper cache
if command -v yay >/dev/null 2>&1; then
  say "yay cache (AUR builds and sources)"
  if [ "$ALL" = 1 ]; then yes | yay -Scc --aur; else yay -Sc --aur --noconfirm; fi
fi

# 3. orphaned packages
say "Orphaned packages"
orphans=$(pacman -Qtdq 2>/dev/null || true)
if [ -n "$orphans" ]; then
  echo "$orphans" | sed 's/^/  /'
  if ask "Remove these packages (and their config files)?"; then
    # shellcheck disable=SC2086
    sudo pacman -Rns --noconfirm $orphans
  fi
else
  echo "  none"
fi

# 4. logs and core dumps
say "Logs and core dumps"
sudo journalctl --vacuum-time=7d --vacuum-size=200M 2>&1 | tail -n1
sudo rm -rf /var/lib/systemd/coredump/* 2>/dev/null || true

# 5. user caches
say "User caches"
rm -rf "$HOME/.cache/thumbnails"
command -v pip >/dev/null 2>&1 && pip cache purge >/dev/null 2>&1 || true
command -v npm >/dev/null 2>&1 && npm cache clean --force >/dev/null 2>&1 || true
command -v flatpak >/dev/null 2>&1 && flatpak uninstall --unused -y >/dev/null 2>&1 || true
if [ "$ALL" = 1 ] && ask "Also empty the trash?"; then rm -rf "$HOME/.local/share/Trash/files/"* "$HOME/.local/share/Trash/info/"* 2>/dev/null || true; fi

after=$(df -B1 --output=avail / | tail -n1 | tr -d ' ')
freed=$((after - before))
say "Done"
if [ "$freed" -gt 0 ]; then echo "  Freed about $(numfmt --to=iec --suffix=B "$freed")"; else echo "  Nothing big to free this time"; fi
echo "  Free space on /: $(numfmt --to=iec --suffix=B "$after")"
