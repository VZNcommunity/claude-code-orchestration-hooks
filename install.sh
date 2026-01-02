#!/usr/bin/env bash
# Claude Code Orchestration Hooks - Installation Script
# Version: 1.1.0
# License: MIT

set -e

echo "===================================="
echo "Claude Code Orchestration Hooks"
echo "Installation Script v1.1.0"
echo "===================================="
echo ""

# Check requirements
echo "[1/7] Checking system requirements..."

# Check bash version
if ! bash --version | grep -q "version [5-9]"; then
    echo "❌ Error: Bash 5+ required"
    exit 1
fi

# Check jq
if ! command -v jq &> /dev/null; then
    echo "❌ Error: jq not installed. Install with: sudo pacman -S jq"
    exit 1
fi

# Check systemd
if ! command -v systemctl &> /dev/null; then
    echo "❌ Error: systemd not found. This tool requires systemd."
    exit 1
fi

# Check Claude Code (optional warning)
if [ ! -f "$HOME/.claude/settings.json" ]; then
    echo "⚠️  Warning: Claude Code settings not found at ~/.claude/settings.json"
    echo "   Continue anyway? (y/n)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "✅ All requirements met"
echo ""

# Create directories
echo "[2/7] Creating directories..."
mkdir -p "$HOME/.local/bin"
mkdir -p "$HOME/.config/systemd/user"
mkdir -p "$HOME/.context"
echo "✅ Directories created"
echo ""

# Install hook scripts
echo "[3/7] Installing hook scripts..."
cp -v hooks/*.sh "$HOME/.local/bin/"
chmod 755 "$HOME/.local/bin"/*.sh
echo "✅ Hook scripts installed to ~/.local/bin/"
echo ""

# Install systemd units
echo "[4/7] Installing systemd units..."
cp -v systemd/*.{timer,service} "$HOME/.config/systemd/user/" 2>/dev/null || true
systemctl --user daemon-reload
echo "✅ Systemd units installed"
echo ""

# Configure Claude Code settings
echo "[5/7] Configuring Claude Code hooks..."
if [ -f "$HOME/.claude/settings.json" ]; then
    echo "Found existing settings.json"
    echo "Backup existing settings? (y/n)"
    read -r backup_response
    if [[ "$backup_response" =~ ^[Yy]$ ]]; then
        cp "$HOME/.claude/settings.json" "$HOME/.claude/settings.json.backup.$(date +%Y%m%d-%H%M%S)"
        echo "✅ Backup created"
    fi

    echo ""
    echo "Configuration options:"
    echo "  1) Use minimal hooks (recommended, no permission blocking)"
    echo "  2) Keep current settings"
    echo "Choose option (1 or 2): "
    read -r config_choice

    if [ "$config_choice" = "1" ]; then
        cp settings.minimal.json "$HOME/.claude/settings.json"
        echo "✅ Minimal hooks configuration applied"
    else
        echo "ℹ️  Keeping existing settings"
    fi
else
    cp settings.minimal.json "$HOME/.claude/settings.json"
    echo "✅ Minimal hooks configuration installed"
fi
echo ""

# Enable systemd timers
echo "[6/7] Enabling systemd timers..."
echo "Enable all timers? (y/n)"
read -r enable_response
if [[ "$enable_response" =~ ^[Yy]$ ]]; then
    systemctl --user enable --now claude-context-monitor.timer
    systemctl --user enable --now claude-search-cache-manager.timer
    systemctl --user enable --now claude-hooks-updater.timer
    systemctl --user enable --now claude-state-validator.timer
    systemctl --user enable --now claude-budget-analyzer.timer
    systemctl --user enable --now claude-performance-monitor.timer
    echo "✅ All timers enabled and started"
else
    echo "ℹ️  Timers not enabled. Enable manually with:"
    echo "   systemctl --user enable --now claude-<timer-name>.timer"
fi
echo ""

# Summary
echo "[7/7] Installation complete!"
echo ""
echo "======================================"
echo "Next Steps:"
echo "======================================"
echo "1. Restart Claude Code to apply hook configuration"
echo "2. Verify timers: systemctl --user list-timers | grep claude"
echo "3. Check hook integrity: ~/.local/bin/claude-hooks-updater.sh --verify"
echo "4. View context status: ~/.local/bin/claude-context-monitor.sh --status"
echo ""
echo "Configuration:"
echo "  - Hooks: ~/.local/bin/claude-*.sh"
echo "  - Systemd: ~/.config/systemd/user/claude-*"
echo "  - State: ~/.context/"
echo "  - Settings: ~/.claude/settings.json"
echo ""
echo "Documentation: https://github.com/VZNcommunity/claude-code-orchestration-hooks"
echo "======================================"
