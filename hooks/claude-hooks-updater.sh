#!/bin/bash
# Claude Hooks Auto-Updater
# Location: ~/.local/bin/claude-hooks-updater.sh
# Purpose: Version-controlled updates with checksum verification and rollback

set -euo pipefail

HOOKS_DIR="$HOME/.local/bin/claude-hooks"
INSTALL_DIR="$HOME/.local/bin"
BACKUP_DIR="$HOOKS_DIR/backups"
VERSION_FILE="$HOOKS_DIR/VERSION"
MANIFEST_FILE="$HOOKS_DIR/.version-manifest"
UPDATE_LOG="$HOME/.context/hooks-update.log"

# Simulated update source (in production, this would be a git repo or download URL)
UPDATE_SOURCE="${UPDATE_SOURCE:-local}"  # local, git, or url

# Logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$UPDATE_LOG"
}

# Desktop notification
notify() {
    local urgency="$1"
    local title="$2"
    local message="$3"

    if command -v notify-send >/dev/null 2>&1; then
        notify-send -u "$urgency" -t 10000 -a "Claude Hooks Updater" "$title" "$message"
    fi
    log "$title: $message"
}

# Calculate SHA256 checksum
calculate_checksum() {
    local file="$1"
    sha256sum "$file" | awk '{print $1}'
}

# Get current installed version
get_current_version() {
    if [ -f "$VERSION_FILE" ]; then
        cat "$VERSION_FILE"
    else
        echo "0.0.0"
    fi
}

# Compare versions (returns 0 if v1 < v2, 1 otherwise)
version_lt() {
    local v1="$1"
    local v2="$2"

    # Simple version comparison (major.minor.patch)
    IFS='.' read -ra V1 <<< "$v1"
    IFS='.' read -ra V2 <<< "$v2"

    for i in 0 1 2; do
        local n1="${V1[$i]:-0}"
        local n2="${V2[$i]:-0}"

        if [ "$n1" -lt "$n2" ]; then
            return 0
        elif [ "$n1" -gt "$n2" ]; then
            return 1
        fi
    done

    return 1  # versions are equal
}

# Backup current hooks
backup_hooks() {
    local backup_name="backup-$(date +%Y%m%d-%H%M%S)"
    local backup_path="$BACKUP_DIR/$backup_name"

    mkdir -p "$backup_path"

    log "Creating backup: $backup_name"

    # Backup all hook scripts
    for hook in delegation-check.sh delegation-warning.sh context-monitor.sh output-monitor.sh \
                claude-state-validator.sh claude-performance-monitor.sh claude-search-cache-manager.sh \
                claude-context-monitor.sh claude-budget-analyzer.sh; do
        if [ -f "$INSTALL_DIR/$hook" ]; then
            cp "$INSTALL_DIR/$hook" "$backup_path/"
            log "Backed up: $hook"
        fi
    done

    # Backup manifest
    if [ -f "$MANIFEST_FILE" ]; then
        cp "$MANIFEST_FILE" "$backup_path/.version-manifest"
    fi

    # Keep only last 5 backups
    local backup_count=$(ls -1 "$BACKUP_DIR" | wc -l)
    if [ "$backup_count" -gt 5 ]; then
        log "Cleaning old backups (keeping last 5)"
        ls -1t "$BACKUP_DIR" | tail -n +6 | xargs -I {} rm -rf "$BACKUP_DIR/{}"
    fi

    echo "$backup_path"
}

# Verify hook integrity
verify_hook() {
    local hook="$1"
    local expected_checksum="$2"

    if [ ! -f "$INSTALL_DIR/$hook" ]; then
        log "ERROR: Hook not found: $hook"
        return 1
    fi

    local actual_checksum=$(calculate_checksum "$INSTALL_DIR/$hook")

    if [ "$actual_checksum" != "$expected_checksum" ]; then
        log "WARNING: Checksum mismatch for $hook"
        log "  Expected: $expected_checksum"
        log "  Actual:   $actual_checksum"
        return 1
    fi

    return 0
}

# Update manifest with current checksums
update_manifest() {
    if [ ! -f "$MANIFEST_FILE" ]; then
        log "ERROR: Manifest file not found"
        return 1
    fi

    local current_version=$(get_current_version)

    # Update checksums for all installed hooks
    for hook in delegation-check.sh delegation-warning.sh context-monitor.sh output-monitor.sh \
                claude-state-validator.sh claude-performance-monitor.sh claude-search-cache-manager.sh \
                claude-context-monitor.sh claude-budget-analyzer.sh; do
        if [ -f "$INSTALL_DIR/$hook" ]; then
            local checksum=$(calculate_checksum "$INSTALL_DIR/$hook")
            local size=$(stat -c%s "$INSTALL_DIR/$hook" 2>/dev/null || stat -f%z "$INSTALL_DIR/$hook" 2>/dev/null)
            local mtime=$(date -r "$INSTALL_DIR/$hook" -Iseconds 2>/dev/null || stat -f%Sm -t '%Y-%m-%dT%H:%M:%S%z' "$INSTALL_DIR/$hook" 2>/dev/null)

            jq --arg hook "$hook" \
               --arg version "$current_version" \
               --arg checksum "$checksum" \
               --arg size "$size" \
               --arg mtime "$mtime" \
               '.hooks[$hook].version = $version |
                .hooks[$hook].checksum = $checksum |
                .hooks[$hook].size = ($size | tonumber) |
                .hooks[$hook].last_modified = $mtime' \
                "$MANIFEST_FILE" > "$MANIFEST_FILE.tmp" && \
            mv "$MANIFEST_FILE.tmp" "$MANIFEST_FILE"
        fi
    done

    log "Manifest updated with current checksums"
}

# Rollback to previous backup
rollback() {
    local backup_path="$1"

    if [ ! -d "$backup_path" ]; then
        log "ERROR: Backup not found: $backup_path"
        return 1
    fi

    log "Rolling back to: $backup_path"

    # Restore all hooks
    for hook in "$backup_path"/*.sh; do
        if [ -f "$hook" ]; then
            local hook_name=$(basename "$hook")
            cp "$hook" "$INSTALL_DIR/"
            chmod +x "$INSTALL_DIR/$hook_name"
            log "Restored: $hook_name"
        fi
    done

    # Restore manifest
    if [ -f "$backup_path/.version-manifest" ]; then
        cp "$backup_path/.version-manifest" "$MANIFEST_FILE"
    fi

    notify "normal" "Hooks Rollback Complete" "Restored from backup: $(basename $backup_path)"
    log "Rollback complete"
}

# Check for updates (simulated)
check_for_updates() {
    local current_version=$(get_current_version)

    log "Checking for updates (current version: $current_version)"

    # In production, this would check a remote source
    # For now, simulate by checking if VERSION file has changed

    case "$UPDATE_SOURCE" in
        local)
            # No updates in local mode
            log "Local mode: No updates available"
            return 1
            ;;
        git)
            # Would check git repository
            log "Git mode: Not implemented yet"
            return 1
            ;;
        url)
            # Would check remote URL
            log "URL mode: Not implemented yet"
            return 1
            ;;
        *)
            log "Unknown update source: $UPDATE_SOURCE"
            return 1
            ;;
    esac
}

# Verify all installed hooks
verify_installation() {
    log "Verifying hook installation integrity..."

    if [ ! -f "$MANIFEST_FILE" ]; then
        log "ERROR: Manifest file not found"
        return 1
    fi

    local failed_hooks=()

    # Check each hook
    while IFS= read -r hook; do
        local expected_checksum=$(jq -r ".hooks[\"$hook\"].checksum" "$MANIFEST_FILE")

        if [ "$expected_checksum" = "null" ] || [ -z "$expected_checksum" ]; then
            log "WARNING: No checksum for $hook in manifest"
            continue
        fi

        if ! verify_hook "$hook" "$expected_checksum"; then
            failed_hooks+=("$hook")
        fi
    done <<< "$(jq -r '.hooks | keys[]' "$MANIFEST_FILE")"

    if [ ${#failed_hooks[@]} -eq 0 ]; then
        log "All hooks verified successfully"
        return 0
    else
        log "✗ Verification failed for: ${failed_hooks[*]}"
        return 1
    fi
}

# Display current status
show_status() {
    echo "═══════════════════════════════════════════════════════════"
    echo "  Claude Hooks Status"
    echo "═══════════════════════════════════════════════════════════"
    echo ""

    local current_version=$(get_current_version)
    echo "Current Version: $current_version"
    echo "Update Source: $UPDATE_SOURCE"
    echo ""

    if [ -f "$MANIFEST_FILE" ]; then
        echo "Installed Hooks:"
        jq -r '.hooks | to_entries[] | "  \(.key): v\(.value.version) (\(.value.size) bytes)"' "$MANIFEST_FILE"
    fi

    echo ""

    # Show recent backups
    if [ -d "$BACKUP_DIR" ]; then
        local backup_count=$(ls -1 "$BACKUP_DIR" 2>/dev/null | wc -l)
        echo "Backups Available: $backup_count"
        if [ "$backup_count" -gt 0 ]; then
            ls -1t "$BACKUP_DIR" | head -5 | while read -r backup; do
                echo "  $backup"
            done
        fi
    fi
}

# Initialize hook versioning (run once)
init_versioning() {
    mkdir -p "$HOOKS_DIR" "$BACKUP_DIR"

    if [ ! -f "$VERSION_FILE" ]; then
        echo "1.0.0" > "$VERSION_FILE"
        log "Initialized VERSION file"
    fi

    if [ ! -f "$MANIFEST_FILE" ]; then
        log "ERROR: Manifest file not found. Please create .version-manifest first."
        return 1
    fi

    # Update manifest with current checksums
    update_manifest

    log "Versioning initialized"
}

main() {
    case "${1:-}" in
        --init)
            init_versioning
            ;;
        --check)
            check_for_updates
            ;;
        --verify)
            verify_installation
            ;;
        --update)
            # Full update workflow
            if check_for_updates; then
                backup_path=$(backup_hooks)
                # Apply updates here
                # verify_installation || rollback "$backup_path"
                log "Update workflow placeholder"
            fi
            ;;
        --rollback)
            if [ -z "${2:-}" ]; then
                log "ERROR: Specify backup path"
                ls -1t "$BACKUP_DIR" | head -5
                exit 1
            fi
            rollback "$BACKUP_DIR/$2"
            ;;
        --status)
            show_status
            ;;
        *)
            # Default: verify and check for updates
            init_versioning
            verify_installation
            check_for_updates || log "No updates available"
            ;;
    esac
}

main "$@"
