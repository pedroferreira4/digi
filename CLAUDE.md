# digi — Agent System

This repo is the source of truth for Pedro's personal agent system. Each persona is a Claude Code skill stored under `skills/` and symlinked into `~/.claude/skills/` so they're available globally.

## Repo Structure

```
digi/
  README.md          # Overview of the system and the crew
  CLAUDE.md          # This file — conventions for working on the system
  index.html         # Visual overview page for new users
  skills/
    digi/SKILL.md    # Crew coordinator — routes multi-domain requests to crew as subagents
    joe/SKILL.md     # Second brain agent (Obsidian vault)
    matt/SKILL.md    # Web research agent
    mimi/SKILL.md    # Career agent (1:1s, PDP, goals)
    tai/SKILL.md     # Engineering — code review, implementation, architecture
    luna/SKILL.md    # Design partner — visual direction, UI components
    rex/SKILL.md     # Meetings — calendar, briefs, transcripts
```

## How Skills Are Wired

Each `skills/<name>/` folder is symlinked from `~/.claude/skills/<name>`. Editing a file here changes the live skill immediately — no copy step needed.

To verify the symlinks are intact:
```bash
ls -la ~/.claude/skills/joe ~/.claude/skills/matt ~/.claude/skills/mimi ~/.claude/skills/tai ~/.claude/skills/luna ~/.claude/skills/rex
```

## Adding a New Persona

1. Create `skills/<name>/SKILL.md` in this repo
2. Add the symlink:
   ```bash
   ln -s ~/Documents/Projetos/digi/skills/<name> ~/.claude/skills/<name>
   ```
3. Add the persona to `README.md` (crew table + What They Do Together section)
4. Commit

## SKILL.md Conventions

Every persona file must follow this structure:

```markdown
---
name: <name>           # lowercase, matches folder name
description: |
  One paragraph describing the persona and domain.
  Use when: <trigger conditions>
allowed-tools: [...]   # only tools the persona actually needs
---

# <Name> — <Role>

> [!<name>]
> **<Name> here.** <Default opener line>

<Identity paragraph — who they are, tone, perspective>

## <Domain section — what they know, where they work>

## What <Name> Does
<Structured breakdown of capabilities>

## <Name>'s Personality
<Voice, quirks, how they open responses, what they won't do>
```

## Persona Callout Format

Every persona opens responses with an Obsidian-style callout:
```
> [!<name>] **<Name> here.**
```

This makes it immediately clear which agent is responding, regardless of which repo or context you're in.

## Committing Changes

Work on this repo like any other — branch, edit, commit. Since skills are symlinked, changes are live as soon as the file is saved, but committing keeps the history clean and lets you roll back persona changes.
