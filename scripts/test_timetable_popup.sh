#!/bin/bash

# Test Script: Trigger the Completion Prompt Manually
# Run this to test the Zenity popup behavior.

TASK_NAME="TEST: Java Multithreading Mastery"
LOG_FILE="$HOME/task_log.txt"
TIMEOUT=180

echo "🚀 Triggering test popup for: $TASK_NAME"
echo "🕒 Timeout set to: $TIMEOUT seconds (3 minutes)"

# Trigger zenity question
if zenity --question \
          --title="TEST Mission Completion Check" \
          --text="Did you complete the task: **$TASK_NAME**?" \
          --ok-label="_Yes (y)" \
          --cancel-label="_No (n)" \
          --timeout="$TIMEOUT"; then
    echo "✅ Success: You clicked 'Yes' or pressed 'Alt+Y'"
    echo "$(date '+%Y-%m-%d %H:%M') - TEST_COMPLETED - $TASK_NAME" >> "$LOG_FILE"
else
    echo "❌ Fail/Timeout: You clicked 'No', pressed 'Alt+N', or 3 minutes passed."
    echo "$(date '+%Y-%m-%d %H:%M') - TEST_INCOMPLETE/IGNORED - $TASK_NAME" >> "$LOG_FILE"
fi

echo "📝 Log updated in: $LOG_FILE"
