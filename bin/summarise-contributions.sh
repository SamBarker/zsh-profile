#!/usr/bin/env zsh
# Summarises a weekly contributions directory produced by weekly-contributions.sh.
# Pipes the 4 raw files through an LLM to produce a themed summary.
#
# Usage:
#   summarise-contributions.sh [--llm BACKEND] [--model MODEL] [DIRECTORY]
#
# LLM backends: claude (default), bob, omlx
# See bin/llm-pipe.sh for backend details and environment variables.
#
# Defaults:
#   DIRECTORY  ~/contributions/YYYY-MM-DD (today's date)
#
# Output: summary-<org>.md written into DIRECTORY.

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
# shellcheck source=bin/llm-pipe.sh
source "${SCRIPT_DIR}/llm-pipe.sh"

LLM_FLAGS=()
INDIR=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --llm)   LLM_FLAGS+=(--llm   "$2"); shift 2 ;;
        --model) LLM_FLAGS+=(--model "$2"); shift 2 ;;
        *)       INDIR="$1"; shift ;;
    esac
done

INDIR="${INDIR:-${HOME}/contributions/$(date +%Y-%m-%d)}"

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
        | llm_prompt "${LLM_FLAGS[@]}" "These are my GitHub contributions in the ${org} org for the week ending ${WEEK_END}.${notes_section}

Write a short weekly summary in the style of a plain personal update — a few paragraphs of prose, loosely grouped by theme, no headings or bullet points. The tone should be direct and understated: technical but not jargon-heavy, honest about blockers or open questions, mentions collaborators by name naturally. No corporate language, no filler phrases, no exclamation marks. Write in first person as if I wrote it myself. Where I have provided additional context or corrections, use my exact wording as much as possible — treat it as text I have already written that should appear in the summary largely verbatim, woven into the surrounding prose. Include the full GitHub URLs from the raw data when referencing PRs or issues." \
        > "${INDIR}/summary-${org}.md"
    echo "Written to ${INDIR}/summary-${org}.md"
done
