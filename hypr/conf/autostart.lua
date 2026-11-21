-- ~/.config/hypr/conf/autostart.lua
hl.on("hyprland.start", function()
  hl.exec_cmd("sh ~/.config/hypr/scripts/dark-mode.sh")           -- dark mode for every app and website
  hl.exec_cmd("sh ~/.config/hypr/scripts/wallpaper.sh")           -- desktop wallpaper: restores your last one (still or animated)
  hl.exec_cmd("qs -p ~/.config/hypr/theme/quickshell/shell.qml")  -- bar + notifications (Quickshell)
  hl.exec_cmd("wl-paste --type text --watch cliphist store")      -- clipboard history (text)
  hl.exec_cmd("wl-paste --type image --watch cliphist store")     -- clipboard history (images)
  hl.exec_cmd("blueman-applet")                                   -- bluetooth pairing agent (for PIN dialogs)
  hl.exec_cmd("hypridle")                                         -- locks the screen before sleep / lid close
  -- polkit agent: shows the graphical password dialog for pkexec (Ventoy, GParted, ...). Its binary is NOT in PATH.
  hl.exec_cmd("sh -c 'export QT_QPA_PLATFORMTHEME=qt6ct QT_STYLE_OVERRIDE=Fusion; for b in /usr/lib/hyprpolkitagent/hyprpolkitagent /usr/libexec/hyprpolkitagent; do [ -x \"$b\" ] && exec \"$b\"; done; systemctl --user start hyprpolkitagent.service'")
  hl.exec_cmd("sh ~/.config/hypr/scripts/nightmode.sh restore")      -- night mode comes back if it was on
  hl.exec_cmd("playerctld daemon")                                -- media keys control the player you used last
  hl.exec_cmd("sh -c 'sleep 3; xhost +SI:localuser:root'")        -- lets root GUI apps (Ventoy, PINCE, GParted) open windows
  hl.exec_cmd("sh -c 'a=/usr/lib/geoclue-2.0/demos/agent; [ -x $a ] && exec $a'")   -- location permission prompts (apps not listed in Settings > Location)
end)
