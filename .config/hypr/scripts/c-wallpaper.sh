#!/usr/bin/env bash

WALL_DIR="$HOME/Pictures/Wallpapers"

wall=$(find "$WALL_DIR" -type f \
    \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) \
    | shuf -n1)

[ -z "$wall" ] && exit 1

hyprctl hyprpaper wallpaper "HDMI-A-1,$wall"
