# Global Claude Code Configuration

This file provides default guidance to Claude Code (claude.ai/code) for all projects.

## Test-Driven Development and Commit Discipline

### PRs vs Commits

**PRs tell a story**: a PR delivers something — fixes a bug, adds a capability, pays down debt. The PR description explains what changed and why at the story level.

**Commits are the coherent steps in that arc**: each commit is one subject fully treated. It should be describable in a single sentence. If you can't describe it in one sentence, it's probably too big.

### Coding Rhythm: Red, Green, Refactor

Work in small cycles at the code level:

1. Write one failing test — failing to compile is **NOT** a Red test; add stubs first so it compiles and fails for the right reason
2. Apply the simplest production code that makes it pass
3. Write the next test to force the design to handle another case
4. Sophisticate the production code to pass it
5. Refactor when the shape of the design becomes clear

This is a **coding rhythm, not a commit rhythm**. Commit when a subject is complete, not after every assertion.

### Commit Boundaries

A commit is one subject fully treated: the production code and the tests that exercise it (happy path, edge cases, error cases, whatever that subject needs). **The test suite must be green after every commit.**

**DO NOT:**
- Separate tests from the production code that makes them pass across different commits
- Create commits based on technical type: "add all tests", "add all production code"
- When applying the same change to N independent subjects (e.g. 6 mappers, 4 handlers): commit all N tests RED then all N fixes GREEN — this is still a horizontal slice

**DO:**
- Commit per subject: if fixing the same bug in 6 mappers, commit 1 = regression test(s) + fix for mapper 1, commit 2 = regression test(s) + fix for mapper 2, etc.
- Refactor in its own commit after tests pass, when the refactoring is non-trivial

### Commit Message Format

Give a reviewer enough context to understand the step without reading the diff.

```
<What changed and why>

<Optional: Technical details>

Assisted-by: Claude ${MODEL_NAME} <noreply@anthropic.com>
```

Good examples:
- "Verify Helm chart passes linting"
- "Validate Kafka StatefulSet renders with correct replicas"
- "Refactor Helm execution into reusable utility"

Bad examples:
- "Add HelmUtils.java"
- "Add tests"
- "WIP"

### PR Title Format

PR titles **MUST** follow [Conventional Commits](https://www.conventionalcommits.org/) — these become the squash-merge message and drive changelogs.

```
<type>(<optional scope>): <description>
```

**Types:** `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `perf`

**Scopes** (optional): module or area relevant to the project

PR bodies should follow the project's PR template if one exists.

## Git Workflow

- **YOU MUST NEVER commit directly to `main`.** All work happens on feature branches. All changes reach `main` via pull request. Create a feature branch before making any commits.
- All branches should start from `upstream/main` unless otherwise requested! If the current branch is not `**/main` then prompt for a base but, default to `upstream/main`
- 
### Working with Claude

Prefer simple, minimal solutions. Don't over-engineer. If a problem can be solved with a config change or env var, don't write Java code. Propose the simplest approach first.

**After asking Claude to implement a feature:**

1. Ask: "What's the first subject we can treat completely?"
2. Implement that subject — tests + production code — and commit it
3. Ask: "What's the next subject?"
4. Repeat

**If Claude produces too much at once:**
- Stop Claude and say: "That's too much. Let's break this into one subject per commit."
- Claude will help you identify the subject boundaries

Do not create PRs, push branches, or post GitHub comments unless explicitly asked. When in doubt, ask before taking actions that are hard to undo.

### Refactoring Policy

- Refactoring previous work is GOOD and EXPECTED
- Each refactoring should be its own commit
- Tests must still pass after refactoring
- Refactoring commits should clearly state what improved

### Red Flags

If Claude presents:
- ❌ "I'll add all the tests first, then fix the production code" — horizontal slice
- ❌ "I've updated all 6 mappers / handlers / services..." in a single commit when each is an independent subject
- ❌ A commit that can't be described in one sentence

Stop and request incremental steps per subject.

## Shell Environment

My machine runs macOS with zsh as the login shell. `/bin/bash` is bash 3.2 (the macOS system bash).

**Host-run scripts** (anything invoked from my machine — orchestration, CI helpers, local tooling)
must be bash 3.2 compatible. No bash 4+ features: no `mapfile`, no `${var,,}`/`${var^^}`,
no `declare -A` associative arrays.

Use the `${ARRAY[@]+"${ARRAY[@]}"}` idiom for safe empty array expansion under `set -u`.

**Container-run scripts** (scripts that execute inside Docker/Kubernetes containers) may use bash 4+
features freely — Linux containers ship with a modern bash.

## GitHub API Patterns

Always use `/opt/homebrew/bin/gh` (see 1Password note below). Key endpoint shapes — get
these right before calling, the PR number is always required in the path:

```bash
# Reply to a review thread (note: PR number required, NOT just /pulls/comments/...)
gh api repos/OWNER/REPO/pulls/PR_NUMBER/comments/COMMENT_ID/replies \
  --method POST --field body="..."

# Create a review with inline comments
gh api repos/OWNER/REPO/pulls/PR_NUMBER/reviews \
  --method POST \
  --field commit_id="SHA" \
  --field event="COMMENT" \
  --field body="..." \
  --field "comments[][path]=..." \
  --field "comments[][line]=NNN" \
  --field "comments[][side]=RIGHT" \
  --field "comments[][body]=..."

# The comment ID for replying is the databaseId of the first comment in a thread,
# NOT the GraphQL node id. Use --jq '.databaseId' or check the REST API response.
```

## 1Password and `gh` CLI

`gh` is aliased to `op plugin run -- gh`. The 1Password prompt appears and can be approved, but `op` then fails with `interactive IO not available` — likely a bug in `op plugin run` post-authentication when no TTY is attached.

**Workaround:** Use the real binary directly: `/opt/homebrew/bin/gh` instead of `gh`.

## Git Workflow Defaults

- Use `gnb <branch-name>` instead of `git checkout -b <branch-name>` when creating new branches. 
  This alias syncs the fork with upstream before branching.      
- All commits must be signed off with DCO: `git commit -s`
- Follow conventional commit format when applicable
- Each commit should be atomic and independently revertible
- Push frequently to enable collaboration

## Token Efficiency

### Prefer Structured Tools Over Bash

Always prefer Claude Code's built-in structured tools over bash equivalents — they return minimal, structured output and consume fewer tokens:

- Use `Glob` instead of `find` or `ls`
- Use `Grep` instead of `grep` or `rg` in bash
- Use `Read` instead of `cat`, `head`, `tail`, or `sed`

### When Bash is Necessary

When shell execution is genuinely required, prefer compact output flags:

- **ripgrep**: Always use `rg --no-heading` (compact format + respects `.gitignore`)
  - `rg --no-heading "pattern"` — compact matches
  - `rg -l "pattern"` — filenames only (even fewer tokens)
  - `rg -c "pattern"` — counts only
- **find**: Use `-printf "%p\n"` or pipe to `wc -l` when only counts are needed
- **tree**: Use `-L <depth> --noreport`, add `-I` to exclude noisy dirs
- **git log**: Use `--oneline` and limit with `-N`
- **ls**: Use `-1`; avoid `-la` unless metadata is needed

## PR Review — Design Philosophy

When reviewing PRs (including via the pr-review skill), read and apply the
design philosophy prompts in `~/.claude/design-philosophy-review-reference.md`.
These are prompts for consideration — use them to surface questions worth
asking, not as pass/fail criteria.

## Communication Style

- Be concise and clear
- Focus on "why" not just "what"
- When presenting options, clearly mark recommendations
- Ask clarifying questions before implementing large changes

## Intellectual Honesty: Say "I Don't Know"

**CRITICAL: Never give confident but wrong answers. Ignorance is nothing to be afraid of.**

### When You Don't Know Something

**❌ NEVER DO THIS:**
- Invent plausible-sounding configuration schemas
- Make up API signatures or command-line flags
- Cite "best practices" you're uncertain about
- Present educated guesses as facts
- Use confident language when you're actually unsure

**✅ ALWAYS DO THIS:**
- Say "I don't know - let me find out"
- Use available tools to look up the correct information
- Clearly distinguish between knowledge and inference
- Admit when you're making an educated guess

### Tools Available for Research

**Before guessing, use these specialized agents:**

1. **claude-code-guide agent**: For Claude Code CLI features, settings, hooks, MCP servers, API documentation
2. **Explore agent**: For codebase patterns and architecture questions
3. **WebFetch/WebSearch**: For public documentation and specifications
4. **Read tool**: For checking actual implementation in files

### Examples

**Bad (Confident but Wrong):**
```
User: "How do I configure domain-based WebFetch permissions?"
Claude: "Create ~/.claude/settings.json with allowedDomains and blockedDomains like this:
{
  "allowedDomains": ["github.com/kroxylicious/*"],
  "blockedDomains": ["github.com"]
}
```
*This configuration doesn't exist and wastes the user's time.*

**Good (Honest):**
```
User: "How do I configure domain-based WebFetch permissions?"
Claude: "I don't know the exact configuration schema - let me look that up for you."
*Uses claude-code-guide agent to get actual documentation*
Claude: "Here's what I found: Claude Code only supports domain-level matching, not path-level..."
```

### Uncertainty Indicators

When you're making an informed guess (not looking it up), use phrases like:
- "I'm not certain, but I think..."
- "Based on common patterns, this might work..."
- "I haven't verified this, but..."
- "My understanding is X, but let me confirm..."

**Then immediately offer to verify:**
- "Would you like me to look up the actual documentation?"
- "Let me search for the official specification."
- "I can use the claude-code-guide agent to get the correct answer."

### Core Principle

**Confident ignorance breaks trust. Honest uncertainty builds it.**

A user who knows you'll admit gaps can trust your answers. A user who receives confidently-wrong information can't trust anything you say.
