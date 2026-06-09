## PR Activity — Current Branch

Summarise outstanding feedback on the PR for the current branch.

### Data Collection

Run the helper script to fetch all data in a single invocation:

```bash
/Users/sbarker/.claude/skills/pr-activity/fetch-pr-activity.sh
```

This returns JSON with `pr`, `reviews`, `unresolved`, and `issueComments` fields.

### Presentation

1. Show PR number, title, and review statuses
2. For each unresolved review thread, include: file, line, author, and a one-line summary
3. For each issue-level comment (`issueComments`), include: author, date, and a one-line summary
4. Group everything into:
   - **Actionable** — threads/comments requiring code changes or a response from me
   - **Informational** — discussions, questions I've already answered, or items waiting on others
5. Present a concise summary table, then ask which items to address

### Rules

- Only show **unresolved** review threads — do not include resolved ones
- Show **all** issue-level comments — they have no resolved state, so include them all and let me judge
- Do NOT post replies, resolve threads, or push until I confirm
- Output any markdown as raw source in code fences
