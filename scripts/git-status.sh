#!/bin/bash
# Git repository status for waybar
# Shows branch, changes, and sync status

# Check if we're in a git repo
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo '{"text": "", "tooltip": "Not in a git repository", "class": "no-repo"}'
    exit 0
fi

# Get branch name
branch=$(git symbolic-ref --short HEAD 2>/dev/null || git describe --tags --always 2>/dev/null)

# Get status counts
staged=$(git diff --cached --numstat 2>/dev/null | wc -l)
modified=$(git diff --numstat 2>/dev/null | wc -l)
untracked=$(git ls-files --others --exclude-standard 2>/dev/null | wc -l)

# Check ahead/behind
ahead=$(git rev-list --count @{upstream}..HEAD 2>/dev/null || echo 0)
behind=$(git rev-list --count HEAD..@{upstream} 2>/dev/null || echo 0)

# Build status string
status=""
class="clean"

if [ "$staged" -gt 0 ]; then
    status+=" +$staged"
    class="staged"
fi
if [ "$modified" -gt 0 ]; then
    status+=" ~$modified"
    class="modified"
fi
if [ "$untracked" -gt 0 ]; then
    status+=" ?$untracked"
    class="untracked"
fi

# Sync status
sync=""
if [ "$ahead" -gt 0 ]; then
    sync+=" ⇡$ahead"
fi
if [ "$behind" -gt 0 ]; then
    sync+=" ⇣$behind"
fi

# Determine icon
if [ "$class" = "clean" ]; then
    icon=""
else
    icon=""
fi

# Build tooltip
tooltip="Branch: $branch"
[ "$staged" -gt 0 ] && tooltip+="\nStaged: $staged files"
[ "$modified" -gt 0 ] && tooltip+="\nModified: $modified files"
[ "$untracked" -gt 0 ] && tooltip+="\nUntracked: $untracked files"
[ -n "$sync" ] && tooltip+="\nSync:$sync"

# Output
text="$icon $branch$status$sync"
echo "{\"text\": \"$text\", \"tooltip\": \"$tooltip\", \"class\": \"$class\"}"
