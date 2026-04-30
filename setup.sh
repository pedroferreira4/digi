#!/usr/bin/env bash
# setup.sh — Install digi agent skills into Claude Code
# Run this once after cloning the repo: bash setup.sh

set -e

# ── Colours ───────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
RESET='\033[0m'
BOLD='\033[1m'

ok()   { echo -e "${GREEN}  ✓${RESET} $1"; }
info() { echo -e "  $1"; }
warn() { echo -e "${YELLOW}  !${RESET} $1"; }
fail() { echo -e "${RED}  ✗${RESET} $1"; }

# ── Banner ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}digi — Agent Setup${RESET}"
echo "────────────────────────────────────"
echo ""

# ── Find the target skills directory ─────────────────────────────────────────
CLAUDE_DIR="$HOME/.claude"
SKILLS_DIR="$CLAUDE_DIR/skills"

if [ -d "$CLAUDE_DIR" ]; then
  ok "Found Claude Code at $CLAUDE_DIR"
else
  warn "Could not find Claude Code at $CLAUDE_DIR"
  echo ""
  info "If you've already installed Claude Code, enter the path to its data folder."
  info "It's usually something like: /Users/yourname/.claude/skills"
  info "Leave blank to cancel."
  echo ""
  read -r -p "  Skills folder path: " CUSTOM_PATH

  if [ -z "$CUSTOM_PATH" ]; then
    echo ""
    fail "No path provided. Exiting."
    echo ""
    info "Install Claude Code first, then run this script again."
    info "Download: https://claude.ai/code"
    echo ""
    exit 1
  fi

  # Expand ~ in case the user typed it
  CUSTOM_PATH="${CUSTOM_PATH/#\~/$HOME}"
  SKILLS_DIR="$CUSTOM_PATH"
fi

# ── Create skills directory if needed ────────────────────────────────────────
if [ ! -d "$SKILLS_DIR" ]; then
  mkdir -p "$SKILLS_DIR"
  ok "Created skills folder at $SKILLS_DIR"
else
  info "Installing into $SKILLS_DIR"
fi

# ── Copy each skill ───────────────────────────────────────────────────────────
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_SKILLS="$REPO_DIR/skills"

echo ""
info "Installing skills..."
echo ""

INSTALLED=0
FAILED=0

for skill_dir in "$REPO_SKILLS"/*/; do
  skill_name="$(basename "$skill_dir")"
  target="$SKILLS_DIR/$skill_name"

  # Remove then copy — avoids the macOS cp -r nesting trap on re-runs
  if rm -rf "$target" && cp -r "$skill_dir" "$target" 2>/dev/null; then
    ok "$skill_name"
    INSTALLED=$((INSTALLED + 1))
  else
    fail "$skill_name — could not copy (check permissions on $SKILLS_DIR)"
    FAILED=$((FAILED + 1))
  fi
done

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "────────────────────────────────────"

if [ "$FAILED" -gt 0 ]; then
  warn "$INSTALLED skills installed, $FAILED failed."
else
  ok "$INSTALLED skills installed successfully."
fi

echo ""
echo -e "${BOLD}You're all set. Here's what to do next:${RESET}"
echo ""
echo "  1. Open Claude Code (the desktop app, or run 'claude' in a terminal)"
echo "  2. Start a new conversation"
echo "  3. Type one of these to activate an agent:"
echo ""
echo "       /joe   — notes and knowledge (asks for your Obsidian vault on first use)"
echo "       /matt  — web research and documentation"
echo "       /tai   — coding, code review, architecture"
echo "       /luna  — design, UI components, visual direction"
echo "       /mimi  — career, 1:1 prep, goal tracking"
echo "       /rex   — meetings and calendar (requires Microsoft 365 connector)"
echo ""
