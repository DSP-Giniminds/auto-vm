#!/usr/bin/env bash
# Post a PR comment, or update the earlier one with the same marker, so a PR
# keeps one "plan" comment, one "result" comment and so on.
#
# Usage: post_comment.sh <pr-number> <marker> <body-file>
# Needs: gh (preinstalled on GitHub runners), GITHUB_TOKEN, GITHUB_REPOSITORY
set -euo pipefail

pr="$1"
marker="<!-- vm-pipeline:$2 -->"
body="${marker}"$'\n'"$(cat "$3")"

comment_id=$(gh api "repos/${GITHUB_REPOSITORY}/issues/${pr}/comments" --paginate \
  --jq ".[] | select(.body | contains(\"${marker}\")) | .id" | tail -n 1)

if [ -n "$comment_id" ]; then
  gh api -X PATCH "repos/${GITHUB_REPOSITORY}/issues/comments/${comment_id}" -f body="$body" > /dev/null
else
  gh api "repos/${GITHUB_REPOSITORY}/issues/${pr}/comments" -f body="$body" > /dev/null
fi
