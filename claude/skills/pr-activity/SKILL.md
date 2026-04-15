## PR Activity — Current Branch

Summarise outstanding feedback on the PR for the current branch.

### Data Collection

Run the helper script to fetch all data in a single invocation:

```bash
/Users/sbarker/.claude/skills/pr-activity/fetch-pr-activity.sh
```

This returns JSON with `pr`, `reviews`, and `unresolved` fields.

### Presentation

1. Show PR number, title, and review statuses
2. For each unresolved thread, include: file, line, author, and a one-line summary
3. Group into:
   - **Actionable** — threads requiring code changes or a response from me
   - **Informational** — discussions, questions I've already answered, or threads waiting on others
4. Present a concise summary table, then ask which items to address

### Rules

- Only show **unresolved** threads — do not include resolved ones
- Do NOT post replies, resolve threads, or push until I confirm
- Output any markdown as raw source in code fences
