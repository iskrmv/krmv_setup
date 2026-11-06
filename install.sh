#!/usr/bin/env bash
# krmv-setup - installs the whole desktop on a fresh Arch Linux with ONE command:
#   Hyprland (Lua config), Quickshell bar + notifications, rofi, kitty, hyprlock/hypridle,
#   SDDM login theme, zsh (oh-my-zsh + powerlevel10k), wallpapers, aliases, dark mode.
#
# Usage:    bash install.sh
# Options (environment variables):
#   YES=1            pass --noconfirm to pacman (no questions)
#   SKIP_PACKAGES=1  do not install packages / yay
#   SKIP_SDDM=1      do not touch SDDM
#   SKIP_ZSH=1       do not touch zsh
#   SKIP_NVIM=1      do not install LazyVim
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CFG="$HOME/.config"
TS="$(date +%Y%m%d-%H%M%S)"

say()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m[!] %s\033[0m\n' "$*"; }
die()  { printf '\033[1;31m[x] %s\033[0m\n' "$*" >&2; exit 1; }

[ "$(id -u)" -ne 0 ] || die "Do not run this as root. It asks for sudo when it needs it."
command -v pacman >/dev/null 2>&1 || die "This installer is for Arch Linux (pacman was not found)."
sudo -v || die "sudo is required."

PAC=(sudo pacman -S --needed)
[ -n "${YES:-}" ] && PAC+=(--noconfirm)

# ------------------------------------------------------------------ 1. yay + packages
if [ -z "${SKIP_PACKAGES:-}" ]; then
  say "Installing build tools"
  "${PAC[@]}" git base-devel curl

  if ! command -v yay >/dev/null 2>&1; then
    say "Installing yay (AUR helper)"
    tmp="$(mktemp -d)"
    git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
    (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
    rm -rf "$tmp"
  else
    echo "yay is already installed - skipping"
  fi

  PKGS=(
    # desktop
    hyprland hypridle hyprlock hyprpolkitagent xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
    sddm qt6-svg qt6-declarative kitty rofi swaybg brightnessctl
    # audio, network, bluetooth
    pipewire pipewire-pulse pipewire-alsa wireplumber networkmanager bluez bluez-utils blueman upower
    # fonts
    ttf-jetbrains-mono-nerd noto-fonts noto-fonts-emoji
    # clipboard, screenshots, file manager, helpers
    wl-clipboard cliphist grim slurp libnotify jq yazi fd ripgrep fzf poppler wev pacman-contrib ttf-poppins
    # media keys, XWayland + Qt/GTK Wayland support (root GUI apps like Ventoy and PINCE need XWayland and xhost)
    playerctl xorg-xwayland xorg-xhost qt5-wayland qt6-wayland
    xcb-util-cursor xcb-util-image xcb-util-keysyms xcb-util-renderutil xcb-util-wm   # Qt's X11 plugin needs these (PINCE, Ventoy GUI)
    # neovim (for LazyVim): editor, tools and language-server helpers
    neovim lazygit tree-sitter-cli nodejs npm unzip
    # fastfetch greeting, night mode (blue light filter), xdg-utils (default apps)
    fastfetch hyprsunset xdg-utils
    # dark mode
    gnome-themes-extra adwaita-icon-theme dconf qt6ct
    # shell
    zsh zsh-autosuggestions zsh-syntax-highlighting zsh-theme-powerlevel10k
  )
  # Install what the official repos have in one transaction; the rest (if any) comes from the AUR
  repo=(); aur=()
  for p in "${PKGS[@]}"; do
    if pacman -Si "$p" >/dev/null 2>&1; then repo+=("$p"); else aur+=("$p"); fi
  done
  say "Installing ${#repo[@]} packages from the official repositories"
  "${PAC[@]}" "${repo[@]}" || warn "Some packages failed to install - continuing"

  command -v qs >/dev/null 2>&1 || aur+=("quickshell-git")
  # the powerlevel10k package is called zsh-theme-powerlevel10k-git in the AUR
  for i in "${!aur[@]}"; do
    if [ "${aur[i]}" = "zsh-theme-powerlevel10k" ]; then aur[i]="zsh-theme-powerlevel10k-git"; fi
  done
  if [ "${#aur[@]}" -gt 0 ]; then
    say "Installing from the AUR: ${aur[*]}"
    yay -S --needed "${aur[@]}" || warn "Some AUR packages failed - install them manually"
  fi
fi

# ------------------------------------------------------------------ 1b. Arithmetic calculator
# https://github.com/armanmaurya/arithmetic - uses the prebuilt Arch package from its releases when there is one,
# otherwise builds it from source with the project's own PKGBUILD (takes a few minutes).
install_arithmetic() {
  if command -v arithmetic >/dev/null 2>&1; then echo "Arithmetic is already installed - skipping"; return 0; fi
  say "Installing the Arithmetic calculator"
  local tmp url=""
  tmp="$(mktemp -d)"
  if [ "$(uname -m)" = "x86_64" ]; then
    url="$(curl -fsSL https://api.github.com/repos/armanmaurya/arithmetic/releases/latest 2>/dev/null \
           | jq -r '.assets[]? | select(.name | endswith(".pkg.tar.zst")) | .browser_download_url' 2>/dev/null | head -n1 || true)"
  fi
  if [ -n "$url" ] && curl -fsSL "$url" -o "$tmp/arithmetic.pkg.tar.zst" && sudo pacman -U --noconfirm "$tmp/arithmetic.pkg.tar.zst"; then
    rm -rf "$tmp"; return 0
  fi
  echo "No prebuilt package found - building Arithmetic from source..."
  if git clone --depth 1 https://github.com/armanmaurya/arithmetic "$tmp/arithmetic" \
     && (cd "$tmp/arithmetic/packaging" && makepkg -si --noconfirm); then
    :
  else
    warn "Could not install Arithmetic - install it manually from https://github.com/armanmaurya/arithmetic"
  fi
  rm -rf "$tmp"
}
if [ -z "${SKIP_PACKAGES:-}" ]; then install_arithmetic; fi

# ------------------------------------------------------------------ 1c. Keyboard layouts (English + Russian)
# Hyprland itself gets its layouts from conf/input.lua. This sets the same for the SDDM login screen and XWayland apps.
if [ -z "${SKIP_PACKAGES:-}" ]; then
  say "Setting the keyboard layouts (us, ru; ALT + SHIFT switches)"
  sudo localectl set-x11-keymap "us,ru" "" "" "grp:alt_shift_toggle" || warn "Could not set the system keyboard layouts"
fi

# ------------------------------------------------------------------ 1d. Neovim + LazyVim
if [ -z "${SKIP_NVIM:-}" ] && command -v nvim >/dev/null 2>&1; then
  if [ ! -d "$HOME/.config/nvim" ]; then
    say "Installing LazyVim (the official starter)"
    if git clone --depth 1 https://github.com/LazyVim/starter "$HOME/.config/nvim"; then
      rm -rf "$HOME/.config/nvim/.git"
      echo "Downloading the plugins (so the first start is instant)..."
      timeout 300 nvim --headless "+Lazy! sync" +qa >/dev/null 2>&1 || warn "Plugins will be downloaded on the first start of nvim"
    else
      warn "Could not download LazyVim - run: git clone https://github.com/LazyVim/starter ~/.config/nvim"
    fi
  else
    echo "$HOME/.config/nvim already exists - leaving your Neovim config alone"
  fi
fi

# ------------------------------------------------------------------ 2. Hyprland config
say "Installing the Hyprland config to $CFG/hypr"
mkdir -p "$CFG/hypr"
BK="$CFG/hypr/backup-$TS"
for item in hyprland.lua hypridle.conf conf theme scripts shell data; do
  if [ -e "$CFG/hypr/$item" ] && [ ! -L "$CFG/hypr/$item" ]; then
    mkdir -p "$BK"; cp -a "$CFG/hypr/$item" "$BK/"
  fi
done
[ -d "$BK" ] && echo "Your previous config was saved to $BK"

cp -r "$HERE/hypr/hyprland.lua" "$HERE/hypr/hypridle.conf" "$HERE/hypr/conf" "$HERE/hypr/theme" \
      "$HERE/hypr/scripts" "$HERE/hypr/shell" "$HERE/hypr/data" "$CFG/hypr/"
mkdir -p "$CFG/hypr/wallpapers"
cp -r --update=none "$HERE/hypr/wallpapers/." "$CFG/hypr/wallpapers/"     # never overwrites wallpapers you already have
rm -f "$CFG/hypr/conf/mice.lua" "$CFG/hypr/scripts/mouse-scroll.sh"   # leftovers from old versions

# ------------------------------------------------------------------ 2b. Anurati font (desktop clock)
# Not stored in this repo (it is free for personal use only): it is downloaded from the original KDE widget's repository.
if ! fc-list 2>/dev/null | grep -qi anurati; then
  say "Installing the Anurati font for the desktop clock"
  mkdir -p "$HOME/.local/share/fonts"
  if curl -fsSL "https://raw.githubusercontent.com/Prayag2/kde_modernclock/main/package/contents/fonts/Anurati.otf" -o "$HOME/.local/share/fonts/Anurati.otf"; then
    fc-cache -f "$HOME/.local/share/fonts" || true
  else
    warn "Could not download Anurati - the desktop clock will use Poppins for the day name"
  fi
else
  echo "Anurati font is already installed - skipping"
fi

# ------------------------------------------------------------------ 2c. Shortcuts, default apps
# The customizable shortcuts are generated from data/binds.tsv (and your changes, made in SUPER + P > Keyboard shortcuts)
sh "$CFG/hypr/scripts/gen-binds.sh" || warn "Could not generate the shortcuts"
rm -f "$HOME/.local/share/applications/pince-root.desktop"      # an old entry from an earlier version

# Default apps: yazi is the default file manager (SUPER + E), kitty the default terminal
mkdir -p "$HOME/.local/state/krmv-setup" "$HOME/.local/share/applications"
[ -f "$HOME/.local/state/krmv-setup/apps.conf" ] || echo "TERMINAL=kitty" > "$HOME/.local/state/krmv-setup/apps.conf"
if [ ! -f /usr/share/applications/yazi.desktop ] && [ ! -f "$HOME/.local/share/applications/yazi.desktop" ]; then
  printf '%s\n' '[Desktop Entry]' 'Type=Application' 'Name=Yazi' 'Comment=Terminal file manager' 'Exec=yazi %u' \
    'Terminal=true' 'Icon=system-file-manager' 'MimeType=inode/directory;' 'Categories=Utility;FileManager;' \
    > "$HOME/.local/share/applications/yazi.desktop"
fi
command -v xdg-mime >/dev/null 2>&1 && xdg-mime default yazi.desktop inode/directory || true

# ------------------------------------------------------------------ 3. kitty / rofi / hyprlock / dark mode
link_cfg() {   # link_cfg <source> <target>: back up a real file, then symlink
  mkdir -p "$(dirname "$2")"
  if [ -e "$2" ] && [ ! -L "$2" ]; then mv "$2" "$2.bak-$TS"; echo "Backed up $2"; fi
  ln -sf "$1" "$2"
}
say "Linking kitty, rofi, hyprlock and fastfetch configs"
link_cfg "$CFG/hypr/theme/kitty/kitty.conf"        "$CFG/kitty/kitty.conf"
link_cfg "$CFG/hypr/theme/rofi/config.rasi"        "$CFG/rofi/config.rasi"
link_cfg "$CFG/hypr/theme/hyprlock/hyprlock.conf"  "$CFG/hypr/hyprlock.conf"
link_cfg "$CFG/hypr/theme/fastfetch/config.jsonc"  "$CFG/fastfetch/config.jsonc"

say "Setting up system-wide dark mode"
link_cfg "$CFG/hypr/theme/gtk/settings3.ini"             "$CFG/gtk-3.0/settings.ini"
link_cfg "$CFG/hypr/theme/gtk/settings4.ini"             "$CFG/gtk-4.0/settings.ini"
link_cfg "$CFG/hypr/theme/portal/hyprland-portals.conf"  "$CFG/xdg-desktop-portal/hyprland-portals.conf"
link_cfg "$CFG/hypr/theme/qt6ct/qt6ct.conf"              "$CFG/qt6ct/qt6ct.conf"
sh "$CFG/hypr/scripts/dark-mode.sh" 2>/dev/null || true   # applies right away when a session bus exists

# ------------------------------------------------------------------ 4. zsh (oh-my-zsh + powerlevel10k + .zshrc + aliases)
if [ -z "${SKIP_ZSH:-}" ]; then
  say "Setting up zsh"
  if [ ! -d "$HOME/.oh-my-zsh" ]; then
    omz="$(mktemp)"
    if curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -o "$omz"; then
      # KEEP_ZSHRC=yes: oh-my-zsh must never replace our .zshrc (that is how aliases got lost before)
      RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh "$omz" --unattended || warn "oh-my-zsh failed to install (the .zshrc works without it)"
    else
      warn "Could not download oh-my-zsh (the .zshrc works without it)"
    fi
    rm -f "$omz"
  fi

  if [ -f "$HOME/.zshrc" ] && ! cmp -s "$HERE/zsh/zshrc" "$HOME/.zshrc"; then
    cp "$HOME/.zshrc" "$HOME/.zshrc.bak-$TS"; echo "Backed up ~/.zshrc to ~/.zshrc.bak-$TS"
  fi
  cp "$HERE/zsh/zshrc" "$HOME/.zshrc"
  # your own powerlevel10k settings (put the file in zsh/p10k.zsh); otherwise p10k's wizard runs on the first start
  if [ -f "$HERE/zsh/p10k.zsh" ] && [ ! -f "$HOME/.p10k.zsh" ]; then cp "$HERE/zsh/p10k.zsh" "$HOME/.p10k.zsh"; fi

  if [ "$(basename "${SHELL:-}")" != "zsh" ] && command -v zsh >/dev/null 2>&1; then
    chsh -s "$(command -v zsh)" || warn "Could not change your login shell. Run: chsh -s $(command -v zsh)"
  fi
fi

# aliases for bash and fish too (zsh gets them from .zshrc)
say "Installing shell aliases (pacman, yoink, yeet, yago)"
SRC_LINE='[ -f ~/.config/hypr/shell/aliases.sh ] && . ~/.config/hypr/shell/aliases.sh   # krmv-setup aliases'
if [ -f "$HOME/.bashrc" ] && ! grep -qF "krmv-setup aliases" "$HOME/.bashrc"; then printf '\n%s\n' "$SRC_LINE" >> "$HOME/.bashrc"; fi
if [ -f "$HOME/.bashrc" ] && ! grep -qF "krmv-setup greeting" "$HOME/.bashrc"; then
  printf '%s\n' '[ -f ~/.config/hypr/shell/greeting.sh ] && . ~/.config/hypr/shell/greeting.sh   # krmv-setup greeting' >> "$HOME/.bashrc"
fi
if command -v fish >/dev/null 2>&1; then
  mkdir -p "$CFG/fish/conf.d"
  ln -sf "$CFG/hypr/shell/aliases.fish" "$CFG/fish/conf.d/krmv-aliases.fish"
fi

# ------------------------------------------------------------------ 5. services
say "Enabling NetworkManager, Bluetooth and UPower (battery info)"
sudo systemctl enable --now NetworkManager bluetooth upower || warn "Could not enable a service"

# Bluetooth must NOT power on at boot
if [ -f /etc/bluetooth/main.conf ]; then
  if grep -qE '^#?AutoEnable=' /etc/bluetooth/main.conf; then
    sudo sed -i 's/^#\?AutoEnable=.*/AutoEnable=false/' /etc/bluetooth/main.conf
  else
    sudo sed -i '/^\[Policy\]/a AutoEnable=false' /etc/bluetooth/main.conf
  fi
  sudo systemctl restart bluetooth || true
fi

# The bar is the notification daemon, so make sure mako is not running
pkill -x mako 2>/dev/null || true

# ------------------------------------------------------------------ 6. SDDM theme
if [ -z "${SKIP_SDDM:-}" ]; then
  say "Installing the SDDM theme"
  T=/usr/share/sddm/themes/krmv-tokyo
  SRC="$CFG/hypr/wallpapers/sddm"
  img="$(find "$SRC" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) 2>/dev/null | sort | head -n1 || true)"

  sudo mkdir -p /usr/share/sddm/themes /etc/sddm.conf.d
  sudo rm -rf "$T"
  sudo cp -r "$HERE/sddm/krmv-tokyo" "$T"
  printf '[Theme]\nCurrent=krmv-tokyo\n' | sudo tee /etc/sddm.conf.d/10-theme.conf >/dev/null
  if [ -n "$img" ]; then
    name="background.${img##*.}"
    sudo cp "$img" "$T/$name"      # SDDM cannot read your home folder, so the image is copied
    printf '[General]\nbackground=%s\n' "$name" | sudo tee "$T/theme.conf" >/dev/null
    echo "SDDM wallpaper: $img"
  else
    echo "No image in $SRC - SDDM uses a plain background. Add one and run this script again."
  fi
  sudo systemctl enable sddm 2>/dev/null || warn "Could not enable sddm (another display manager may already be enabled)"
fi

# ------------------------------------------------------------------ done
say "Done"
cat <<MSG
Next steps:
  1. Reboot (or log out and pick the Hyprland session in SDDM).
  2. Press SUPER + /  to see every shortcut.
  3. Put more wallpapers in  $CFG/hypr/wallpapers/desktop  and  .../sddm  (then run this script again for SDDM).
  4. Test the SDDM theme:  sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/krmv-tokyo
Old configs were backed up (look for backup-* and .bak-* names).
MSG
