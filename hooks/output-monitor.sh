#!/bin/bash
# PostToolUse Hook: Large Output Detection & Delegation
# Location: $HOME/.local/bin/output-monitor.sh
# Purpose: Detect large tool outputs and suggest summarization via delegation

set -euo pipefail

# Read stdin JSON
INPUT=$(cat)

# Extract tool information
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "unknown"')
TOOL_RESULT=$(echo "$INPUT" | jq -r '.tool_result // ""')
OUTPUT_SIZE=${#TOOL_RESULT}
LARGE_THRESHOLD=10000  # 10KB = ~2500 tokens

# Logging
log() {
  echo "[output-monitor] $*" >&2
}

log "PostToolUse for $TOOL_NAME, output size: ${OUTPUT_SIZE} bytes"

# Monitor specific tools for large outputs
if [[ "$TOOL_NAME" =~ ^(Grep|Glob|Read|Bash)$ ]]; then
  if (( OUTPUT_SIZE > LARGE_THRESHOLD )); then
    ESTIMATED_TOKENS=$((OUTPUT_SIZE / 4))

    echo "" >&2
    echo "[Context Debt] Large output from $TOOL_NAME:" >&2
    echo "   Size: ${OUTPUT_SIZE} chars (~${ESTIMATED_TOKENS} tokens)" >&2
    echo "" >&2
    echo "   💡 OPTIMIZATION: Delegate analysis to reduce context:" >&2
    echo "      mcp__claude-orchestrator__delegate_task({" >&2
    echo "        task_type: 'research'," >&2
    echo "        prompt: 'Analyze and summarize: [tool output]'" >&2
    echo "      })" >&2
    echo "" >&2
    echo "   Benefits:" >&2
    echo "   • Saves ~${ESTIMATED_TOKENS} tokens in context" >&2
    echo "   • Reduces context debt" >&2
    echo "   • Uses Grok for efficient summarization" >&2
    echo "" >&2

    # Update context tracking
    SHARED_STATE="$HOME/.context/shared-budget.json"
    if [ -f "$SHARED_STATE" ]; then
      log "Updating context debt in shared state"

      # Read current values
      CURRENT_DEBT=$(jq -r '.context_tracking.context_debt // 0' "$SHARED_STATE" 2>/dev/null || echo "0")
      CURRENT_COUNT=$(jq -r '.context_tracking.large_outputs_count // 0' "$SHARED_STATE" 2>/dev/null || echo "0")

      # Calculate new values
      NEW_DEBT=$((CURRENT_DEBT + ESTIMATED_TOKENS))
      NEW_COUNT=$((CURRENT_COUNT + 1))

      log "Context debt: ${CURRENT_DEBT} → ${NEW_DEBT} tokens"

      # Update state file
      TEMP_FILE=$(mktemp)
      jq ".context_tracking.context_debt = $NEW_DEBT | .context_tracking.large_outputs_count = $NEW_COUNT" "$SHARED_STATE" > "$TEMP_FILE" 2>/dev/null && mv "$TEMP_FILE" "$SHARED_STATE" || rm -f "$TEMP_FILE"
    fi
  fi
fi

exit 0
