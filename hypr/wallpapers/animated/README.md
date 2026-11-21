# Animated wallpapers

Put your animated wallpaper files in this folder. Supported formats are `.mp4`, `.webm`, `.gif` and `.mkv` (anything `mpv` can play). Still images belong in `../desktop` instead.

Run `wallpaper.sh next` to cycle through **both** the `desktop` and `animated` folders. Video and GIF files are displayed with `mpvpaper`; still images are displayed with `swaybg`.

The installer copies this folder to `~/.config/hypr/wallpapers/animated` without overwriting files you already have there, so it is safe to add your own wallpapers before or after running it.
