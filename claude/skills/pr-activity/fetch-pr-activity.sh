#!/bin/bash
#
# Fetches PR activity for the current branch: review statuses and unresolved threads.
# Outputs JSON with two top-level keys: "reviews" and "unresolved".
#

set -euo pipefail

GH=/opt/homebrew/bin/gh

# Step 1: Get PR number for current branch
PR_JSON=$("${GH}" pr view --json number,title,url,state 2>&1) || {
    echo "No PR found for current branch" >&2
    exit 1
}

PR_NUMBER=$(echo "${PR_JSON}" | sed -n 's/.*"number":\([0-9]*\).*/\1/p')
OWNER_REPO=$("${GH}" repo view --json nameWithOwner --jq '.nameWithOwner')
OWNER="${OWNER_REPO%%/*}"
REPO="${OWNER_REPO##*/}"

# Step 2: Fetch reviews + unresolved threads in a single GraphQL call
"${GH}" api graphql -f query="
{
  repository(owner: \"${OWNER}\", name: \"${REPO}\") {
    pullRequest(number: ${PR_NUMBER}) {
      number
      title
      url
      state
      reviews(last: 10) {
        nodes {
          author { login }
          state
          submittedAt
        }
      }
      reviewThreads(first: 100) {
        nodes {
          isResolved
          comments(first: 10) {
            nodes {
              author { login }
              createdAt
              body
              path
              line
            }
          }
        }
      }
    }
  }
}" --jq '{
  pr: {
    number: .data.repository.pullRequest.number,
    title: .data.repository.pullRequest.title,
    url: .data.repository.pullRequest.url,
    state: .data.repository.pullRequest.state
  },
  reviews: [.data.repository.pullRequest.reviews.nodes[] | {
    author: .author.login,
    state,
    at: .submittedAt
  }],
  unresolved: [.data.repository.pullRequest.reviewThreads.nodes[] |
    select(.isResolved == false) | {
      file: .comments.nodes[0].path,
      line: .comments.nodes[0].line,
      author: .comments.nodes[0].author.login,
      firstComment: .comments.nodes[0].body,
      lastAuthor: .comments.nodes[-1].author.login,
      lastComment: .comments.nodes[-1].body,
      commentCount: (.comments.nodes | length)
    }
  ]
}'
