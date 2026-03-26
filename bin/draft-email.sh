#!/usr/bin/env zsh
# Interactively reviews per-org contribution summaries and drafts a single email.
#
# Usage:
#   draft-email.sh [DIRECTORY]
#
# Defaults:
#   DIRECTORY  ~/contributions/YYYY-MM-DD (today's date)
#
# Output: email-draft.md written into DIRECTORY.

set -euo pipefail

INDIR="${1:-${HOME}/contributions/$(date +%Y-%m-%d)}"

if [[ ! -d "$INDIR" ]]; then
    echo "Directory not found: $INDIR" >&2
    exit 1
fi

WEEK_END=$(basename "$INDIR")

orgs=()
for f in "${INDIR}"/summary-*.md; do
    [[ -f "$f" ]] || continue
    org="${f##*summary-}"
    org="${org%.md}"
    orgs+=("$org")
done

if [[ ${#orgs[@]} -eq 0 ]]; then
    echo "No per-org summaries found in ${INDIR}" >&2
    exit 1
fi

BAT=$(command -v bat 2>/dev/null || true)

content=""

for org in "${orgs[@]}"; do
    echo ""
    echo "=== ${org} ==="
    echo ""
    if [[ -n "$BAT" ]]; then
        "$BAT" "${INDIR}/summary-${org}.md"
    else
        cat "${INDIR}/summary-${org}.md"
    fi

    echo ""
    echo "Corrections or comments for ${org}? (Ctrl-D when done, leave empty to skip):"
    org_corrections=$(cat /dev/tty) || true

    content+="--- ${org} ---
$(cat "${INDIR}/summary-${org}.md")
"
    if [[ -n "${org_corrections// }" ]]; then
        content+="
Corrections for ${org}:
${org_corrections}
"
    fi
done

echo ""
printf "Use org headings in the email? [y/N] "
read -r use_headings </dev/tty
use_headings="${use_headings,,}"

if [[ "${use_headings}" == "y" ]]; then
    heading_instruction="Use a heading for each org."
else
    heading_instruction="Combine into a single flowing piece of prose without org headings."
fi

echo ""
echo "Drafting email..."

echo "$content" | claude -p "These are my weekly contribution summaries for the week ending ${WEEK_END}, one per org. ${heading_instruction} Where corrections are provided, incorporate them using my exact wording. Write a short weekly email in the style of a plain personal update — prose, direct and understated, technical but not jargon-heavy, honest about blockers. No corporate language, no filler phrases, no exclamation marks. First person as if I wrote it myself." \
    > "${INDIR}/email-draft.md"

echo ""
echo "=== EMAIL DRAFT ==="
echo ""
if [[ -n "$BAT" ]]; then
    "$BAT" "${INDIR}/email-draft.md"
else
    cat "${INDIR}/email-draft.md"
fi

echo ""
echo "Written to ${INDIR}/email-draft.md"
