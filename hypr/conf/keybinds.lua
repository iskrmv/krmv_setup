-- ~/.config/hypr/conf/keybinds.lua
local mod = "SUPER"

-- The customizable shortcuts (terminal, launcher, file manager, browser, settings, screenshots, ...) are NOT here:
-- they live in data/binds.tsv and are turned into conf/custom-binds.lua by scripts/gen-binds.sh.
-- Change them with SUPER + I > Keyboard shortcuts. This file keeps the fixed ones.
pcall(require, "conf/custom-binds")

-- Windows
hl.bind(mod .. " + Q", hl.dsp.window.close())                                 -- close politely
hl.bind(mod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
hl.bind(mod .. " + T", hl.dsp.window.float({ action = "toggle" }))            -- floating on/off

-- Move the window in the layout (SUPER + SHIFT + arrows)
hl.bind(mod .. " + SHIFT + left",  hl.dsp.window.move({ direction = "left" }))
hl.bind(mod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }))
hl.bind(mod .. " + SHIFT + up",    hl.dsp.window.move({ direction = "up" }))
hl.bind(mod .. " + SHIFT + down",  hl.dsp.window.move({ direction = "down" }))

-- Focus (arrow keys)
hl.bind(mod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- Workspaces: SUPER+1..9,0 switches; SUPER+SHIFT+1..9,0 moves the window
for i = 1, 10 do
  local key = i % 10   -- workspace 10 is on the "0" key
  hl.bind(mod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
  hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Mouse: SUPER + left button = move, right button = resize
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Volume (PipeWire / wpctl)
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),        { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),       { locked = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),     { locked = true })

-- Media keys (Fn + play / pause / next / previous), they control the player you used last
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("sh ~/.config/hypr/scripts/media-key.sh play-pause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("sh ~/.config/hypr/scripts/media-key.sh pause"),      { locked = true })
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("sh ~/.config/hypr/scripts/media-key.sh next"),       { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("sh ~/.config/hypr/scripts/media-key.sh previous"),   { locked = true })
hl.bind("XF86AudioStop",  hl.dsp.exec_cmd("sh ~/.config/hypr/scripts/media-key.sh stop"),       { locked = true })

-- Touchpad on / off key (an info box shows the state)
hl.bind("XF86TouchpadToggle", hl.dsp.exec_cmd("sh ~/.config/hypr/scripts/touchpad.sh toggle"), { locked = true })
hl.bind("XF86TouchpadOff",    hl.dsp.exec_cmd("sh ~/.config/hypr/scripts/touchpad.sh off"),    { locked = true })
hl.bind("XF86TouchpadOn",     hl.dsp.exec_cmd("sh ~/.config/hypr/scripts/touchpad.sh on"),     { locked = true })

-- Brightness (the script also tells the bar to refresh instantly)
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("sh ~/.config/hypr/scripts/brightness.sh up"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("sh ~/.config/hypr/scripts/brightness.sh down"), { locked = true, repeating = true })
