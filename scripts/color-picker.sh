#!/bin/bash
# Color picker script - picks color and copies to clipboard
color=$(hyprpicker -a -f hex 2>/dev/null)
if [ -n "$color" ]; then
    echo "$color" | wl-copy
    notify-send "Color Picker" "Copied: $color" -i color-select
fi
