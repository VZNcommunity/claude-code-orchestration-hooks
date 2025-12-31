# Claude Code Orchestration Hooks

**Version:** 1.0.0
**Status:** Private Development
**Created:** 2025-11-23

Self-driving orchestration system for Claude Code with automated delegation enforcement, context monitoring, and budget optimization.

## Overview

This project implements a comprehensive automation layer for Claude Code that:
- Enforces orchestration-first policy via PreToolUse/PostToolUse hooks
- Monitors context window usage in real-time
- Manages token budgets with adaptive optimization
- Provides self-healing state file validation
- Tracks performance metrics
- Caches search results with TTL expiration
- Auto-updates with version control and rollback

**Goal:** Reduce token usage by 50-75% through proactive delegation to OpenCode+LFM2 while maintaining code quality.

## Architecture

### Components

**Core Hooks (Session 1):**
- `delegation-check.sh` - PreToolUse enforcement for Write|Edit
- `delegation-warning.sh` - PostToolUse awareness notifications
- `context-monitor.sh` - Real-time context window tracking
- `output-monitor.sh` - Large output detection and debt tracking

**Self-Driving Features (Session 2):**
- `claude-state-validator.sh` - Daily state validation with auto-repair
- `claude-performance-monitor.sh` - Hook execution time tracking
- `claude-search-cache-manager.sh` - TTL-based search result caching
- `claude-context-monitor.sh` - Every-2-minute context monitoring
- `claude-budget-analyzer.sh` - Weekly budget optimization
- `claude-hooks-updater.sh` - Version-controlled auto-updates

### Systemd Timers

| Timer | Frequency | Purpose |
|-------|-----------|---------|
| claude-context-monitor | 2 minutes | Context usage alerts |
| claude-search-cache-manager | Hourly | Cache cleanup |
| claude-hooks-updater | Daily 3 AM | Version checks |
| claude-state-validator | Daily 4 AM | State validation |
| claude-budget-analyzer | Weekly Mon 9 AM | Budget optimization |
| claude-performance-monitor | Weekly Sun 8 PM | Performance reports |

## Configuration Modes (2025-12-31)

### Minimal Configuration (Current)

**Status:** Active since 2025-12-31

Due to interference with Claude Code's auto-accept permissions for Edit/Write operations, the hooks system now runs in **minimal mode**.

**Active Hooks:**
- `output-monitor.sh` (PostToolUse: Grep|Glob|Read|Bash) - Large output detection and context debt tracking
- `auto-review-trigger.sh` (PostToolUse: Bash) - Code review suggestions after delegation

**Disabled Hooks:**
- **All PreToolUse hooks:** progress-validator, context-monitor, loop-checkpoint
  - These ran before every tool call and blocked Edit/Write auto-accept
- **PostToolUse on Write|Edit:** delegation-warning, review-enforcer, auto-commit
  - These interfered with automatic permission handling
- **PostToolUse on "*":** consistency-tracker
  - Universal matcher caused blocking on all operations
- **PostToolUse on TodoWrite:** auto-commit

**Systemd Timers:** Still active - these run independently and don't interfere with tool operations.

**Configuration File:** `settings.minimal.json` (reference configuration)

**Reason for Change:** PreToolUse and aggressive PostToolUse hooks were preventing Claude Code from automatically accepting Edit/Write operations that were explicitly allowed in permissions, requiring manual user approval for every file change.

### Full Configuration (Archived)

The original full configuration with all PreToolUse and PostToolUse hooks is documented in git history (commits before 2025-12-31). It can be restored if the auto-accept permission issues are resolved in future Claude Code versions.

**Trade-offs:**
- **Minimal mode:** Better user experience (no permission blocks), reduced enforcement
- **Full mode:** Strong orchestration enforcement, but blocks auto-accept permissions

## Installation Status

**Current Deployment:** Fully operational on personal system
- Installed: `~/.local/bin/` (hook scripts)
- Systemd: `~/.config/systemd/user/` (timers + services)
- State: `~/.context/` (shared-budget.json, logs, cache)
- Config: `~/.claude/settings.json` (hooks enabled)

**Files:**
- 9 hook scripts (49.6KB total)
- 12 systemd units (6 timers + 6 services)
- 1 version manifest with SHA256 checksums
- Multiple state/log files

## Integration

### MCP Servers
- **claude-orchestrator** (v0.2.0) - Delegation policy and task execution
- **claude-context** - Semantic code search via Gemini embeddings
- **claude-monitor** (v3.1.0) - Real-time token usage tracking

### External Services
- Desktop notifications via `notify-send`
- Systemd journal logging
- Performance metrics collection

## Current State

**Configuration Mode:** Minimal (2025-12-31)
**Active Hooks:** 2/9 (output-monitor, auto-review-trigger)
**Timers Active:** 6/6
**Hooks Verified:** 9/9 with checksums
**Version:** 1.0.0
**Last Update:** 2025-12-31
**Last Validation:** 2025-11-23

## Performance

- Hook overhead: <200ms average
- Memory: 30-50MB per service (enforced)
- CPU: 5-10% quota per service
- Token reduction: Target 50-75% via delegation

## Documentation

- **Implementation Summary:** `docs/IMPLEMENTATION-SUMMARY.md`
- **Version Manifest:** `config/version-manifest.json`
- **Systemd Units:** `systemd/*.{timer,service}`
- **Hook Scripts:** `hooks/*.sh`

## TODO: Public Release Preparation

When ready to make this repository public, complete these tasks:

- [ ] Replace hardcoded `/home/vzith` paths with `$HOME` variables
- [ ] Create example state files (schemas only, not real data)
- [ ] Add comprehensive installation script (`install.sh`)
- [ ] Add uninstallation script (`uninstall.sh`)
- [ ] Add MIT License
- [ ] Create CONTRIBUTING.md
- [ ] Add architecture diagrams
- [ ] Create troubleshooting guide
- [ ] Add installation requirements check
- [ ] Test on clean system
- [ ] Sanitize any personal information from logs/examples
- [ ] Update README for general audience
- [ ] Add GitHub workflows for validation
- [ ] Create release tags

## Development Notes

**Session 1 (2025-11-23):**
- Implemented core hooks system
- Integrated claude-orchestrator and claude-context MCPs
- Added context window monitoring
- Created shared state management

**Session 2 (2025-11-23):**
- Implemented self-healing state validation
- Added performance monitoring
- Created search result caching
- Implemented adaptive budget management
- Added version-controlled auto-updates
- Deployed all systemd timers

**Session 3 (2025-12-31):**
- Switched to minimal hooks configuration
- Disabled PreToolUse hooks (blocking Edit/Write auto-accept)
- Disabled aggressive PostToolUse hooks
- Retained only non-blocking hooks (output-monitor, auto-review-trigger)
- Documented configuration modes and trade-offs
- Created `settings.minimal.json` reference configuration

## Repository Structure

```
claude-code-orchestration-hooks/
├── README.md                    # This file
├── CHANGELOG.md                 # Version history
├── hooks/                       # All hook scripts (9 files)
├── systemd/                     # Systemd units (12 files)
├── config/                      # Configuration files
│   └── version-manifest.json    # Hook checksums
└── docs/                        # Documentation
    └── IMPLEMENTATION-SUMMARY.md
```

## Quick Commands

```bash
# Verify all timers
systemctl --user list-timers | grep claude

# Check hook integrity
~/.local/bin/claude-hooks-updater.sh --verify

# View context status
~/.local/bin/claude-context-monitor.sh --status

# View cache stats
~/.local/bin/claude-search-cache-manager.sh --stats

# Generate budget report
~/.local/bin/claude-budget-analyzer.sh --report
```

## Future Enhancements

- Git-based hook updates from this repository
- Advanced ML-based cache pre-warming
- Grafana dashboard integration
- Prometheus metrics export
- Multi-channel notifications (Slack, Discord)
- Performance optimization (parallel execution)

## Notes

This repository is currently **private** for personal development and refinement. It will be sanitized and made public when ready for community use.

**Target Audience (when public):** Claude Code users on Arch Linux with systemd who want to optimize token usage through automated orchestration.

---

**System Requirements:**
- Arch Linux (or systemd-based distro)
- Bash 5+
- jq
- Claude Code with MCP support
- claude-orchestrator MCP server
- claude-context MCP server (optional but recommended)
