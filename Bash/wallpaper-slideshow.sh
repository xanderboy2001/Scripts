#!/usr/bin/env bash

WALLPAPER_DIR="$HOME/Pictures/wallpapers/"

# Wait until hyprpaper is running
while ! pgrep -x hyprpaper >/dev/null; do
		sleep 0.5
done

while true; do
		CURRENT_WALLPAPER=$(hyprctl hyprpaper listloaded)
		# Get random wallpaper that is not the current one
		WALLPAPER=$(find "$WALLPAPER_DIR" -type f ! -name "$(basename "$CURRENT_WALLPAPER")" | shuf -n 1)
		# Unload the current wallpaper, load the new one and set it
		hyprctl hyprpaper unload all
		hyprctl hyprpaper preload "$WALLPAPER"
		hyprctl hyprpaper wallpaper , "$WALLPAPER"
		sleep 300
done
