#!/usr/bin/env bash
# Claude Code Orchestration Hooks - Uninstallation Script
# Version: 1.1.0
# License: MIT

set -e

echo "===================================="
echo "Claude Code Orchestration Hooks"
echo "Uninstallation Script v1.1.0"
echo "===================================="
echo ""

echo "WARNING: This will remove all Claude orchestration hooks and timers."
echo "Continue with uninstallation? (y/n)"
read -r confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Uninstallation cancelled."
    exit 0
fi
echo ""

# Stop and disable timers
echo "[1/5] Stopping and disabling systemd timers..."
systemctl --user stop claude-context-monitor.timer 2>/dev/null || true
systemctl --user stop claude-search-cache-manager.timer 2>/dev/null || true
systemctl --user stop claude-hooks-updater.timer 2>/dev/null || true
systemctl --user stop claude-state-validator.timer 2>/dev/null || true
systemctl --user stop claude-budget-analyzer.timer 2>/dev/null || true
systemctl --user stop claude-performance-monitor.timer 2>/dev/null || true

systemctl --user disable claude-context-monitor.timer 2>/dev/null || true
systemctl --user disable claude-search-cache-manager.timer 2>/dev/null || true
systemctl --user disable claude-hooks-updater.timer 2>/dev/null || true
systemctl --user disable claude-state-validator.timer 2>/dev/null || true
systemctl --user disable claude-budget-analyzer.timer 2>/dev/null || true
systemctl --user disable claude-performance-monitor.timer 2>/dev/null || true
echo "Timers stopped and disabled"
echo ""

# Remove systemd units
echo "[2/5] Removing systemd units..."
rm -f "$HOME/.config/systemd/user/claude-"*.timer
rm -f "$HOME/.config/systemd/user/claude-"*.service
systemctl --user daemon-reload
echo "Systemd units removed"
echo ""

# Remove hook scripts
echo "[3/5] Removing hook scripts..."
rm -f "$HOME/.local/bin/claude-budget-analyzer.sh"
rm -f "$HOME/.local/bin/claude-context-monitor.sh"
rm -f "$HOME/.local/bin/claude-hooks-updater.sh"
rm -f "$HOME/.local/bin/claude-performance-monitor.sh"
rm -f "$HOME/.local/bin/claude-search-cache-manager.sh"
rm -f "$HOME/.local/bin/claude-state-validator.sh"
rm -f "$HOME/.local/bin/context-monitor.sh"
rm -f "$HOME/.local/bin/delegation-check.sh"
rm -f "$HOME/.local/bin/delegation-warning.sh"
rm -f "$HOME/.local/bin/output-monitor.sh"
rm -f "$HOME/.local/bin/auto-review-trigger.sh"
echo "Hook scripts removed"
echo ""

# Handle state directory
echo "[4/5] State directory cleanup..."
if [ -d "$HOME/.context" ]; then
    echo "Remove state directory (~/.context)? This includes logs and cache. (y/n)"
    read -r remove_state
    if [[ "$remove_state" =~ ^[Yy]$ ]]; then
        rm -rf "$HOME/.context"
        echo "State directory removed"
    else
        echo "ℹ️  State directory kept"
    fi
else
    echo "ℹ️  No state directory found"
fi
echo ""

# Handle Claude settings
echo "[5/5] Claude Code settings..."
if [ -f "$HOME/.claude/settings.json.backup."* ]; then
    echo "Found settings backup(s). Restore from backup? (y/n)"
    read -r restore_settings
    if [[ "$restore_settings" =~ ^[Yy]$ ]]; then
        latest_backup=$(ls -t "$HOME/.claude/settings.json.backup."* | head -1)
        cp "$latest_backup" "$HOME/.claude/settings.json"
        echo "Settings restored from: $(basename "$latest_backup")"
    else
        echo "ℹ️  Settings not restored. You may want to manually edit ~/.claude/settings.json"
    fi
else
    echo "ℹ️  No backup found. You may want to manually edit ~/.claude/settings.json to remove hooks"
fi
echo ""

echo "======================================"
echo "Uninstallation Complete"
echo "======================================"
echo "Removed:"
echo "  - 6 systemd timers (stopped and disabled)"
echo "  - 12 systemd units"
echo "  - 11 hook scripts from ~/.local/bin/"
if [[ "$remove_state" =~ ^[Yy]$ ]]; then
    echo "  - State directory (~/.context/)"
fi
echo ""
echo "Note: Restart Claude Code to apply changes"
echo "======================================"
