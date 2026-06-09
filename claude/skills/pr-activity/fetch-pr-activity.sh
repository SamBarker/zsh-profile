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

PR_STATE=$(echo "${PR_JSON}" | jq -r '.state')
if [[ "${PR_STATE}" == "MERGED" ]]; then
    echo "PR #$(echo "${PR_JSON}" | jq -r '.number') ($(echo "${PR_JSON}" | jq -r '.title')) has been merged" >&2
    exit 0
elif [[ "${PR_STATE}" == "CLOSED" ]]; then
    echo "PR #$(echo "${PR_JSON}" | jq -r '.number') ($(echo "${PR_JSON}" | jq -r '.title')) is closed" >&2
    exit 0
fi

PR_NUMBER=$(echo "${PR_JSON}" | jq -r '.number')
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
          id
          isResolved
          comments(first: 10) {
            nodes {
              databaseId
              author { login }
              createdAt
              body
              path
              line
            }
          }
        }
      }
      comments(first: 50) {
        nodes {
          databaseId
          author { login }
          createdAt
          body
          url
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
      threadId: .id,
      file: .comments.nodes[0].path,
      line: .comments.nodes[0].line,
      author: .comments.nodes[0].author.login,
      firstCommentId: .comments.nodes[0].databaseId,
      firstComment: .comments.nodes[0].body,
      lastAuthor: .comments.nodes[-1].author.login,
      lastCommentId: .comments.nodes[-1].databaseId,
      lastComment: .comments.nodes[-1].body,
      commentCount: (.comments.nodes | length)
    }
  ],
  issueComments: [.data.repository.pullRequest.comments.nodes[] | {
    id: .databaseId,
    author: .author.login,
    createdAt,
    body,
    url
  }]
}'
