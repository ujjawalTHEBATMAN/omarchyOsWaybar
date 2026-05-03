#!/usr/bin/env bash
# Waybar Music Controller — v3 (stable)
# Fixed: race-condition auto-next, cascading track switches, PID tracking
#
# Controls:
#   toggle/play-pause  — Play / Pause (left click on play)
#   next / prev        — Next / Previous track
#   stop               — Stop everything
#   shuffle             — Rebuild & shuffle queue
#   cycle-player       — Cycle MPRIS players
#   mode [auto|mpris|local] — Switch mode
#   seek-forward / seek-back
#   vol-up / vol-down
#   status / status-prev / status-next  — JSON for waybar

set -u

MUSIC_DIR="${MUSIC_DIR:-$HOME/Music}"
STATE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/waybar-music"
QUEUE_FILE="$STATE_DIR/queue"
INDEX_FILE="$STATE_DIR/index"
CURRENT_TRACK_FILE="$STATE_DIR/current_track"
MODE_FILE="$STATE_DIR/mode"
PREFERRED_PLAYER_FILE="$STATE_DIR/preferred_player"
PID_FILE="$STATE_DIR/mpv.pid"
LOCK_FILE="$STATE_DIR/action.lock"
SIGNAL=12
MAX_LABEL_LEN=22
SEEK_STEP="${WAYBAR_MUSIC_SEEK_STEP:-10}"
VOLUME_STEP="${WAYBAR_MUSIC_VOLUME_STEP:-0.05}"

mkdir -p "$STATE_DIR"

# ---------- Utilities ----------

trigger_update() {
  pkill -RTMIN+"$SIGNAL" waybar 2>/dev/null || true
}

notify() {
  if command -v notify-send >/dev/null 2>&1; then
    notify-send -i audio-x-generic "$1" "$2" -t "${3:-1800}" >/dev/null 2>&1 || true
  fi
}

json_escape() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e ':a;N;$!ba;s/\n/\\n/g' -e 's/\r/\\r/g' -e 's/\t/\\t/g'
}

trim_label() {
  local text="$1"
  if [ "${#text}" -gt "$MAX_LABEL_LEN" ]; then
    printf '%s…' "${text:0:$((MAX_LABEL_LEN-1))}"
  else
    printf '%s' "$text"
  fi
}

# Simple lock to prevent concurrent next/prev/toggle from piling up
acquire_lock() {
  local attempts=0
  while [ -f "$LOCK_FILE" ]; do
    # Check if the lock is stale (older than 5 seconds)
    if [ -f "$LOCK_FILE" ]; then
      local lock_age
      lock_age=$(( $(date +%s) - $(stat -c %Y "$LOCK_FILE" 2>/dev/null || echo 0) ))
      if [ "$lock_age" -gt 5 ]; then
        rm -f "$LOCK_FILE"
        break
      fi
    fi
    attempts=$((attempts + 1))
    if [ "$attempts" -gt 10 ]; then
      return 1  # Give up — another action is running
    fi
    sleep 0.1
  done
  touch "$LOCK_FILE"
  return 0
}

release_lock() {
  rm -f "$LOCK_FILE"
}

# ---------- Local queue helpers ----------

get_music_files() {
  find "$MUSIC_DIR" -maxdepth 1 -type f \( \
    -iname "*.mp3" -o -iname "*.flac" -o -iname "*.wav" -o \
    -iname "*.ogg" -o -iname "*.m4a" -o -iname "*.aac" -o \
    -iname "*.opus" -o -iname "*.wma" \
  \) 2>/dev/null
}

build_queue() {
  get_music_files | shuf > "$QUEUE_FILE"
  if [ -s "$QUEUE_FILE" ]; then
    echo "1" > "$INDEX_FILE"
  else
    : > "$INDEX_FILE"
  fi
}

ensure_queue() {
  if [ ! -s "$QUEUE_FILE" ]; then
    build_queue
  fi
}

queue_total() {
  wc -l < "$QUEUE_FILE" 2>/dev/null || echo "0"
}

queue_index() {
  cat "$INDEX_FILE" 2>/dev/null || echo "1"
}

queue_track_at() {
  sed -n "${1}p" "$QUEUE_FILE" 2>/dev/null
}

music_count() {
  if [ -s "$QUEUE_FILE" ]; then
    queue_total
  else
    get_music_files | wc -l
  fi
}

# ---------- Player detection ----------

has_playerctl() {
  command -v playerctl >/dev/null 2>&1
}

list_players() {
  has_playerctl || return 0
  # Filter out our own mpv instance — it registers as MPRIS "mpv"
  playerctl -l 2>/dev/null | grep -v '^mpv' | sort -u
}

player_status() {
  has_playerctl || return 1
  playerctl --player="$1" status 2>/dev/null
}

pick_external_player() {
  has_playerctl || return 0

  local preferred player status
  preferred="$(cat "$PREFERRED_PLAYER_FILE" 2>/dev/null || true)"

  if [ -n "$preferred" ]; then
    status="$(player_status "$preferred" || true)"
    if [ "$status" = "Playing" ] || [ "$status" = "Paused" ]; then
      printf '%s' "$preferred"
      return
    fi
  fi

  while IFS= read -r player; do
    status="$(player_status "$player" || true)"
    if [ "$status" = "Playing" ]; then
      printf '%s' "$player"
      return
    fi
  done < <(list_players)

  while IFS= read -r player; do
    status="$(player_status "$player" || true)"
    if [ "$status" = "Paused" ]; then
      printf '%s' "$player"
      return
    fi
  done < <(list_players)
}

# ---------- Local mpv management (PID-based, subshell wrapper) ----------

is_local_running() {
  local pid
  pid="$(cat "$PID_FILE" 2>/dev/null || true)"
  [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
}

stop_local() {
  local pid
  pid="$(cat "$PID_FILE" 2>/dev/null || true)"
  if [ -n "$pid" ]; then
    # Kill children first (mpv running inside the subshell)
    pkill -P "$pid" 2>/dev/null || true
    # Then kill the subshell itself
    kill "$pid" 2>/dev/null || true
    # Brief wait
    local i=0
    while kill -0 "$pid" 2>/dev/null && [ "$i" -lt 10 ]; do
      sleep 0.05
      i=$((i + 1))
    done
    # Force kill if still alive
    kill -9 "$pid" 2>/dev/null || true
    pkill -9 -P "$pid" 2>/dev/null || true
  fi
  rm -f "$PID_FILE"
}

current_mode() {
  local mode
  mode="$(cat "$MODE_FILE" 2>/dev/null || echo "auto")"
  case "$mode" in
    auto|mpris|local) printf '%s' "$mode" ;;
    *) printf 'auto' ;;
  esac
}

set_mode() {
  local mode="$1"
  case "$mode" in
    auto|mpris|local)
      printf '%s' "$mode" > "$MODE_FILE"
      notify "Music Mode" "Switched to $mode" 1400
      ;;
    *)
      notify "Music Mode" "Invalid mode: $mode" 1400
      ;;
  esac
  trigger_update
}

cycle_mode() {
  case "$(current_mode)" in
    auto) set_mode "mpris" ;;
    mpris) set_mode "local" ;;
    *) set_mode "auto" ;;
  esac
}

active_target() {
  local mode player
  mode="$(current_mode)"

  case "$mode" in
    local)
      printf 'local'
      return
      ;;
    mpris)
      player="$(pick_external_player)"
      if [ -n "$player" ]; then
        printf 'mpris:%s' "$player"
      else
        printf 'none'
      fi
      return
      ;;
  esac

  if is_local_running; then
    printf 'local'
    return
  fi

  player="$(pick_external_player)"
  if [ -n "$player" ]; then
    printf 'mpris:%s' "$player"
  else
    printf 'none'
  fi
}

# ---------- Playback actions ----------

play_local_track() {
  local track="$1"
  [ -n "$track" ] || return 1
  [ -f "$track" ] || return 1

  if ! command -v mpv >/dev/null 2>&1; then
    notify "Music" "mpv is not installed" 2200
    return 1
  fi

  # Kill any existing local playback FIRST
  stop_local

  # Write the track we're about to play
  echo "$track" > "$CURRENT_TRACK_FILE"

  local script_path="$0"

  # Run mpv inside a SINGLE detached subshell.
  # mpv runs in foreground WITHIN the subshell, so:
  # - The subshell stays alive as long as mpv plays
  # - Killing the subshell's children (pkill -P) kills mpv
  # - disown detaches it from waybar's process group
  (
    mpv \
      --audio-display=no \
      --force-window=no \
      --no-video \
      --really-quiet \
      --title="waybar-music-player" \
      "$track" >/dev/null 2>&1

    mpv_exit=$?

    # Auto-advance only if:
    # 1. We are still the tracked subshell (not replaced by next/prev)
    # 2. mpv exited normally (code 0 = song finished, not killed)
    current_pid="$(cat "$PID_FILE" 2>/dev/null || true)"
    if [ "$current_pid" = "$BASHPID" ] && [ "$mpv_exit" -eq 0 ]; then
      sleep 0.3
      current_pid="$(cat "$PID_FILE" 2>/dev/null || true)"
      if [ "$current_pid" = "$BASHPID" ]; then
        "$script_path" _auto_next
      fi
    fi
  ) </dev/null >/dev/null 2>&1 &

  local subshell_pid=$!
  echo "$subshell_pid" > "$PID_FILE"
  disown "$subshell_pid" 2>/dev/null || true

  local title
  title="$(basename "$track")"
  title="${title%.*}"
  notify "Now Playing" "$(trim_label "$title")" 2200

  trigger_update
  return 0
}

# Internal command: auto-advance to next track (called only by the watcher)
do_auto_next() {
  if ! acquire_lock; then
    return 0  # Someone else is already doing something, skip
  fi

  ensure_queue
  local idx total track
  total="$(queue_total)"
  if [ "$total" -le 0 ]; then
    release_lock
    return 0
  fi

  idx="$(queue_index)"
  idx=$((idx + 1))
  if [ "$idx" -gt "$total" ]; then
    idx=1  # Loop back
  fi
  echo "$idx" > "$INDEX_FILE"

  track="$(queue_track_at "$idx")"
  release_lock

  if [ -n "$track" ] && [ -f "$track" ]; then
    play_local_track "$track"
  fi
}

play_local_random() {
  build_queue
  local total idx track
  total="$(queue_total)"
  if [ "$total" -eq 0 ]; then
    notify "Music" "No tracks found in $MUSIC_DIR" 2400
    return 1
  fi

  idx=$((RANDOM % total + 1))
  echo "$idx" > "$INDEX_FILE"
  track="$(queue_track_at "$idx")"
  play_local_track "$track"
}

local_next() {
  ensure_queue
  local idx total track
  total="$(queue_total)"
  [ "$total" -gt 0 ] || { notify "Music" "No local queue available" 2000; return 1; }

  idx="$(queue_index)"
  idx=$((idx + 1))
  [ "$idx" -le "$total" ] || idx=1
  echo "$idx" > "$INDEX_FILE"

  track="$(queue_track_at "$idx")"
  if [ ! -f "$track" ]; then
    play_local_random
    return
  fi
  play_local_track "$track"
}

local_prev() {
  ensure_queue
  local idx total track
  total="$(queue_total)"
  [ "$total" -gt 0 ] || { notify "Music" "No local queue available" 2000; return 1; }

  idx="$(queue_index)"
  idx=$((idx - 1))
  [ "$idx" -ge 1 ] || idx="$total"
  echo "$idx" > "$INDEX_FILE"

  track="$(queue_track_at "$idx")"
  if [ ! -f "$track" ]; then
    play_local_random
    return
  fi
  play_local_track "$track"
}

external_do() {
  local player="$1"
  shift
  has_playerctl || return 1
  playerctl --player="$player" "$@" >/dev/null 2>&1
}

toggle_play_pause() {
  local target player
  target="$(active_target)"

  case "$target" in
    local)
      if is_local_running; then
        stop_local
        notify "Music" "Local playback stopped" 1200
      else
        local track
        track="$(cat "$CURRENT_TRACK_FILE" 2>/dev/null || true)"
        if [ -n "$track" ] && [ -f "$track" ]; then
          play_local_track "$track"
        else
          play_local_random
        fi
      fi
      ;;
    mpris:*)
      player="${target#mpris:}"
      external_do "$player" play-pause || notify "Music" "Unable to toggle $player" 1400
      ;;
    *)
      play_local_random
      ;;
  esac

  trigger_update
}

play_next() {
  if ! acquire_lock; then
    return 0  # Already handling an action
  fi

  local target player
  target="$(active_target)"

  case "$target" in
    local) release_lock; local_next ;;
    mpris:*)
      player="${target#mpris:}"
      external_do "$player" next || notify "Music" "Unable to skip next" 1400
      release_lock
      ;;
    *) release_lock; local_next ;;
  esac

  trigger_update
}

play_prev() {
  if ! acquire_lock; then
    return 0
  fi

  local target player
  target="$(active_target)"

  case "$target" in
    local) release_lock; local_prev ;;
    mpris:*)
      player="${target#mpris:}"
      external_do "$player" previous || notify "Music" "Unable to go previous" 1400
      release_lock
      ;;
    *) release_lock; local_prev ;;
  esac

  trigger_update
}

replace_track() {
  local target player
  target="$(active_target)"

  case "$target" in
    mpris:*)
      player="${target#mpris:}"
      external_do "$player" next || true
      ;;
    *)
      play_local_random
      ;;
  esac

  trigger_update
}

seek_by() {
  local delta="$1"
  local target player sign abs
  target="$(active_target)"

  if [ "$delta" -ge 0 ]; then
    sign="+"
    abs="$delta"
  else
    sign="-"
    abs=$((delta * -1))
  fi

  case "$target" in
    mpris:*)
      player="${target#mpris:}"
      external_do "$player" position "${abs}${sign}" || notify "Music" "Seek unsupported for $player" 1400
      ;;
    *)
      notify "Music" "Seek is available for MPRIS players" 1400
      ;;
  esac

  trigger_update
}

volume_by() {
  local direction="$1"
  local target player arg
  target="$(active_target)"

  case "$direction" in
    up) arg="${VOLUME_STEP}+" ;;
    down) arg="${VOLUME_STEP}-" ;;
    *) return 1 ;;
  esac

  case "$target" in
    mpris:*)
      player="${target#mpris:}"
      external_do "$player" volume "$arg" || notify "Music" "Volume control unsupported for $player" 1400
      ;;
    *)
      # Fallback to system sink volume
      if command -v pactl >/dev/null 2>&1; then
        if [ "$direction" = "up" ]; then
          pactl set-sink-volume @DEFAULT_SINK@ +5% >/dev/null 2>&1 || true
        else
          pactl set-sink-volume @DEFAULT_SINK@ -5% >/dev/null 2>&1 || true
        fi
      fi
      ;;
  esac

  trigger_update
}

stop_all() {
  stop_local

  if has_playerctl; then
    while IFS= read -r player; do
      external_do "$player" stop || true
    done < <(list_players)
  fi

  notify "Music" "Playback stopped" 1200
  trigger_update
}

shuffle_queue() {
  build_queue
  notify "Music Queue" "Shuffled $(queue_total) tracks" 1600
  trigger_update
}

cycle_player() {
  if ! has_playerctl; then
    notify "Music" "playerctl not installed" 1800
    trigger_update
    return
  fi

  mapfile -t players < <(list_players)
  if [ "${#players[@]}" -eq 0 ]; then
    notify "Music" "No MPRIS players found" 1800
    trigger_update
    return
  fi

  local current next i
  current="$(cat "$PREFERRED_PLAYER_FILE" 2>/dev/null || true)"
  next="${players[0]}"

  for i in "${!players[@]}"; do
    if [ "${players[$i]}" = "$current" ]; then
      next="${players[$(((i + 1) % ${#players[@]}))]}"
      break
    fi
  done

  echo "$next" > "$PREFERRED_PLAYER_FILE"
  notify "Music Player" "Active player: $next" 1600
  trigger_update
}

# ---------- Waybar status ----------

mode_tag() {
  case "$(current_mode)" in
    auto) printf 'AUTO' ;;
    mpris) printf 'MPRIS' ;;
    local) printf 'LOCAL' ;;
  esac
}

status_payload() {
  local text="$1"
  local tooltip="$2"
  local class="$3"
  printf '{"text":"%s","tooltip":"%s","class":"%s"}\n' \
    "$(json_escape "$text")" \
    "$(json_escape "$tooltip")" \
    "$(json_escape "$class")"
}

local_track_label() {
  local track title
  track="$(cat "$CURRENT_TRACK_FILE" 2>/dev/null || true)"
  if [ -n "$track" ]; then
    title="$(basename "$track")"
    printf '%s' "${title%.*}"
  else
    printf 'Local music'
  fi
}

external_label() {
  local player="$1"
  local title
  title="$(playerctl --player="$player" metadata title 2>/dev/null || true)"

  if [ -n "$title" ]; then
    printf '%s' "$title"
  else
    printf '%s' "$player"
  fi
}

get_playpause_status() {

  local target mode total status alt class tooltip player label display
  target="$(active_target)"
  mode="$(mode_tag)"
  total="$(music_count)"

  case "$target" in
    local)
      alt="playing"
      class="playing"
      label="$(local_track_label)"
      tooltip="  Mode: $mode (Local)\n󰎆  Track: $label\n\n  Mouse Controls:\n  • Left Click: Play/Pause\n  • Right Click: Cycle Player\n  • Middle Click: Stop All\n  • Scroll: Volume Up/Down\n\n󰒮 / 󰒭 Controls:\n  • Left Click: Prev/Next\n  • Right Click: Seek -/+"
      ;;
    mpris:*)
      player="${target#mpris:}"
      status="$(player_status "$player" || true)"
      label="$(external_label "$player")"

      if [ "$status" = "Paused" ]; then
        alt="paused"
        class="paused"
      else
        alt="playing"
        class="playing"
      fi

      tooltip="  Mode: $mode (Online/App)\n󰎆  Playing: $label\n󰑈  Player: $player ($status)\n\n  Mouse Controls:\n  • Left Click: Play/Pause\n  • Right Click: Cycle Player\n  • Middle Click: Stop All\n  • Scroll: Volume Up/Down\n\n󰒮 / 󰒭 Controls:\n  • Left Click: Prev/Next\n  • Right Click: Seek -/+"
      ;;
    *)
      alt="stopped"
      class="stopped"
      label="No Music"
      tooltip="  Mode: $mode\n󰎆  Status: No Active Player\n󰝚  Local Tracks: $total\n\n  Mouse Controls:\n  • Left Click: Start Local Music\n  • Right Click: Cycle Player\n  • Middle Click: Stop All\n  • Scroll: Volume Up/Down"
      ;;
  esac

  # Hard truncate label for fixed-width display
  display="$(trim_label "$label")"

  printf '{"text":"%s","alt":"%s","tooltip":"%s","class":"%s"}\n' \
    "$(json_escape "$display")" "$alt" "$(json_escape "$tooltip")" "$class"
}

get_prev_status() {
  status_payload "󰒮" "Previous\n\nLeft: Previous\nRight: Seek -${SEEK_STEP}s\nMiddle: Cycle player" "control"
}

get_next_status() {
  status_payload "󰒭" "Next\n\nLeft: Next\nRight: Seek +${SEEK_STEP}s\nMiddle: Replace track" "control"
}

# ---------- Main ----------

case "${1:-status}" in
  toggle|play-pause)
    toggle_play_pause
    ;;
  play)
    play_local_random
    trigger_update
    ;;
  next)
    play_next
    ;;
  prev|previous)
    play_prev
    ;;
  stop)
    stop_all
    ;;
  shuffle|rebuild)
    shuffle_queue
    ;;
  replace|swap)
    replace_track
    ;;
  cycle-player)
    cycle_player
    ;;
  mode)
    if [ -n "${2:-}" ]; then
      set_mode "$2"
    else
      cycle_mode
    fi
    ;;
  seek-forward)
    seek_by "$SEEK_STEP"
    ;;
  seek-back)
    seek_by "$((SEEK_STEP * -1))"
    ;;
  vol-up|volume-up)
    volume_by up
    ;;
  vol-down|volume-down)
    volume_by down
    ;;
  _auto_next)
    # Internal: called by the background watcher when mpv finishes naturally
    do_auto_next
    ;;
  status)
    get_playpause_status
    ;;
  status-prev)
    get_prev_status
    ;;
  status-next)
    get_next_status
    ;;
  count)
    music_count
    ;;
  current)
    local_track_label
    ;;
  *)
    toggle_play_pause
    ;;
esac
