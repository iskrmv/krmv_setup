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
