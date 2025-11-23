#!/bin/bash
# Claude Budget Analyzer - Adaptive Budget Management
# Location: ~/.local/bin/claude-budget-analyzer.sh
# Purpose: Weekly budget optimization based on delegation rate and ROI

set -euo pipefail

SHARED_STATE="$HOME/.context/shared-budget.json"
ORCHESTRATOR_STATE="$HOME/.context/orchestrator-session.json"
ANALYSIS_LOG="$HOME/.context/budget-analysis.log"

# Logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$ANALYSIS_LOG"
}

# Desktop notification
notify() {
    local urgency="$1"
    local title="$2"
    local message="$3"

    if command -v notify-send >/dev/null 2>&1; then
        notify-send -u "$urgency" -t 15000 -a "Claude Budget Analyzer" "$title" "$message"
    fi
    log "$title: $message"
}

# Get delegation statistics from orchestrator
get_delegation_stats() {
    if [ ! -f "$ORCHESTRATOR_STATE" ]; then
        echo "0 0 0"
        return
    fi

    local total_calls=$(jq -r '.stats.total_calls // 0' "$ORCHESTRATOR_STATE" 2>/dev/null || echo "0")
    local delegations=$(jq -r '.stats.total_delegations // 0' "$ORCHESTRATOR_STATE" 2>/dev/null || echo "0")
    local policy_checks=$(jq -r '.stats.policy_checks // 0' "$ORCHESTRATOR_STATE" 2>/dev/null || echo "0")

    echo "$total_calls $delegations $policy_checks"
}

# Get token usage from claude-monitor
get_token_usage() {
    if command -v claude-monitor >/dev/null 2>&1; then
        # Get last 7 days usage
        local weekly_usage=$(claude-monitor --view daily 2>/dev/null | grep -oP 'Total:\s+\K[\d,]+' | tr -d ',' | head -1 || echo "0")
        echo "${weekly_usage:-0}"
    else
        # Fallback to reading ~/.claude.json
        if [ -f "$HOME/.claude.json" ]; then
            jq -r '
                [.usage[] | select(.timestamp > (now - 604800)) | .tokens_used] |
                add // 0
            ' "$HOME/.claude.json" 2>/dev/null || echo "0"
        else
            echo "0"
        fi
    fi
}

# Calculate delegation rate and ROI
calculate_metrics() {
    read total_calls delegations policy_checks <<< "$(get_delegation_stats)"
    local weekly_tokens=$(get_token_usage)

    local delegation_rate=0
    if [ "$policy_checks" -gt 0 ]; then
        delegation_rate=$(echo "scale=2; ($delegations / $policy_checks) * 100" | bc 2>/dev/null || echo "0")
    fi

    # ROI calculation: Tokens saved per delegation
    # Assume: Direct implementation = 5000 tokens, Delegation = 500 tokens
    # Savings per delegation = 4500 tokens
    local estimated_savings=$((delegations * 4500))
    local roi=0
    if [ "$weekly_tokens" -gt 0 ]; then
        roi=$(echo "scale=2; ($estimated_savings / $weekly_tokens) * 100" | bc 2>/dev/null || echo "0")
    fi

    echo "$delegation_rate $roi $weekly_tokens $delegations"
}

# Recommend budget adjustments
recommend_budget_adjustment() {
    read delegation_rate roi weekly_tokens delegations <<< "$(calculate_metrics)"

    local current_session_budget=$(jq -r '.session_budget_tokens // 10000' "$SHARED_STATE" 2>/dev/null || echo "10000")
    local current_daily_budget=$(jq -r '.daily_budget_tokens // 50000' "$SHARED_STATE" 2>/dev/null || echo "50000")

    local new_session_budget=$current_session_budget
    local new_daily_budget=$current_daily_budget
    local adjustment_reason=""

    log "=== Budget Analysis ==="
    log "Current Budgets: Session=$current_session_budget, Daily=$current_daily_budget"
    log "Metrics: Delegation Rate=${delegation_rate}%, ROI=${roi}%, Weekly Tokens=$weekly_tokens"
    log "Delegations: $delegations"

    # High delegation rate (>50%) - can reduce budgets
    if (( $(echo "$delegation_rate >= 50" | bc -l 2>/dev/null || echo 0) )); then
        new_session_budget=$((current_session_budget * 80 / 100))  # -20%
        new_daily_budget=$((current_daily_budget * 85 / 100))      # -15%
        adjustment_reason="High delegation rate (${delegation_rate}%) - reducing budgets by 15-20%"

        notify "normal" \
               "Budget Optimization: High Delegation" \
               "Delegation Rate: ${delegation_rate}%\nROI: ${roi}%\n\nNew Budgets:\nSession: ${new_session_budget} (was ${current_session_budget})\nDaily: ${new_daily_budget} (was ${current_daily_budget})"

    # Medium delegation rate (20-50%) - maintain budgets
    elif (( $(echo "$delegation_rate >= 20" | bc -l 2>/dev/null || echo 0) )); then
        adjustment_reason="Moderate delegation rate (${delegation_rate}%) - maintaining current budgets"
        log "$adjustment_reason"

    # Low delegation rate (<20%) - increase budgets slightly
    else
        new_session_budget=$((current_session_budget * 110 / 100))  # +10%
        new_daily_budget=$((current_daily_budget * 105 / 100))      # +5%
        adjustment_reason="Low delegation rate (${delegation_rate}%) - increasing budgets by 5-10%"

        notify "normal" \
               "Budget Adjustment: Low Delegation" \
               "Delegation Rate: ${delegation_rate}%\nROI: ${roi}%\n\nConsider:\n- More delegations to OpenCode\n- Search before generating\n\nNew Budgets:\nSession: ${new_session_budget}\nDaily: ${new_daily_budget}"
    fi

    # Apply adjustments if changed
    if [ "$new_session_budget" != "$current_session_budget" ] || [ "$new_daily_budget" != "$current_daily_budget" ]; then
        apply_budget_adjustment "$new_session_budget" "$new_daily_budget" "$adjustment_reason"
    fi

    # Log analysis
    echo "$(date +%s),$delegation_rate,$roi,$weekly_tokens,$delegations,$new_session_budget,$new_daily_budget" >> "$HOME/.context/budget-history.csv"
}

# Apply budget adjustments to shared state
apply_budget_adjustment() {
    local new_session="$1"
    local new_daily="$2"
    local reason="$3"

    if [ ! -f "$SHARED_STATE" ]; then
        log "ERROR: Shared state not found: $SHARED_STATE"
        return 1
    fi

    log "Applying budget adjustment: $reason"

    # Atomic update with flock
    (
        flock -x 200

        jq --arg session "$new_session" \
           --arg daily "$new_daily" \
           --arg reason "$reason" \
           --arg timestamp "$(date +%s)" \
           '.session_budget_tokens = ($session | tonumber) |
            .daily_budget_tokens = ($daily | tonumber) |
            .budget_adjustment_history += [{
                timestamp: ($timestamp | tonumber),
                session_budget: ($session | tonumber),
                daily_budget: ($daily | tonumber),
                reason: $reason
            }] |
            .budget_adjustment_history = (.budget_adjustment_history | .[-10:])' \
            "$SHARED_STATE" > "$SHARED_STATE.tmp" && \
        mv "$SHARED_STATE.tmp" "$SHARED_STATE"

    ) 200>"$SHARED_STATE.lock"

    log "Budget adjustment applied successfully"
}

# Generate detailed weekly report
generate_report() {
    if [ ! -f "$HOME/.context/budget-history.csv" ]; then
        log "No budget history available for report"
        return
    fi

    local week_ago=$(($(date +%s) - 604800))

    echo "═══════════════════════════════════════════════════════════"
    echo "  Weekly Budget Analysis Report"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""

    # Parse last 7 days from CSV
    echo "Recent Trends:"
    echo ""
    printf "%-20s %12s %8s %12s %12s %12s %12s\n" \
           "Date" "Deleg Rate" "ROI" "Tokens" "Delegations" "Session" "Daily"
    echo "────────────────────────────────────────────────────────────────────────────────────────────────"

    awk -F',' -v week="$week_ago" '
        $1 > week {
            time = strftime("%Y-%m-%d %H:%M", $1)
            printf "%-20s %11.1f%% %7.1f%% %12s %12s %12s %12s\n",
                   time, $2, $3, $4, $5, $6, $7
        }
    ' "$HOME/.context/budget-history.csv"

    echo ""

    # Summary statistics
    local avg_delegation=$(awk -F',' -v week="$week_ago" '$1 > week {sum+=$2; count++} END {print sum/count}' "$HOME/.context/budget-history.csv")
    local avg_roi=$(awk -F',' -v week="$week_ago" '$1 > week {sum+=$3; count++} END {print sum/count}' "$HOME/.context/budget-history.csv")
    local total_tokens=$(awk -F',' -v week="$week_ago" '$1 > week {sum+=$4} END {print sum}' "$HOME/.context/budget-history.csv")

    echo "Weekly Summary:"
    echo "  Average Delegation Rate: ${avg_delegation}%"
    echo "  Average ROI: ${avg_roi}%"
    echo "  Total Tokens Used: ${total_tokens}"
    echo ""

    # Current budgets
    local current_session=$(jq -r '.session_budget_tokens' "$SHARED_STATE" 2>/dev/null || echo "N/A")
    local current_daily=$(jq -r '.daily_budget_tokens' "$SHARED_STATE" 2>/dev/null || echo "N/A")

    echo "Current Budgets:"
    echo "  Session: ${current_session} tokens"
    echo "  Daily: ${current_daily} tokens"
    echo ""

    # Recommendations
    echo "Recommendations:"
    if (( $(echo "$avg_delegation < 20" | bc -l 2>/dev/null || echo 0) )); then
        echo "  ⚠️ Low delegation rate - consider using OpenCode more frequently"
        echo "  💡 Search existing patterns before generating code"
        echo "  🤖 Delegate boilerplate and test generation"
    elif (( $(echo "$avg_delegation >= 50" | bc -l 2>/dev/null || echo 0) )); then
        echo "  ✅ Excellent delegation rate - budgets optimized"
        echo "  💰 High ROI on token usage"
    else
        echo "  ℹ️ Moderate delegation rate - room for improvement"
        echo "  📊 Monitor context usage during sessions"
    fi
}

# Initialize budget history CSV
init_history() {
    if [ ! -f "$HOME/.context/budget-history.csv" ]; then
        echo "timestamp,delegation_rate,roi,weekly_tokens,delegations,session_budget,daily_budget" > "$HOME/.context/budget-history.csv"
        log "Initialized budget history CSV"
    fi
}

main() {
    init_history

    case "${1:-}" in
        --analyze)
            recommend_budget_adjustment
            ;;
        --report)
            generate_report
            ;;
        *)
            # Default: analyze and report
            recommend_budget_adjustment
            echo ""
            generate_report
            ;;
    esac
}

main "$@"
