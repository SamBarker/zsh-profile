#!/usr/bin/env bash
# Summarises a weekly contributions directory produced by weekly-contributions.sh.
# Pipes the 4 raw files through claude -p to produce a themed summary.
#
# Usage:
#   summarise-contributions.sh [DIRECTORY]
#
# Defaults:
#   DIRECTORY  ~/contributions/YYYY-MM-DD (today's date)
#
# Output: summary.md written into DIRECTORY.

set -euo pipefail

INDIR="${1:-${HOME}/contributions/$(date +%Y-%m-%d)}"

if [[ ! -d "$INDIR" ]]; then
    echo "Directory not found: $INDIR" >&2
    exit 1
fi

WEEK_END=$(basename "$INDIR")

echo "Summarising ${INDIR}..."
cat "${INDIR}/prs-authored.md" "${INDIR}/issues-opened.md" \
    "${INDIR}/prs-reviewed.md" "${INDIR}/commented-on.md" \
    | claude -p "These are my GitHub contributions for the week ending ${WEEK_END}.
Write a short weekly summary in the style of a plain personal update — a few paragraphs of prose, grouped by org and then loosely by theme within each org, no headings or bullet points. The tone should be direct and understated: technical but not jargon-heavy, honest about blockers or open questions, mentions collaborators by name naturally. No corporate language, no filler phrases, no exclamation marks. Write in first person as if I wrote it myself." \
    > "${INDIR}/summary.md"
echo "Written to ${INDIR}/summary.md"
