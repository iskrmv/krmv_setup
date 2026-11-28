-- ~/.config/hypr/conf/autostart.lua
hl.on("hyprland.start", function()
  hl.exec_cmd("sh ~/.config/hypr/scripts/dark-mode.sh")           -- dark mode for every app and website
  hl.exec_cmd("sh ~/.config/hypr/scripts/wallpaper.sh")           -- desktop wallpaper: restores your last one (still or animated)
  hl.exec_cmd("qs -p ~/.config/hypr/theme/quickshell/shell.qml")  -- bar + notifications (Quickshell)
  hl.exec_cmd("wl-paste --type text --watch cliphist store")      -- clipboard history (text)
  hl.exec_cmd("wl-paste --type image --watch cliphist store")     -- clipboard history (images)
  hl.exec_cmd("blueman-applet")                                   -- bluetooth pairing agent (for PIN dialogs)
  hl.exec_cmd("hypridle")                                         -- locks the screen before sleep / lid close
  -- polkit password dialog: it is part of the Quickshell bar (theme/quickshell/PolkitDialog.qml), which falls back to hyprpolkitagent by itself
  hl.exec_cmd("sh ~/.config/hypr/scripts/phone-mount.sh watch")       -- phones (MTP) are mounted in ~/Phone when plugged in
  hl.exec_cmd("sh ~/.config/hypr/scripts/appvol-daemon.sh")           -- per-app volumes are applied the moment a new sound stream opens
  hl.exec_cmd("sh ~/.config/hypr/scripts/mouse.sh restore")            -- flat mouse acceleration comes back if it was on
  hl.exec_cmd("sh ~/.config/hypr/scripts/nightmode.sh restore")      -- night mode comes back if it was on
  hl.exec_cmd("playerctld daemon")                                -- media keys control the player you used last
  hl.exec_cmd("sh -c 'sleep 3; xhost +SI:localuser:root'")        -- lets root GUI apps (Ventoy, PINCE, GParted) open windows
  hl.exec_cmd("sh -c 'a=/usr/lib/geoclue-2.0/demos/agent; [ -x $a ] && exec $a'")   -- location permission prompts (apps not listed in Settings > Location)
end)
