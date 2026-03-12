#!/usr/bin/env bash
# Dumps a raw summary of GitHub contributions for a given user
# across the kroxylicious org for the last 7 days (or a custom date range).
#
# Usage:
#   weekly-contributions.sh [--user LOGIN] [--since YYYY-MM-DD] [--until YYYY-MM-DD]
#
# Defaults:
#   --user   SamBarker
#   --since  7 days ago
#   --until  today
#
# Output: plain text summary to stdout. Redirect to a file as needed.

set -euo pipefail

GH=/opt/homebrew/bin/gh
USER=SamBarker
SINCE=$(date -v-7d +%Y-%m-%d 2>/dev/null || date -d '7 days ago' +%Y-%m-%d)
UNTIL=$(date +%Y-%m-%d)
ORG=kroxylicious
OUTDIR="${HOME}/contributions/${UNTIL}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --user)  USER="$2";  shift 2 ;;
        --since) SINCE="$2"; shift 2 ;;
        --until) UNTIL="$2"; shift 2 ;;
        --outdir) OUTDIR="$2"; shift 2 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

mkdir -p "${OUTDIR}"
echo "Writing to ${OUTDIR}"

# --- PRs authored ---
echo "Fetching PRs authored..."
$GH api "search/issues?q=author:${USER}+org:${ORG}+is:pr+updated:>=${SINCE}&per_page=50" \
    --jq '.items[] | "- [\(.state|ascii_upcase)] #\(.number) \(.title) (\(.repository_url | split("/") | last)) — created \(.created_at[:10]), updated \(.updated_at[:10])"' \
    > "${OUTDIR}/prs-authored.md"

# --- Issues opened ---
echo "Fetching issues opened..."
$GH api "search/issues?q=author:${USER}+org:${ORG}+is:issue+created:>=${SINCE}&per_page=50" \
    --jq '.items[] | "- [\(.state|ascii_upcase)] #\(.number) \(.title) (\(.repository_url | split("/") | last)) — \(.created_at[:10])"' \
    > "${OUTDIR}/issues-opened.md"

# --- PRs reviewed ---
echo "Fetching PRs reviewed..."
$GH api "search/issues?q=reviewed-by:${USER}+org:${ORG}+is:pr+updated:>=${SINCE}&per_page=50" \
    --jq '.items[] | "- #\(.number) \(.title) (\(.repository_url | split("/") | last)) — updated \(.updated_at[:10])"' \
    > "${OUTDIR}/prs-reviewed.md"

# --- Issues/PRs commented on (not authored) ---
echo "Fetching items commented on..."
# shellcheck disable=SC2016 # $user is a jq variable passed via --arg, not a bash variable
$GH api "search/issues?q=commenter:${USER}+org:${ORG}+updated:>=${SINCE}&per_page=50" \
    --jq --arg user "$USER" \
    '.items[] | select(.user.login != $user) | "- \(if .pull_request then "PR" else "Issue" end) #\(.number) \(.title) (\(.repository_url | split("/") | last)) — updated \(.updated_at[:10])"' \
    > "${OUTDIR}/commented-on.md"

echo "Done. Files written:"
ls -1 "${OUTDIR}/"
