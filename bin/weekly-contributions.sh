#!/usr/bin/env bash
# Dumps a raw summary of GitHub contributions for a given user
# across one or more GitHub orgs for the last 7 days (or a custom date range).
#
# Usage:
#   weekly-contributions.sh [--user LOGIN] [--org ORG]... [--since YYYY-MM-DD]
#                           [--until YYYY-MM-DD] [--week-ends-on YYYY-MM-DD] [--outdir PATH]
#
# Defaults:
#   --user   SamBarker
#   --org    kroxylicious  (may be specified multiple times)
#   --since  7 days ago
#   --until  today
#
# --week-ends-on YYYY-MM-DD sets UNTIL to that date and SINCE to 7 days before it.

set -euo pipefail

GH=/opt/homebrew/bin/gh
USER=SamBarker
SINCE=$(date -v-7d +%Y-%m-%d 2>/dev/null || date -d '7 days ago' +%Y-%m-%d)
UNTIL=$(date +%Y-%m-%d)
ORGS=()
OUTDIR=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --user)         USER="$2";        shift 2 ;;
        --org)          ORGS+=("$2");     shift 2 ;;
        --since)        SINCE="$2";       shift 2 ;;
        --until)        UNTIL="$2";       shift 2 ;;
        --outdir)       OUTDIR="$2";      shift 2 ;;
        --week-ends-on)
            UNTIL="$2"
            SINCE=$(date -j -v-7d -f "%Y-%m-%d" "$2" +%Y-%m-%d 2>/dev/null \
                    || date -d "$2 - 7 days" +%Y-%m-%d)
            shift 2 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

[[ ${#ORGS[@]} -eq 0 ]] && ORGS=(kroxylicious)

OUTDIR="${OUTDIR:-${HOME}/contributions/${UNTIL}}"

mkdir -p "${OUTDIR}"
echo "Writing to ${OUTDIR}"

for org in "${ORGS[@]}"; do
    if ! $GH api "orgs/${org}" --silent 2>/dev/null; then
        echo "Warning: org '${org}' not found or not accessible — check for typos" >&2
        continue
    fi

    echo "[$org] Fetching PRs authored..."
    $GH api "search/issues?q=author:${USER}+org:${org}+is:pr+updated:>=${SINCE}&per_page=50" \
        --jq '.items[] | "- [\(.state|ascii_upcase)] \(.title) \(.html_url) — created \(.created_at[:10]), updated \(.updated_at[:10])"' \
        > "${OUTDIR}/prs-authored-${org}.md"

    echo "[$org] Fetching issues opened..."
    $GH api "search/issues?q=author:${USER}+org:${org}+is:issue+created:>=${SINCE}&per_page=50" \
        --jq '.items[] | "- [\(.state|ascii_upcase)] \(.title) \(.html_url) — \(.created_at[:10])"' \
        > "${OUTDIR}/issues-opened-${org}.md"

    echo "[$org] Fetching PRs reviewed..."
    $GH api "search/issues?q=reviewed-by:${USER}+org:${org}+is:pr+updated:>=${SINCE}&per_page=50" \
        --jq '.items[] | "- \(.title) \(.html_url) — updated \(.updated_at[:10])"' \
        > "${OUTDIR}/prs-reviewed-${org}.md"

    echo "[$org] Fetching items commented on..."
    $GH api "search/issues?q=commenter:${USER}+org:${org}+updated:>=${SINCE}&per_page=50" \
        | jq -r --arg user "$USER" \
        '.items[] | select(.user.login != $user) | "- \(if .pull_request then "PR" else "Issue" end) \(.title) \(.html_url) — updated \(.updated_at[:10])"' \
        > "${OUTDIR}/commented-on-${org}.md"
done

echo "Done. Files written:"
ls -1 "${OUTDIR}/"
