# digi — Agent System

This repo is the source of truth for Pedro's personal agent system. Each persona is a Claude Code skill stored under `skills/`. The shipped installer **copies** each skill into `~/.claude/skills/` so they're available globally; symlinks are an optional local-dev shortcut (see below).

## Repo Structure

```
digi/
  README.md          # Overview of the system and the crew
  CLAUDE.md          # This file — conventions for working on the system
  index.html         # Visual overview page for new users
  setup.sh           # Installer (macOS/Linux) — copies crew, re-fetches third-party deps
  setup.ps1          # Installer (Windows/PowerShell) — same behaviour as setup.sh
  skills-deps.lock.json  # Pinned third-party (non-crew) skills the installer re-fetches via git
  profiles/          # Install profiles — one skill-folder name per line
    work.txt         # Default profile: the full crew (everything)
    personal.txt     # Lean profile: digi, tai, joe, sora
  skills/
    digi/SKILL.md    # Crew coordinator — routes multi-domain requests to crew as subagents
    izzy/SKILL.md    # Project manager — stress-tests plans, produces scope handoffs
    joe/SKILL.md     # Second brain agent (Obsidian vault)
    matt/SKILL.md    # Web research agent (also searches Confluence/Jira)
    mimi/SKILL.md    # Career agent (1:1s, PDP, goals)
    tai/SKILL.md     # Engineering — code review, implementation, architecture
    sora/SKILL.md    # Design partner — visual direction, UI components
    davis/SKILL.md   # Teaching — concepts, lessons, learning records
    agumon/SKILL.md  # Meeting briefings — transcripts, summaries, action items
    tk/SKILL.md      # Slack agent — channels, threads, search, messages
```

## How Skills Are Installed

The shipped path is **copy**, which works cross-platform:

- **macOS / Linux:** `bash setup.sh [profile]`
- **Windows:** `pwsh ./setup.ps1 [profile]`

Both installers read `profiles/<name>.txt` and copy only the listed skills into `~/.claude/skills/` (`%USERPROFILE%\.claude\skills` on Windows). Because it's a copy — not a symlink — Windows users don't need Developer Mode.

### Profiles

Profiles let the same repo install different subsets on different machines. Each `profiles/<name>.txt` is plaintext, one skill-folder name per line, with `#` comments and blank lines ignored.

- `work.txt` — the **default** (used when no profile is passed): the whole crew.
- `personal.txt` — a lean set: `digi`, `tai`, `joe`, `sora`.

`bash setup.sh` with no argument installs everything. `bash setup.sh personal` installs only the personal set. An unknown profile fails with the list of available profiles; a listed-but-missing skill folder warns and is skipped.

### Third-party skill dependencies

The crew personas invoke **external skills that don't live in this repo** — they're in other people's GitHub repos. Tai calls `improve`, the Vercel skills, `modern-javascript-patterns`; Sora calls `emil-design-eng`, `ui-ux-pro-max`, `ui-animation`, `web-design-guidelines`, and the animation / `better-*` skills; Davis needs `teach`; Izzy needs the `grill-*` skills. These are pinned in **`skills-deps.lock.json`** at the repo root.

The lock file's shape: a top-level `profiles` map (which personas each profile activates), a `skills` map where each entry has `sourceUrl` (git repo), `skillPath` (path to `SKILL.md` inside that repo — the containing folder is what gets copied), and `neededBy` (personas that use it), plus an `unresolved` block for skills that have no git source and must be installed via a plugin/marketplace (`master-review`, `code-review-skill`, `frontend-design`, `pr-review-toolkit:review-pr`).

**Both installers re-fetch these automatically after the crew copy step.** They shallow-clone each unique repo once, copy the skill folder into `~/.claude/skills/<name>`, and clean up temp clones. The step is:

- **Profile-driven** — only skills whose `neededBy` intersects the profile's persona list are fetched (`personal` → Tai + Sora deps; `work` → all). An unknown profile fetches everything.
- **Gated on `git`** — if `git` isn't on PATH, the step warns and skips; the crew install still succeeds. (The bash path also needs `python3` to read the JSON; PowerShell uses `ConvertFrom-Json`.)
- **Warn-and-continue** — a failed clone/copy for one skill never aborts the rest.
- **MCP caveat** — skills backed by an MCP server (e.g. Figma) are *not* fully wired by fetching files; the MCP server still has to be configured in Claude Code. Both scripts print this and carry a code comment saying so.

When you change which external skills a persona depends on, update `skills-deps.lock.json` too. The authoritative source for `sourceUrl`/`skillPath` values is the local store lock at `~/.agents/.skill-lock.json` (do not edit that file — only read from it).

### Local dev shortcut: symlinks

For fast iteration you can symlink a skill folder instead of re-copying after every edit — a symlinked skill goes live the moment you save the file:

```bash
ln -s ~/Documents/Projetos/digi/skills/<name> ~/.claude/skills/<name>
```

This is a convenience for working *on* the system, not how it's shipped or installed on other machines. To check what's currently linked:

```bash
ls -la ~/.claude/skills
```

## Adding a New Persona

1. Create `skills/<name>/SKILL.md` in this repo
2. Add `<name>` to the relevant profile file(s) in `profiles/` — always `profiles/work.txt`, plus `profiles/personal.txt` if it belongs in the lean set
3. Install it — either copy via `bash setup.sh` / `pwsh ./setup.ps1`, or symlink for local dev:
   ```bash
   ln -s ~/Documents/Projetos/digi/skills/<name> ~/.claude/skills/<name>
   ```
4. Add the persona to `README.md` (both crew tables + Personas section + What They Do Together)
5. Commit

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

Work on this repo like any other — branch, edit, commit. If you've symlinked a skill for local dev, changes are live as soon as the file is saved; if you installed by copy, re-run the installer to pick up edits. Either way, committing keeps the history clean and lets you roll back persona changes.
