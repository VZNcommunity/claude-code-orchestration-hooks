#!/bin/bash
# Claude Context Search Cache Manager
# Location: ~/.local/bin/claude-search-cache-manager.sh
# Purpose: Intelligent caching for mcp__claude-context__search_code results

set -euo pipefail

CACHE_FILE="$HOME/.context/search-cache.json"
DEFAULT_TTL=3600  # 1 hour
MAX_CACHE_SIZE=100  # Max 100 cached queries

# Logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2
}

# Initialize cache
init_cache() {
    if [ ! -f "$CACHE_FILE" ]; then
        log "Initializing search cache"
        cat > "$CACHE_FILE" <<'EOF'
{
  "version": "1.0",
  "entries": [],
  "stats": {
    "total_hits": 0,
    "total_misses": 0,
    "cache_hit_rate": 0.0,
    "tokens_saved": 0,
    "last_cleanup": 0
  },
  "prewarm_queries": [
    "systemd timer configuration",
    "notification system implementation",
    "budget tracking logic",
    "hook performance optimization"
  ]
}
EOF
    fi
}

# Cleanup expired entries
cleanup_expired() {
    if [ ! -f "$CACHE_FILE" ]; then
        return
    fi

    local now=$(date +%s)
    local before_count=$(jq '.entries | length' "$CACHE_FILE" 2>/dev/null || echo "0")

    log "Cleaning expired cache entries (now: $now)"

    # Remove expired entries
    jq --arg now "$now" '
        .entries = [.entries[] | select(.expires > ($now | tonumber))] |
        .stats.last_cleanup = ($now | tonumber)
    ' "$CACHE_FILE" > "$CACHE_FILE.tmp" 2>/dev/null && mv "$CACHE_FILE.tmp" "$CACHE_FILE" || rm -f "$CACHE_FILE.tmp"

    local after_count=$(jq '.entries | length' "$CACHE_FILE" 2>/dev/null || echo "0")
    local removed=$((before_count - after_count))

    if [ "$removed" -gt 0 ]; then
        log "Removed $removed expired entries"
    fi
}

# Optimize cache (LRU eviction if full)
optimize_cache() {
    if [ ! -f "$CACHE_FILE" ]; then
        return
    fi

    local entry_count=$(jq '.entries | length' "$CACHE_FILE" 2>/dev/null || echo "0")

    if [ "$entry_count" -gt "$MAX_CACHE_SIZE" ]; then
        log "Cache full ($entry_count entries), optimizing with LRU eviction..."

        # Keep top MAX_CACHE_SIZE most-hit queries
        jq --arg max "$MAX_CACHE_SIZE" '
            .entries = (.entries | sort_by(.hit_count) | reverse | .[0:($max | tonumber)])
        ' "$CACHE_FILE" > "$CACHE_FILE.tmp" 2>/dev/null && mv "$CACHE_FILE.tmp" "$CACHE_FILE" || rm -f "$CACHE_FILE.tmp"

        log "Reduced cache to $MAX_CACHE_SIZE entries (kept most-used)"
    fi
}

# Calculate and update statistics
calculate_stats() {
    if [ ! -f "$CACHE_FILE" ]; then
        return
    fi

    jq '
        .stats.cache_hit_rate = (
            if (.stats.total_hits + .stats.total_misses) > 0 then
                .stats.total_hits / (.stats.total_hits + .stats.total_misses)
            else
                0
            end
        )
    ' "$CACHE_FILE" > "$CACHE_FILE.tmp" 2>/dev/null && mv "$CACHE_FILE.tmp" "$CACHE_FILE" || rm -f "$CACHE_FILE.tmp"

    # Update shared budget state
    local shared_state="$HOME/.context/shared-budget.json"
    if [ -f "$shared_state" ] && [ -f "$CACHE_FILE" ]; then
        local cache_stats=$(jq '{cache_hits: .stats.total_hits, cache_misses: .stats.total_misses, cache_hit_rate: .stats.cache_hit_rate, tokens_saved: .stats.tokens_saved}' "$CACHE_FILE" 2>/dev/null)

        if [ -n "$cache_stats" ]; then
            echo "$cache_stats" | jq -s --slurpfile state "$shared_state" '
                $state[0].search_cache = .[0] | $state[0]
            ' > "$shared_state.tmp" 2>/dev/null && mv "$shared_state.tmp" "$shared_state" || rm -f "$shared_state.tmp"
        fi
    fi
}

# Pre-warm cache with common queries (run during low-activity periods)
prewarm_cache() {
    if [ ! -f "$CACHE_FILE" ]; then
        return
    fi

    local prewarm_queries=$(jq -r '.prewarm_queries[]?' "$CACHE_FILE" 2>/dev/null)

    if [ -z "$prewarm_queries" ]; then
        log "No prewarm queries configured"
        return
    fi

    # Only prewarm during low-activity hours (2-5 AM)
    local hour=$(date +%H)
    if [ "$hour" -lt 2 ] || [ "$hour" -gt 5 ]; then
        return
    fi

    log "Pre-warming cache with common queries..."

    while IFS= read -r query; do
        if [ -z "$query" ]; then
            continue
        fi

        # Check if already cached and not expired
        local now=$(date +%s)
        local cached=$(jq --arg q "$query" --arg now "$now" '
            .entries[] | select(.query == $q and .expires > ($now | tonumber)) | .query
        ' "$CACHE_FILE" 2>/dev/null)

        if [ -z "$cached" ]; then
            log "Would pre-warm: $query (MCP integration needed)"
            # Note: Actual MCP call would go here in production
            # For now, just log the intent
        fi
    done <<< "$prewarm_queries"
}

# Display cache statistics
show_stats() {
    if [ ! -f "$CACHE_FILE" ]; then
        echo "Cache not initialized"
        return
    fi

    echo "═══════════════════════════════════════════════════════════"
    echo "  Search Cache Statistics"
    echo "═══════════════════════════════════════════════════════════"
    echo ""

    local entries=$(jq '.entries | length' "$CACHE_FILE" 2>/dev/null || echo "0")
    local hits=$(jq '.stats.total_hits' "$CACHE_FILE" 2>/dev/null || echo "0")
    local misses=$(jq '.stats.total_misses' "$CACHE_FILE" 2>/dev/null || echo "0")
    local hit_rate=$(jq '.stats.cache_hit_rate' "$CACHE_FILE" 2>/dev/null || echo "0")
    local tokens_saved=$(jq '.stats.tokens_saved' "$CACHE_FILE" 2>/dev/null || echo "0")
    local last_cleanup=$(jq '.stats.last_cleanup' "$CACHE_FILE" 2>/dev/null || echo "0")

    echo "Entries: $entries / $MAX_CACHE_SIZE"
    echo "Hits: $hits"
    echo "Misses: $misses"
    echo "Hit Rate: $(echo "$hit_rate * 100" | bc 2>/dev/null || echo "0")%"
    echo "Tokens Saved: $tokens_saved"

    if [ "$last_cleanup" != "0" ]; then
        echo "Last Cleanup: $(date -d @$last_cleanup '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -r $last_cleanup '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "Unknown")"
    fi

    echo ""
    echo "Top 5 Most-Hit Queries:"
    jq -r '.entries | sort_by(.hit_count) | reverse | .[0:5] | .[] | "  \(.hit_count) hits: \(.query)"' "$CACHE_FILE" 2>/dev/null || echo "  No data"
}

main() {
    case "${1:-}" in
        --init)
            init_cache
            log "Cache initialized: $CACHE_FILE"
            ;;
        --cleanup)
            init_cache
            cleanup_expired
            optimize_cache
            calculate_stats
            log "Cache cleanup complete"
            ;;
        --prewarm)
            init_cache
            prewarm_cache
            ;;
        --stats)
            show_stats
            ;;
        *)
            # Default: cleanup and optimize
            init_cache
            cleanup_expired
            optimize_cache
            calculate_stats
            ;;
    esac
}

main "$@"
