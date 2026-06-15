---
name: design-analysis
description: "Design philosophy analysis of the current branch's diff, optionally focused on a specific area"
---

## Design Analysis — Current Branch

Analyse the changed code on the current branch through the lens of Sam's
design philosophy prompts. Optionally accepts a focus area to narrow the
analysis (e.g. `/design-analysis static routes`, `/design-analysis error handling`).

### How This Skill Works

Spawn a **single Agent** to read the diff and design philosophy reference,
then return the analysis. The raw diff stays in the agent's context.

The agent prompt must include all the instructions below. If the user
provided a focus area, include it in the prompt so the agent can narrow
its lens.

### Agent Instructions

Include these instructions verbatim in the agent prompt:

#### Data Collection

1. Read the design philosophy prompts:

```bash
cat ~/.claude/design-philosophy-review-reference.md
```

2. Read the changed files:

```bash
git diff $(git merge-base HEAD origin/main)..HEAD
```

#### Analysis

Use the design philosophy prompts as a lens on the changed code. Organise
the analysis around what the code reveals, not around the prompt list —
write a coherent narrative, not a checklist. When multiple prompts converge
on the same concern, say so.

For each observation, note which prompt(s) surfaced it so the analysis is
traceable. The prompts are angles on one idea (preserve independence of
action), not independent dimensions — and the answer to any of them might
be "yes, and that's fine here."

**If a focus area was provided**, concentrate the analysis on that area.
Still read the full diff for context, but spend the analysis on the
specified topic. Mention anything outside the focus only if it's
directly relevant.

**If no focus area was provided**, analyse the full diff.

#### Output Format

**1. Design Philosophy Analysis**

The narrative analysis as described above.

**2. Overall Impression**

One paragraph summarising the design's strengths and any concerns.

**3. Where to Focus**

2–4 specific areas that deserve the closest attention, in priority order.

### After the Agent Returns

Relay the agent's full output to Sam. Do not summarise or truncate it.

### Rules

- Do NOT post replies, resolve threads, or push until Sam confirms
- Output any markdown as raw source in code fences
