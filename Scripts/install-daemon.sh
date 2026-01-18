#!/bin/bash
set -e

echo "Installing FocusBlock Daemon..."
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

if [ ! -f "$PROJECT_ROOT/.build/release/focus-daemon" ]; then
    echo "Error: Daemon binary not found."
    echo "Please build the project first:"
    echo "  cd $PROJECT_ROOT"
    echo "  swift build -c release"
    exit 1
fi

echo "📦 Copying binaries (requires sudo)..."
if ! sudo -n true 2>/dev/null; then
    echo "Please enter your password to install:"
fi
sudo cp "$PROJECT_ROOT/.build/release/focus" /usr/local/bin/
sudo cp "$PROJECT_ROOT/.build/release/focus-daemon" /usr/local/bin/
sudo chmod +x /usr/local/bin/focus /usr/local/bin/focus-daemon

echo "📝 Installing launch agent..."
cp "$PROJECT_ROOT/Resources/com.focusblock.daemon.plist" ~/Library/LaunchAgents/

echo "🔒 Disabling DNS over HTTPS in browsers..."
if "$PROJECT_ROOT/.build/release/focus" daemon disable-doh 2>/dev/null; then
    echo "   DoH disabled successfully"
else
    echo "   ⚠️  Warning: Some browsers may still use DoH"
fi

echo ""
echo "⚠️  Important: Chrome, Arc, and Brave will show 'Managed by your organization'"
echo "   This is normal and indicates DoH has been disabled for website blocking."
echo ""

echo "🚀 Starting daemon..."
launchctl load ~/Library/LaunchAgents/com.focusblock.daemon.plist

sleep 2

if launchctl list | grep -q "com.focusblock.daemon"; then
    echo ""
    echo "✅ FocusBlock Daemon installed successfully!"
    echo ""
    echo "The daemon is now running and will start automatically on login."
    echo ""
    echo "Key changes in this version:"
    echo "  • Browsers are NO LONGER KILLED during sessions"
    echo "  • You can browse normally for work"
    echo "  • Blocked sites won't load (DoH disabled, hosts file now works)"
    echo ""
    echo "Useful commands:"
    echo "  Check status:      launchctl list | grep focusblock"
    echo "  View logs:         tail -f /tmp/focusblock-daemon.log"
    echo "  Verify DoH status: focus daemon verify-doh"
    echo "  Stop daemon:       launchctl unload ~/Library/LaunchAgents/com.focusblock.daemon.plist"
else
    echo ""
    echo "⚠️  Warning: Daemon may not be running. Check logs:"
    echo "  tail /tmp/focusblock-daemon.error.log"
fi
