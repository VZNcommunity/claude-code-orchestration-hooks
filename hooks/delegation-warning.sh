#!/bin/bash
# PostToolUse Hook: Delegation Policy Awareness
# Location: $HOME/.local/bin/delegation-warning.sh
# Purpose: Notify after code generation to build awareness

set -euo pipefail

# Read stdin JSON
INPUT=$(cat)

# Extract tool information
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "unknown"')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')

# Logging
log() {
  echo "[delegation-warning] $*" >&2
}

log "PostToolUse triggered for: $TOOL_NAME"

# Detect code file operations
if [[ "$TOOL_NAME" =~ ^(Write|Edit)$ ]] && [ -n "$FILE_PATH" ]; then
  BASENAME=$(basename "$FILE_PATH")

  # Skip whitelisted config files
  if [[ "$BASENAME" =~ ^(package\.json|tsconfig\.json|\.env|\.gitignore|README\.md|CLAUDE\.md|LICENSE)$ ]]; then
    log "Skipping whitelisted file: $BASENAME"
    exit 0
  fi

  # Detect code files
  if [[ "$FILE_PATH" =~ \.(js|jsx|ts|tsx|py|go|rs|java|cpp|c|h|sh|rb|php|swift|kt)$ ]]; then
    log "Code generation detected in: $FILE_PATH"

    echo "" >&2
    echo "[Orchestration Policy] Code generation detected in $FILE_PATH" >&2
    echo "" >&2
    echo "   💡 OPTIMIZATION OPPORTUNITIES:" >&2
    echo "      1. Search existing patterns: mcp__claude-context__search_code" >&2
    echo "      2. Check delegation: mcp__claude-orchestrator__check_delegation_policy" >&2
    echo "      3. Track usage: mcp__claude-orchestrator__get_session_stats" >&2
    echo "" >&2
    echo "   Benefits: 2-4x token efficiency, consistent code, reduced context debt" >&2
    echo "" >&2
  fi
fi

exit 0
