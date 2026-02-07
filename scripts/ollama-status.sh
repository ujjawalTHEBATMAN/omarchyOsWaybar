#!/bin/bash
# Check if Ollama is running and output JSON for waybar

if pgrep -x "ollama" > /dev/null; then
    # Check if any model is loaded
    models=$(curl -s http://localhost:11434/api/tags 2>/dev/null | jq -r '.models | length' 2>/dev/null)
    if [ "$models" != "" ] && [ "$models" != "0" ]; then
        echo '{"text": "󱜚", "tooltip": "Ollama: Running\nModels available: '$models'", "class": "running"}'
    else
        echo '{"text": "󱜚", "tooltip": "Ollama: Running (no models)", "class": "running"}'
    fi
else
    echo '{"text": "", "tooltip": "Ollama: Not running\nClick to start", "class": "stopped"}'
fi
