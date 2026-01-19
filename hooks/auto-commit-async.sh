#!/bin/bash
# auto-commit-async.sh - Non-blocking PostToolUse hook for auto-commit (2026-01-18)
# Spawns background process immediately, never blocks Edit/Write operations

STATE_FILE="$HOME/.context/auto-commit-state.json"
LOCK_FILE="$STATE_FILE.lock"
LOG_FILE="$HOME/.context/auto-commit.log"
QUEUE_FILE="$HOME/.context/auto-commit-queue.json"

# Always return allow immediately - this is the key change
output_allow() {
    cat << 'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "permissionDecision": "allow"
  }
}
EOF
}

# Read and parse hook input
parse_input() {
    local input
    input=$(cat)
    
    # Debug log
    echo "[$(date -Iseconds)] INPUT: $input" >> "$LOG_FILE"
    
    local file_path
    file_path=$(echo "$input" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null || true)

    echo "$file_path"
}

# Queue file for async commit
queue_file() {
    local file_path="$1"
    local now
    now=$(date +%s)

    # Initialize queue if needed
    [[ -f "$QUEUE_FILE" ]] || echo '{"files":[],"last_flush":0}' > "$QUEUE_FILE"

    # Add to queue (deduplicated)
    local temp
    temp=$(mktemp)
    jq --arg file "$file_path" --argjson now "$now" \
       '.files = ([.files[] | select(.path != $file)] + [{"path": $file, "queued": $now}])' \
       "$QUEUE_FILE" > "$temp" && mv "$temp" "$QUEUE_FILE"
    
    echo "[$(date -Iseconds)] QUEUED: $file_path" >> "$LOG_FILE"
}

# Background commit worker (runs detached)
run_commit_worker() {
    local target_dir="$1"
    
    # Detach completely from parent process
    nohup bash -c "
        cd \"$target_dir\" || exit 0
        
        QUEUE_FILE=\"\$HOME/.context/auto-commit-queue.json\"
        STATE_FILE=\"\$HOME/.context/auto-commit-state.json\"
        LOG_FILE=\"\$HOME/.context/auto-commit.log\"
        LOCK_FILE=\"\$STATE_FILE.lock\"

        # Wait a moment for potential batch
        sleep 2

        # Acquire lock or exit
        exec 200>\"\$LOCK_FILE\"
        flock -n 200 || exit 0

        # Check if in git repo
        git rev-parse --git-dir &>/dev/null || exit 0

        # Read queue
        [[ -f \"\$QUEUE_FILE\" ]] || exit 0

        mapfile -t files < <(jq -r '.files[].path' \"\$QUEUE_FILE\" 2>/dev/null)

        [[ \${#files[@]} -eq 0 ]] && exit 0

        echo \"[\$(date -Iseconds)] WORKER: Processing \${#files[@]} files\" >> \"\$LOG_FILE\"

        # Clear queue atomically
        echo '{\"files\":[],\"last_flush\":'\$(date +%s)'}' > \"\$QUEUE_FILE\"

        # Stage all queued files
        staged=0
        for f in \"\${files[@]}\"; do
            if [[ -f \"\$f\" ]]; then
                git add \"\$f\" 2>/dev/null && ((staged++)) || true
            fi
        done

        [[ \$staged -eq 0 ]] && exit 0

        # Check for staged changes
        git diff --cached --quiet && exit 0

        # Secret scan (optional - skip if missing)
        if [[ -x \"\$HOME/.local/bin/auto-commit-secret-scan.sh\" ]]; then
            if ! \"\$HOME/.local/bin/auto-commit-secret-scan.sh\" staged 2>/dev/null; then
                echo \"[\$(date -Iseconds)] Secret detected - commit blocked\" >> \"\$LOG_FILE\"
                git restore --staged . 2>/dev/null || true
                exit 0
            fi
        fi

        # Get file list for commit message
        file_list=\$(git diff --cached --name-only | head -5 | tr '\\n' ', ' | sed 's/,\$//')
        file_count=\$(git diff --cached --name-only | wc -l)

        # Build commit message
        if [[ \$file_count -eq 1 ]]; then
            msg=\"auto: \$file_list\"
        else
            msg=\"auto: \$file_count files (\$file_list)\"
        fi

        # Commit
        commit_hash=\$(git commit -m \"\$msg

🤖 Auto-committed by Claude Code\" --quiet 2>/dev/null && git rev-parse --short HEAD) || exit 0

        echo \"[\$(date -Iseconds)] COMMITTED: \$file_count files (\$commit_hash): \$file_list\" >> \"\$LOG_FILE\"

    " &>/dev/null &

    disown 2>/dev/null || true
}

main() {
    # Parse input (reads from stdin)
    local file_path
    file_path=$(parse_input)

    # Output allow FIRST - never block
    output_allow

    # Then handle commit logic async
    if [[ -n "$file_path" ]] && [[ -f "$file_path" ]]; then
        # Get directory of file for git context
        local file_dir
        file_dir=$(dirname "$file_path")
        
        # Quick check: is this a git repo?
        (cd "$file_dir" && git rev-parse --git-dir &>/dev/null) || exit 0

        # Queue the file
        queue_file "$file_path"

        # Spawn background worker with correct directory
        run_commit_worker "$file_dir"
    fi
}

main
