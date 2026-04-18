#!/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  Timetable Script for Waybar · Single-shot (interval mode)  ║
# ║  Outputs JSON: { text, tooltip, class }                     ║
# ╚══════════════════════════════════════════════════════════════╝

set -euo pipefail

LOG_FILE="${HOME}/task_log.txt"
TZ_ZONE="Asia/Kolkata"

# ── Daily Schedule (24-hour times) ─────────────────────────────
# Format: "HH:MM HH:MM Task Description"
TIMETABLE=(
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

# ── Get current IST epoch ──────────────────────────────────────
now_hm=$(TZ="$TZ_ZONE" date +%H:%M)
now_epoch=$(TZ="$TZ_ZONE" date -d "$now_hm" +%s)

# ── Find current task ──────────────────────────────────────────
current_task=""
time_left=0
next_task=""
css_class="free"

for i in "${!TIMETABLE[@]}"; do
    entry="${TIMETABLE[$i]}"
    start="${entry%% *}"                        # first field
    rest="${entry#* }"
    end="${rest%% *}"                            # second field
    task="${rest#* }"                             # remaining = task name

    start_epoch=$(TZ="$TZ_ZONE" date -d "$start" +%s 2>/dev/null || echo 0)
    end_epoch=$(TZ="$TZ_ZONE" date -d "$end" +%s 2>/dev/null || echo 0)

    if (( now_epoch >= start_epoch && now_epoch < end_epoch )); then
        current_task="$task"
        time_left=$(( (end_epoch - now_epoch) / 60 ))

        # Determine CSS class based on task type
        case "$task" in
            *Break*|*Sleep*|*Dinner*|*Lunch*|*Relax*|*Recharge*)
                css_class="free"
                ;;
            *Contest*|*LeetCode*|*Grind*)
                css_class="contest"
                ;;
            *)
                css_class="focus"
                ;;
        esac

        # Peek at next task for tooltip
        next_idx=$(( i + 1 ))
        if (( next_idx < ${#TIMETABLE[@]} )); then
            next_entry="${TIMETABLE[$next_idx]}"
            nr="${next_entry#* }"
            next_task="${nr#* }"
        fi
        break
    fi
done

# ── Warnings via notify-send (at 5 & 1 min) ───────────────────
if [[ -n "$current_task" && ( "$time_left" -eq 5 || "$time_left" -eq 1 ) ]]; then
    notify-send -u critical -i dialog-warning \
        "⏰ ${time_left}m left" \
        "Current: $current_task" 2>/dev/null || true
fi

# ── Generate output ────────────────────────────────────────────
if [[ -n "$current_task" ]]; then
    # Format time_left as Xh Ym if over 60 min
    if (( time_left >= 60 )); then
        display_time="$((time_left / 60))h $((time_left % 60))m"
    else
        display_time="${time_left}m"
    fi

    # Escape ampersands for Pango markup + JSON
    safe_task="${current_task//&/&amp;}"
    safe_next="${next_task//&/&amp;}"
    text="${safe_task} · ${display_time}"
    tooltip="📋 ${safe_task}\n⏳ ${display_time} remaining"
    [[ -n "$next_task" ]] && tooltip="${tooltip}\n➡️ Next: ${safe_next}"

    printf '{"text": "%s", "tooltip": "%s", "class": "%s"}\n' \
        "$text" "$tooltip" "$css_class"
else
    printf '{"text": "☕ Free Time", "tooltip": "No scheduled task right now", "class": "free"}\n'
fi
