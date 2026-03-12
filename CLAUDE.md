# CLAUDE.md

This repo is a personal zsh profile / dotfiles repo for Sam Barker (GitHub: SamBarker).

## Structure

- `bin/` — personal scripts, symlinked or on PATH
- `custom/` — zsh customisations
- `zshrc` — main zsh config

## In-Progress Work: weekly-contributions.sh

`bin/weekly-contributions.sh` fetches a raw summary of GitHub contributions across the
`kroxylicious` org for the last 7 days and writes them to 4 files under a dated output
directory (`~/contributions/YYYY-MM-DD/` by default).

### What it produces

```
~/contributions/2026-03-12/
├── prs-authored.md
├── issues-opened.md
├── prs-reviewed.md
└── commented-on.md
```

### Usage

```bash
weekly-contributions.sh [--user LOGIN] [--since YYYY-MM-DD] [--until YYYY-MM-DD] [--outdir PATH]
```

Defaults: `--user SamBarker`, last 7 days, `~/contributions/YYYY-MM-DD/`.

### Next Step: LLM summarisation

The goal is to add a summarise step that pipes the 4 output files through an LLM to produce
a themed grouping (like the example in `contributions/2026-03-05--2026-03-12.md` in the
kroxylicious proxy repo).

**Preferred tool:** Simon Willison's `llm` CLI (`brew install llm` — already installed).

**Blocker:** Sam uses Claude hosted via a corporate Google Cloud Vertex AI setup, not direct
Anthropic API. We don't yet know:

1. How auth works — gcloud ADC, service account key, corporate proxy token?
2. Whether there's a base URL / endpoint to point `llm` at
3. Whether `llm-vertex` plugin or something else is the right approach

**Fallback:** Use `claude -p` (the Claude Code CLI) instead, since it already has the right
auth configured. Downside: ties the script to Claude Code being installed.

### Relevant `llm` plugins to investigate

- `llm-anthropic` — direct Anthropic API (won't work for Vertex)
- `llm-vertex` — Google Cloud Vertex AI (likely the right one for Claude-on-Vertex)
- Custom base URL config — `llm` supports `OPENAI_API_BASE` style overrides for some models

### Example summarisation command (once wired up)

```bash
cat ~/contributions/2026-03-12/*.md | llm -m claude-sonnet-4-6 \
  "These are my GitHub contributions for the week across the kroxylicious org.
   Group them into themes and write a short summary of the key work in each theme."
```
