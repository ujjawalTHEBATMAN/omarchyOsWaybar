#!/bin/bash
# Stopwatch Script for Waybar
# Features: Time tracking, Daily logs, Instant Waybar updates, Notifications
# Author: Antigravity

# Configuration
DATA_DIR="$HOME/.local/share/waybar-stopwatch"
STATE_FILE="$DATA_DIR/.state"
CURRENT_SESSION_FILE="$DATA_DIR/.current_session"

# Waybar Signal for instant updates (Must match "signal": 10 in config)
SIGNAL=10

# Ensure data directory exists
mkdir -p "$DATA_DIR"

# Get current date info
YEAR=$(date +%Y)
MONTH=$(date +%m)
DAY=$(date +%d)
DATE_DIR="$DATA_DIR/$YEAR/$MONTH"
LOG_FILE="$DATE_DIR/$DAY.log"

# Ensure date directory exists
mkdir -p "$DATE_DIR"

# Initialize state file if not exists
if [[ ! -f "$STATE_FILE" ]]; then
    echo "stopped" > "$STATE_FILE"
fi

# Function to get current timestamp in seconds
get_timestamp() {
    date +%s
}

# Function to format time as MM:SS or HH:MM:SS
format_time() {
    local total_seconds=$1
    local hours=$((total_seconds / 3600))
    local minutes=$(( (total_seconds % 3600) / 60 ))
    local seconds=$((total_seconds % 60))
    
    if [[ $hours -gt 0 ]]; then
        printf "%02d:%02d:%02d" $hours $minutes $seconds
    else
        printf "%02d:%02d" $minutes $seconds
    fi
}

# Function to get elapsed time
get_elapsed() {
    if [[ -f "$CURRENT_SESSION_FILE" ]]; then
        local start_time=$(cat "$CURRENT_SESSION_FILE")
        local now=$(get_timestamp)
        echo $((now - start_time))
    else
        echo 0
    fi
}

# Function to get today's total time from log using awk for performance
get_today_total() {
    if [[ -f "$LOG_FILE" ]]; then
        awk -F',' '{sum+=$3} END {print sum+0}' "$LOG_FILE"
        # Fallback to 0 handled by +0 if file is empty or invalid
    else
        echo 0
    fi
}

# Send Signal to Waybar
update_waybar() {
    pkill -RTMIN+${SIGNAL} waybar
}

# System Notification
notify() {
    local title=$1
    local message=$2
    # Check if notify-send exists
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -i "timer" "$title" "$message"
    fi
}

# Function to start the stopwatch
start_stopwatch() {
    # Check if already running to avoid reset
    local state=$(cat "$STATE_FILE" 2>/dev/null || echo "stopped")
    if [[ "$state" == "running" ]]; then
        return
    fi

    local now=$(get_timestamp)
    echo "$now" > "$CURRENT_SESSION_FILE"
    echo "running" > "$STATE_FILE"
    
    # Log start event
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Session started" >> "$LOG_FILE.events"
    
    notify "Stopwatch Started" "Tracking time..."
    update_waybar
}

# Function to stop the stopwatch
stop_stopwatch() {
    local state=$(cat "$STATE_FILE" 2>/dev/null || echo "stopped")
    
    # Only stop if running or if we want to force cleanup
    if [[ -f "$CURRENT_SESSION_FILE" ]]; then
        local start_time=$(cat "$CURRENT_SESSION_FILE")
        local end_time=$(get_timestamp)
        local duration=$((end_time - start_time))
        
        # Log to daily file: start,end,duration
        echo "$start_time,$end_time,$duration" >> "$LOG_FILE"
        
        # Log stop event
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Session stopped ($(format_time $duration))" >> "$LOG_FILE.events"
        
        # Clean up current session
        rm -f "$CURRENT_SESSION_FILE"
        
        notify "Stopwatch Stopped" "Session: $(format_time $duration)"
    fi
    echo "stopped" > "$STATE_FILE"
    update_waybar
}

# Function to toggle stopwatch
toggle() {
    local state=$(cat "$STATE_FILE" 2>/dev/null || echo "stopped")
    
    if [[ "$state" == "running" ]]; then
        stop_stopwatch
    else
        start_stopwatch
    fi
}

# Reset function
reset() {
    rm -f "$CURRENT_SESSION_FILE"
    echo "stopped" > "$STATE_FILE"
    notify "Stopwatch Reset" "Current session cleared."
    update_waybar
}

# Function to output status for Waybar
status() {
    local state=$(cat "$STATE_FILE" 2>/dev/null || echo "stopped")
    local elapsed=0
    local today_total=$(get_today_total)
    local icon=""
    local class=""
    local tooltip_extra=""
    
    if [[ "$state" == "running" ]]; then
        elapsed=$(get_elapsed)
        icon="󰔟"  # Timer running icon
        class="running"
        
        # Add start time to tooltip
        if [[ -f "$CURRENT_SESSION_FILE" ]]; then
            local start_ts=$(cat "$CURRENT_SESSION_FILE")
            local start_str=$(date -d "@$start_ts" "+%H:%M:%S")
            tooltip_extra="Started at: $start_str\n"
        fi
    else
        icon="󰔛"  # Timer stopped icon
        class="stopped"
    fi
    
    local current_time=$(format_time $elapsed)
    local total_time=$(format_time $today_total)
    
    # JSON output for Waybar
    if [[ "$state" == "running" ]]; then
        echo "{\"text\": \"$icon $current_time\", \"tooltip\": \"${tooltip_extra}Session: $current_time\\nToday: $total_time\\n\\nRight-click to stop\", \"class\": \"$class\"}"
    else
        if [[ $today_total -gt 0 ]]; then
            echo "{\"text\": \"$icon $total_time\", \"tooltip\": \"Today's total: $total_time\\n\\nRight-click to start\", \"class\": \"$class\"}"
        else
            echo "{\"text\": \"$icon 00:00\", \"tooltip\": \"No time tracked today\\n\\nRight-click to start\", \"class\": \"$class\"}"
        fi
    fi
}

# Main command handler
case "${1:-status}" in
    toggle)
        toggle
        ;;
    start)
        start_stopwatch
        ;;
    stop)
        stop_stopwatch
        ;;
    status)
        status
        ;;
    reset)
        reset
        ;;
    *)
        echo "Usage: $0 {toggle|start|stop|status|reset}"
        exit 1
        ;;
esac
