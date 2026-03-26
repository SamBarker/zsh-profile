#!/usr/bin/env zsh
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

orgs=()
for f in "${INDIR}"/prs-authored-*.md; do
    [[ -f "$f" ]] || continue
    org="${f##*prs-authored-}"
    org="${org%.md}"
    orgs+=("$org")
done

if [[ ${#orgs[@]} -eq 0 ]]; then
    echo "No per-org data files found in ${INDIR}" >&2
    exit 1
fi

for org in "${orgs[@]}"; do
    echo "Summarising ${org}..."

    notes=""
    [[ -f "${INDIR}/notes.md" ]]       && notes+=$'\n'"$(cat "${INDIR}/notes.md")"
    [[ -f "${INDIR}/notes-${org}.md" ]] && notes+=$'\n'"$(cat "${INDIR}/notes-${org}.md")"

    notes_section=""
    if [[ -n "${notes// }" ]]; then
        notes_section=$'\n\nAdditional context and corrections from me:\n'"${notes}"
    fi

    cat "${INDIR}/prs-authored-${org}.md" \
        "${INDIR}/issues-opened-${org}.md" \
        "${INDIR}/prs-reviewed-${org}.md" \
        "${INDIR}/commented-on-${org}.md" \
        | claude -p "These are my GitHub contributions in the ${org} org for the week ending ${WEEK_END}.${notes_section}

Write a short weekly summary in the style of a plain personal update — a few paragraphs of prose, loosely grouped by theme, no headings or bullet points. The tone should be direct and understated: technical but not jargon-heavy, honest about blockers or open questions, mentions collaborators by name naturally. No corporate language, no filler phrases, no exclamation marks. Write in first person as if I wrote it myself. Where I have provided additional context or corrections, use my exact wording as much as possible — treat it as text I have already written that should appear in the summary largely verbatim, woven into the surrounding prose. Include the full GitHub URLs from the raw data when referencing PRs or issues." \
        > "${INDIR}/summary-${org}.md"
    echo "Written to ${INDIR}/summary-${org}.md"
done
