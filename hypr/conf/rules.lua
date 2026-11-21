-- ~/.config/hypr/conf/rules.lua
-- Ignore "maximize" requests from apps (this rule is part of Hyprland's own default config).
-- Without it, apps such as Tor Browser, Firefox or kitty can maximize themselves and cover the whole screen.
hl.window_rule({
  name = "suppress-maximize-events",
  match = { class = ".*" },
  suppress_event = "maximize",
})

-- The calculator is a small app: open it floating in the middle of the screen instead of tiling it
hl.window_rule({
  name = "calculator-floating",
  match = { class = "^arithmetic$" },
  float = true,
  center = true,
})

-- Waydroid (and some games/VMs) ask Hyprland to forward ALL shortcuts to them, which silently disables
-- SUPER + K, SUPER + Q and friends while they are focused. Never allow that.
hl.window_rule({
  name = "no-shortcut-inhibit",
  match = { class = ".*" },
  no_shortcuts_inhibit = true,
})

-- The screenshot selection overlay must disappear at once, otherwise its fade-out ends up in the picture.
hl.layer_rule({
  name = "no-selection-fade",
  match = { namespace = "^selection$" },
  no_anim = true,
})
