# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-11-23

### Added

#### Core Hooks System
- `delegation-check.sh` - PreToolUse hook enforcing search-first + delegation workflow
  - File type detection for code files
  - Context-aware prompting with MCP integration
  - Whitelisting for configuration files
- `delegation-warning.sh` - PostToolUse educational notifications
  - Non-blocking optimization suggestions
  - Token usage awareness prompts
- `context-monitor.sh` - Real-time context window tracking
  - Critical alerts at 75% usage (150k/200k tokens)
  - Warning alerts at 60% usage (120k/200k tokens)
  - Integration with shared budget state
- `output-monitor.sh` - Large output detection and tracking
  - 10KB threshold for "large" outputs
  - Automatic context debt calculation
  - Token estimation (4 chars = 1 token)

#### Self-Healing Infrastructure
- `claude-state-validator.sh` - Daily state file validation
  - JSON corruption detection
  - Automatic repair with schema merging
  - 7-day backup retention
  - Atomic operations with flock
- Systemd timer: Daily validation at 4:00 AM

#### Performance Monitoring
- `claude-performance-monitor.sh` - Hook execution tracking
  - Slow hook detection (>500ms threshold)
  - Weekly performance reports
  - P95 latency calculation
  - 10MB log rotation
- Systemd timer: Weekly Sunday 20:00

#### Search Caching
- `claude-search-cache-manager.sh` - TTL-based search result caching
  - 1 hour TTL by default
  - LRU eviction (100 entries max)
  - Pre-warming during low-activity hours (2-5 AM)
  - Hit/miss statistics with token savings tracking
- Systemd timer: Hourly cleanup

#### Context Automation
- `claude-context-monitor.sh` - Continuous context monitoring
  - Every 2-minute usage checks
  - Desktop notifications via notify-send
  - 90% critical threshold, 60% warning threshold
  - Compaction recommendation flags
- Systemd timer: Every 2 minutes

#### Budget Optimization
- `claude-budget-analyzer.sh` - Adaptive budget management
  - Weekly delegation rate analysis
  - ROI calculation (tokens saved per delegation)
  - Automatic budget adjustments:
    - High delegation (>50%): Reduce by 15-20%
    - Low delegation (<20%): Increase by 5-10%
  - Historical tracking in CSV format
- Systemd timer: Weekly Monday 9:00 AM

#### Auto-Updates
- `claude-hooks-updater.sh` - Version-controlled updates
  - SHA256 checksum verification
  - Automatic backups before updates
  - Rollback capability (5 backup retention)
  - Integrity verification commands
- Version manifest with hook metadata
- Systemd timer: Daily 3:00 AM with randomized delay

#### Configuration
- Enhanced `~/.claude/settings.json` with hooks configuration
- Shared state file: `~/.context/shared-budget.json`
- Search cache storage: `~/.context/search-cache.json`
- Budget history tracking: `~/.context/budget-history.csv`

#### Documentation
- Comprehensive implementation summary
- Architecture documentation
- Manual operations guide
- Troubleshooting procedures

### Changed
- N/A (initial release)

### Deprecated
- N/A (initial release)

### Removed
- N/A (initial release)

### Fixed
- N/A (initial release)

### Security
- All file operations use atomic writes with flock
- No credentials or secrets stored in scripts
- State files protected with user-only permissions
- Checksum verification for hook integrity

## [Unreleased]

### Planned
- Git-based hook updates from repository
- ML-based cache pre-warming
- Grafana dashboard integration
- Prometheus metrics export
- Multi-channel notifications (Slack, Discord)
- Parallel hook execution optimization
- Enhanced error recovery mechanisms
- Public release preparation (sanitization)

---

## Version History

- **1.0.0** (2025-11-23) - Initial release with full orchestration system
