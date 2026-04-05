#!/bin/bash

# --- CONFIGURATION ---
LOG_FILE="$HOME/task_log.txt"
ZENITY_TIMEOUT_SECS=180 # Closes the prompt after 3 mins defaulting to "No/Ignored"

# Hardcoded Daily Timetable (Format: "HH:MM HH:MM Task Name")
# Add your schedule here using 24-hour time format.
readonly TIMETABLE=(
    "05:00 05:30 Core Collections"
    "05:30 07:30 DSA Grind"
    "07:30 08:00 Morning Prep"
    "08:00 09:30 Spring Boot DS1"
    "09:30 09:40 Screen Break"
    "09:40 11:10 Spring Boot DS2"
    "11:10 11:20 Screen Break"
    "11:20 13:00 SB DS3 (Commit Code)"
    "13:00 14:00 Lunch & Recharge"
    "14:00 16:00 Spring Boot Learning"
    "16:00 18:00 Core Java Rev"
    "18:00 19:00 Multithreading"
    "19:00 20:00 Dinner & Relax"
    "20:00 21:30 JVM Arch (Books)"
    "21:30 23:59 Hard Stop & Sleep"
    "00:00 05:00 Deep Sleep/Rest"
)

# --- HELPER FUNCTIONS ---
get_ist_time() {
    TZ='Asia/Kolkata' date +%H:%M
}

get_ist_day() {
    TZ='Asia/Kolkata' date +%u # 1=Monday, ... , 6=Saturday, 7=Sunday
}

get_epoch() {
    TZ='Asia/Kolkata' date -d "$1" +%s
}

# --- STATE TRACKING ---
LAST_ALERT=""
PROMPT_DONE=""

# --- MAIN LOOP ---
while true; do
    # 1. Determine Current Task
    cur_time=$(get_ist_time)
    cur_epoch=$(get_epoch "$cur_time")
    
    current_task=""
    time_left_mins=0
    
    for entry in "${TIMETABLE[@]}"; do
        start=$(echo "$entry" | cut -d' ' -f1)
        end=$(echo "$entry" | cut -d' ' -f2)
        task=$(echo "$entry" | cut -d' ' -f3-)
        
        start_epoch=$(get_epoch "$start")
        end_epoch=$(get_epoch "$end")
        
        # Check if the current time falls within this task's block
        if [[ "$cur_epoch" -ge "$start_epoch" && "$cur_epoch" -lt "$end_epoch" ]]; then
            current_task="$task"
            time_left_mins=$(( (end_epoch - cur_epoch) / 60 ))
            break
        fi
    done

    # 2. Handle Task Output and Notifications
    if [[ -n "$current_task" ]]; then
        echo "{\"text\": \"$current_task - ${time_left_mins}m left\", \"class\": \"focus\"}"
        
        # Send warnings at exactly 10 and 5 minutes remaining
        if [[ "$time_left_mins" -eq 10 || "$time_left_mins" -eq 5 ]]; then
            alert_id="${current_task}_${time_left_mins}"
            if [[ "$LAST_ALERT" != "$alert_id" ]]; then
                notify-send -u critical "Time is up soon!" "Update your session for: $current_task"
                LAST_ALERT="$alert_id"
            fi
        
        # Trigger Zenity popup when time is exactly at 0 mins (last minute)
        elif [[ "$time_left_mins" -eq 0 ]]; then
            if [[ "$PROMPT_DONE" != "$current_task" ]]; then
                PROMPT_DONE="$current_task"
                
                # Run the popup inside the background `(...) &` so it NEVER hangs Waybar!
                (
                    # Zenity returns 0 for yes, 1 for no, 5 for timeout. 
                    # The --timeout flag defaults to dropping to `else` if ignored.
                    # _Yes and _No allow for Alt+Y and Alt+N as keyboard shortcuts.
                    if zenity --question \
                              --title="Mission Completion Check" \
                              --text="Did you complete the task: **$current_task**?" \
                              --ok-label="_Yes (y)" \
                              --cancel-label="_No (n)" \
                              --timeout="$ZENITY_TIMEOUT_SECS"; then
                        echo "$(TZ='Asia/Kolkata' date '+%Y-%m-%d %H:%M') - COMPLETED - $current_task" >> "$LOG_FILE"
                    else
                        echo "$(TZ='Asia/Kolkata' date '+%Y-%m-%d %H:%M') - INCOMPLETE/IGNORED - $current_task" >> "$LOG_FILE"
                    fi
                ) &
            fi
        fi
        
    else
        # No task matched in the timetable
        echo '{"text": "Free Time", "class": "free"}'
        LAST_ALERT=""
        PROMPT_DONE=""
    fi

    # Sync sleep ensures the script triggers perfectly at the start of the next minute
    sleep $((60 - $(date +%S)))
done
