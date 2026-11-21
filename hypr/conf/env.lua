-- ~/.config/hypr/conf/env.lua
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")   -- Qt apps follow the dark palette from qt6ct
-- Native Wayland for Electron/Chromium/Firefox apps: same scroll speed and smoothness as the rest of the desktop
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("MOZ_ENABLE_WAYLAND", "1")
