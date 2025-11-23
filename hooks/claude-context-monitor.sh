#!/bin/bash
# Claude Context Monitor - Autonomous Context Tracking
# Location: ~/.local/bin/claude-context-monitor.sh
# Purpose: Real-time context usage monitoring with proactive notifications

set -euo pipefail

SHARED_STATE="$HOME/.context/shared-budget.json"
CONTEXT_LIMIT=200000
CRITICAL_THRESHOLD=90  # 90% = 180K tokens
WARNING_THRESHOLD=60   # 60% = 120K tokens
CHECK_INTERVAL=120     # 2 minutes

# Logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2
}

# Desktop notification
notify() {
    local urgency="$1"
    local title="$2"
    local message="$3"

    if command -v notify-send >/dev/null 2>&1; then
        notify-send -u "$urgency" -t 10000 -a "Claude Context Monitor" "$title" "$message"
    fi
    log "$title: $message"
}

# Get current context usage from claude-monitor
get_context_usage() {
    # Try claude-monitor if available
    if command -v claude-monitor >/dev/null 2>&1; then
        local usage=$(claude-monitor 2>/dev/null | grep -oP 'Context:\s+\K[\d,]+' | tr -d ',' || echo "0")
        echo "${usage:-0}"
    else
        # Fallback to shared state
        jq -r '.context_tracking.current_tokens // 0' "$SHARED_STATE" 2>/dev/null || echo "0"
    fi
}

# Update shared state with current context
update_context_state() {
    local current_tokens="$1"
    local usage_percent="$2"
    local compaction_needed="$3"

    if [ ! -f "$SHARED_STATE" ]; then
        log "ERROR: Shared state file not found: $SHARED_STATE"
        return 1
    fi

    # Atomic update with flock
    (
        flock -x 200

        jq --arg tokens "$current_tokens" \
           --arg percent "$usage_percent" \
           --arg compact "$compaction_needed" \
           --arg timestamp "$(date +%s)" \
           '.context_tracking.current_tokens = ($tokens | tonumber) |
            .context_tracking.usage_percent = ($percent | tonumber) |
            .context_tracking.compaction_recommended = ($compact == "true") |
            .context_tracking.last_check = ($timestamp | tonumber)' \
            "$SHARED_STATE" > "$SHARED_STATE.tmp" && \
        mv "$SHARED_STATE.tmp" "$SHARED_STATE"

    ) 200>"$SHARED_STATE.lock"
}

# Check context and notify if needed
check_context() {
    local current_tokens=$(get_context_usage)
    local usage_percent=$(echo "scale=2; ($current_tokens / $CONTEXT_LIMIT) * 100" | bc 2>/dev/null || echo "0")
    local compaction_needed="false"

    log "Context check: ${current_tokens}/${CONTEXT_LIMIT} tokens (${usage_percent}%)"

    # Critical threshold - immediate action required
    if (( $(echo "$usage_percent >= $CRITICAL_THRESHOLD" | bc -l 2>/dev/null || echo 0) )); then
        compaction_needed="true"
        notify "critical" \
               "Context Critical: ${usage_percent}%" \
               "Current: ${current_tokens}/${CONTEXT_LIMIT} tokens\n\nACTIONS:\n1. Delegate to OpenCode\n2. Summarize conversation\n3. Start new session"

        # Log critical event
        echo "$(date +%s),context_critical,${current_tokens},${usage_percent}" >> "$HOME/.context/context-alerts.log"

    # Warning threshold - proactive alert
    elif (( $(echo "$usage_percent >= $WARNING_THRESHOLD" | bc -l 2>/dev/null || echo 0) )); then
        compaction_needed="true"
        notify "normal" \
               "Context Warning: ${usage_percent}%" \
               "Current: ${current_tokens}/${CONTEXT_LIMIT} tokens\n\nCONSIDER:\n- Search before generating\n- Delegate boilerplate\n- Monitor large outputs"

        echo "$(date +%s),context_warning,${current_tokens},${usage_percent}" >> "$HOME/.context/context-alerts.log"
    fi

    # Update shared state
    update_context_state "$current_tokens" "$usage_percent" "$compaction_needed"
}

# Continuous monitoring mode
monitor_continuous() {
    log "Starting continuous context monitoring (check every ${CHECK_INTERVAL}s)"

    while true; do
        check_context
        sleep "$CHECK_INTERVAL"
    done
}

# One-time check mode
check_once() {
    check_context
}

# Display current status
show_status() {
    if [ ! -f "$SHARED_STATE" ]; then
        echo "Shared state not initialized"
        return 1
    fi

    local current_tokens=$(jq -r '.context_tracking.current_tokens // 0' "$SHARED_STATE")
    local usage_percent=$(jq -r '.context_tracking.usage_percent // 0' "$SHARED_STATE")
    local compaction=$(jq -r '.context_tracking.compaction_recommended // false' "$SHARED_STATE")
    local debt=$(jq -r '.context_tracking.context_debt // 0' "$SHARED_STATE")
    local last_check=$(jq -r '.context_tracking.last_check // 0' "$SHARED_STATE")

    echo "═══════════════════════════════════════════════════════════"
    echo "  Context Monitor Status"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "Current Usage: ${current_tokens} / ${CONTEXT_LIMIT} tokens (${usage_percent}%)"
    echo "Context Debt: ${debt} tokens"
    echo "Compaction Recommended: ${compaction}"

    if [ "$last_check" != "0" ]; then
        echo "Last Check: $(date -d @$last_check '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -r $last_check '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo 'Unknown')"
    fi

    echo ""

    # Show recent alerts
    if [ -f "$HOME/.context/context-alerts.log" ]; then
        echo "Recent Alerts (last 10):"
        tail -10 "$HOME/.context/context-alerts.log" | while IFS=',' read -r timestamp type tokens percent; do
            local time_str=$(date -d @$timestamp '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -r $timestamp '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "$timestamp")
            printf "  %s | %-17s | %6s tokens (%s%%)\n" "$time_str" "$type" "$tokens" "$percent"
        done
    else
        echo "No alerts recorded"
    fi
}

main() {
    case "${1:-}" in
        --continuous)
            monitor_continuous
            ;;
        --check)
            check_once
            ;;
        --status)
            show_status
            ;;
        *)
            # Default: one-time check
            check_once
            ;;
    esac
}

main "$@"
