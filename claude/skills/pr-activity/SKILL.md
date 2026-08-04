---
name: pr-activity
description: "PR Activity — Current Branch"
---

## PR Activity — Current Branch

Catch up on what's happened on the PR for the current branch. Automatically
detects whether Sam is the author or a reviewer and adjusts focus accordingly.

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

Run the shared fetch script:

```bash
/Users/sbarker/.claude/skills/shared/fetch-pr-data.sh
```

This returns YAML with `pr`, `reviews`, `issueComments`, `unresolvedThreads`,
`resolvedThreads`, and `files` fields.

#### Perspective Detection

Check the `pr.author` field. If the author is `SBarker` or `sam0r040`
(case-insensitive), use the **author perspective**. Otherwise, use the
**reviewer perspective**.

#### Output Format — Author Perspective

**1. Status**

PR number, title, and a table of reviewers with their latest review state.

**2. Needs My Action**

Unresolved threads where the **last comment is not from Sam** — these are
waiting on a response or code change. For each thread show:
- File and line
- Who started the thread and what they asked (one-line summary)
- Last reply (who said what)
- Thread length

**3. Waiting on Others**

Unresolved threads where the **last comment is from Sam** — the ball is in
someone else's court. Show file, line, and a one-line summary.

**4. Issue Comments**

Issue-level comments with author, date, and a one-line summary. Flag any
that appear to need a response.

**5. Where to Look**

Flag things that evolved without Sam or that may need his attention — e.g.
"Rob pushed back on the approach in thread T2", "new review from Keith".
Do not point Sam back at his own comments or pending reviews — he knows
about those already.

#### Output Format — Reviewer Perspective

**1. Status**

PR number, title, author, and a table of reviewers with their latest state.

**2. Author Responded**

Unresolved threads where the **author posted after Sam's last comment** —
the author has replied or made changes and the thread needs Sam's attention.
For each thread show:
- File and line
- Sam's original comment (one-line summary)
- Author's latest reply (one-line summary)
- Thread length

**3. No Response Yet**

Unresolved threads where the **author has not replied since Sam's last
comment**. Show file, line, and a one-line summary of Sam's comment.

**4. Other Reviewers**

Threads started by other reviewers that Sam hasn't participated in — may
need attention or alignment. Show file, line, reviewer, and one-line summary.

**5. Issue Comments**

Issue-level comments with author, date, and a one-line summary.

**6. Where to Look**

Flag things that evolved without Sam or that may need his attention — e.g.
"Tom and Keith are debating X (Tom thinks Y, Keith thinks Z)", "author
responded to 3 threads". Do not point Sam back at his own comments or
pending reviews — he knows about those already.

#### Thread Reference Table (both perspectives)

Always end with a compact table of **all** unresolved threads:

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

### Posting Replies

When Sam asks to post replies, use the shared post script:

```bash
PATH="/opt/homebrew/bin:$PATH" python3 /Users/sbarker/.claude/skills/shared/post-review-comments.py <comments-file> <owner/repo> <pr-number>
```

The comments file is a JSON array. Each entry has:

```json
{
  "type": "review_thread_reply | issue_comment | review",
  "thread": "T1",
  "replyToId": 1234567,
  "body": "Reply text",
  "event": "APPROVE | REQUEST_CHANGES | COMMENT",
  "status": "pending | posted"
}
```

- `type: review_thread_reply` — posts a reply to an inline review thread; requires `replyToId`
- `type: issue_comment` — posts a top-level PR comment (issue-level)
- `type: review` — submits a review with `event` (APPROVE, REQUEST_CHANGES, or COMMENT)
- Entries with `status: posted` are skipped automatically
- After posting, the script updates `status` to `posted` in the file

The comments file lives at `proposals/<pr-number>-review-comments.json` in the design repo.
If it doesn't exist yet, create it as an empty array `[]` before drafting replies into it.

### Rules

- Only show **unresolved** review threads — do not include resolved ones
- Show **all** issue-level comments — they have no resolved state
- Do NOT post replies, resolve threads, or push until Sam confirms
- Output any markdown as raw source in code fences
- When showing thread content, truncate long comments to key points
