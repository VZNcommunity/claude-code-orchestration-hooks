---
name: Bug Report
about: Report a bug or unexpected behavior
title: '[BUG] '
labels: bug
assignees: ''
---

## Description

A clear and concise description of the bug.

## Environment

- **OS:** [e.g., Arch Linux, Ubuntu 22.04]
- **systemd version:** [e.g., 255]
- **Bash version:** [e.g., 5.2]
- **Claude Code version:** [e.g., 0.1.0]
- **Hook version:** [e.g., v1.1.0]

## Steps to Reproduce

1.
2.
3.

## Expected Behavior

What you expected to happen.

## Actual Behavior

What actually happened.

## Logs

Please provide relevant logs:

```bash
# Check timer status
systemctl --user status claude-context-monitor.timer

# View service logs
journalctl --user -u claude-context-monitor.service -n 50

# Check hook integrity
~/.local/bin/claude-hooks-updater.sh --verify
```

<details>
<summary>Logs output</summary>

```
Paste logs here
```

</details>

## Configuration

**~/.claude/settings.json hooks section:**
```json
Paste your hooks configuration here
```

**State files:**
- [ ] ~/.context/shared-budget.json exists
- [ ] ~/.context/search-cache.json exists

## Additional Context

Any other information that might be helpful.
