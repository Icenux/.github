#!/usr/bin/env bash
# Make a repo's labels identical to labels.json (create/update, delete extras).
# Usage: scripts/sync-labels.sh <repo> [<repo> ...]   (repos within Icenux org)
set -euo pipefail
cd "$(dirname "$0")/.."
for repo in "$@"; do
  full="Icenux/$repo"
  existing=$(gh api --paginate "repos/$full/labels" -q '.[].name')
  jq -c '.[]' labels.json | while read -r l; do
    name=$(jq -r .name <<<"$l"); color=$(jq -r .color <<<"$l"); desc=$(jq -r '.description // ""' <<<"$l")
    match=$(grep -ixF -- "$name" <<<"$existing" | head -1 || true)
    if [ -n "$match" ]; then
      gh api -X PATCH "repos/$full/labels/$(jq -rn --arg n "$match" '$n|@uri')" -f new_name="$name" -f color="$color" -f description="$desc" >/dev/null
    else
      gh api -X POST "repos/$full/labels" -f name="$name" -f color="$color" -f description="$desc" >/dev/null
    fi
  done
  while read -r have; do
    [ -z "$have" ] && continue
    jq -e --arg n "$have" 'any(.[]; .name==$n)' labels.json >/dev/null || \
      gh api -X DELETE "repos/$full/labels/$(jq -rn --arg n "$have" '$n|@uri')" >/dev/null
  done < <(gh api --paginate "repos/$full/labels" -q '.[].name')
  echo "synced $repo"
done
