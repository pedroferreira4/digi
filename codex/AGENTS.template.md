# AGENTS.md template for digi in Codex

Use this file as the starting point for a root-level `AGENTS.md` when the repo is ready to make Codex support active. Do not copy it automatically unless Pedro asks.

## Repository purpose

This repo maintains Pedro's Digi agent crew. The existing `skills/` directory is Claude-first. The `codex/` directory contains Codex-facing guidance and staging artifacts.

## Editing rules

- Do not edit existing Claude files unless explicitly asked: `README.md`, `CLAUDE.md`, `setup.sh`, and `skills/*/SKILL.md`.
- Prefer additive Codex work under `codex/` or `.agents/`.
- Keep Claude and Codex setup paths separate.
- If converting a persona for Codex, preserve the persona identity and behavior, but rewrite tool names and activation instructions for Codex.

## Codex skill rules

- Codex skill frontmatter should include only `name` and `description`.
- Put trigger conditions in `description`, because Codex uses it before loading the full body.
- Keep `SKILL.md` concise. Move large reference material into `references/` files if needed.
- Use `.agents/skills` for repo-scoped skills when activation is desired.

## Digi crew behavior in Codex

- Treat "use Digi", "use the Digi team", "route this through the crew", or "use parallel agents" as permission to coordinate crew-style work.
- Do not spawn Codex subagents for ordinary tasks unless the user explicitly asks for delegation, the Digi team, or parallel agent work.
- When acting as a persona, read the relevant persona source in `skills/<name>/SKILL.md` first.
- If a persona references unavailable external tools, say what is missing and continue with the best available local workflow.

## External connectors

Slack, Atlassian, Obsidian, Zoom, and similar systems require the matching Codex plugin, MCP server, connector, or filesystem permission. Do not assume Claude MCP tool names exist in Codex.

