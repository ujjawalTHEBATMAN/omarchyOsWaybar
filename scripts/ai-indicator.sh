#!/bin/bash

# Check if ollama is running
if ! systemctl is-active --quiet ollama && ! pgrep -x ollama > /dev/null; then
    echo '{"text": "", "class": "offline", "tooltip": "AI Daemon Offline"}'
    exit 0
fi

# Try to get active models
models_json=$(curl -s http://localhost:11434/api/ps 2>/dev/null)
models_count=$(echo "$models_json" | grep -o '"name":' | wc -l)

# Calculate CPU usage of ollama processes to detect active generation
# We check if CPU usage is greater than 10.0%
is_processing=$(ps aux | awk 'BEGIN {s=0} /[o]llama/ {s+=$3} END {if (s > 5.0) print 1; else print 0}')

class="idle"
tooltip="AI Daemon is Idle"

if [[ "$models_count" -gt 0 ]]; then
    # Extract names of loaded models if possible
    model_names=$(echo "$models_json" | grep -o '"name":"[^"]*"' | cut -d'"' -f4 | tr '\n' ',' | sed 's/,$//' | sed 's/:latest//g')
    tooltip="AI Models Loaded: $model_names"
    class="loaded"
fi

if [[ "$is_processing" == "1" ]]; then
    class="processing"
    tooltip="AI is Processing Prompt..."
fi

# Ensure UTF-8 brain icon (Nerd font brain or Emoji)
echo "{\"text\": \"🧠\", \"class\": \"$class\", \"tooltip\": \"$tooltip\"}"
