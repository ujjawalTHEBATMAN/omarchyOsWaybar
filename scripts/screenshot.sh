#!/bin/bash
# Screenshot script with multiple modes
# Usage: screenshot.sh [full|area|window]

SCREENSHOTS_DIR="$HOME/Pictures/Screenshots"
mkdir -p "$SCREENSHOTS_DIR"

FILENAME="$SCREENSHOTS_DIR/screenshot_$(date +%Y%m%d_%H%M%S).png"

case "$1" in
    "area")
        grim -g "$(slurp)" "$FILENAME" && wl-copy < "$FILENAME"
        ;;
    "window")
        grim -g "$(hyprctl activewindow -j | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')" "$FILENAME" && wl-copy < "$FILENAME"
        ;;
    *)
        grim "$FILENAME" && wl-copy < "$FILENAME"
        ;;
esac

if [ -f "$FILENAME" ]; then
    notify-send "Screenshot" "Saved & copied to clipboard" -i camera-photo -t 2000
fi
