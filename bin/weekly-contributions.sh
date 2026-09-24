#!/usr/bin/env zsh
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
    {
        $GH api "search/issues?q=author:${USER}+org:${org}+is:pr+created:${SINCE}..${UNTIL}&per_page=50" \
            --jq '.items[] | "- [\(.state|ascii_upcase)] \(.title) \(.html_url) — created \(.created_at[:10]), updated \(.updated_at[:10])"'
        $GH api "search/issues?q=author:${USER}+org:${org}+is:pr+closed:${SINCE}..${UNTIL}&per_page=50" \
            --jq '.items[] | "- [\(.state|ascii_upcase)] \(.title) \(.html_url) — created \(.created_at[:10]), updated \(.updated_at[:10])"'
        $GH api "search/issues?q=author:${USER}+org:${org}+is:pr+is:open+updated:${SINCE}..${UNTIL}&per_page=50" \
            --jq '.items[] | "- [\(.state|ascii_upcase)] \(.title) \(.html_url) — created \(.created_at[:10]), updated \(.updated_at[:10])"'
    } | awk '!seen[$0]++' > "${OUTDIR}/prs-authored-${org}.md"

    echo "[$org] Fetching issues opened..."
    $GH api "search/issues?q=author:${USER}+org:${org}+is:issue+created:${SINCE}..${UNTIL}&per_page=50" \
        --jq '.items[] | "- [\(.state|ascii_upcase)] \(.title) \(.html_url) — \(.created_at[:10])"' \
        > "${OUTDIR}/issues-opened-${org}.md"

    echo "[$org] Fetching PRs reviewed..."
    $GH api graphql -f query="
    {
      user(login: \"${USER}\") {
        contributionsCollection(from: \"${SINCE}T00:00:00Z\", to: \"${UNTIL}T23:59:59Z\") {
          pullRequestReviewContributions(first: 100) {
            nodes {
              occurredAt
              pullRequest {
                title
                url
                repository {
                  owner {
                    login
                  }
                }
              }
            }
          }
        }
      }
    }" | jq -r --arg org "${org}" '
      [.data.user.contributionsCollection.pullRequestReviewContributions.nodes[]
       | select(.pullRequest.repository.owner.login == $org)]
      | group_by(.pullRequest.url)
      | .[]
      | (.[0].pullRequest) as $pr
      | ([.[] | .occurredAt[:10]] | max) as $lastReview
      | "- \($pr.title) \($pr.url) — reviewed \($lastReview)"' \
        > "${OUTDIR}/prs-reviewed-${org}.md"

    echo "[$org] Fetching items commented on..."
    page=1
    tmp_events=$(mktemp)
    while :; do
        page_json=$($GH api "/users/${USER}/events/orgs/${org}?per_page=100&page=${page}" 2>/dev/null) || break
        [[ $(printf '%s' "$page_json" | jq 'length') -eq 0 ]] && break
        printf '%s\n' "$page_json" >> "$tmp_events"
        printf '%s' "$page_json" | jq -e --arg since "${SINCE}T00:00:00Z" \
            '.[-1].created_at < $since' >/dev/null 2>&1 && break
        ((page++))
        [[ $page -gt 10 ]] && break
    done
    jq -s -r --arg since "${SINCE}T00:00:00Z" --arg until "${UNTIL}T23:59:59Z" --arg user "$USER" '
      (add // [])
      | [.[]
         | select(.created_at >= $since)
         | select(.created_at <= $until)
         | select(.type == "IssueCommentEvent")
         | select(.payload.action == "created")
         | select(.payload.comment.user.login == $user)
         | {
             title: .payload.issue.title,
             url:   .payload.issue.html_url,
             kind:  (if .payload.issue.pull_request then "PR" else "Issue" end),
             date:  (.created_at[:10])
           }]
      | group_by(.url)
      | .[]
      | (.[0]) as $item
      | ([.[] | .date] | max) as $last
      | "- \($item.kind) \($item.title) \($item.url) — commented \($last)"' \
        "$tmp_events" > "${OUTDIR}/commented-on-${org}.md"
    rm -f "$tmp_events"
done

echo "Done. Files written:"
ls -1 "${OUTDIR}/"
