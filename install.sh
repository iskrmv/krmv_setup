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
#   SKIP_DNS=1       do not install the dns command (DNS-over-TLS switcher)
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
    # clipboard, screenshots, file manager, helpers (hyprpicker: Wayland color picker; btop: system monitor)
    wl-clipboard cliphist grim slurp libnotify jq yazi fd ripgrep fzf poppler wev pacman-contrib ttf-poppins
    hyprpicker btop
    # media keys, camera, XWayland + Qt/GTK Wayland support (root GUI apps like Ventoy and PINCE need XWayland and xhost)
    playerctl snapshot imagemagick gamescope jmtpfs libmtp alsa-utils geoclue xorg-xwayland xorg-xhost qt5-wayland qt6-wayland
    xcb-util-cursor xcb-util-image xcb-util-keysyms xcb-util-renderutil xcb-util-wm   # Qt's X11 plugin needs these (PINCE, Ventoy GUI)
    # neovim (for LazyVim): editor, tools and language-server helpers
    neovim lazygit tree-sitter-cli nodejs npm unzip
    # fastfetch greeting, night mode (blue light filter), xdg-utils (default apps)
    fastfetch hyprsunset xdg-utils
    # clock app alarm sound; image viewer (swayimg: tiny, native Wayland, opens nearly every format incl. SVG)
    sound-theme-freedesktop swayimg libheif libjxl libavif libraw librsvg libwebp
    # dark mode
    gnome-themes-extra adwaita-icon-theme dconf qt6ct qt5ct hyprqt6engine
    # shell
    zsh zsh-autosuggestions zsh-syntax-highlighting zsh-theme-powerlevel10k
    # dns tool (openssl verifies the DoT certificate; curl checks the result)
    openssl curl
  )
  # Install what the official repos have in one transaction; the rest (if any) comes from the AUR
  repo=(); aur=()
  for p in "${PKGS[@]}"; do
    if pacman -Si "$p" >/dev/null 2>&1; then repo+=("$p"); else aur+=("$p"); fi
  done
  say "Installing ${#repo[@]} packages from the official repositories"
  "${PAC[@]}" "${repo[@]}" || warn "Some packages failed to install - continuing"

  command -v qs >/dev/null 2>&1 || aur+=("quickshell-git")
  aur+=("mpvpaper")   # animated/video wallpapers: AUR-only (yay pulls its mpv dependency automatically)
  aur+=("tork")       # torrent search + download TUI (type "run tork" in the launcher)
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
mkdir -p "$CFG/hypr/wallpapers" "$CFG/hypr/wallpapers/animated"
cp -r --update=none "$HERE/hypr/wallpapers/." "$CFG/hypr/wallpapers/"     # never overwrites wallpapers you already have
cp -r --update=none "$HERE/hypr/wallpapers/animated/." "$CFG/hypr/wallpapers/animated/"
rm -f "$CFG/hypr/conf/mice.lua" "$CFG/hypr/scripts/mouse-scroll.sh"   # leftovers from old versions

# A real command, not a shell alias: the rofi launcher uses non-interactive shells where aliases do not exist.
sudo install -Dm755 "$HERE/hypr/scripts/sudogui.sh" /usr/local/bin/sudogui
sudo install -Dm755 "$HERE/hypr/scripts/krmv-stretch.sh" /usr/local/bin/krmv-stretch   # stretched resolution for games (Steam launch option: krmv-stretch %command%)
sudo install -Dm755 "$HERE/hypr/scripts/run-cmd.sh" /usr/local/bin/run-cmd      # the rofi launcher runs typed commands through it
# "rofi" wrapper: fixes the scroll direction inside rofi for touchpad AND mouse (calls the real /usr/bin/rofi)
sudo install -Dm755 "$HERE/hypr/scripts/rofi-wrap.sh" /usr/local/bin/rofi

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
# The customizable shortcuts are generated from data/binds.tsv (and your changes, made in SUPER + I > Keyboard shortcuts)
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

# swayimg is the default image viewer (PNG, JPEG, GIF, WebP, HEIF/HEIC, AVIF, SVG, TIFF, BMP, JXL, RAW ...)
# A user-edited swayimg.desktop is left alone; otherwise generate one covering all common image formats.
IMG_MIMES=(image/png image/jpeg image/gif image/webp image/heif image/heic image/avif image/svg+xml image/tiff image/bmp image/jxl)
IMG_MIME_LIST="$(IFS=';'; printf '%s' "${IMG_MIMES[*]}");"
if [ ! -f "$HOME/.local/share/applications/swayimg.desktop" ]; then
  printf '%s\n' '[Desktop Entry]' 'Type=Application' 'Name=swayimg' 'Comment=Image viewer' 'Exec=swayimg %F' \
    'Icon=image-x-generic' "MimeType=$IMG_MIME_LIST" 'Terminal=false' 'Categories=Graphics;Viewer;' \
    > "$HOME/.local/share/applications/swayimg.desktop"
fi
if command -v xdg-mime >/dev/null 2>&1; then
  for m in "${IMG_MIMES[@]}"; do
    xdg-mime default swayimg.desktop "$m"
  done
fi

# "Settings" and "Clock" show up in the app launcher (type settings, clock, timer or alarm in rofi)
printf '%s\n' '[Desktop Entry]' 'Type=Application' 'Name=Settings' 'Comment=Display, network, sound, input, widgets, privacy and more' \
  "Exec=sh $CFG/hypr/scripts/settings.sh" 'Icon=preferences-system' 'Terminal=false' 'Categories=Settings;' \
  'Keywords=settings;preferences;default apps;shortcuts;keyboard;widgets;night mode;' \
  > "$HOME/.local/share/applications/krmv-settings.desktop"
printf '%s\n' '[Desktop Entry]' 'Type=Application' 'Name=Clock' 'Comment=Timer, alarm and stopwatch' \
  "Exec=qs -p $CFG/hypr/theme/quickshell/shell.qml ipc call widgets clock" 'Icon=preferences-system-time' 'Terminal=false' 'Categories=Utility;' \
  'Keywords=clock;timer;alarm;stopwatch;' \
  > "$HOME/.local/share/applications/krmv-clock.desktop"

# ------------------------------------------------------------------ 3. kitty / rofi / hyprlock / dark mode
link_cfg() {   # link_cfg <source> <target>: back up a real file, then symlink
  mkdir -p "$(dirname "$2")"
  if [ -e "$2" ] && [ ! -L "$2" ]; then mv "$2" "$2.bak-$TS"; echo "Backed up $2"; fi
  ln -sf "$1" "$2"
}
say "Linking kitty, rofi, hyprlock, fastfetch and yazi configs"
link_cfg "$CFG/hypr/theme/kitty/kitty.conf"        "$CFG/kitty/kitty.conf"
link_cfg "$CFG/hypr/theme/rofi/config.rasi"        "$CFG/rofi/config.rasi"
link_cfg "$CFG/hypr/theme/hyprlock/hyprlock.conf"  "$CFG/hypr/hyprlock.conf"
link_cfg "$CFG/hypr/theme/fastfetch/config.jsonc"  "$CFG/fastfetch/config.jsonc"
link_cfg "$CFG/hypr/theme/yazi/yazi.toml"          "$CFG/yazi/yazi.toml"

say "Setting up system-wide dark mode"
link_cfg "$CFG/hypr/theme/gtk/settings3.ini"             "$CFG/gtk-3.0/settings.ini"
link_cfg "$CFG/hypr/theme/gtk/settings4.ini"             "$CFG/gtk-4.0/settings.ini"
link_cfg "$CFG/hypr/theme/portal/hyprland-portals.conf"  "$CFG/xdg-desktop-portal/hyprland-portals.conf"
mkdir -p "$CFG/qt6ct/colors"
cp "$CFG/hypr/theme/qt6ct/colors/krmv-tokyo.conf" "$CFG/qt6ct/colors/krmv-tokyo.conf"
sed -i "s|^color_scheme_path=.*|color_scheme_path=$CFG/qt6ct/colors/krmv-tokyo.conf|" "$CFG/hypr/theme/qt6ct/qt6ct.conf"   # qt6ct needs an absolute path
link_cfg "$CFG/hypr/theme/qt6ct/qt6ct.conf"              "$CFG/qt6ct/qt6ct.conf"
# the same palette for Qt5 apps (many root tools such as Ventoy are Qt5/GTK)
mkdir -p "$CFG/qt5ct/colors"
cp "$CFG/hypr/theme/qt6ct/colors/krmv-tokyo.conf" "$CFG/qt5ct/colors/krmv-tokyo.conf"
sed "s|$CFG/qt6ct/|$CFG/qt5ct/|" "$CFG/hypr/theme/qt6ct/qt6ct.conf" > "$CFG/qt5ct/qt5ct.conf"
# The polkit password dialog (hyprpolkitagent) is a Qt Quick app: it takes its colors from hyprqt6engine, which can
# read the same Tokyo Night palette. It is started by systemd, so the variables go into a service drop-in.
POLKIT_THEME=qt6ct
ls /usr/lib/qt6/plugins/platformthemes/libhyprqt6engine.so >/dev/null 2>&1 && POLKIT_THEME=hyprqt6engine
cat > "$CFG/hypr/hyprqt6engine.conf" <<QTEOF
theme {
    color_scheme = $CFG/qt6ct/colors/krmv-tokyo.conf
    style = Fusion
    font = JetBrainsMono Nerd Font
    font_size = 11
}
QTEOF
mkdir -p "$CFG/systemd/user/hyprpolkitagent.service.d"
cat > "$CFG/systemd/user/hyprpolkitagent.service.d/theme.conf" <<SDEOF
[Service]
Environment=QT_QPA_PLATFORMTHEME=$POLKIT_THEME
Environment=QT_STYLE_OVERRIDE=Fusion
SDEOF
systemctl --user daemon-reload 2>/dev/null || true
# the bar has its own themed polkit dialog now; the stock agent must not grab the polkit slot first
systemctl --user disable --now hyprpolkitagent.service 2>/dev/null || true
pkill -x hyprpolkitagent 2>/dev/null || true
# session-wide theme variables, also for the polkit password dialog (it is started by systemd, not by Hyprland)
mkdir -p "$CFG/environment.d"
cat > "$CFG/environment.d/10-krmv-theme.conf" <<'ENVEOF'
QT_QPA_PLATFORMTHEME=qt6ct:qt5ct
QT_STYLE_OVERRIDE=Fusion
GTK_THEME=Adwaita:dark
ENVEOF
sh "$CFG/hypr/scripts/dark-mode.sh" 2>/dev/null || true   # applies right away when a session bus exists

# swayimg: Tokyo Night colors (init.lua is only used by swayimg 4.x; older versions ignore it). Never overwritten.
if [ ! -e "$CFG/swayimg/init.lua" ]; then
  mkdir -p "$CFG/swayimg"
  cp "$CFG/hypr/theme/swayimg/init.lua" "$CFG/swayimg/init.lua"
fi

# ------------------------------------------------------------------ 3b. btop (TTY colors, transparent background)
# btop uses the 16 terminal colors ("TTY" theme), so it matches the kitty Tokyo Night palette in every terminal.
# Only these two keys are changed; the rest of an existing btop.conf is left alone. Done for you AND for root.
set_btop_keys() {   # set_btop_keys <config-file> <use-sudo: 0|1>
  local f="$1" priv=""
  [ "$2" = 1 ] && priv="sudo"
  $priv mkdir -p "$(dirname "$f")"
  $priv touch "$f"
  for kv in 'color_theme|"TTY"' 'theme_background|False'; do
    key="${kv%%|*}"; val="${kv#*|}"
    if $priv grep -qE "^[[:space:]]*${key}[[:space:]]*=" "$f" 2>/dev/null; then
      $priv sed -i -E "s|^[[:space:]]*${key}[[:space:]]*=.*|$key = $val|" "$f"
    else
      printf '%s = %s\n' "$key" "$val" | $priv tee -a "$f" >/dev/null
    fi
  done
}
say "Setting up btop (TTY colors, no theme background) for $USER and root"
set_btop_keys "$CFG/btop/btop.conf" 0
set_btop_keys "/root/.config/btop/btop.conf" 1 || warn "Could not write the root btop config"

# ------------------------------------------------------------------ 3c. Chrome/Chromium on native Wayland
# XWayland browsers can scroll at a different speed than native-Wayland apps. These flag files
# are read by the Arch Chromium and Google Chrome wrappers. Custom content is never overwritten.
add_wayland_flags() {  # add_wayland_flags <flags-file>
  local f="$1" marker="# krmv-setup: native Wayland (safe to remove)"
  mkdir -p "$(dirname "$f")"
  if [ -f "$f" ] && grep -qF "krmv-setup: native Wayland" "$f"; then return 0; fi
  if [ -s "$f" ] && [ "$(tail -c1 "$f" | wc -l)" -eq 0 ]; then printf '\n' >> "$f"; fi
  printf '%s\n%s\n' "$marker" '--ozone-platform=wayland' >> "$f"
}
for f in "$CFG/chrome-flags.conf" "$CFG/chromium-flags.conf" "$CFG/chrome-beta-flags.conf"; do
  add_wayland_flags "$f"
done

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

# Saved Wi-Fi profiles connect automatically on boot/reconnect, not only after a manual click.
sh "$CFG/hypr/scripts/network.sh" autoconnect || warn "Could not enable Wi-Fi autoconnect now"

# The bar is the notification daemon, so make sure mako is not running
pkill -x mako 2>/dev/null || true

# ------------------------------------------------------------------ 5b. DNS switcher (dns)
# Only installs the command. It never changes the user's DNS settings.
if [ -z "${SKIP_DNS:-}" ]; then
  if [ -f "$HERE/dns/dns" ]; then
    say "Installing the dns command (DNS-over-TLS switcher)"
    sudo install -Dm755 "$HERE/dns/dns" /usr/local/bin/dns
    sudo rm -f /usr/local/bin/krmvdns      # the old command name
    echo "dns installed. To enable DoT DNS, run: dns dns.adguard.com"
  else
    warn "dns/dns is missing - skipping the DNS switcher"
  fi
fi

# ------------------------------------------------------------------ 6. SDDM theme
if [ -z "${SKIP_SDDM:-}" ]; then
  say "Installing the SDDM theme"
  T=/usr/share/sddm/themes/krmv-tokyo
  SRC="$CFG/hypr/wallpapers/sddm"
  # a picture, an animated gif or a silent video: the first file found (sorted by name)
  img="$(find "$SRC" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' \
        -o -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' -o -iname '*.mov' \) 2>/dev/null | sort | head -n1 || true)"

  sudo mkdir -p /usr/share/sddm/themes /etc/sddm.conf.d
  sudo rm -rf "$T"
  sudo cp -r "$HERE/sddm/krmv-tokyo" "$T"
  printf '[Theme]\nCurrent=krmv-tokyo\n' | sudo tee /etc/sddm.conf.d/10-theme.conf >/dev/null
  if [ -n "$img" ]; then
    ext="$(printf '%s' "${img##*.}" | tr 'A-Z' 'a-z')"
    name="background.$ext"
    sudo cp "$img" "$T/$name"      # SDDM cannot read your home folder, so the file is copied
    case "$ext" in
      mp4|webm|mkv|mov)
        # a video wallpaper needs the Qt multimedia module and its ffmpeg backend
        sudo pacman -S --needed --noconfirm qt6-multimedia qt6-multimedia-ffmpeg || warn "Could not install qt6-multimedia: the login screen keeps a plain background" ;;
    esac
    sudo sed -i "s|^background=.*|background=$name|" "$T/theme.conf"
    sudo chmod -R a+rX "$T"
    echo "SDDM wallpaper: $img"
  else
    echo "No image in $SRC - SDDM uses a plain background. Add one (jpg, png, gif or mp4) and run this script again."
  fi
  sudo systemctl enable sddm 2>/dev/null || warn "Could not enable sddm (another display manager may already be enabled)"
fi

# ------------------------------------------------------------------ done
say "Done"
cat <<MSG
Next steps:
  1. Reboot (or log out and pick the Hyprland session in SDDM).
  2. Press SUPER + /  to see every shortcut.
  3. Put still wallpapers in  $CFG/hypr/wallpapers/desktop  and  .../sddm , animated ones in  .../animated
     (then run this script again for SDDM). Use  wallpaper.sh next  to cycle through desktop + animated.
  4. Test the SDDM theme:  sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/krmv-tokyo
Old configs were backed up (look for backup-* and .bak-* names).
MSG
