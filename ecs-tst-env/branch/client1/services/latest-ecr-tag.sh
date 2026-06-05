#!/usr/bin/env bash
#
# latest-ecr-tag.sh — Terraform external data source helper.
#
# Given an ECR repo + a tag prefix, returns the tag of the most recently PUSHED
# image whose tag starts with that prefix. Used by data.external.latest_image so
# each ECS service auto-deploys the newest image for its app.
#
# Protocol (Terraform external data source):
#   stdin : JSON object { "repository_name", "region", "prefix" }
#   stdout: JSON object { "tag": "<resolved tag>" }
# All diagnostics go to stderr; any non-zero exit fails the plan with the message.
#
set -euo pipefail

for cmd in aws jq; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "ERROR: '$cmd' is required but not installed." >&2; exit 1; }
done

# ---------- read query from stdin ----------
eval "$(jq -r '@sh "REPO=\(.repository_name) REGION=\(.region) PREFIX=\(.prefix)"')"

# ---------- find the newest image tag matching the prefix ----------
# describe-images returns each image's tags + push time; we filter tags by prefix,
# sort by imagePushedAt (ISO 8601 sorts lexicographically), and take the latest.
TAG="$(
  aws ecr describe-images \
    --repository-name "$REPO" \
    --region "$REGION" \
    --output json \
  | jq -r --arg p "$PREFIX" '
      [ .imageDetails[]
        | select(.imageTags != null)
        | . as $img
        | ($img.imageTags[] | select(startswith($p))) as $t
        | { tag: $t, pushed: $img.imagePushedAt } ]
      | sort_by(.pushed)
      | last
      | .tag // empty
    '
)"

if [[ -z "$TAG" ]]; then
  echo "ERROR: no image in repo '$REPO' has a tag starting with '$PREFIX'." >&2
  exit 1
fi

# ---------- machine-readable result on stdout ----------
jq -n --arg tag "$TAG" '{ "tag": $tag }'
