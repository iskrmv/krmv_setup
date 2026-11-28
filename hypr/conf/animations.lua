-- ~/.config/hypr/conf/animations.lua
-- Transitions: windows opening / closing / moving, workspaces, fades, layers (rofi, bar popups), borders.
-- Everything is chosen in  SUPER + I > System > Animations  and saved in ~/.local/state/krmv-setup/animations.conf :
--   preset    = off | sharp | classic | calm | smooth | playful        (sharp = short and crisp, the default)
--   window    = auto | pop | slide | gnome | fade                      (how a window appears; auto = what the preset uses)
--   workspace = auto | slide | vertical | fade | slidefade             (how workspaces change)
-- "classic" leaves Hyprland's own animations untouched (the look you had before this file existed).
-- Every call is wrapped in pcall: a leaf that your Hyprland version does not know is simply skipped.
local home = os.getenv("HOME") or ""
local cfg = { preset = "sharp", window = "auto", workspace = "auto" }

local f = io.open(home .. "/.local/state/krmv-setup/animations.conf", "r")
if f then
  for line in f:lines() do
    local k, v = line:match("^(%w+)=(%w+)$")
    if k and cfg[k] ~= nil then cfg[k] = v end
  end
  f:close()
else
  local old = io.open(home .. "/.local/state/krmv-setup/animations", "r")      -- the single-word file of an older version
  if old then
    local v = old:read("*l")
    old:close()
    if v and v:match("^%w+$") then cfg.preset = v end
  end
end

if cfg.preset == "off" then
  pcall(hl.config, { animations = { enabled = false } })
  return
end
pcall(hl.config, { animations = { enabled = true } })
pcall(hl.config, { misc = { animate_manual_resizes = true, animate_mouse_windowdragging = true } })

local function curve(name, p1, p2)
  pcall(hl.curve, name, { type = "bezier", points = { p1, p2 } })
end
-- Hyprland wants the curve in the field "bezier" (or "spring")
local function anim(leaf, speed, c, style)
  pcall(hl.animation, { leaf = leaf, enabled = true, speed = speed, bezier = c, style = style })
end

-- curves
curve("krmv_sharp", { 0.22, 1.0 },  { 0.36, 1.0 })     -- crisp: fast start, short soft landing (ease-out quint)
curve("krmv_out",   { 0.16, 1.0 },  { 0.30, 1.0 })     -- a little longer landing
curve("krmv_in",    { 0.70, 0.0 },  { 0.84, 0.0 })     -- things that leave
curve("krmv_over",  { 0.34, 1.30 }, { 0.64, 1.0 })     -- small overshoot
curve("krmv_boing", { 0.30, 1.75 }, { 0.50, 1.0 })     -- bigger overshoot

-- the styles you can pick in Settings
local windowStyles = { pop = "popin 85%", slide = "slide", gnome = "gnomed", fade = "popin 100%" }
local workspaceStyles = { slide = "slide", vertical = "slidevert", fade = "fade", slidefade = "slidefade 25%" }

-- the presets: speed (higher = slower) per group, curve, and the default styles
local presets = {
  sharp   = { c = "krmv_sharp", cin = "krmv_in", win = "popin 93%",  ws = "slide",         layers = "fade",
              s = { wIn = 3,   wOut = 2.5, wMove = 3, fIn = 3,   fOut = 2.5, fSwitch = 3, fDim = 4, fLayers = 2.5, layers = 2.5, border = 4,  ws = 3 } },
  calm    = { c = "krmv_out",   cin = "krmv_in", win = "popin 95%",  ws = "fade",          layers = "fade",
              s = { wIn = 3.5, wOut = 3,   wMove = 3.5, fIn = 3.5, fOut = 3, fSwitch = 3.5, fDim = 5, fLayers = 3, layers = 3, border = 5, ws = 4 } },
  smooth  = { c = "krmv_out",   cin = "krmv_in", win = "popin 82%",  ws = "slidefade 24%", layers = "fade",
              s = { wIn = 5,   wOut = 4,   wMove = 5, fIn = 5,   fOut = 4,   fSwitch = 5, fDim = 6, fLayers = 4,   layers = 4,   border = 8,  ws = 6 } },
  playful = { c = "krmv_boing", cin = "krmv_in", win = "popin 65%",  ws = "slide",         layers = "popin 85%",
              s = { wIn = 6,   wOut = 4,   wMove = 6, fIn = 6,   fOut = 4,   fSwitch = 6, fDim = 7, fLayers = 4,   layers = 5,   border = 10, ws = 7 } },
}

local p = presets[cfg.preset]
if cfg.preset == "classic" then
  -- Hyprland's defaults stay as they are. Only a style you picked yourself is applied on top.
  p = { c = "krmv_out", cin = "krmv_in", win = "popin 87%", ws = "slide", layers = "fade",
        s = { wIn = 4.1, wOut = 1.5, wMove = 4.8, ws = 2 } }
  if cfg.window == "auto" and cfg.workspace == "auto" then return end
end
if not p then return end

local win = windowStyles[cfg.window] or p.win
local ws = workspaceStyles[cfg.workspace] or p.ws
local s = p.s

anim("global", s.wMove or 4, p.c)
-- windows
anim("windowsIn",   s.wIn,   p.c,   win)
anim("windowsOut",  s.wOut,  p.cin, win)
anim("windowsMove", s.wMove, p.c)
-- fades
if s.fIn then
  anim("fadeIn", s.fIn, p.c);           anim("fadeOut", s.fOut, p.cin)
  anim("fadeSwitch", s.fSwitch, p.c);   anim("fadeDim", s.fDim, p.c)
  anim("fadeShadow", s.fDim, p.c);      anim("fadeLayers", s.fLayers, p.c)
  anim("fadeLayersIn", s.fLayers, p.c); anim("fadeLayersOut", s.fLayers, p.cin)
end
-- layers: rofi, the bar's popups, notifications
if s.layers then
  anim("layers",    s.layers, p.c,   p.layers)
  anim("layersIn",  s.layers, p.c,   p.layers)
  anim("layersOut", s.layers, p.cin, p.layers)
end
-- borders
if s.border then anim("border", s.border, p.c) end
-- workspaces (and the special workspace, vertical when the workspaces slide up and down)
local vertical = (cfg.workspace == "vertical")
anim("workspaces",    s.ws, p.c,   ws)
anim("workspacesIn",  s.ws, p.c,   ws)
anim("workspacesOut", s.ws, p.cin, ws)
anim("specialWorkspace",    s.ws, p.c,   vertical and "slidefadevert 20%" or "slidefadevert 20%")
anim("specialWorkspaceIn",  s.ws, p.c,   "slidefadevert 20%")
anim("specialWorkspaceOut", s.ws, p.cin, "slidefadevert 20%")
