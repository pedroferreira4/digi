#!/usr/bin/env bash
# setup.sh — Install digi agent skills into Claude Code
# Run this once after cloning the repo: bash setup.sh [profile]
#
# The optional first argument is a profile name (see profiles/<name>.txt).
# Omit it to install every agent (the "work" profile is the default).
#   bash setup.sh            # full install (all agents)
#   bash setup.sh personal   # install only the agents in profiles/personal.txt
#
# You'll be asked for your name during install — it replaces the
# {{USER_NAME}} placeholder baked into each SKILL.md so the crew addresses
# you, not the repo owner.

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

# ── Resolve the profile ───────────────────────────────────────────────────────
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
PROFILES_DIR="$REPO_DIR/profiles"
PROFILE="${1:-work}"
PROFILE_FILE="$PROFILES_DIR/$PROFILE.txt"

# ── Banner ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}digi — Agent Setup${RESET}  ${YELLOW}(profile: $PROFILE)${RESET}"
echo "────────────────────────────────────"
echo ""

if [ ! -f "$PROFILE_FILE" ]; then
  fail "No profile named '$PROFILE' found at $PROFILE_FILE"
  echo ""
  info "Available profiles:"
  for f in "$PROFILES_DIR"/*.txt; do
    [ -e "$f" ] && info "  • $(basename "$f" .txt)"
  done
  echo ""
  exit 1
fi

# ── Ask for the user's name ───────────────────────────────────────────────────
# SKILL.md files ship with a {{USER_NAME}} placeholder instead of a hardcoded
# name. We substitute it into each copied skill below so the crew addresses you
# by name instead of the repo owner's.
read -r -p "  What's your name? " USER_NAME
if [ -z "$USER_NAME" ]; then
  read -r -p "  Name can't be empty — what's your name? " USER_NAME
fi
if [ -z "$USER_NAME" ]; then
  warn "No name provided — skills will keep the {{USER_NAME}} placeholder."
  info "  Re-run this script and enter your name to personalize them."
fi
echo ""

# Replace every {{USER_NAME}} in a file with $USER_NAME, preserving exact
# trailing-newline behaviour (the trailing "x" sentinel survives the command
# substitution that would otherwise eat trailing newlines).
personalize_file() {
  local file="$1"
  local content
  content="$(cat "$file"; printf x)"
  content="${content%x}"
  content="${content//'{{USER_NAME}}'/$USER_NAME}"
  printf '%s' "$content" > "$file"
}

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

# ── Copy each skill in the profile ────────────────────────────────────────────
REPO_SKILLS="$REPO_DIR/skills"

echo ""
info "Installing skills..."
echo ""

INSTALLED=0
FAILED=0
MISSING=0

# Read the profile: one skill-folder name per line, ignoring blanks and # comments
while IFS= read -r line || [ -n "$line" ]; do
  # Strip inline comments and surrounding whitespace
  skill_name="${line%%#*}"
  skill_name="$(echo "$skill_name" | xargs)"
  [ -z "$skill_name" ] && continue

  skill_dir="$REPO_SKILLS/$skill_name"
  target="$SKILLS_DIR/$skill_name"

  if [ ! -d "$skill_dir" ]; then
    warn "$skill_name — listed in profile but no such folder in skills/ (skipping)"
    MISSING=$((MISSING + 1))
    continue
  fi

  # Remove then copy — avoids the macOS cp -r nesting trap on re-runs
  if rm -rf "$target" && cp -r "$skill_dir" "$target" 2>/dev/null; then
    # Personalize the copy: SKILL.md ships with a {{USER_NAME}} placeholder.
    # Substituting after copy keeps the repo's own source files untouched.
    if [ -n "$USER_NAME" ] && [ -f "$target/SKILL.md" ]; then
      personalize_file "$target/SKILL.md"
    fi
    ok "$skill_name"
    INSTALLED=$((INSTALLED + 1))
  else
    fail "$skill_name — could not copy (check permissions on $SKILLS_DIR)"
    FAILED=$((FAILED + 1))
  fi
done < "$PROFILE_FILE"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "────────────────────────────────────"

if [ "$FAILED" -gt 0 ] || [ "$MISSING" -gt 0 ]; then
  warn "$INSTALLED skills installed, $FAILED failed, $MISSING missing from skills/."
else
  ok "$INSTALLED skills installed successfully."
fi

# ── Third-party skill dependencies ────────────────────────────────────────────
# The crew (especially Tai and Sora) invoke external, non-crew skills that live
# in OTHER GitHub repos — they're described in skills-deps.lock.json. We re-fetch
# them here by shallow-cloning each unique repo once and copying the folder that
# contains the skill's SKILL.md into ~/.claude/skills/<name>.
#
# Gating:
#   • Needs `git` on PATH and `python3` (to read the JSON lock). If either is
#     missing we warn and skip — the crew install above still succeeded.
#   • Profile-driven: only fetches deps whose owning persona is active for this
#     profile (see the "profiles" map in the lock file). So `personal` pulls
#     Tai + Sora deps; `work` pulls everything.
#   • Warn-and-continue: a failed clone/copy for one skill never aborts the rest.
#
# NOTE: MCP-backed skills (e.g. Figma design skills) are NOT fully wired by this
# step. Cloning the SKILL.md files does not configure their MCP server — that has
# to be set up separately in Claude Code.
DEPS_LOCK="$REPO_DIR/skills-deps.lock.json"

echo ""
echo "────────────────────────────────────"
info "Third-party skill dependencies..."
echo ""

if [ ! -f "$DEPS_LOCK" ]; then
  warn "No skills-deps.lock.json found — skipping third-party skills."
elif ! command -v git >/dev/null 2>&1; then
  warn "git not found on PATH — skipping third-party skills."
  info "  Install git, then re-run this script to fetch Tai's & Sora's external skills."
elif ! command -v python3 >/dev/null 2>&1; then
  warn "python3 not found — can't read the lock file — skipping third-party skills."
else
  # Emit one "name<TAB>sourceUrl<TAB>skillPath" line per skill needed by this profile.
  DEPS_LIST="$(python3 - "$DEPS_LOCK" "$PROFILE" <<'PY'
import json, sys
lock_path, profile = sys.argv[1], sys.argv[2]
data = json.load(open(lock_path))
personas = set(data.get("profiles", {}).get(profile, []))
# Unknown profile → fetch everything (safest default; matches "work" = all).
for name, e in data.get("skills", {}).items():
    needed_by = set(e.get("neededBy", []))
    if personas and not (needed_by & personas):
        continue
    url = e.get("sourceUrl", "")
    path = e.get("skillPath", "")
    if url and path:
        print(f"{name}\t{url}\t{path}")
PY
)" || DEPS_LIST=""

  if [ -z "$DEPS_LIST" ]; then
    info "No third-party skills needed for profile '$PROFILE'."
  else
    TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/digi-deps.XXXXXX")"
    FETCHED=0
    FETCH_FAILED=0

    # Clone each unique repo once, keyed by a filesystem-safe slug of the URL.
    clone_repo() {
      url="$1"
      slug="$(echo "$url" | tr -c 'A-Za-z0-9' '_')"
      dest="$TMP_ROOT/$slug"
      if [ -d "$dest" ]; then
        return 0   # already cloned this run
      fi
      if git clone --quiet --depth 1 "$url" "$dest" 2>/dev/null; then
        return 0
      fi
      rm -rf "$dest"
      return 1
    }

    while IFS="$(printf '\t')" read -r name url skillpath; do
      [ -z "$name" ] && continue

      if ! clone_repo "$url"; then
        warn "$name — could not clone $url (skipping)"
        FETCH_FAILED=$((FETCH_FAILED + 1))
        continue
      fi

      slug="$(echo "$url" | tr -c 'A-Za-z0-9' '_')"
      src_dir="$TMP_ROOT/$slug/$(dirname "$skillpath")"
      target="$SKILLS_DIR/$name"

      if [ ! -f "$TMP_ROOT/$slug/$skillpath" ]; then
        warn "$name — $skillpath not found in repo (skipping)"
        FETCH_FAILED=$((FETCH_FAILED + 1))
        continue
      fi

      if rm -rf "$target" && cp -r "$src_dir" "$target" 2>/dev/null; then
        ok "$name  (from $url)"
        FETCHED=$((FETCHED + 1))
      else
        warn "$name — could not copy into $SKILLS_DIR (skipping)"
        FETCH_FAILED=$((FETCH_FAILED + 1))
      fi
    done <<EOF
$DEPS_LIST
EOF

    rm -rf "$TMP_ROOT"

    echo ""
    if [ "$FETCH_FAILED" -gt 0 ]; then
      warn "$FETCHED third-party skills fetched, $FETCH_FAILED failed (see warnings above)."
    else
      ok "$FETCHED third-party skills fetched."
    fi
    info "Note: MCP-backed skills (e.g. Figma) still need their MCP server configured in Claude Code."
  fi
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
echo "       /sora  — design, UI components, visual direction"
echo "       /mimi  — career, 1:1 prep, goal tracking"
echo "       /agumon — meeting briefings from transcripts"
echo ""
