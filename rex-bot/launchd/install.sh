#!/bin/zsh
# Install Rex launchd agents — run once after cloning/setting up the repo
# Usage: zsh install.sh [uninstall]

PLIST_DIR="$(cd "$(dirname "$0")" && pwd)"
LAUNCH_AGENTS="$HOME/Library/LaunchAgents"

BOT_PLIST="com.digi.rex.bot.plist"
MORNING_PLIST="com.digi.rex.morning.plist"

if [[ "$1" == "uninstall" ]]; then
  echo "Unloading Rex agents..."
  launchctl unload "$LAUNCH_AGENTS/$BOT_PLIST" 2>/dev/null
  launchctl unload "$LAUNCH_AGENTS/$MORNING_PLIST" 2>/dev/null
  rm -f "$LAUNCH_AGENTS/$BOT_PLIST" "$LAUNCH_AGENTS/$MORNING_PLIST"
  echo "Done. Rex is offline."
  exit 0
fi

echo "Installing Rex agents..."

# Copy plists to LaunchAgents
cp "$PLIST_DIR/$BOT_PLIST" "$LAUNCH_AGENTS/"
cp "$PLIST_DIR/$MORNING_PLIST" "$LAUNCH_AGENTS/"

# Load them
launchctl load "$LAUNCH_AGENTS/$BOT_PLIST"
launchctl load "$LAUNCH_AGENTS/$MORNING_PLIST"

echo ""
echo "Rex bot:     always-on, starts on login  →  logs at /tmp/rex-bot.log"
echo "Rex morning: weekdays at 08:00            →  logs at /tmp/rex-morning.log"
echo ""
echo "To test the morning brief now:"
echo "  node /Users/pedro.ferreira4/Documents/Projetos/digi/rex-bot/morning-brief.js"
echo ""
echo "To uninstall: zsh install.sh uninstall"
