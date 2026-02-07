#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║              Smart Music Controller for Waybar                                ║
# ║  Unified control: Play/Pause, Prev/Next with local music library             ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

MUSIC_DIR="$HOME/Music"
QUEUE_FILE="/tmp/waybar-music-queue"
INDEX_FILE="/tmp/waybar-music-index"
CURRENT_TRACK_FILE="/tmp/waybar-music-current"

# ─────────────────────────────────────────────────────────────────────────────
# SIGNAL TRIGGER FOR INSTANT WAYBAR UPDATES
# ─────────────────────────────────────────────────────────────────────────────

trigger_update() {
    pkill -RTMIN+8 waybar 2>/dev/null
}

# ─────────────────────────────────────────────────────────────────────────────
# HELPER FUNCTIONS
# ─────────────────────────────────────────────────────────────────────────────

# Get all music files recursively
get_music_files() {
    find "$MUSIC_DIR" -type f \( \
        -iname "*.mp3" -o -iname "*.flac" -o -iname "*.wav" -o \
        -iname "*.ogg" -o -iname "*.m4a" -o -iname "*.aac" -o \
        -iname "*.opus" -o -iname "*.wma" \
    \) 2>/dev/null
}

# Build shuffled queue
build_queue() {
    get_music_files | shuf > "$QUEUE_FILE"
    echo "1" > "$INDEX_FILE"
}

# Get current index
get_index() {
    cat "$INDEX_FILE" 2>/dev/null || echo "1"
}

# Get total tracks
get_total() {
    wc -l < "$QUEUE_FILE" 2>/dev/null || echo "0"
}

# Get track at index
get_track_at() {
    local idx=$1
    sed -n "${idx}p" "$QUEUE_FILE" 2>/dev/null
}

# Check if our mpv music player is running (using specific class name)
is_our_mpv_running() {
    pgrep -f "mpv.*waybar-music-player" >/dev/null 2>&1
}

# Get our mpv PID
get_our_mpv_pid() {
    pgrep -f "mpv.*waybar-music-player" 2>/dev/null | head -1
}

# Check if any MPRIS player is active (Spotify, Firefox, etc.)
is_mpris_active() {
    local status=$(playerctl -a status 2>/dev/null | grep -E "Playing|Paused" | head -1)
    [ -n "$status" ]
}

# Get MPRIS player status
get_mpris_status() {
    playerctl status 2>/dev/null
}

# ─────────────────────────────────────────────────────────────────────────────
# PLAYBACK CONTROLS
# ─────────────────────────────────────────────────────────────────────────────

# Play a specific track
play_track() {
    local track="$1"
    
    if [ -z "$track" ] || [ ! -f "$track" ]; then
        notify-send -i dialog-warning "Music" "Track not found" -t 2000
        return 1
    fi
    
    # Stop any existing music player we started
    stop_our_mpv
    
    # Save current track
    echo "$track" > "$CURRENT_TRACK_FILE"
    
    # Start mpv with a unique title so we can identify it
    # Using --title for identification
    nohup mpv --audio-display=no --force-window=no --really-quiet \
        --title="waybar-music-player" "$track" &>/dev/null &
    
    # Notification
    local filename=$(basename "$track")
    local name="${filename%.*}"
    # Truncate long names
    [ ${#name} -gt 40 ] && name="${name:0:37}..."
    notify-send -i audio-x-generic "🎵 Now Playing" "$name" -t 3000
}

# Stop our mpv player only
stop_our_mpv() {
    pkill -f "mpv.*waybar-music-player" 2>/dev/null
    # Small delay to ensure process is killed
    sleep 0.1
}

# Toggle play/pause
toggle_play_pause() {
    # Check if our mpv is running
    if is_our_mpv_running; then
        # Our player is running - stop it
        stop_our_mpv
        notify-send -i audio-x-generic "Music" "Paused" -t 1500
        trigger_update
        return
    fi
    
    # Check if MPRIS player (Spotify, Firefox, etc.) is active
    local mpris_status=$(get_mpris_status)
    if [ "$mpris_status" = "Playing" ] || [ "$mpris_status" = "Paused" ]; then
        playerctl play-pause
        trigger_update
        return
    fi
    
    # Nothing playing - start random music
    play_random
    trigger_update
}

# Play random track
play_random() {
    # Build queue if needed
    [ ! -f "$QUEUE_FILE" ] || [ ! -s "$QUEUE_FILE" ] && build_queue
    
    local total=$(get_total)
    [ "$total" -eq 0 ] && { notify-send -i dialog-warning "Music" "No music found in $MUSIC_DIR" -t 3000; return 1; }
    
    # Pick random index
    local idx=$((RANDOM % total + 1))
    echo "$idx" > "$INDEX_FILE"
    
    local track=$(get_track_at "$idx")
    play_track "$track"
}

# Play next track
play_next() {
    # Stop our player if running (will start new track)
    local was_playing=0
    if is_our_mpv_running; then
        stop_our_mpv
        was_playing=1
    fi
    
    # If MPRIS active and we weren't playing, use playerctl
    if [ "$was_playing" -eq 0 ] && is_mpris_active; then
        playerctl next
        trigger_update
        return
    fi
    
    # Build queue if needed
    [ ! -f "$QUEUE_FILE" ] || [ ! -s "$QUEUE_FILE" ] && build_queue
    
    local idx=$(get_index)
    local total=$(get_total)
    
    # Increment index (wrap around)
    idx=$((idx + 1))
    [ "$idx" -gt "$total" ] && idx=1
    
    echo "$idx" > "$INDEX_FILE"
    local track=$(get_track_at "$idx")
    play_track "$track"
    trigger_update
}

# Play previous track
play_prev() {
    # Stop our player if running (will start new track)
    local was_playing=0
    if is_our_mpv_running; then
        stop_our_mpv
        was_playing=1
    fi
    
    # If MPRIS active and we weren't playing, use playerctl
    if [ "$was_playing" -eq 0 ] && is_mpris_active; then
        playerctl previous
        trigger_update
        return
    fi
    
    # Build queue if needed
    [ ! -f "$QUEUE_FILE" ] || [ ! -s "$QUEUE_FILE" ] && build_queue
    
    local idx=$(get_index)
    local total=$(get_total)
    
    # Decrement index (wrap around)
    idx=$((idx - 1))
    [ "$idx" -lt 1 ] && idx=$total
    
    echo "$idx" > "$INDEX_FILE"
    local track=$(get_track_at "$idx")
    play_track "$track"
    trigger_update
}

# Stop all playback
stop_all() {
    stop_our_mpv
    playerctl -a stop 2>/dev/null
    notify-send -i audio-x-generic "Music" "Playback stopped" -t 2000
    trigger_update
}

# ─────────────────────────────────────────────────────────────────────────────
# WAYBAR STATUS OUTPUT (JSON)
# ─────────────────────────────────────────────────────────────────────────────

# Get MPRIS metadata for tooltip
get_mpris_tooltip() {
    local artist=$(playerctl metadata artist 2>/dev/null)
    local title=$(playerctl metadata title 2>/dev/null)
    if [ -n "$title" ]; then
        [ -n "$artist" ] && echo "♪ $artist - $title" || echo "♪ $title"
    else
        echo "Media Player"
    fi
}

# Get play/pause button status
get_playpause_status() {
    local track_count=$(get_music_files | wc -l)
    
    # Check if our mpv is running first
    if is_our_mpv_running; then
        local track=$(cat "$CURRENT_TRACK_FILE" 2>/dev/null | xargs -r basename)
        [ -n "$track" ] && track="${track%.*}"
        echo "{\"text\": \"󰏤\", \"class\": \"playing\", \"tooltip\": \"Pause: ${track:-Local Music}\"}"
        return
    fi
    
    # Check MPRIS players (Spotify, Firefox, etc.)
    local mpris_status=$(get_mpris_status)
    local tooltip=$(get_mpris_tooltip)
    
    if [ "$mpris_status" = "Playing" ]; then
        echo "{\"text\": \"󰏤\", \"class\": \"playing\", \"tooltip\": \"Pause: $tooltip\"}"
    elif [ "$mpris_status" = "Paused" ]; then
        echo "{\"text\": \"󰐊\", \"class\": \"paused\", \"tooltip\": \"Resume: $tooltip\"}"
    else
        # Nothing playing - show play button
        echo "{\"text\": \"󰐊\", \"class\": \"stopped\", \"tooltip\": \"🎵 Shuffle Play (${track_count} tracks)\"}"
    fi
}

# Get prev button status
get_prev_status() {
    echo '{"text": "󰒮", "class": "control", "tooltip": "Previous Track"}'
}

# Get next button status  
get_next_status() {
    echo '{"text": "󰒭", "class": "control", "tooltip": "Next Track"}'
}

# ─────────────────────────────────────────────────────────────────────────────
# MAIN COMMAND HANDLER
# ─────────────────────────────────────────────────────────────────────────────

case "$1" in
    # Playback controls
    "toggle"|"play-pause")
        toggle_play_pause
        ;;
    "play")
        play_random
        ;;
    "next")
        play_next
        ;;
    "prev"|"previous")
        play_prev
        ;;
    "stop")
        stop_all
        ;;
    "shuffle"|"rebuild")
        build_queue
        notify-send -i audio-x-generic "Music Queue" "Shuffled $(get_total) tracks" -t 2000
        ;;
    
    # Status for waybar
    "status")
        get_playpause_status
        ;;
    "status-prev")
        get_prev_status
        ;;
    "status-next")
        get_next_status
        ;;
    
    # Info
    "count")
        get_music_files | wc -l
        ;;
    "current")
        cat "$CURRENT_TRACK_FILE" 2>/dev/null | xargs -r basename || echo "None"
        ;;
    
    # Default: toggle play/pause
    *)
        toggle_play_pause
        ;;
esac
