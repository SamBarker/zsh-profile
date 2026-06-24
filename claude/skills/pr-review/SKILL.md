---
name: pr-review
description: Review a PR authored by someone else — thread overview, design-philosophy analysis, and where to focus attention
---

## PR Review — Current Branch

Give a thorough reviewer's assessment of the PR for the current branch: what it
does, what other reviewers are saying, and how the code holds up against Sam's
design philosophy.

### How This Skill Works

Spawn a **single Agent** to do all data collection and analysis. The agent
processes the raw PR data in its own context — the main conversation only
receives the finished summary. This keeps the main context clean for
follow-up discussion.

The agent prompt must include all the instructions below so it knows what
to fetch, how to analyse, and what to return.

### Agent Instructions

Include these instructions verbatim in the agent prompt:

#### Data Collection

1. Read the changed files first — before looking at any thread data:

```bash
git diff $(git merge-base HEAD origin/main)..HEAD
```

2. Read `~/.claude/design-philosophy-review-reference.md` for the design
philosophy prompts.

3. Run the shared fetch script to get PR metadata and thread data:

```bash
/Users/sbarker/.claude/skills/shared/fetch-pr-data.sh
```

This returns YAML with `pr`, `reviews`, `issueComments`, `unresolvedThreads`,
`resolvedThreads`, and `files` fields.

**Important:** Complete the design philosophy analysis (section 6) from the
diff before reading the thread data. The thread data is for sections 2–5 and
for cross-referencing in section 7 — it must not anchor the design analysis.

#### Output Format

The agent must return **all** of the following sections. This is what
gets relayed to the main conversation.

**1. PR Overview**

- PR number, title, author, state, labels
- One-paragraph summary of the PR description (the `body` field)
- Stats: files changed, additions, deletions
- Base and head branches

**2. Review Status**

- Table of reviewers and their latest review state (APPROVED, CHANGES_REQUESTED, COMMENTED, PENDING)
- Note any review bodies that contain substantive feedback

**3. Open Threads**

For each **unresolved** thread, show:
- File and line
- First comment (the review comment that started the thread)
- Last reply (to show current state of discussion)
- Number of comments in thread
- Whether Sam (SBarker / sam0r040) has participated

Group into:
- **Needs attention** — threads with no response from the author, or where a follow-up question was asked
- **Active discussion** — threads with back-and-forth that are still open
- **Likely ready to resolve** — threads where the author appears to have addressed the feedback

**4. Global Comments**

Show issue-level comments (not on specific lines) with author and timestamp.

**5. Recently Resolved Threads**

Show resolved threads, most recent first. Include file, line, and a one-line
summary of what was discussed.

**6. Design Philosophy Analysis**

Use the ten prompts from the design philosophy reference as a lens on the
changed code. This analysis must be grounded in the diff — what the code
actually does — not in what other reviewers have said. Do not let existing
threads anchor or shape the observations here; those are read after the
analysis is formed.

Organise the analysis around what the code reveals, not around the prompt
list — write a coherent narrative, not a checklist. When multiple prompts
converge on the same concern, say so.

For each observation, note which prompt(s) surfaced it so the analysis is
traceable. The prompts are angles on one idea (preserve independence of
action), not independent dimensions — and the answer to any of them might
be "yes, and that's fine here."

Close with a one-paragraph overall impression of the design.

**7. Where to Focus**

List 2–4 areas that deserve Sam's attention as a reviewer, prioritising:
1. Areas with **no existing thread coverage** — fresh territory where Sam's
   view is the only one
2. Areas with **active debate or open questions** — where Sam's perspective
   could add weight or a new angle to a contested point

For each item use this structure:

**Title** — one-line description of the concern from the diff
What to look at: specific code location or pattern to examine, and why it matters
Thread context: *(one sentence only — e.g. "T5 raises this, no reply" or "not covered")*

Keep thread context strictly separate from the substance. If an existing thread
covers part of the concern but Sam sees a distinct angle, describe Sam's angle
in "What to look at" and note only the overlap in "Thread context" — do not
blend them.

**8. Thread Reference Table**

A compact table of **all** unresolved threads with the data needed for
follow-up actions:

```
| # | File:Line | Topic | replyToId | URL |
```

- `#` — short label (T1, T2, …) for referring to threads in conversation
- `Topic` — one-line summary (enough to identify the thread, not a full recap)
- `replyToId` — the `databaseId` needed to post a reply via the GitHub API
- `URL` — direct link to the thread on GitHub

### After the Agent Returns

Relay the agent's full output to Sam. Do not summarise or truncate it — the
agent has already produced the right level of detail.

### Rules

- **This is someone else's PR.** Sam is a reviewer, not the author. Draft
  review comments when asked, but never offer to edit the code or apply
  changes — the author makes those changes, not the reviewer.
- Do NOT post replies, resolve threads, or push until Sam confirms
- Output any markdown as raw source in code fences
- When showing thread content, truncate long comments to key points
- If the PR description is very long, summarise it rather than showing in full
