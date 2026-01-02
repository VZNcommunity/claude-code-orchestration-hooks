#!/bin/bash
# PreToolUse Hook: Orchestration + Context-Aware Delegation
# Location: $HOME/.local/bin/delegation-check.sh
# Purpose: Enforce search-first + delegation workflow for code generation

set -euo pipefail

# Read stdin JSON
INPUT=$(cat)

# Extract tool information
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "unknown"')
TOOL_INPUT_JSON=$(echo "$INPUT" | jq -r '.tool_input // {}')

# Load shared state for context tracking
SHARED_STATE="$HOME/.context/shared-budget.json"
if [ -f "$SHARED_STATE" ]; then
  CONTEXT_USAGE=$(jq -r '.context_tracking.context_usage_percent // 0' "$SHARED_STATE" 2>/dev/null || echo "0")
  CONTEXT_DEBT=$(jq -r '.context_tracking.context_debt // 0' "$SHARED_STATE" 2>/dev/null || echo "0")
else
  CONTEXT_USAGE=0
  CONTEXT_DEBT=0
fi

# Logging (to stderr, won't interfere with JSON stdout)
log() {
  echo "[delegation-check] $*" >&2
}

log "Hook triggered for tool: $TOOL_NAME"

# Check Write/Edit for code generation
if [ "$TOOL_NAME" = "Write" ] || [ "$TOOL_NAME" = "Edit" ]; then
  FILE_PATH=$(echo "$TOOL_INPUT_JSON" | jq -r '.file_path // ""')

  # Skip if no file path
  if [ -z "$FILE_PATH" ]; then
    log "No file path, allowing operation"
    exit 0
  fi

  log "File operation detected: $FILE_PATH"

  # Whitelist: Allow common config files
  BASENAME=$(basename "$FILE_PATH")
  if [[ "$BASENAME" =~ ^(package\.json|tsconfig\.json|\.env|\.gitignore|README\.md|CLAUDE\.md|LICENSE|\.eslintrc|\.prettierrc)$ ]]; then
    log "Config/docs file whitelisted: $BASENAME"
    exit 0
  fi

  # Detect code files by extension
  if [[ "$FILE_PATH" =~ \.(js|jsx|ts|tsx|py|go|rs|rust|java|cpp|c|h|hpp|sh|bash|rb|php|swift|kt|scala|clj)$ ]]; then
    log "Code file detected, prompting for delegation"

    # Extract task description from file path
    TASK_DESC="implement $(basename "$FILE_PATH" | sed 's/\.[^.]*$//' | tr '_-' ' ')"

    # Build context-aware guidance
    GUIDANCE="⚠️ CODE GENERATION DETECTED

File: $FILE_PATH
Task: $TASK_DESC
Context Usage: ${CONTEXT_USAGE}%
Context Debt: ${CONTEXT_DEBT} tokens

RECOMMENDED WORKFLOW (Search-First + Delegate):

1. 🔍 SEARCH EXISTING PATTERNS
   mcp__claude-context__search_code({
     path: '$HOME/Development',
     query: '$TASK_DESC patterns examples'
   })
   → Finds existing implementations to learn from
   → Ensures consistency with codebase
   → Provides context to OpenCode

2. 📊 CHECK DELEGATION POLICY
   mcp__claude-orchestrator__check_delegation_policy({
     task_type: 'code_generation',
     description: '$TASK_DESC'
   })
   → Determines if should delegate (2-4x efficiency)
   → Checks budget status
   → Provides specific command

3. 🤖 DELEGATE WITH CONTEXT
   mcp__claude-orchestrator__delegate_task({
     task_type: 'code',
     prompt: 'Based on existing patterns [search results], $TASK_DESC'
   })
   → Executes via OpenCode+LFM2
   → Saves ~500-2000 tokens
   → Reduces context window pressure

BENEFITS:
✅ Consistent with existing code
✅ 2-4x token efficiency via delegation
✅ Reduces context debt
✅ Improves compliance score"

    # Add context warnings if needed
    if (( $(echo "$CONTEXT_USAGE >= 75" | bc -l 2>/dev/null || echo 0) )); then
      GUIDANCE="$GUIDANCE

⚠️ HIGH CONTEXT USAGE (${CONTEXT_USAGE}%)
Recommend: /compact before proceeding"
    fi

    if (( CONTEXT_DEBT > 10000 )); then
      GUIDANCE="$GUIDANCE

⚠️ HIGH CONTEXT DEBT (${CONTEXT_DEBT} tokens)
Consider: Delegate recent large operations to reduce debt"
    fi

    GUIDANCE="$GUIDANCE

Proceed with direct generation anyway?"

    # Return JSON response with ask permission
    cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "ask",
    "permissionDecisionReason": $(echo "$GUIDANCE" | jq -Rs .)
  }
}
EOF
    exit 0
  else
    log "Non-code file, allowing operation"
  fi
fi

# Allow all other operations
log "Operation allowed"
exit 0
