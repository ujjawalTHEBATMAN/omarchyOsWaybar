#!/bin/bash
# Power menu using rofi/wofi

options="󰌾 Lock\n󰒲 Sleep\n󰜉 Restart\n󰐥 Shutdown\n󰗼 Logout"

# Try wofi first, then rofi
if command -v wofi &> /dev/null; then
    chosen=$(echo -e "$options" | wofi --dmenu --prompt "Power Menu" --width 200 --height 250)
elif command -v rofi &> /dev/null; then
    chosen=$(echo -e "$options" | rofi -dmenu -p "Power Menu" -theme-str 'window {width: 200px;}')
else
    notify-send "Power Menu" "Neither wofi nor rofi found!"
    exit 1
fi

case "$chosen" in
    *"Lock"*)
        hyprlock || swaylock
        ;;
    *"Sleep"*)
        systemctl suspend
        ;;
    *"Restart"*)
        systemctl reboot
        ;;
    *"Shutdown"*)
        systemctl poweroff
        ;;
    *"Logout"*)
        hyprctl dispatch exit
        ;;
esac
