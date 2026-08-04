#!/usr/bin/env python3
"""
Post draft review replies from a JSON file to a GitHub PR.

Usage:
  python3 post-review-comments.py <comments-file> <owner/repo> <pr-number>

The JSON file is an array of objects with these fields:
  type       - one of: review_thread_reply, issue_comment, review,
               inline_comment, resolve_thread (default: review_thread_reply)
  thread     - label (T1, T2, ...) for logging only
  replyToId  - databaseId of the comment to reply to (review_thread_reply only)
  body       - reply text
  file       - file path for inline_comment
  line       - line number for inline_comment
  resolve    - if true, resolve the thread after replying (review_thread_reply only)
  event      - APPROVE, REQUEST_CHANGES, or COMMENT (review type only, default: COMMENT)
  graphqlThreadId - thread node ID for resolve_thread
  status     - if "posted", skip this entry (already posted)

inline_comment entries are batched and posted as a single review with COMMENT event.
review_thread_reply entries without replyToId but with file+line are treated as inline_comment.

After posting, updates the JSON file marking posted entries with status=posted.
"""

import json
import subprocess
import sys


def gh_rest(method, path, payload):
    res = subprocess.run(
        ["gh", "api", path, "-X", method, "--input", "-"],
        input=json.dumps(payload),
        capture_output=True, text=True,
    )
    if res.returncode != 0:
        raise RuntimeError(res.stderr.strip() or res.stdout.strip())
    return json.loads(res.stdout)


def graphql(query):
    res = subprocess.run(
        ["gh", "api", "graphql", "-f", f"query={query}"],
        capture_output=True, text=True,
    )
    if res.returncode != 0:
        raise RuntimeError(res.stderr.strip())
    return json.loads(res.stdout)


def get_thread_node_id(repo_owner, repo_name, pr_number, reply_to_id):
    """Find the review thread node ID containing a comment with the given databaseId."""
    data = graphql(f"""{{
  repository(owner: "{repo_owner}", name: "{repo_name}") {{
    pullRequest(number: {pr_number}) {{
      reviewThreads(first: 100) {{
        nodes {{
          id
          isResolved
          comments(first: 5) {{
            nodes {{ databaseId }}
          }}
        }}
      }}
    }}
  }}
}}""")
    threads = data["data"]["repository"]["pullRequest"]["reviewThreads"]["nodes"]
    for t in threads:
        for comment in t["comments"]["nodes"]:
            if comment["databaseId"] == reply_to_id:
                return t["id"]
    return None


def resolve_thread(node_id):
    result = subprocess.run(
        ["gh", "api", "graphql", "-f", f"""mutation {{
  resolveReviewThread(input: {{threadId: "{node_id}"}}) {{
    thread {{ isResolved }}
  }}
}}"""],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip())


def post_reply(repo, pr_number, reply_to_id, body):
    return gh_rest("POST",
                   f"repos/{repo}/pulls/{pr_number}/comments/{reply_to_id}/replies",
                   {"body": body})


def post_issue_comment(repo, pr_number, body):
    return gh_rest("POST",
                   f"repos/{repo}/issues/{pr_number}/comments",
                   {"body": body})


def post_review(repo, pr_number, event, body):
    return gh_rest("POST",
                   f"repos/{repo}/pulls/{pr_number}/reviews",
                   {"body": body, "event": event})


def post_review_with_comments(repo, pr_number, commit_sha, inline_comments):
    payload = {
        "commit_id": commit_sha,
        "event": "COMMENT",
        "body": "",
        "comments": [
            {"path": c["file"], "line": c["line"], "side": "RIGHT", "body": c["body"]}
            for c in inline_comments
        ],
    }
    return gh_rest("POST", f"repos/{repo}/pulls/{pr_number}/reviews", payload)


def get_head_sha(repo, pr_number):
    res = subprocess.run(
        ["gh", "api", f"repos/{repo}/pulls/{pr_number}", "--jq", ".head.sha"],
        capture_output=True, text=True,
    )
    if res.returncode != 0:
        raise RuntimeError(res.stderr.strip() or res.stdout.strip())
    return res.stdout.strip()


def resolve_thread_by_id(node_id):
    result = subprocess.run(
        ["gh", "api", "graphql", "-f", f"query=mutation {{ resolveReviewThread(input: {{threadId: \"{node_id}\"}}) {{ thread {{ isResolved }} }} }}"],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip())


def main():
    if len(sys.argv) != 4:
        print(__doc__)
        sys.exit(1)

    comments_file = sys.argv[1]
    repo = sys.argv[2]       # e.g. kroxylicious/design
    pr_number = sys.argv[3]  # e.g. 116

    repo_owner, repo_name = repo.split("/")

    with open(comments_file) as f:
        comments = json.load(f)

    posted_count = 0
    skipped_count = 0
    failed_count = 0

    # First pass: collect inline_comments and review_thread_replies that
    # have file+line but no replyToId (these are new inline comments)
    inline_batch = []
    inline_indices = []
    for i, c in enumerate(comments):
        if c.get("status") == "posted" or c.get("posted"):
            continue
        entry_type = c.get("type", "review_thread_reply")
        is_inline = entry_type == "inline_comment"
        is_reply_without_id = (entry_type == "review_thread_reply"
                               and "replyToId" not in c
                               and "file" in c and "line" in c)
        if is_inline or is_reply_without_id:
            inline_batch.append(c)
            inline_indices.append(i)

    if inline_batch:
        try:
            commit_sha = get_head_sha(repo, pr_number)
            resp = post_review_with_comments(repo, pr_number, commit_sha, inline_batch)
            print(f"Inline comments: {len(inline_batch)} posted as review ✓ (id={resp.get('id')})")
            for idx in inline_indices:
                comments[idx]["status"] = "posted"
            posted_count += len(inline_batch)
        except Exception as e:
            labels = ", ".join(c.get("thread", f"#{i}") for i, c in zip(inline_indices, inline_batch))
            print(f"Inline comments ({labels}): FAILED — {e}")
            failed_count += len(inline_batch)

    # Second pass: handle all other entry types
    for i, c in enumerate(comments):
        label = c.get("thread", f"#{i}")
        entry_type = c.get("type", "review_thread_reply")

        if c.get("status") == "posted" or c.get("posted"):
            if i not in inline_indices:
                print(f"{label} ({entry_type}): already posted, skipping")
                skipped_count += 1
            continue

        try:
            if entry_type == "review_thread_reply":
                reply_to_id = c["replyToId"]
                if c.get("body"):
                    resp = post_reply(repo, pr_number, reply_to_id, c["body"])
                    print(f"{label}: reply posted ✓ (id={resp.get('id')})")

                if c.get("resolve"):
                    node_id = get_thread_node_id(repo_owner, repo_name, pr_number, reply_to_id)
                    if not node_id:
                        print(f"{label}: WARNING — could not find thread node ID to resolve")
                    else:
                        resolve_thread(node_id)
                        print(f"{label}: thread resolved ✓")

            elif entry_type == "resolve_thread":
                node_id = c.get("graphqlThreadId")
                if not node_id:
                    print(f"{label}: FAILED — resolve_thread requires graphqlThreadId")
                    continue
                resolve_thread_by_id(node_id)
                print(f"{label}: thread resolved ✓")

            elif entry_type == "issue_comment":
                resp = post_issue_comment(repo, pr_number, c["body"])
                print(f"{label} (issue_comment): posted ✓ (id={resp.get('id')})")

            elif entry_type == "review":
                event = c.get("event", "COMMENT")
                resp = post_review(repo, pr_number, event, c.get("body", ""))
                print(f"{label} (review {event}): posted ✓ (id={resp.get('id')})")

            else:
                print(f"{label}: unknown type '{entry_type}', skipping")
                skipped_count += 1
                continue

            comments[i]["status"] = "posted"
            posted_count += 1

        except Exception as e:
            print(f"{label}: FAILED — {e}")
            failed_count += 1

    # Final check: anything still unposted that wasn't intentionally skipped
    missed = [
        c.get("thread", f"#{i}")
        for i, c in enumerate(comments)
        if c.get("status") != "posted" and not c.get("posted") and c.get("type", "review_thread_reply") != "resolve_thread"
    ]
    if missed:
        print(f"\nWARNING: {len(missed)} entr{'y' if len(missed) == 1 else 'ies'} not posted: {', '.join(missed)}")
        failed_count += len(missed)

    # Write back updated JSON with status flags set
    with open(comments_file, "w") as f:
        json.dump(comments, f, indent=2)
        f.write("\n")

    print(f"\nDone: {posted_count} posted, {skipped_count} skipped, {failed_count} failed")
    if failed_count:
        sys.exit(1)


if __name__ == "__main__":
    main()
