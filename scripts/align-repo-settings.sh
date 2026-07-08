#!/usr/bin/env bash
# One-time repo settings alignment across teemow's private repos.
#
# Applies the canonical settings:
#   - squash-only merges, auto-merge enabled, delete branch on merge
#   - branch protection on main: required correctness checks (ci + gitleaks),
#     enforce_admins off, no review requirement
#
# Only correctness gates are required -- never post-merge/publish jobs
# (release / Tag, goreleaser, docker builds).
#
# Requires: gh authenticated with admin rights on the repos.
# Usage: ./align-repo-settings.sh

set -euo pipefail

OWNER=teemow

# repo -> comma-separated required status check contexts.
# Context = "<workflow name> / <job name>" as reported on check runs.
declare -A CHECKS=(
  [demiurgctl]="ci / go,gitleaks / gitleaks"
  [ekobeescope]="ci / go,gitleaks / gitleaks"
  [fluxforward]="ci / go,gitleaks / gitleaks"
  [minecraft-mods]="ci / go,gitleaks / gitleaks"
  [spiderview]="go / go,frontend / node,gitleaks / gitleaks"
  [stammbaum]="backend / go,frontend / node,gitleaks / gitleaks"
  [training]="backend / node,frontend / node,gitleaks / gitleaks"
  [imgctl]="ci / node,gitleaks / gitleaks"
  [spider]="ci / rust,gitleaks / gitleaks"
  [github-stats]="ci / python,gitleaks / gitleaks"
)

for repo in "${!CHECKS[@]}"; do
  echo "=== ${OWNER}/${repo} ==="

  echo "--- repo settings (squash-only, auto-merge, delete-branch-on-merge)"
  gh api -X PATCH "repos/${OWNER}/${repo}" \
    -F allow_auto_merge=true \
    -F delete_branch_on_merge=true \
    -F allow_squash_merge=true \
    -F allow_merge_commit=false \
    -F allow_rebase_merge=false \
    --silent

  echo "--- branch protection on main (required checks: ${CHECKS[$repo]})"
  jq -n --arg checks "${CHECKS[$repo]}" '{
    required_status_checks: {
      strict: false,
      contexts: ($checks | split(","))
    },
    enforce_admins: false,
    required_pull_request_reviews: null,
    restrictions: null,
    allow_force_pushes: false,
    allow_deletions: false
  }' | gh api -X PUT "repos/${OWNER}/${repo}/branches/main/protection" --input - --silent

  echo "OK"
done

echo
echo "All repos aligned."
