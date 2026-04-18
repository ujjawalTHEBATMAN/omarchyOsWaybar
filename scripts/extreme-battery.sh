#!/bin/bash
# ~/.config/waybar/scripts/extreme-battery.sh
# Toggle Extreme Battery Saver Mode

STATE_FILE="/tmp/extreme_battery_state"

if [ "$1" == "toggle" ]; then
    if [ -f "$STATE_FILE" ]; then
        # Currently enabled, let's disable
        rm "$STATE_FILE"
        
        # 1. Restore Power Profile
        if command -v powerprofilesctl &> /dev/null; then powerprofilesctl set balanced; fi
        
        # 2. Restore Screen & Keyboard Brightness
        if command -v brightnessctl &> /dev/null; then 
            brightnessctl set 50%
            brightnessctl --device='*kbd_backlight' set 100% 2>/dev/null || true
        fi
        
        # 3. Enable Bluetooth safely
        if command -v bluetoothctl &> /dev/null; then bluetoothctl power on; fi
        
        # 4. Notify User
        notify-send -u normal "🔋 Battery Mode" "Extreme Saver DISABLED.\nRestored to Balanced."
    else
        # Currently disabled, let's enable
        touch "$STATE_FILE"
        
        # 1. Set Power Profile to Power-Saver
        if command -v powerprofilesctl &> /dev/null; then powerprofilesctl set power-saver; fi
        
        # 2. Lower Screen Brightness and Disable Keyboard Backlight
        if command -v brightnessctl &> /dev/null; then 
            brightnessctl set 15%
            brightnessctl --device='*kbd_backlight' set 0% 2>/dev/null || true
        fi
        
        # 3. Disable Bluetooth (high battery drain)
        if command -v bluetoothctl &> /dev/null; then bluetoothctl power off; fi
        
        # 4. Notify User
        notify-send -u critical "🔋 Battery Mode" "Extreme Saver ENABLED.\nBackground drains minimized!"
    fi
    exit 0
fi

echo "Usage: $0 toggle"
exit 1
