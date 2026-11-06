-- ~/.config/hypr/conf/input.lua
local layouts = "us,ru"                       -- keyboard layouts, e.g. "us,ru" or "us,ru,uz"
local switch  = "grp:alt_shift_toggle"        -- ALT + SHIFT switches the layout

hl.config({
  input = {
    kb_layout  = layouts,
    kb_options = switch,
    natural_scroll = false,          -- mouse: normal scrolling
    touchpad = {
      natural_scroll = false,        -- trackpad: normal scrolling
      scroll_factor = 0.6,           -- trackpad scroll speed (1.0 = default, lower = slower)
    },
  },
})
