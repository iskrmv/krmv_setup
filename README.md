# krmv-setup

My complete Arch Linux desktop in **one command**: Hyprland, a Quickshell bar with notifications, rofi, kitty,
a lock screen, an SDDM login theme and a zsh setup. Everything uses the same Tokyo Night colors and square corners.

```bash
git clone https://github.com/iskrmv/krmv-setup.git
cd krmv-setup
bash install.sh
```

Run it as a normal user (it asks for `sudo` when needed). On a fresh Arch install, run `sudo pacman -Syu` first.
Reboot afterwards and choose the **Hyprland** session in SDDM.

## What you get

| Part | What it does |
| --- | --- |
| **Hyprland** (Lua config) | Split into small files: `conf/display.lua`, `input.lua`, `autostart.lua`, `keybinds.lua`, `env.lua` |
| **Quickshell bar** | Workspaces, clock with calendar on hover, CPU / RAM / disk details on hover, volume and brightness with sliders, Wi-Fi / Ethernet status, Wi-Fi and Bluetooth panels (connect, pair, passwords), battery (live via UPower: hover shows charge, time to full / time left, power draw and health), tray icons, power button. Only one hover popup is open at a time |
| **Notifications** | Built into the bar. Every notification stays 10 seconds and shows a countdown line (hover pauses it). Click one to jump to that app's window; chat apps (Telegram, Discord, ...) get a reply box when they support it |
| **On-screen display** | Volume and brightness changes (Fn keys, scroll, sliders) show a small level indicator at the bottom center. It shows "Muted" when muted |
| **Media** | Any player that speaks MPRIS (Spotify, VLC, mpv, YouTube / Netflix / music in Chrome or Firefox): back / play-pause / next, the title and the time between the launcher and the clock. Hover for the full info and a seek slider |
| **Volume mixer** | Hover the volume icon: master slider; click the small arrow (bottom right) for one slider and mute per app. Every app with an audio stream is listed (Steam, Telegram, Discord, browsers...). Running apps that are silent at the moment are listed too, and their slider works: the volume is remembered and applied when the app starts making sound |
| **Settings** | `SUPER + I` (or type "settings" in the app launcher) opens a rofi settings menu: **default apps** (browser, file manager, terminal, editor, video, music, images, PDF), a **keyboard shortcut editor**, desktop widgets and night mode. Everyone can pick their own apps and keys |
| **Default apps** | `SUPER + E` opens your default file manager (yazi by default), `SUPER + B` your default browser, `SUPER + Return` your default terminal |
| **Info boxes** | Volume and brightness, the media keys (play / pause / next / previous) and the touchpad key show a small box at the bottom center, like Windows. The media box appears only for the keys, not when you click inside a player |
| **Clock app** | Timer, alarms (with days and labels) and a stopwatch. Click the clock in the bar or press `SUPER + C`. An alarm or a finished timer rings with a sound and a window (Enter dismisses, S snoozes 5 minutes). Alarms and the running timer are remembered after a restart |
| **Images** | [swayimg](https://github.com/artemsen/swayimg) is the default image viewer: light, native Wayland, opens nearly every format (PNG, JPEG, GIF, WebP, AVIF, HEIC, JXL, SVG, TIFF, RAW...). Choose another one in Settings |
| **Night mode** | Open the brightness popup and click its small arrow: a night mode switch (blue light filter, `hyprsunset`) |
| **Terminal greeting** | `fastfetch` with the Tokyo Night theme greets you in zsh, bash and fish |
| **Keyboard** | English + Russian layouts, `ALT + SHIFT` switches them, the bar shows the current one (click it to switch). Also set for the SDDM login screen |
| **Editor** | Neovim with [LazyVim](https://www.lazyvim.org/) (the official starter, plugins pre-downloaded). `vim` is an alias for `nvim` |
| **Calculator** | [Arithmetic](https://github.com/armanmaurya/arithmetic) (Rust + Slint), installed by `install.sh`; the calculator key opens it floating in the middle of the screen |
| **Desktop widget** | The day in big stylized letters with the date and the time under it, same look as KDE's [Modern Clock](https://store.kde.org/p/2135653). Settings at the top of `DesktopClock.qml` |
| **Power menu** | Power icon in the bar: lock, log out, sleep, reboot, power off |
| **Lock screen** | `hyprlock`, themed. Locks automatically before sleep, so **closing the laptop lid locks the screen** (`hypridle`) |
| **rofi** | App launcher, clipboard history, emoji picker (with search keywords), shortcut list |
| **kitty** | Tokyo Night terminal theme |
| **SDDM** | Login screen theme with your wallpaper |
| **zsh** | oh-my-zsh + powerlevel10k + autosuggestions + syntax highlighting, vi mode |
| **Dark mode** | GTK, Qt and websites follow the dark theme automatically |
| **Aliases** | `pacman` = `sudo pacman`, `yoink` = `yay -S`, `yeet` = `yay -Rns`, `yago` = `yay -Ss`, `sweep` = deep clean (see below) |
| **yay** | Installed automatically if it is missing |

## Shortcuts

Press **SUPER + /** at any time to see this list on screen.

| Keys | Action |
| --- | --- |
| `SUPER + /` | Show all shortcuts |
| `ALT + SPACE` | App launcher |
| `SUPER + Return` | Terminal (kitty). The HP Omen key does the same |
| `SUPER + E` | Default file manager (yazi) |
| `SUPER + V` | Clipboard history |
| `SUPER + .` | Emoji picker |
| `SUPER + SHIFT + S` | Screenshot: select an area |
| `Print` | Screenshot: the focused monitor, instantly |
| `CTRL + Print` | Screenshot: all monitors, instantly |
| `CTRL + SHIFT + Print` | Screenshot: the focused window, instantly |
| `SUPER + I` | Settings (default apps, shortcuts, widgets) |
| `SUPER + C` | Clock app: timer, alarm, stopwatch (also: click the clock in the bar) |
| `SUPER + B` | Default web browser |
| `SUPER + W` | Next wallpaper |
| `SUPER + SHIFT + W` | Move the desktop clock (drag it, Enter saves, R resets, Esc cancels). Double-clicking the clock does the same |
| Calculator key | Calculator ([Arithmetic](https://github.com/armanmaurya/arithmetic)) |
| `SUPER + Q` | Close window |
| `SUPER + K` | Force kill the whole application (also Steam) |
| `SUPER + F` | Fullscreen |
| `SUPER + T` | Toggle floating |
| `SUPER + Arrow keys` | Move focus |
| `SUPER + SHIFT + Arrow keys` | Move the window |
| `SUPER + 1 ... 0` | Go to workspace 1-10 |
| `SUPER + SHIFT + 1 ... 0` | Move window to workspace 1-10 |
| `SUPER + left / right mouse drag` | Move / resize window |
| `SUPER + R` | Reload the Hyprland config |
| `SUPER + L` | Lock screen |
| `SUPER + SHIFT + E` | Log out |
| 4-finger swipe left / right (touchpad) | Switch workspace |
| Volume / brightness keys | Change volume and brightness (the bar updates instantly) |
| Media keys (Fn + play / pause / next / previous) | Control the player you used last |
| `ALT + SHIFT` | Switch keyboard layout |

Power menu keys: `L` lock, `E` log out, `S` sleep, `R` reboot, `P` power off, `Esc` cancel.

## Install options

Environment variables for `install.sh`:

| Variable | Effect |
| --- | --- |
| `YES=1` | No questions from pacman (`--noconfirm`) |
| `SKIP_PACKAGES=1` | Do not install packages or yay |
| `SKIP_SDDM=1` | Do not touch SDDM |
| `SKIP_ZSH=1` | Do not touch zsh |
| `SKIP_NVIM=1` | Do not install LazyVim |

Example: `YES=1 bash install.sh`. The script is safe to run again. Your old files are never lost: they are saved as
`~/.config/hypr/backup-<date>/` and `<file>.bak-<date>`.

## Repository layout

```
install.sh              the installer
hypr/                   -> ~/.config/hypr
  hyprland.lua            main file, only require() calls
  hypridle.conf           lock before sleep / lid close
  conf/                   display, input, env, autostart, keybinds
  theme/
    quickshell/           the bar, notifications and power menu (QML)
    rofi/ kitty/          linked to ~/.config/rofi and ~/.config/kitty
    hyprlock/             lock screen theme
    gtk/ qt6ct/ portal/   dark mode settings
    theme.lua             gaps and borders
  scripts/                wallpaper, brightness, screenshot, clipboard, emoji, keys, focus-app, dark-mode
  shell/                  aliases for bash / zsh / fish
  data/                   emoji list and the shortcut list
  wallpapers/desktop      desktop wallpapers
  wallpapers/sddm         login screen wallpaper
sddm/krmv-tokyo/        SDDM theme
zsh/zshrc               -> ~/.zshrc
```

## Customizing

- **Wallpapers:** put images in `~/.config/hypr/wallpapers/desktop` (random one at login, `SUPER + W` for the next).
  For the login screen put an image in `wallpapers/sddm` and run `bash install.sh` again.
- **Desktop widget:** the look and settings are in `hypr/theme/quickshell/ClockFace.qml` (`showDay`, `showDate`, `showTime`, `use24Hour`, `timeDecor`, `textColor`, `sizeScale`). To move it press `SUPER + SHIFT + W` (or double-click it), drag it, press Enter: the place is remembered in `~/.local/state/krmv-setup/clock-position`. To remove it, delete the `DesktopClock { ... }` line in `shell.qml`. The day name uses the Anurati font, which `install.sh` downloads from the original KDE widget's repository (it is free for personal use, so it is not stored in this repo); the rest uses Poppins.
- **Media in browsers:** works out of the box (Chrome, Firefox). For mpv install `mpv-mpris`.
- **Colors / font:** the `theme` block at the top of `hypr/theme/quickshell/shell.qml` (one `icon` color for every icon).
  The Quickshell bar reloads by itself when you save a file.
- **Hide a tray icon:** add a word to `trayHide` in `shell.qml`. Run `qs` in a terminal to see each tray item's id.
- **Scroll direction, trackpad speed:** `hypr/conf/input.lua`.
- **Shortcuts:** `hypr/conf/keybinds.lua`. Keep `hypr/data/shortcuts.txt` in sync, it feeds `SUPER + /`.
- **Idle lock (lock after N minutes):** uncomment the `listener` block in `hypr/hypridle.conf`.
- **HP Omen key:** bound to `XF86Launch2` (the kernel's name for it). If it does nothing on your model, run `sh ~/.config/hypr/scripts/find-key.sh`, press the key and put the printed name in `keybinds.lua`.
- **Touchpad gestures:** `hypr/conf/gestures.lua` (4-finger swipe switches workspaces).
- **Keys in zsh:** emacs style by default (Alt+Backspace deletes a word, Ctrl/Alt + arrows move by word). Want vi mode? Change `bindkey -e` to `bindkey -v` in `zsh/zshrc`.

## Changing shortcuts and default apps

Press `SUPER + I`:
- **Default apps**: pick the app for each job (the list shows every installed app that can do it).
- **Keyboard shortcuts**: pick a shortcut and type the new keys, for example `SUPER + SHIFT + T`. It rejects invalid
  combinations and keys that are already used. Your changes are saved in `~/.local/state/krmv-setup/binds.user.tsv`
  and survive `install.sh`; "Reset all shortcuts" removes them.
- The defaults live in `hypr/data/binds.tsv`; `scripts/gen-binds.sh` turns them (plus your changes) into
  `conf/custom-binds.lua` and into the `SUPER + /` list. A few fixed shortcuts (windows, workspaces, arrows) stay in `conf/keybinds.lua`.

## Desktop widgets

Press `SUPER + SHIFT + W` (or double-click the clock) to edit: drag a widget, switch widgets on and off in the list
at the top (more widgets will appear there later), Enter saves, `R` resets, `Delete` hides the clock.

## Cleaning up: `sweep`

One command for a deep clean of Arch:

```bash
sweep          # pacman + yay caches (keeps the newest version of installed packages), orphans (asks), old logs, thumbnails, pip/npm caches
sweep --all    # also deletes EVERY cached package file and offers to empty the trash
sweep -y       # no questions
```

It always removes the cached files of packages you uninstalled, and prints how much space it freed.

## Your powerlevel10k settings

Run `p10k configure` once. To make the prompt identical on every machine, copy the result into the repo:

```bash
cp ~/.p10k.zsh zsh/p10k.zsh
```

`install.sh` installs it automatically (only when `~/.p10k.zsh` does not exist yet).

## Laptop lid

Closing the lid suspends the laptop (systemd-logind default). `hypridle` locks the screen right before it sleeps, so
the lock screen is waiting when you open the lid. With an external monitor connected, logind may ignore the lid
(`HandleLidSwitchDocked`), then nothing sleeps and nothing locks. Use `SUPER + L` there.

## Troubleshooting

- **GUI apps that need root (Ventoy GUI, PINCE, GParted) do not open:** root is not allowed to draw on your desktop by default.
  `install.sh` installs XWayland, `xhost` and the Qt X11 helper libraries, and allows root at login.
  Start such apps from a terminal with `sudogui` (`sudogui ventoygui`, `sudogui PINCE`): it tries Wayland first, then X11,
  and prints the app's own error. `sudogui --x11 ...` / `--wayland ...` force one way. `sudogui --check` lists what is missing.
  From the app launcher: Ventoy and PINCE ask for the password through the polkit dialog (the polkit agent is started at
  login). Log out and in once after `install.sh`.
  pkexec only accepts administrators from the `wheel` group: if the polkit password dialog says "Not authorized", add yourself:
  `sudo usermod -aG wheel $USER` and log in again.
- **A clicked link does not bring up the browser:** `hypr/conf/misc.lua` turns on `focus_on_activate`, so a window that asks
  for attention is focused (and its workspace is shown). It only works if the app that opens the link hands over the
  focus request, which most do (Telegram, Discord, Chrome, Firefox).
- **Another keyboard layout (e.g. Uzbek):** change `layouts` at the top of `hypr/conf/input.lua` and the `localectl` line in `install.sh`.

- **The bar does not appear / something is broken:** run it in a terminal to see the errors:
  `pkill qs; qs -p ~/.config/hypr/theme/quickshell/shell.qml`
- **A window sticks out of its border (often when two apps share a workspace):** some apps have a minimum size that is bigger
  than the tile they get, and Hyprland lets them overflow. Float that window with `SUPER + T`. To investigate, run `winfo`
  while it happens and send the output (it lists window sizes, XWayland or Wayland, and the monitor scale).
- **A window opens covering the whole screen:** that is a maximize request from the app; `hypr/conf/rules.lua` ignores them. Check with `hyprctl clients | grep -B8 fullscreen`. A single window in a tiling layout always fills the workspace (inside the gaps); `SUPER + T` makes it floating.
- **Hyprland config errors:** `hyprctl configerrors`
- **A notification does not show:** make sure no other daemon runs: `pgrep -a "mako|dunst|swaync"`
- **Emoji look like empty boxes:** `fc-list | grep -i "noto color emoji"`, install `noto-fonts-emoji`
- **SDDM theme preview:** `sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/krmv-tokyo`

## License

The code in this repository is released under the [MIT License](LICENSE): use it, change it, share it.
Not covered by it:
- the wallpapers in `hypr/wallpapers/` belong to their authors;
- the Anurati font is not stored here: `install.sh` downloads it from the original KDE Modern Clock repository;
- the desktop clock only imitates the look of KDE's [Modern Clock](https://store.kde.org/p/2135653) (GPL-3.0), no code was copied.

## Notes

- Built for Arch Linux. Needs Hyprland with the Lua config (0.55 or newer) and Quickshell.
- Quickshell is installed from the official repository when it is there, otherwise from the AUR (`quickshell-git`).
