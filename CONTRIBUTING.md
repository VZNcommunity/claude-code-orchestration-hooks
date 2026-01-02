# Contributing to Claude Code Orchestration Hooks

Thank you for your interest in contributing to this project! This document provides guidelines for contributing.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [How to Contribute](#how-to-contribute)
- [Code Style](#code-style)
- [Testing](#testing)
- [Submitting Changes](#submitting-changes)

## Code of Conduct

- Be respectful and constructive
- Focus on technical accuracy over personal preferences
- Welcome feedback and criticism on code, not people
- Help others learn and grow

## Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/YOUR-USERNAME/claude-code-orchestration-hooks.git
   cd claude-code-orchestration-hooks
   ```
3. **Add upstream remote**:
   ```bash
   git remote add upstream https://github.com/VZNcommunity/claude-code-orchestration-hooks.git
   ```

## Development Setup

### Prerequisites

- Arch Linux (or systemd-based distribution)
- Bash 5+
- jq (JSON processor)
- Claude Code installed
- Git

### Install Development Version

```bash
# Install hooks to test locally
./install.sh

# Verify installation
systemctl --user list-timers | grep claude
~/.local/bin/claude-hooks-updater.sh --verify
```

## How to Contribute

### Reporting Bugs

1. **Check existing issues** first
2. **Create a new issue** with:
   - Clear, descriptive title
   - Steps to reproduce
   - Expected vs actual behavior
   - System information (OS, Claude Code version)
   - Relevant logs or error messages

### Suggesting Enhancements

1. **Check existing issues/PRs** for similar suggestions
2. **Create an issue** describing:
   - The problem you're trying to solve
   - Your proposed solution
   - Alternative approaches considered
   - Potential drawbacks or considerations

### Pull Requests

1. **Create a feature branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes** following [Code Style](#code-style)

3. **Test thoroughly**:
   - Test hook scripts manually
   - Verify systemd timers work correctly
   - Check for shell script errors with `shellcheck`

4. **Commit your changes**:
   ```bash
   git add .
   git commit -m "type: brief description

   Detailed explanation of changes.

   - Bullet point 1
   - Bullet point 2"
   ```

   Commit types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`

5. **Push to your fork**:
   ```bash
   git push origin feature/your-feature-name
   ```

6. **Create Pull Request** on GitHub

## Code Style

### Shell Scripts

- **Shebang**: Use `#!/usr/bin/env bash` or `#!/bin/bash`
- **Error handling**: Use `set -euo pipefail` at the top
- **Variables**:
  - UPPERCASE for constants and environment variables
  - lowercase for local variables
- **Quoting**: Always quote variables: `"$VARIABLE"`
- **Functions**: Use descriptive names, document complex logic
- **Comments**: Explain *why*, not *what*

**Example:**
```bash
#!/usr/bin/env bash
# Purpose: Brief description
# Location: $HOME/.local/bin/script-name.sh

set -euo pipefail

# Constants
readonly STATE_FILE="$HOME/.context/state.json"

# Main function
main() {
    local input_data
    input_data=$(cat)

    # Process input (comment explains why, not what)
    process_data "$input_data"
}

main "$@"
```

### JSON Files

- Use 2-space indentation
- No trailing commas
- Validate with `jq` before committing:
  ```bash
  jq empty < file.json
  ```

### Systemd Units

- Use `%h` for home directory references
- Include `Description=` and `Documentation=`
- Set resource limits (`MemoryMax`, `CPUQuota`)
- Use `StandardOutput=journal` for logging

## Testing

### Manual Testing

1. **Hook Scripts**:
   ```bash
   # Test hook directly
   echo '{"tool_name":"Write","tool_input":{}}' | ~/.local/bin/delegation-check.sh
   ```

2. **Systemd Services**:
   ```bash
   # Test service execution
   systemctl --user start claude-state-validator.service
   journalctl --user -u claude-state-validator.service -n 50
   ```

3. **Installation Scripts**:
   ```bash
   # Test in clean environment (VM recommended)
   ./install.sh
   ./uninstall.sh
   ```

### Validation Tools

```bash
# Check shell scripts
shellcheck hooks/*.sh *.sh

# Validate JSON
jq empty < settings.minimal.json
jq empty < examples/*.json

# Check systemd syntax
systemd-analyze verify systemd/*.service
```

## Submitting Changes

### PR Checklist

- [ ] Code follows style guidelines
- [ ] Tested manually on clean system
- [ ] No hardcoded paths (use `$HOME`, `%h`)
- [ ] Shell scripts pass `shellcheck`
- [ ] JSON files validated with `jq`
- [ ] Updated README if needed
- [ ] Updated CHANGELOG if significant change
- [ ] Commit messages are clear and descriptive

### Review Process

1. Maintainers will review your PR
2. Address feedback through additional commits
3. Once approved, maintainers will merge

### After Merge

1. **Pull latest changes**:
   ```bash
   git checkout master
   git pull upstream master
   ```

2. **Delete feature branch**:
   ```bash
   git branch -d feature/your-feature-name
   ```

## Project Structure

```
claude-code-orchestration-hooks/
├── hooks/              # Hook scripts (9 files)
├── systemd/            # Systemd units (timers + services)
├── examples/           # Example state file schemas
├── docs/               # Additional documentation
├── config/             # Configuration files
├── install.sh          # Installation script
├── uninstall.sh        # Uninstallation script
├── README.md           # Main documentation
├── CHANGELOG.md        # Version history
├── CONTRIBUTING.md     # This file
└── LICENSE             # MIT License
```

## Getting Help

- **Issues**: Check existing issues or create a new one
- **Discussions**: Use GitHub Discussions for questions
- **Documentation**: See README.md and docs/

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

Thank you for contributing to Claude Code Orchestration Hooks!
