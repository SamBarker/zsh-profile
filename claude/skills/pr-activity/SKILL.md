---
name: pr-activity
description: "PR Activity — Current Branch"
---

## PR Activity — Current Branch

Catch up on what's happened on the PR for the current branch. This skill
**reports the current state of discussion** — it does not generate new review
feedback, suggest code changes, or offer opinions on the code. Its job is to
help Sam understand where things stand so he can decide what to do next.

Automatically detects whether Sam is the author or a reviewer and adjusts
focus accordingly.

### Data Collection

Run the shared fetch script:

```bash
/Users/sbarker/.claude/skills/shared/fetch-pr-data.sh
```

This returns YAML with `pr`, `reviews`, `issueComments`, `unresolvedThreads`,
`resolvedThreads`, and `files` fields.

### Perspective Detection

Check the `pr.author` field. If the author is `SBarker` or `sam0r040`
(case-insensitive), use the **author perspective**. Otherwise, use the
**reviewer perspective**.

### Presentation — Author Perspective

#### 1. Status

PR number, title, and a table of reviewers with their latest review state.

#### 2. Needs My Action

Unresolved threads where the **last comment is not from Sam** — these are
waiting on a response or code change. For each thread show:
- File and line
- Who started the thread and what they asked (one-line summary)
- Last reply (who said what)
- Thread length

#### 3. Waiting on Others

Unresolved threads where the **last comment is from Sam** — the ball is in
someone else's court. Show file, line, and a one-line summary.

#### 4. Issue Comments

Issue-level comments with author, date, and a one-line summary. Flag any
that appear to need a response.

#### 5. What to Do Next

A short prioritised list of recommended actions.

### Presentation — Reviewer Perspective

#### 1. Status

PR number, title, author, and a table of reviewers with their latest state.

#### 2. Author Responded

Unresolved threads where the **author posted after Sam's last comment** —
the author has replied or made changes and the thread needs Sam's attention.
For each thread show:
- File and line
- Sam's original comment (one-line summary)
- Author's latest reply (one-line summary)
- Thread length

#### 3. No Response Yet

Unresolved threads where the **author has not replied since Sam's last
comment**. Show file, line, and a one-line summary of Sam's comment.

#### 4. Other Reviewers

Threads started by other reviewers that Sam hasn't participated in — may
need attention or alignment. Show file, line, reviewer, and one-line summary.

#### 5. Issue Comments

Issue-level comments with author, date, and a one-line summary.

#### 6. What to Do Next

A short prioritised list — e.g. "re-review threads where author responded",
"check new threads from other reviewers".

### Rules

- **Report, don't review.** Summarise what others have said. Do not generate
  your own review comments, code suggestions, or opinions on the code. If Sam
  wants a review, he will use `/pr-review`.
- Only show **unresolved** review threads — do not include resolved ones
- Show **all** issue-level comments — they have no resolved state
- Do NOT post replies, resolve threads, or push until Sam confirms
- Output any markdown as raw source in code fences
- When showing thread content, truncate long comments to key points
