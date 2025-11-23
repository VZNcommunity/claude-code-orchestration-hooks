#!/bin/bash
# PreToolUse Hook: Context Window Management
# Location: /home/vzith/.local/bin/context-monitor.sh
# Purpose: Proactive context size monitoring and compaction warnings

set -euo pipefail

# Read stdin JSON
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "unknown"')

# Logging
log() {
  echo "[context-monitor] $*" >&2
}

log "Context monitoring for: $TOOL_NAME"

# Load shared state
SHARED_STATE="$HOME/.context/shared-budget.json"
if [ ! -f "$SHARED_STATE" ]; then
  log "Shared state not found, skipping context check"
  exit 0
fi

# Extract context tracking data
CONTEXT_USAGE=$(jq -r '.context_tracking.context_usage_percent // 0' "$SHARED_STATE" 2>/dev/null || echo "0")
CONTEXT_SIZE=$(jq -r '.context_tracking.current_tokens // 0' "$SHARED_STATE" 2>/dev/null || echo "0")
CONTEXT_LIMIT=200000
DELEGATION_RATE=$(jq -r '.compliance_score // 100' "$SHARED_STATE" 2>/dev/null || echo "100")

log "Context: ${CONTEXT_SIZE}/${CONTEXT_LIMIT} tokens (${CONTEXT_USAGE}%)"

# Critical threshold: 75%
if (( $(echo "$CONTEXT_USAGE >= 75" | bc -l 2>/dev/null || echo 0) )); then
  REMAINING=$((CONTEXT_LIMIT - CONTEXT_SIZE))

  cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "ask",
    "permissionDecisionReason": "⚠️ CRITICAL CONTEXT USAGE\\n\\nCurrent: ${CONTEXT_SIZE} tokens (${CONTEXT_USAGE}%)\\nLimit: ${CONTEXT_LIMIT} tokens\\nRemaining: ${REMAINING} tokens\\n\\nRECOMMENDED ACTIONS:\\n1. Compact conversation: /compact\\n2. Increase delegation rate (current: ${DELEGATION_RATE}%)\\n3. Clear unnecessary context\\n\\nProceeding may risk context limit errors.\\n\\nContinue anyway?"
  }
}
EOF
  exit 0
fi

# Warning threshold: 60%
if (( $(echo "$CONTEXT_USAGE >= 60" | bc -l 2>/dev/null || echo 0) )); then
  log "Context warning: ${CONTEXT_USAGE}%"
  echo "💡 [Context Monitor] Context approaching limit (${CONTEXT_USAGE}%). Consider /compact soon." >&2
fi

exit 0
