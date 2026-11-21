-- ~/.config/swayimg/init.lua - Tokyo Night look for the image viewer (swayimg 4.x).
-- Every line is wrapped in pcall: if a setting does not exist in your swayimg version it is skipped,
-- the viewer still opens (SVG, PNG, JPEG, GIF, WebP, AVIF, HEIC, JXL, TIFF, BMP, RAW ...).
local function try(f) pcall(f) end
try(function() swayimg.text.size = 16 end)
try(function() swayimg.text.color = 0xffa9b1d6 end)
try(function() swayimg.viewer.default_scale = "fit" end)
