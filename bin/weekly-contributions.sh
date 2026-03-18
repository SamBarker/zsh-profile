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
ORG_QUERY=$(IFS=+; echo "${ORGS[*]/#/org:}")

OUTDIR="${OUTDIR:-${HOME}/contributions/${UNTIL}}"

mkdir -p "${OUTDIR}"
echo "Writing to ${OUTDIR}"

# --- PRs authored ---
echo "Fetching PRs authored..."
$GH api "search/issues?q=author:${USER}+${ORG_QUERY}+is:pr+updated:>=${SINCE}&per_page=50" \
    --jq '.items[] | "- [\(.state|ascii_upcase)] #\(.number) \(.title) (\(.repository_url | split("/") | .[-2:] | join("/"))) — created \(.created_at[:10]), updated \(.updated_at[:10])"' \
    > "${OUTDIR}/prs-authored.md"

# --- Issues opened ---
echo "Fetching issues opened..."
$GH api "search/issues?q=author:${USER}+${ORG_QUERY}+is:issue+created:>=${SINCE}&per_page=50" \
    --jq '.items[] | "- [\(.state|ascii_upcase)] #\(.number) \(.title) (\(.repository_url | split("/") | .[-2:] | join("/"))) — \(.created_at[:10])"' \
    > "${OUTDIR}/issues-opened.md"

# --- PRs reviewed ---
echo "Fetching PRs reviewed..."
$GH api "search/issues?q=reviewed-by:${USER}+${ORG_QUERY}+is:pr+updated:>=${SINCE}&per_page=50" \
    --jq '.items[] | "- #\(.number) \(.title) (\(.repository_url | split("/") | .[-2:] | join("/"))) — updated \(.updated_at[:10])"' \
    > "${OUTDIR}/prs-reviewed.md"

# --- Issues/PRs commented on (not authored) ---
echo "Fetching items commented on..."
$GH api "search/issues?q=commenter:${USER}+${ORG_QUERY}+updated:>=${SINCE}&per_page=50" \
    | jq -r --arg user "$USER" \
    '.items[] | select(.user.login != $user) | "- \(if .pull_request then "PR" else "Issue" end) #\(.number) \(.title) (\(.repository_url | split("/") | .[-2:] | join("/"))) — updated \(.updated_at[:10])"' \
    > "${OUTDIR}/commented-on.md"

echo "Done. Files written:"
ls -1 "${OUTDIR}/"
