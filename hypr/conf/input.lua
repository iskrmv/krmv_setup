-- ~/.config/hypr/conf/input.lua
-- Keyboard layouts live in ~/.local/state/krmv-setup/layouts (one line, e.g. "us,ru").
-- Right-click the keyboard chip in the bar to add or remove layouts; no need to edit this file.
local layouts = "us,ru"
local switch  = "grp:alt_shift_toggle"        -- ALT + SHIFT switches the layout

local f = io.open((os.getenv("HOME") or "") .. "/.local/state/krmv-setup/layouts", "r")
if f then
  local line = f:read("*l")
  f:close()
  if line and line:match("^[%w_,%-]+$") then layouts = line end
end

hl.config({
  input = {
    kb_layout  = layouts,
    kb_options = switch,
    natural_scroll = false,          -- regular USB mouse: normal scrolling
    touchpad = {
      natural_scroll = true,         -- trackpad: natural scrolling (the bar sliders still go "fingers up = more")
      scroll_factor = 0.5,           -- trackpad scroll speed (1.0 = default, lower = slower)
    },
  },
})
