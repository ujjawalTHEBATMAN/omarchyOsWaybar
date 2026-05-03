#!/bin/bash
# ═══════════════════════════════════════════════════════════
# WORKSPACE DETAILS — Rich workspace info for Waybar
# Shows: active window title, class, workspace count
# ═══════════════════════════════════════════════════════════

get_workspace_info() {
    local ws_id="$1"
    local active_ws
    active_ws=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.id' 2>/dev/null)

    # Get all windows in this workspace
    local windows
    windows=$(hyprctl clients -j 2>/dev/null | jq -r "[.[] | select(.workspace.id == $ws_id)]" 2>/dev/null)
    local win_count
    win_count=$(echo "$windows" | jq 'length' 2>/dev/null)

    if [[ "$win_count" -gt 0 ]]; then
        # Get the focused/last window info
        local title class
        title=$(echo "$windows" | jq -r '.[0].title' 2>/dev/null | head -c 35)
        class=$(echo "$windows" | jq -r '.[0].class' 2>/dev/null)

        # Map class to a meaningful icon
        local app_icon
        case "$class" in
            brave-browser|Brave-browser)     app_icon="󰖟" ;;
            Thorium-browser|thorium-browser) app_icon="󰖟" ;;
            firefox|Firefox)                 app_icon="󰈹" ;;
            chromium|google-chrome*)          app_icon="󰊯" ;;
            code|Code)                        app_icon="󰨞" ;;
            antigravity)                      app_icon="" ;;
            jetbrains-idea*|idea)             app_icon="" ;;
            Alacritty|kitty|foot|xterm)       app_icon="" ;;
            thunar|nautilus|nemo|dolphin)     app_icon="󰉋" ;;
            discord|Discord)                  app_icon="󰙯" ;;
            telegram*|Telegram*)             app_icon="" ;;
            spotify|Spotify)                  app_icon="󰓇" ;;
            slack|Slack)                       app_icon="󰒱" ;;
            obs|OBS*)                         app_icon="󰑋" ;;
            gimp|Gimp)                        app_icon="" ;;
            vlc|mpv)                          app_icon="󰕧" ;;
            *)                                app_icon="󰣆" ;;
        esac

        echo "${app_icon}|${title}|${win_count}|${class}"
    else
        echo "|empty|0|"
    fi
}

# Output JSON for all workspaces (1-5)
active_ws=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.id' 2>/dev/null)

output="["
for i in 1 2 3 4 5; do
    info=$(get_workspace_info "$i")
    IFS='|' read -r icon title count class <<< "$info"
    is_active="false"
    [[ "$i" -eq "$active_ws" ]] && is_active="true"

    # Escape title for JSON
    title=$(echo "$title" | sed 's/"/\\"/g; s/\\/\\\\/g' | head -c 35)

    output+="{"
    output+="\"id\":$i,"
    output+="\"icon\":\"$icon\","
    output+="\"title\":\"$title\","
    output+="\"count\":$count,"
    output+="\"class\":\"$class\","
    output+="\"active\":$is_active"
    output+="}"
    [[ "$i" -lt 5 ]] && output+=","
done
output+="]"

echo "$output"
