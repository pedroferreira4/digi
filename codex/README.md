# Codex support for digi

This folder is a non-active Codex staging area. It does not change the existing Claude setup, and Codex will not automatically load these files unless they are copied or symlinked into a supported Codex location.

## Verdict

The repo is Claude-ready today.

The repo is partly Codex-ready:

- The existing `skills/*/SKILL.md` files are readable by Codex because they have `name` and `description` frontmatter.
- The skill bodies are still Claude-first. They mention Claude slash commands, `~/.claude`, Claude tool names, and Claude MCP tool identifiers.
- There is no active repo-level Codex setup yet, such as `.agents/skills` or a root `AGENTS.md`.

So: usable with Codex after manual installation, but not fully Codex-native yet.

## Codex concepts this repo should target

Codex discovers repo-scoped skills from `.agents/skills` under the current repository path. A skill is a folder with a `SKILL.md` file containing at least `name` and `description`.

Codex discovers persistent repo instructions from `AGENTS.md` files. A root `AGENTS.md` is the right place for repo-wide working agreements and setup notes.

Codex can run subagents, but only when the user explicitly asks for delegation, parallel agents, or the Digi team. The `digi` coordinator should not silently spawn subagents for ordinary single-agent tasks.

Plugins are the right packaging layer if this crew later needs to bundle skills with Slack, Atlassian, Obsidian, or other connectors.

## Recommended path

Keep Claude and Codex separate at first:

1. Leave the current `skills/`, `README.md`, `CLAUDE.md`, and `setup.sh` as the Claude source of truth.
2. Use `codex/skills/digi-team/SKILL.md` as the Codex-native wrapper skill.
3. When ready to activate it for the repo, copy or symlink `codex/skills/digi-team` into `.agents/skills/digi-team`.
4. Later, if needed, create Codex-native versions of each persona under `.agents/skills/<persona>` with Claude-specific wording removed.

## Activation options

Repo-local activation:

```bash
mkdir -p .agents/skills
ln -s ../../codex/skills/digi-team .agents/skills/digi-team
```

Personal activation:

```bash
mkdir -p ~/.agents/skills
ln -s "$(pwd)/codex/skills/digi-team" ~/.agents/skills/digi-team
```

Either option may require restarting Codex or starting a new Codex session before the skill appears.

## What a full Codex-native conversion should fix

- Remove Claude-only `allowed-tools` frontmatter from Codex copies.
- Replace `/joe`, `/tai`, and similar slash-command language with `$joe`, `$tai`, or plain explicit prompts.
- Replace `~/.claude` config paths with Codex-friendly paths or session prompts.
- Replace `Agent` and `Skill` tool references with Codex concepts: skills, subagents, local tools, MCP servers, and plugins.
- Replace `mcp__claude_ai_*` tool names with generic connector requirements.
- Add optional `agents/openai.yaml` metadata if these skills should appear nicely in Codex UI.

