#!/bin/bash

# Check if ollama is running
if ! systemctl is-active --quiet ollama && ! pgrep -x ollama > /dev/null; then
    notify-send "Omarchy AI" "Ollama is not running!" -u critical
    exit 1
fi

# Get text input from user using Zenity
USER_TEXT=$(zenity --text-info --title="Omarchy AI Optimization" --editable --width=800 --height=600 2>/dev/null)

# If user cancelled or passed empty text, exit quietly
if [ $? -ne 0 ] || [ -z "$USER_TEXT" ]; then
    exit 0
fi

# Send notification that processing has started
notify-send "Omarchy AI" "Analyzing text and generating response..." -u normal -i dialog-information

# Determine which model to use
# Try to get the first active/loaded model
MODEL=$(curl -s http://localhost:11434/api/ps 2>/dev/null | grep -o '"name":"[^"]*"' | head -n 1 | cut -d'"' -f4)

# If no model is active, default to a robust choice we know exists in the user's system
if [ -z "$MODEL" ]; then
    MODEL="llama3.2:latest"
fi

# Construct the massive super prompt
PROMPT="[Header: Omarchy OS Technical Alignment & Optimization Engine]
System Role & Context:
Act as an elite Linux Systems Engineer specializing in Arch Linux and the custom Omarchy OS environment. Your objective is to analyze the \"Target Text\" provided by the user and compare it against the architectural philosophy of Omarchy OS.

Omarchy OS Core Specifications:
Base: Arch Linux (Rolling Release).
Package Management: Prioritize yay (AUR) over standard pacman.
Environment: Wayland-based, specifically utilizing Hyprland and Waybar.
Tooling Preferences: Zellij (multiplexer), Zoxide (navigation), Eza (ls replacement), Neovim (IDE), and Ollama (Local AI).
Philosophy: Minimalist, high-performance, CLI-centric, and automated.

[The Analysis Task]
Analyze the provided text through three deep-level lenses:
Compatibility Audit: Does the text suggest tools or commands that conflict with Omarchy OS? (e.g., suggesting apt instead of yay, or X11 tools instead of Wayland native ones).
Efficiency Gap: How can the provided text be optimized using the Omarchy toolset? (e.g., replacing a standard bash loop with a specialized CLI tool like jq or tokei if applicable).
Integration Deep-Dive: How should this information be integrated into the Omarchy OS guide? Provide the output in a structured format:
Direct Translation: (Target Command -> Omarchy Command).
Optimization Note: (How to make it faster/better).
Workflow Impact: (How it fits into the Zellij/Neovim workflow).

[Example Execution (Internal Reference)]
Target Text: \"To manage your files and search for text, use the standard file manager and grep.\"
Deep Analysis Response:
Omarchy Translation: Instead of a GUI file manager, utilize eza for visualization and zoxide for rapid navigation. Replace standard grep with ripgrep (rg) for superior speed within the terminal.
Integration: Map these to Neovim keybindings or shell aliases within the Omarchy configuration files to maintain the \"headless-first\" philosophy.

Target Text:
$USER_TEXT
"

# Generate response from the locally running Ollama model
RESPONSE=$(ollama run "$MODEL" "$PROMPT")

# Copy the response directly to the clipboard
echo "$RESPONSE" | wl-copy

# Notify user that it's complete
notify-send "Omarchy AI" "AI Analysis Complete!\n\nResponse has been fully copied to your clipboard. Ready to paste!" -u normal -i dialog-information
