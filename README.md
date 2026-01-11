# SwiftBar Runner Monitor

A macOS menu bar plugin to monitor and control GitHub Actions self-hosted runners.

![screenshot](screenshot.png)

## Features

- **Real-time status** - See runner status at a glance (●/○)
- **Job monitoring** - View running and recent workflow jobs
- **Notifications** - Get notified when new jobs start
- **Runner control** - Start/stop runner from menu bar
- **Configurable refresh** - 5s / 10s / 30s / 60s intervals
- **Launch at login** - Toggle autostart

## Menu Bar Icons

| Icon | Status |
|------|--------|
| ○ | Runner stopped |
| ● | Runner idle |
| ● N | N jobs running |

## Requirements

- [SwiftBar](https://github.com/swiftbar/SwiftBar) or [xbar](https://xbarapp.com/)
- [GitHub CLI](https://cli.github.com/) (`gh`)
- GitHub Actions self-hosted runner

## Installation

### 1. Install SwiftBar

```bash
brew install --cask swiftbar
```

### 2. Install GitHub CLI

```bash
brew install gh
gh auth login
```

### 3. Install Plugin

```bash
# Download plugin
curl -o ~/Library/Application\ Support/SwiftBar/Plugins/runner.10s.sh \
  https://raw.githubusercontent.com/fkysly/swiftbar-runner/main/runner.10s.sh

# Make executable
chmod +x ~/Library/Application\ Support/SwiftBar/Plugins/runner.10s.sh
```

### 4. Configure

Create config file:

```bash
mkdir -p ~/.config/swiftbar-runner
cat > ~/.config/swiftbar-runner/config << 'EOF'
# Required
REPO="owner/repo"
SERVICE_NAME="actions.runner.OWNER-REPO.MACHINE-NAME"
RUNNER_DIR="$HOME/actions-runner"

# Optional
GH="/opt/homebrew/bin/gh"
EOF
```

To find your service name:
```bash
launchctl list | grep actions.runner
```

## Configuration Options

| Variable | Required | Description |
|----------|----------|-------------|
| `REPO` | Yes | GitHub repository (e.g., `owner/repo`) |
| `SERVICE_NAME` | Yes | launchd service name |
| `RUNNER_DIR` | Yes | Path to runner directory |
| `GH` | No | Path to `gh` CLI (default: auto-detect) |

## License

MIT
