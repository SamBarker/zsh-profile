#!/bin/bash
#
# Fetches comprehensive PR data for the current branch.
# Shared by pr-review and pr-activity skills.
#
# Outputs YAML with: pr, reviews, issueComments, unresolvedThreads,
# resolvedThreads, and files.
#

set -euo pipefail

GH=/opt/homebrew/bin/gh
YQ=/opt/homebrew/bin/yq

# Get PR number for current branch
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

# Fetch everything in a single GraphQL call, reshape with jq, convert to YAML
"${GH}" api graphql -f query="
{
  repository(owner: \"${OWNER}\", name: \"${REPO}\") {
    pullRequest(number: ${PR_NUMBER}) {
      number
      title
      url
      state
      body
      author { login }
      baseRefName
      headRefName
      additions
      deletions
      changedFiles
      labels(first: 10) {
        nodes { name }
      }
      reviews(last: 20) {
        nodes {
          author { login }
          state
          submittedAt
          body
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
      reviewThreads(first: 100) {
        nodes {
          isResolved
          comments(first: 20) {
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
      files(first: 100) {
        nodes {
          path
          additions
          deletions
        }
      }
    }
  }
}" --jq '{
  pr: {
    number: .data.repository.pullRequest.number,
    title: .data.repository.pullRequest.title,
    url: .data.repository.pullRequest.url,
    state: .data.repository.pullRequest.state,
    author: .data.repository.pullRequest.author.login,
    body: .data.repository.pullRequest.body,
    baseRef: .data.repository.pullRequest.baseRefName,
    headRef: .data.repository.pullRequest.headRefName,
    additions: .data.repository.pullRequest.additions,
    deletions: .data.repository.pullRequest.deletions,
    changedFiles: .data.repository.pullRequest.changedFiles,
    labels: [.data.repository.pullRequest.labels.nodes[].name]
  },
  reviews: [.data.repository.pullRequest.reviews.nodes[] | {
    author: .author.login,
    state,
    at: .submittedAt,
    body: (if .body == "" then null else .body end)
  }],
  issueComments: [.data.repository.pullRequest.comments.nodes[] | {
    id: .databaseId,
    author: .author.login,
    at: .createdAt,
    body: .body,
    url: .url
  }],
  unresolvedThreads: [.data.repository.pullRequest.reviewThreads.nodes[] |
    select(.isResolved == false) | {
      file: .comments.nodes[0].path,
      line: .comments.nodes[0].line,
      replyToId: .comments.nodes[0].databaseId,
      comments: [.comments.nodes[] | {
        author: .author.login,
        at: .createdAt,
        body: .body
      }]
    }
  ],
  resolvedThreads: [.data.repository.pullRequest.reviewThreads.nodes[] |
    select(.isResolved == true) | {
      file: .comments.nodes[0].path,
      line: .comments.nodes[0].line,
      comments: [.comments.nodes[] | {
        author: .author.login,
        at: .createdAt,
        body: .body
      }]
    }
  ],
  files: [.data.repository.pullRequest.files.nodes[] | {
    path,
    additions,
    deletions
  }]
}' | "${YQ}" -P
