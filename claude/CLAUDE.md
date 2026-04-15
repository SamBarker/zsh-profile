# Global Claude Code Configuration

This file provides default guidance to Claude Code (claude.ai/code) for all projects.

## Test-Driven Development and Commit Discipline

### Core Principles

1. **Red, Green, Refactor**: Write failing test → Make it pass → Refactor
2. **Incremental Commits**: Commit after each logical step, not when "everything is done"
3. **User Story Focus**: Each commit should answer "what can the user/developer do now?"
4. **Small Commits**: Target ~100-200 lines per commit (max ~300)
5. **Refactoring is Mandatory**: Always refactor after making tests pass

### Commit Sequence Rules

**YOU MUST follow this pattern for all feature work:**

1. Write a failing test (commit: "Add failing test for X")
2. Make the test pass with minimal code (commit: "Implement X to pass test")
3. Refactor if needed (commit: "Refactor X for clarity")
4. Repeat for next feature

**For larger features, break into incremental user stories:**
- NOT: "Add entire authentication system" (1000 lines)
- YES:
  - Commit 1: "Add test that user can be created" → make it pass
  - Commit 2: "Add test that user can log in" → make it pass
  - Commit 3: "Add test that invalid credentials fail" → make it pass
  - Commit 4: "Refactor authentication to extract password hashing"

### When to Commit

**Commit immediately after:**
- Making a failing test pass
- Completing a refactoring step
- Adding a discrete new capability
- Before starting a different logical change

**DO NOT:**
- Batch multiple features into one commit
- Wait until everything is "done"
- Create commits based on file types ("add all tests", "add all utils")

### Commit Message Format

Commit messages should be descriptive but don't need to follow a rigid format.
Include enough context for someone reviewing the branch to understand each step.

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

### Maximum Commit Size

- **Soft limit**: 200 lines changed
- **Hard limit**: 300 lines changed
- If approaching limit, you're batching too much - break it down

## Git Workflow

- **YOU MUST NEVER commit directly to `main`.** All work happens on feature branches. All changes reach `main` via pull request. Create a feature branch before making any commits.
- All branches should start from `upstream/main` unless otherwise requested! If the current branch is not `**/main` then prompt for a base but, default to `upstream/main`
- 
### Working with Claude

**After asking Claude to implement a feature:**

1. Ask: "What's the smallest first step we can test?"
2. Implement only that step
3. Commit it
4. Ask: "What's the next small step?"
5. Repeat

**If Claude produces too much at once:**
- Stop Claude and say: "That's too much. Let's commit what we have so far incrementally."
- Claude will help you break it into proper commits

Do not create PRs, push branches, or post GitHub comments unless explicitly asked. When in doubt, ask before taking actions that are hard to undo.

### Refactoring Policy

- Refactoring previous work is GOOD and EXPECTED
- Each refactoring should be its own commit
- Tests must still pass after refactoring
- Refactoring commits should clearly state what improved

### Example: Adding a New Feature

**Bad approach:**
```
Commit: "Add testing infrastructure"
- 7 files changed, 1181 insertions
```

**Good approach (incremental TDD):**
```
Commit 1: "Verify Helm chart passes lint"
- pom.xml (minimal)
- HelmLintTest.java (inline execution)
- ~50 lines

Commit 2: "Extract Helm CLI execution to utility"
- HelmUtils.java
- Refactor HelmLintTest
- ~100 lines

Commit 3: "Render Helm templates without errors"
- Add renderTemplate() to HelmUtils
- Add HelmTemplateRenderingTest
- ~150 lines

[...continue incrementally...]
```

### Red Flags

If Claude presents:
- ❌ "I've created 5 files..."
- ❌ "Here's the complete implementation..."
- ❌ More than 300 lines of changes at once

Stop and request incremental steps.

### Questions to Ask Before Committing

1. "Can someone review this in < 5 minutes?" (If no: too big)
2. "What can we do now that we couldn't before?" (User story)
3. "Are there multiple logical changes here?" (If yes: split it)
4. "Could I revert this without losing other work?" (Independence)

## Shell Environment

My machine runs macOS with zsh as the login shell. `/bin/bash` is bash 3.2 (the macOS system bash).

**Host-run scripts** (anything invoked from my machine — orchestration, CI helpers, local tooling)
must be bash 3.2 compatible. No bash 4+ features: no `mapfile`, no `${var,,}`/`${var^^}`,
no `declare -A` associative arrays.

Use the `${ARRAY[@]+"${ARRAY[@]}"}` idiom for safe empty array expansion under `set -u`.

**Container-run scripts** (scripts that execute inside Docker/Kubernetes containers) may use bash 4+
features freely — Linux containers ship with a modern bash.

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
