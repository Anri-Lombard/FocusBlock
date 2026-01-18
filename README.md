# FocusBlock

A macOS focus session manager that hard-blocks distracting websites during timed focus sessions.

> **Note**: I built this for myself to keep focus on what matters. It's a work in progress, built mainly with Claude Opus 4.5.

## Features

- 🔒 **Hard Blocking**: Multi-layer blocking via /etc/hosts modification + DNS cache flushing
- ⏰ **Timed Sessions**: Default 90-minute sessions (configurable)
- 📊 **Rich Statistics**: GitHub-style heatmap, streaks, and analytics
- 🎯 **Default Blocks**: YouTube, X (Twitter), Reddit, LinkedIn
- 💪 **Commitment Mode**: Cannot stop sessions early
- 🔥 **Streak Tracking**: Track daily focus streaks

## Installation

### Prerequisites

- macOS Big Sur (11.0) or later
- Swift 5.9+
- Administrator access (for sudo privileges)

### Build from Source

```bash
cd ~/Desktop/FocusBlock
swift build -c release
sudo cp .build/release/focus /usr/local/bin/
```

## Quick Start

```bash
# Start a 90-minute focus session (default)
focus start

# Start a custom duration session
focus start 120  # 2 hours

# Check session status
focus status

# View statistics
focus stats

# Stop session (only after duration expires)
focus stop
```

## Commands

### `focus start [duration] [--sites <sites>]`
Start a new focus session
- `duration`: Optional session duration in minutes (default: 90)
- `--sites`: Optional comma-separated list of sites to block

**Examples:**
```bash
focus start                     # 90-minute session with default sites
focus start 60                  # 1-hour session
focus start 120 --sites youtube.com,reddit.com
```

### `focus stop`
Stop the active session (only after session duration has expired)

### `focus status`
Display current session progress with a visual progress bar

### `focus stats [--range <range>]`
View comprehensive statistics including:
- Current and longest streaks
- Total focus time
- Sessions this week
- Average session duration
- GitHub-style activity heatmap

### `focus history [--limit <N>]`
Show recent session history (default: 10 sessions)

### `focus config`
Manage configuration settings

**Subcommands:**
```bash
focus config get                           # View all settings
focus config get default_duration          # View specific setting
focus config set default_duration 120      # Set default to 120 minutes
focus config reset                         # Reset to defaults
```

## Default Blocked Sites

When starting a session without the `--sites` flag, the following sites are blocked:

- **YouTube**: youtube.com, www.youtube.com, m.youtube.com, youtu.be
- **X/Twitter**: x.com, www.x.com, twitter.com, www.twitter.com, mobile.twitter.com
- **Reddit**: reddit.com, www.reddit.com, old.reddit.com, new.reddit.com
- **LinkedIn**: linkedin.com, www.linkedin.com

## How It Works

FocusBlock uses a multi-layer blocking strategy:

1. **Hosts File Modification**: Adds entries to `/etc/hosts` redirecting blocked domains to 127.0.0.1
2. **DNS Cache Flushing**: Clears DNS cache to ensure immediate effect
3. **Session Lock-in**: Prevents early termination of focus sessions
4. **Database Tracking**: Stores all sessions and statistics in SQLite

## Configuration

Configuration is stored at: `~/Library/Application Support/FocusBlock/config.json`

Available settings:
- `default_duration`: Default session duration in minutes (default: 90)
- `default_sites`: Array of default sites to block

## Database

Session data and statistics are stored at:
`~/Library/Application Support/FocusBlock/focusblock.db`

## Development Status

**✅ Complete**
- Core library (session management, blocking engine, stats tracking)
- CLI tool with all commands
- Configuration management
- Statistics visualization (GitHub-style heatmap)
- Background daemon for session monitoring
- Hosts file integrity checking
- Launch agent setup

## Project Structure

```
FocusBlock/
├── Sources/
│   ├── FocusBlockCore/      # Shared library
│   │   ├── Models.swift
│   │   ├── Configuration.swift
│   │   ├── SessionManager.swift
│   │   ├── BlockEngine.swift
│   │   ├── StatsTracker.swift
│   │   └── Database/
│   │       └── Schema.swift
│   ├── FocusCLI/            # Terminal command
│   │   ├── main.swift
│   │   ├── Utilities.swift
│   │   ├── Commands/
│   │   └── Rendering/
│   └── FocusDaemon/         # Background daemon
├── Tests/
└── Package.swift
```

## Security & Privacy

- Requires sudo for hosts file modification (one-time prompt per session)
- All data stored locally (no cloud sync)
- Open source and auditable
- No network requests or telemetry

## License

MIT License - See LICENSE file for details

## Contributing

Contributions welcome! Please open an issue or PR.

## Author

Built with Swift for macOS

---

**Note**: This tool modifies your `/etc/hosts` file and requires sudo privileges. Always review code before granting elevated permissions.
