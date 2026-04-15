---
name: pr-status
description: Review status of a PR on the current branch — code overview, open and resolved threads, global comments
---

## PR Status — Current Branch

Give a reviewer's overview of the PR for the current branch: what it does, the
state of reviews, and the full conversation.

### Data Collection

Run the helper script to fetch all data in a single invocation:

```bash
/Users/sbarker/.claude/skills/pr-status/fetch-pr-status.sh
```

This returns JSON with `pr`, `reviews`, `issueComments`, `unresolvedThreads`,
`resolvedThreads`, and `files` fields.

### Presentation

#### 1. PR Overview

- PR number, title, author, state, labels
- One-paragraph summary of the PR description (the `body` field)
- Stats: files changed, additions, deletions
- Base and head branches

#### 2. Review Status

- Table of reviewers and their latest review state (APPROVED, CHANGES_REQUESTED, COMMENTED, PENDING)
- Note any review bodies that contain substantive feedback

#### 3. Open Threads

For each **unresolved** thread, show:
- File and line
- First comment (the review comment that started the thread)
- Last reply (to show current state of discussion)
- Number of comments in thread
- Whether I (SBarker / sam0r040) have participated

Group into:
- **Needs attention** — threads with no response, or where the author asked a follow-up question
- **Active discussion** — threads with back-and-forth that are still open
- **Likely ready to resolve** — threads where the author appears to have addressed the feedback

#### 4. Global Comments

Show issue-level comments (not on specific lines) with author and timestamp.

#### 5. Recently Resolved Threads

Show resolved threads, most recent first. Include file, line, and a one-line
summary of what was discussed. This helps catch up on what was resolved since
last review.

#### 6. Code Overview (optional)

If I ask for a code review or the PR is small enough (< 500 lines changed),
read the changed files and provide a high-level assessment:
- What the PR changes and why
- Any concerns about correctness, performance, or design
- Areas that deserve closer attention

Use `git diff $(git merge-base HEAD origin/main)..HEAD` or read changed files directly.

### Rules

- Do NOT post replies, resolve threads, or push until I confirm
- Output any markdown as raw source in code fences
- When showing thread content, truncate long comments to key points
- If the PR description is very long, summarise it rather than showing in full
