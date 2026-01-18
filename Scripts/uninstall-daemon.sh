#!/bin/bash

echo "Uninstalling FocusBlock Daemon..."
echo ""

echo "🛑 Stopping daemon..."
launchctl unload ~/Library/LaunchAgents/com.focusblock.daemon.plist 2>/dev/null || true

sleep 1

echo "🔓 Restoring DNS over HTTPS settings..."
if /usr/local/bin/focus daemon enable-doh 2>/dev/null; then
    echo "   DoH settings restored"
else
    echo "   ⚠️  Could not restore DoH (may not have been disabled)"
fi

echo "🗑️  Removing files..."
rm -f ~/Library/LaunchAgents/com.focusblock.daemon.plist
sudo rm -f /usr/local/bin/focus-daemon

echo "🧹 Cleaning up logs and state..."
rm -f /tmp/focusblock-daemon.log
rm -f /tmp/focusblock-daemon.error.log
rm -f ~/.config/focusblock/doh-state.json

echo ""
echo "✅ FocusBlock Daemon uninstalled successfully"
echo ""
echo "Note: Browser DoH settings have been restored to their original state."
