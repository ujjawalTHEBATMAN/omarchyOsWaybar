#!/usr/bin/env bash
# Waybar Music Controller
# Features:
# - Unified controls for MPRIS players + local mpv fallback
# - Shuffle queue from ~/Music
# - Player cycling, mode switching, seek and volume actions
# - Rich JSON status for Waybar custom modules

set -u

MUSIC_DIR="${MUSIC_DIR:-$HOME/Music}"
STATE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/waybar-music"
QUEUE_FILE="$STATE_DIR/queue"
INDEX_FILE="$STATE_DIR/index"
CURRENT_TRACK_FILE="$STATE_DIR/current_track"
MODE_FILE="$STATE_DIR/mode"
PREFERRED_PLAYER_FILE="$STATE_DIR/preferred_player"
SIGNAL=8
MAX_LABEL_LEN=22
SEEK_STEP="${WAYBAR_MUSIC_SEEK_STEP:-10}"
VOLUME_STEP="${WAYBAR_MUSIC_VOLUME_STEP:-0.05}"
LOCAL_MPV_PATTERN='mpv.*waybar-music-player'

mkdir -p "$STATE_DIR"

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

# ---------- Local queue helpers ----------

get_music_files() {
  find "$MUSIC_DIR" -type f \( \
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
  playerctl -l 2>/dev/null | sort -u
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

is_local_running() {
  pgrep -f "$LOCAL_MPV_PATTERN" >/dev/null 2>&1
}

stop_local() {
  pkill -f "$LOCAL_MPV_PATTERN" 2>/dev/null || true
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

  stop_local
  echo "$track" > "$CURRENT_TRACK_FILE"

  nohup mpv \
    --audio-display=no \
    --force-window=no \
    --no-video \
    --really-quiet \
    --title="waybar-music-player" \
    "$track" >/dev/null 2>&1 &

  local title
  title="$(basename "$track")"
  title="${title%.*}"
  notify "Now Playing" "$(trim_label "$title")" 2200
  return 0
}

play_local_random() {
  ensure_queue
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
  local target player
  target="$(active_target)"

  case "$target" in
    local) local_next ;;
    mpris:*)
      player="${target#mpris:}"
      external_do "$player" next || notify "Music" "Unable to skip next" 1400
      ;;
    *) local_next ;;
  esac

  trigger_update
}

play_prev() {
  local target player
  target="$(active_target)"

  case "$target" in
    local) local_prev ;;
    mpris:*)
      player="${target#mpris:}"
      external_do "$player" previous || notify "Music" "Unable to go previous" 1400
      ;;
    *) local_prev ;;
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
      # Fallback to system sink volume when no MPRIS target is active.
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
  local artist title
  artist="$(playerctl --player="$player" metadata artist 2>/dev/null || true)"
  title="$(playerctl --player="$player" metadata title 2>/dev/null || true)"

  if [ -n "$artist" ] && [ -n "$title" ]; then
    printf '%s - %s' "$artist" "$title"
  elif [ -n "$title" ]; then
    printf '%s' "$title"
  else
    printf '%s' "$player"
  fi
}

get_playpause_status() {
  local target mode total status icon class tooltip player label
  target="$(active_target)"
  mode="$(mode_tag)"
  total="$(music_count)"

  case "$target" in
    local)
      icon="󰎈"
      class="playing local"
      label="$(local_track_label)"
      tooltip="Mode: $mode\nLocal playback\nTrack: $label\n\nLeft: Play/Pause\nRight: Shuffle queue\nMiddle: Stop\nScroll: Volume" 
      ;;
    mpris:*)
      player="${target#mpris:}"
      status="$(player_status "$player" || true)"
      label="$(external_label "$player")"

      if [ "$status" = "Paused" ]; then
        icon="󰐊"
        class="paused mpris"
      else
        icon="󰎈"
        class="playing mpris"
      fi

      tooltip="Mode: $mode\nPlayer: $player ($status)\nNow: $label\n\nLeft: Play/Pause\nRight: Shuffle local queue\nMiddle: Stop\nScroll: Volume"
      ;;
    *)
      icon="󰐊"
      class="stopped"
      label=""
      tooltip="Mode: $mode\nNo active player\nLocal tracks: $total\n\nLeft: Start music\nRight: Shuffle queue\nMiddle: Stop"
      ;;
  esac

  # Output only icon - visualizer (cava) shows the animation
  printf '{"text":"%s","tooltip":"%s","class":"%s"}\n' \
    "$icon" "$tooltip" "$class"
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
