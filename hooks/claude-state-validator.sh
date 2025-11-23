#!/bin/bash
# Self-Healing State File Validator
# Location: ~/.local/bin/claude-state-validator.sh
# Purpose: Automatic validation, backup, and repair of Claude Code state files

set -euo pipefail

STATE_DIR="$HOME/.context"
BACKUP_DIR="$STATE_DIR/backups"
RETENTION_DAYS=7

# State files to monitor
STATE_FILES=(
    "shared-budget.json"
    "orchestrator-session.json"
)

# Required schema for shared-budget.json
SHARED_BUDGET_SCHEMA='{
    "session_budget_tokens": 10000,
    "session_tokens_used": 0,
    "session_budget_exceeded": false,
    "daily_budget_tokens": 50000,
    "daily_tokens_used": 0,
    "daily_budget_date": "",
    "daily_budget_exceeded": false,
    "last_updated": 0,
    "last_claude_json_read": 0,
    "monitor_plan": null,
    "monitor_limit": null,
    "monitor_warnings": [],
    "delegations_today": 0,
    "tokens_saved_today": 0,
    "compliance_score": 100,
    "context_tracking": {
        "current_tokens": 0,
        "context_limit": 200000,
        "context_usage_percent": 0,
        "context_debt": 0,
        "last_compact": null,
        "compaction_recommended": false,
        "large_outputs_count": 0,
        "delegation_could_save": 0
    },
    "search_cache": {
        "cache_hits": 0,
        "cache_misses": 0,
        "cache_hit_rate": 0,
        "tokens_saved": 0,
        "last_cleanup": null
    },
    "integration_metrics": {
        "orchestrator_calls": 0,
        "claude_context_searches": 0,
        "monitor_syncs": 0,
        "workflow_efficiency": 1.0
    },
    "performance_metrics": {
        "avg_hook_time_ms": 0,
        "slow_hook_count": 0,
        "last_performance_report": null
    }
}'

# Logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2
}

validate_json() {
    local file="$1"

    if ! jq empty "$file" 2>/dev/null; then
        log "ERROR: Invalid JSON: $file"
        return 1
    fi

    log "JSON valid: $file"
    return 0
}

validate_schema() {
    local file="$1"
    local schema="$2"

    # Check required fields exist
    local required_fields=$(echo "$schema" | jq -r 'paths(scalars) as $p | if ($p | length) > 0 then $p | join(".") else empty end' | sort -u)

    local missing_fields=()
    while IFS= read -r field; do
        if ! echo "$field" | grep -q '\[\]' && ! jq -e ".${field}" "$file" >/dev/null 2>&1; then
            missing_fields+=("$field")
        fi
    done <<< "$required_fields"

    if [ ${#missing_fields[@]} -gt 0 ]; then
        log "ERROR: Missing fields in $file: ${missing_fields[*]}"
        return 1
    fi

    log "Schema valid: $file"
    return 0
}

backup_state_file() {
    local file="$1"
    local backup_name="$(basename "$file" .json)-$(date +%Y%m%d-%H%M%S).json"

    mkdir -p "$BACKUP_DIR"

    # Atomic copy with flock
    (
        flock -x 200
        if [ -f "$file" ]; then
            cp "$file" "$BACKUP_DIR/$backup_name"
            log "Backed up: $backup_name"
        fi
    ) 200>"$file.lock"

    # Cleanup old backups (keep last 7 days)
    find "$BACKUP_DIR" -name "$(basename "$file" .json)-*.json" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
}

restore_from_backup() {
    local file="$1"
    local latest_backup=$(find "$BACKUP_DIR" -name "$(basename "$file" .json)-*.json" -type f 2>/dev/null | sort -r | head -1)

    if [ -z "$latest_backup" ]; then
        log "ERROR: No backups found for $file"
        return 1
    fi

    log "Restoring from: $(basename "$latest_backup")"

    # Atomic restore with flock
    (
        flock -x 200
        cp "$latest_backup" "$file"
        log "Restored: $file"
    ) 200>"$file.lock"

    # Send notification
    notify-send -u normal -i dialog-warning \
        "Claude State File Restored" \
        "Corrupted file restored from backup:\n$(basename "$file")" 2>/dev/null || true

    return 0
}

repair_missing_fields() {
    local file="$1"
    local schema="$2"

    log "Repairing missing fields in $(basename "$file")..."

    # Merge with schema to fill missing fields (schema provides defaults, file overrides)
    local merged=$(jq -s '.[0] * .[1]' <(echo "$schema") "$file" 2>/dev/null)

    if [ $? -ne 0 ] || [ -z "$merged" ]; then
        log "ERROR: Failed to merge schema for $file"
        return 1
    fi

    # Atomic write with flock
    (
        flock -x 200
        echo "$merged" | jq '.' > "$file.tmp"
        if [ -s "$file.tmp" ]; then
            mv "$file.tmp" "$file"
            log "Repaired: $(basename "$file")"
        else
            rm -f "$file.tmp"
            return 1
        fi
    ) 200>"$file.lock"

    return 0
}

validate_all_state_files() {
    local errors=0
    local repaired=0
    local restored=0

    log "Starting state file validation..."

    for state_file in "${STATE_FILES[@]}"; do
        local full_path="$STATE_DIR/$state_file"

        if [ ! -f "$full_path" ]; then
            log "SKIP: Missing state file: $state_file (will be created on next use)"
            continue
        fi

        log "Validating: $state_file"

        # Backup before validation
        backup_state_file "$full_path"

        # Validate JSON syntax
        if ! validate_json "$full_path"; then
            log "Attempting restore from backup..."
            if restore_from_backup "$full_path"; then
                log "SUCCESS: Restored $state_file"
                ((restored++))

                # Re-validate after restoration
                if ! validate_json "$full_path"; then
                    log "ERROR: Restored file still invalid: $state_file"
                    ((errors++))
                    continue
                fi
            else
                log "ERROR: Restoration failed for $state_file"
                ((errors++))
                continue
            fi
        fi

        # Validate schema (only for shared-budget.json)
        if [ "$state_file" = "shared-budget.json" ]; then
            if ! validate_schema "$full_path" "$SHARED_BUDGET_SCHEMA"; then
                log "Schema validation failed, attempting repair..."
                if repair_missing_fields "$full_path" "$SHARED_BUDGET_SCHEMA"; then
                    log "SUCCESS: Repaired $state_file"
                    ((repaired++))
                else
                    log "ERROR: Repair failed for $state_file"
                    ((errors++))
                fi
            fi
        fi

        log "COMPLETE: $state_file"
    done

    # Summary
    log "Validation complete: $errors errors, $repaired repaired, $restored restored"

    if [ "$errors" -gt 0 ]; then
        notify-send -u critical -i dialog-error \
            "Claude State File Errors" \
            "$errors state file(s) could not be repaired.\nCheck logs: journalctl --user -u claude-state-validator" 2>/dev/null || true
    elif [ "$repaired" -gt 0 ] || [ "$restored" -gt 0 ]; then
        notify-send -u low -i emblem-default \
            "Claude State Files Maintained" \
            "Repaired: $repaired | Restored: $restored\nAll state files healthy" 2>/dev/null || true
    fi

    return "$errors"
}

main() {
    log "Claude State Validator v1.0"
    validate_all_state_files
    local exit_code=$?
    log "Validator finished with exit code: $exit_code"
    exit "$exit_code"
}

main
