# Claude Code Orchestration Hooks

[![Version](https://img.shields.io/badge/version-1.2.0-blue.svg)](https://github.com/VZNcommunity/claude-code-orchestration-hooks/releases/tag/v1.2.0)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Validate](https://github.com/VZNcommunity/claude-code-orchestration-hooks/actions/workflows/validate.yml/badge.svg)](https://github.com/VZNcommunity/claude-code-orchestration-hooks/actions/workflows/validate.yml)
[![Shell](https://img.shields.io/badge/shell-bash%205.0%2B-orange.svg)](https://www.gnu.org/software/bash/)
[![Issues](https://img.shields.io/github/issues/VZNcommunity/claude-code-orchestration-hooks.svg)](https://github.com/VZNcommunity/claude-code-orchestration-hooks/issues)

Self-driving orchestration system for Claude Code with automated delegation enforcement, context monitoring, and budget optimization.

## Overview

This project implements a comprehensive automation layer for Claude Code that:
- Monitors context window usage in real-time
- Manages token budgets with adaptive optimization
- Provides self-healing state file validation
- Tracks performance metrics
- Caches search results with TTL expiration
- Auto-updates with version control and rollback

**Goal:** Reduce token usage by 50-75% through proactive delegation while maintaining code quality.

## Features

### Active Hooks (Minimal Configuration)

Since version 1.1.0, the system runs in minimal mode for better compatibility with Claude Code's auto-accept permissions:

- **output-monitor.sh** - Large output detection and context debt tracking
- **auto-review-trigger.sh** - Code review suggestions after delegation
- **auto-commit-async.sh** (v1.2.0) - Non-blocking auto-commit on Edit/Write operations

### Systemd Timers

Automated background services for continuous monitoring:

| Timer | Frequency | Purpose |
|-------|-----------|---------|
| claude-context-monitor | 2 minutes | Context usage alerts |
| claude-search-cache-manager | Hourly | Cache cleanup |
| claude-hooks-updater | Daily 3 AM | Version checks |
| claude-state-validator | Daily 4 AM | State validation |
| claude-budget-analyzer | Weekly Mon 9 AM | Budget optimization |
| claude-performance-monitor | Weekly Sun 8 PM | Performance reports |

## Prerequisites

### System Requirements

- **Operating System:** Arch Linux or systemd-based distribution
- **Shell:** Bash 5.0+
- **Tools:** jq (JSON processor)
- **Claude Code:** Latest version with MCP support
- **systemd:** For automated timer services

### Optional MCP Servers

- **claude-orchestrator** (v0.2.0+) - Delegation policy enforcement
- **claude-context** - Semantic code search via embeddings

## Installation

### Quick Install

```bash
# Clone the repository
git clone https://github.com/VZNcommunity/claude-code-orchestration-hooks.git
cd claude-code-orchestration-hooks

# Run installation script
./install.sh
```

### What Gets Installed

The installation script will:

1. Check system requirements (Bash 5+, jq, systemd)
2. Create necessary directories:
   - `~/.local/bin/` - Hook scripts
   - `~/.config/systemd/user/` - Systemd units
   - `~/.context/` - State files
3. Copy hook scripts with proper permissions
4. Install systemd timers and services
5. Optionally configure Claude Code settings
6. Enable and start systemd timers

### Manual Installation

If you prefer manual installation:

```bash
# Create directories
mkdir -p ~/.local/bin ~/.config/systemd/user ~/.context

# Copy hook scripts
cp hooks/*.sh ~/.local/bin/
chmod +x ~/.local/bin/*.sh

# Copy systemd units
cp systemd/*.{timer,service} ~/.config/systemd/user/

# Reload systemd
systemctl --user daemon-reload

# Enable timers
systemctl --user enable --now claude-context-monitor.timer
systemctl --user enable --now claude-search-cache-manager.timer
systemctl --user enable --now claude-hooks-updater.timer
systemctl --user enable --now claude-state-validator.timer
systemctl --user enable --now claude-budget-analyzer.timer
systemctl --user enable --now claude-performance-monitor.timer

# Copy configuration (optional)
cp settings.minimal.json ~/.claude/settings.json
```

## Configuration

### Minimal vs Full Mode

**Minimal Mode** (default, v1.1.0+):
- Only 2 non-blocking hooks active
- Better compatibility with Claude Code auto-accept
- Systemd timers still provide monitoring

**Full Mode** (archived):
- All PreToolUse and PostToolUse hooks active
- Strong orchestration enforcement
- May interfere with auto-accept permissions

See `CHANGELOG.md` for migration notes between modes.

### Configuration Files

- **~/.claude/settings.json** - Claude Code hooks configuration
- **~/.context/shared-budget.json** - Budget and delegation tracking
- **~/.context/search-cache.json** - Search result cache

Example state files are available in `examples/` directory.

## Usage

### Verification Commands

```bash
# Verify all timers are running
systemctl --user list-timers | grep claude

# Check hook integrity
~/.local/bin/claude-hooks-updater.sh --verify

# View context status
~/.local/bin/claude-context-monitor.sh --status

# View cache statistics
~/.local/bin/claude-search-cache-manager.sh --stats

# Generate budget report
~/.local/bin/claude-budget-analyzer.sh --report
```

### Monitoring

View systemd service logs:

```bash
# Context monitor logs
journalctl --user -u claude-context-monitor.service -n 50

# State validator logs
journalctl --user -u claude-state-validator.service -n 50

# All claude services
journalctl --user -u 'claude-*' -n 100
```

## Uninstallation

```bash
# Run uninstallation script
./uninstall.sh
```

The uninstall script will:
- Stop and disable all systemd timers
- Remove hook scripts from `~/.local/bin/`
- Remove systemd units
- Optionally remove state directory (`~/.context/`)
- Optionally restore settings backup

## Troubleshooting

### Common Issues

**Timers not starting:**
```bash
# Check timer status
systemctl --user status claude-context-monitor.timer

# View timer logs
journalctl --user -u claude-context-monitor.timer -n 20

# Manually start timer
systemctl --user start claude-context-monitor.timer
```

**Hooks not executing:**
```bash
# Verify hook scripts exist and are executable
ls -lh ~/.local/bin/claude-*.sh

# Test hook manually
echo '{"tool_name":"Read"}' | ~/.local/bin/output-monitor.sh

# Check Claude Code settings
cat ~/.claude/settings.json | jq '.hooks'
```

**State file errors:**
```bash
# Validate state files
jq empty < ~/.context/shared-budget.json
jq empty < ~/.context/search-cache.json

# Reset state files (use examples)
cp examples/shared-budget.json.example ~/.context/shared-budget.json
cp examples/search-cache.json.example ~/.context/search-cache.json
```

**Permission issues:**
```bash
# Fix hook script permissions
chmod +x ~/.local/bin/claude-*.sh

# Fix state directory permissions
chmod 700 ~/.context
```

### Getting Help

- **Issues:** Report bugs at [GitHub Issues](https://github.com/VZNcommunity/claude-code-orchestration-hooks/issues)
- **Documentation:** See `CONTRIBUTING.md` for development setup
- **Examples:** Check `examples/` directory for state file schemas

## Performance

- Hook overhead: <200ms average
- Memory: 30-50MB per service (enforced)
- CPU: 5-10% quota per service
- Token reduction: Target 50-75% via delegation

## Project Structure

```
claude-code-orchestration-hooks/
├── README.md                    # This file
├── LICENSE                      # MIT License
├── CHANGELOG.md                 # Version history
├── CONTRIBUTING.md              # Contribution guidelines
├── install.sh                   # Installation script
├── uninstall.sh                 # Uninstallation script
├── hooks/                       # Hook scripts (10 files)
├── systemd/                     # Systemd units (12 files)
├── examples/                    # Example state files
│   ├── README.md
│   ├── shared-budget.json.example
│   └── search-cache.json.example
├── config/                      # Configuration files
│   └── version-manifest.json
├── docs/                        # Additional documentation
│   └── IMPLEMENTATION-SUMMARY.md
└── .github/
    └── workflows/
        └── validate.yml         # CI/CD validation
```

## Development

See `CONTRIBUTING.md` for:
- Development setup instructions
- Code style guidelines
- Testing procedures
- Pull request workflow

## Version History

- **1.2.0** (2026-01-18) - Non-blocking auto-commit hook
- **1.1.0** (2025-12-31) - Minimal configuration mode, public release
- **1.0.0** (2025-11-23) - Initial release with full orchestration system

See `CHANGELOG.md` for detailed version history.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

Built for the Claude Code community to optimize token usage through automated orchestration.

---

**Contributing:** We welcome contributions! See `CONTRIBUTING.md` for guidelines.

**Support:** Report issues or request features at [GitHub Issues](https://github.com/VZNcommunity/claude-code-orchestration-hooks/issues).
