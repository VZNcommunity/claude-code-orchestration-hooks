# Example State Files

This directory contains example schemas for state files used by Claude Code Orchestration Hooks.

## Files

### shared-budget.json.example

Schema for the shared budget state file (`~/.context/shared-budget.json`).

**Purpose**: Tracks token usage, budget limits, and delegation statistics across sessions.

**Location**: `~/.context/shared-budget.json`

**Used by**:
- `claude-budget-analyzer.sh` - Analyzes budget and delegation patterns
- `claude-context-monitor.sh` - Monitors context usage
- `claude-orchestrator` MCP server - Enforces budget limits
- Hook scripts - Track delegation vs direct generation

**Fields**:
- `session_tokens`: Current session token consumption
- `session_budget`: Maximum tokens per session (default: 10000)
- `daily_tokens`: Current day total token consumption
- `daily_budget`: Maximum tokens per day (default: 50000)
- `delegation_count`: Number of delegations to OpenCode this session
- `direct_generation_count`: Number of direct code generations this session
- `context_tracking`: Real-time context window usage tracking
- `notifications`: Tracks which budget threshold notifications have been sent

### search-cache.json.example

Schema for the search result cache file (`~/.context/search-cache.json`).

**Purpose**: Caches MCP search results to reduce redundant searches and save tokens.

**Location**: `~/.context/search-cache.json`

**Used by**:
- `claude-search-cache-manager.sh` - Manages cache entries, TTL expiration, LRU eviction

**Fields**:
- `cache`: Hash-keyed search results with TTL timestamps
- `stats`: Cache hit/miss statistics and token savings
- `config`: Cache configuration (max entries, TTL, eviction policy)

**Cache Entry Structure**:
- `query`: Original search query string
- `path`: Search path parameter
- `results`: Array of search results with scores and snippets
- `timestamp`: When the search was cached
- `ttl_seconds`: Time-to-live in seconds (default: 3600)

## Usage

These are **example schemas only** - they show the structure but contain placeholder data.

Actual state files are created automatically by the hooks system at runtime in `~/.context/`.

## Creating State Files Manually

If you need to initialize state files manually:

```bash
# Create state directory
mkdir -p ~/.context

# Copy examples (remove .example extension)
cp examples/shared-budget.json.example ~/.context/shared-budget.json
cp examples/search-cache.json.example ~/.context/search-cache.json

# Update timestamps to current time
# (or let the hooks auto-initialize them)
```

## Notes

- State files are automatically created on first run if they don't exist
- Do not commit real state files to the repository (they contain session data)
- State files use JSON format and must be valid JSON
- The `claude-state-validator.sh` service validates and repairs state files daily
