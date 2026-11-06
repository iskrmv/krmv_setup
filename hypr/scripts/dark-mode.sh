#!/bin/sh
# System-wide dark mode: GTK/libadwaita apps, Qt apps (via qt6ct) and websites (prefers-color-scheme)
# all follow this setting through gsettings + xdg-desktop-portal.
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'
