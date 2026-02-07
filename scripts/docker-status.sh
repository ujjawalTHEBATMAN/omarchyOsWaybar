#!/bin/bash
# Docker status script for waybar

if ! command -v docker &> /dev/null; then
    echo '{"text": "", "tooltip": "Docker not installed", "class": "unavailable"}'
    exit 0
fi

# Check if docker daemon is running
if ! docker info &> /dev/null; then
    echo '{"text": "󰡨", "tooltip": "Docker: Daemon not running", "class": "stopped"}'
    exit 0
fi

# Count running containers
running=$(docker ps -q 2>/dev/null | wc -l)
total=$(docker ps -aq 2>/dev/null | wc -l)

if [ "$running" -gt 0 ]; then
    # Get container names for tooltip
    containers=$(docker ps --format "{{.Names}}" 2>/dev/null | head -5 | tr '\n' ', ' | sed 's/,$//')
    echo '{"text": "󰡨 '$running'", "tooltip": "Docker: '$running'/'$total' containers\nRunning: '$containers'", "class": "running"}'
else
    echo '{"text": "󰡨", "tooltip": "Docker: No running containers\nTotal: '$total'", "class": "idle"}'
fi
