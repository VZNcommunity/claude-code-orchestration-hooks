#!/bin/bash
# Claude Code Hooks Performance Monitor
# Location: ~/.local/bin/claude-performance-monitor.sh
# Purpose: Track hook execution times, identify slow hooks, generate weekly reports

set -euo pipefail

PERF_LOG="$HOME/.context/performance.log"
REPORT_DIR="$HOME/.context/reports"
SLOW_THRESHOLD_MS=500
MAX_LOG_SIZE=$((10 * 1024 * 1024))  # 10MB

# Logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2
}

# Log hook performance (called by hooks)
log_performance() {
    local hook_name="$1"
    local duration_ms="$2"
    local success="${3:-true}"

    # Ensure log exists
    touch "$PERF_LOG"

    # Log format: timestamp,hook_name,duration_ms,success
    echo "$(date +%s),$hook_name,$duration_ms,$success" >> "$PERF_LOG"

    # Alert on slow hooks
    if [ "$duration_ms" -gt "$SLOW_THRESHOLD_MS" ]; then
        log "SLOW_HOOK: $hook_name took ${duration_ms}ms"

        # Update slow hook count in shared state
        local shared_state="$HOME/.context/shared-budget.json"
        if [ -f "$shared_state" ]; then
            jq '.performance_metrics.slow_hook_count += 1' "$shared_state" > "$shared_state.tmp" 2>/dev/null && \
                mv "$shared_state.tmp" "$shared_state" || rm -f "$shared_state.tmp"
        fi
    fi
}

# Generate weekly performance report
generate_report() {
    local report_file="$REPORT_DIR/performance-$(date +%Y%m%d-%H%M%S).txt"
    mkdir -p "$REPORT_DIR"

    log "Generating performance report: $(basename "$report_file")"

    if [ ! -f "$PERF_LOG" ] || [ ! -s "$PERF_LOG" ]; then
        log "No performance data available"
        return 1
    fi

    # Calculate statistics from last 7 days
    local week_ago=$(date -d '7 days ago' +%s 2>/dev/null || date -v-7d +%s 2>/dev/null || echo "0")

    cat > "$report_file" <<EOF
═══════════════════════════════════════════════════════════
  Claude Code Hooks Performance Report
═══════════════════════════════════════════════════════════

Generated: $(date '+%Y-%m-%d %H:%M:%S')
Period: Last 7 days
Log file: $PERF_LOG

───────────────────────────────────────────────────────────
SUMMARY
───────────────────────────────────────────────────────────
EOF

    # Total hook executions
    local total_executions=$(awk -F',' -v week="$week_ago" '$1 > week' "$PERF_LOG" 2>/dev/null | wc -l)
    echo "Total hook executions: $total_executions" >> "$report_file"

    if [ "$total_executions" -eq 0 ]; then
        echo "No hook executions in the last 7 days." >> "$report_file"
        log "Report generated (no data): $report_file"
        return 0
    fi

    # Average execution time per hook
    echo "" >> "$report_file"
    echo "───────────────────────────────────────────────────────────" >> "$report_file"
    echo "AVERAGE EXECUTION TIME BY HOOK" >> "$report_file"
    echo "───────────────────────────────────────────────────────────" >> "$report_file"

    awk -F',' -v week="$week_ago" '$1 > week {sum[$2]+=$3; count[$2]++}
        END {for (hook in sum) printf "%-40s %8.2f ms (%d calls)\n", hook, sum[hook]/count[hook], count[hook]}' \
        "$PERF_LOG" 2>/dev/null | sort -t' ' -k2 -n -r >> "$report_file"

    # Overall average
    local overall_avg=$(awk -F',' -v week="$week_ago" '$1 > week {sum+=$3; count++}
        END {if (count>0) printf "%.2f", sum/count; else print "0"}' "$PERF_LOG" 2>/dev/null)
    echo "" >> "$report_file"
    echo "Overall average: ${overall_avg} ms" >> "$report_file"

    # Slowest hook executions
    echo "" >> "$report_file"
    echo "───────────────────────────────────────────────────────────" >> "$report_file"
    echo "TOP 10 SLOWEST EXECUTIONS" >> "$report_file"
    echo "───────────────────────────────────────────────────────────" >> "$report_file"

    awk -F',' -v week="$week_ago" '$1 > week {print $0}' "$PERF_LOG" 2>/dev/null | \
        sort -t, -k3 -n -r | head -10 | \
        awk -F',' '{printf "%-40s %8d ms  %s\n", $2, $3, strftime("%Y-%m-%d %H:%M:%S", $1)}' \
        >> "$report_file"

    # Success rate
    echo "" >> "$report_file"
    echo "───────────────────────────────────────────────────────────" >> "$report_file"
    echo "SUCCESS RATE" >> "$report_file"
    echo "───────────────────────────────────────────────────────────" >> "$report_file"

    awk -F',' -v week="$week_ago" '$1 > week {total++; if($4=="true") success++}
        END {if (total>0) printf "Success: %d/%d (%.1f%%)\nFailed: %d (%.1f%%)\n", success, total, (success/total)*100, (total-success), ((total-success)/total)*100}' \
        "$PERF_LOG" 2>/dev/null >> "$report_file"

    # Hooks exceeding threshold
    echo "" >> "$report_file"
    echo "───────────────────────────────────────────────────────────" >> "$report_file"
    echo "OPTIMIZATION SUGGESTIONS" >> "$report_file"
    echo "───────────────────────────────────────────────────────────" >> "$report_file"

    local slow_hooks=$(awk -F',' -v week="$week_ago" -v threshold="$SLOW_THRESHOLD_MS" \
        '$1 > week && $3 > threshold {print $2}' "$PERF_LOG" 2>/dev/null | \
        sort | uniq -c | sort -n -r | head -5)

    if [ -n "$slow_hooks" ]; then
        echo "$slow_hooks" | awk '{printf "• %s exceeded threshold %d times\n", $2, $1}' >> "$report_file"
        echo "" >> "$report_file"
        echo "Consider optimizing these hooks or increasing threshold." >> "$report_file"
    else
        echo "All hooks performing within threshold (${SLOW_THRESHOLD_MS}ms)" >> "$report_file"
    fi

    # Update shared state
    local shared_state="$HOME/.context/shared-budget.json"
    if [ -f "$shared_state" ]; then
        jq --arg avg "$overall_avg" --arg report "$report_file" \
            '.performance_metrics.avg_hook_time_ms = ($avg | tonumber) |
             .performance_metrics.last_performance_report = $report' \
            "$shared_state" > "$shared_state.tmp" 2>/dev/null && \
            mv "$shared_state.tmp" "$shared_state" || rm -f "$shared_state.tmp"
    fi

    log "Report generated: $report_file"

    # Notify user
    notify-send -u low -i emblem-documents \
        "Weekly Hooks Performance Report" \
        "Report generated: $(basename "$report_file")\nAverage execution: ${overall_avg}ms\n\nView: $report_file" 2>/dev/null || true

    # Rotate old reports (keep last 4 weeks)
    find "$REPORT_DIR" -name "performance-*.txt" -mtime +28 -delete 2>/dev/null || true
}

# Rotate log if too large
rotate_log() {
    if [ -f "$PERF_LOG" ] && [ $(stat -c%s "$PERF_LOG" 2>/dev/null || stat -f%z "$PERF_LOG" 2>/dev/null || echo 0) -gt "$MAX_LOG_SIZE" ]; then
        log "Rotating performance log (size limit exceeded)"
        mv "$PERF_LOG" "$PERF_LOG.old"
        touch "$PERF_LOG"
    fi
}

main() {
    case "${1:-}" in
        --log)
            if [ $# -lt 3 ]; then
                echo "Usage: $0 --log <hook_name> <duration_ms> [success]" >&2
                exit 1
            fi
            log_performance "$2" "$3" "${4:-true}"
            ;;
        --report)
            rotate_log
            generate_report
            ;;
        *)
            echo "Usage: $0 {--log <hook_name> <duration_ms> [success]|--report}" >&2
            exit 1
            ;;
    esac
}

main "$@"
