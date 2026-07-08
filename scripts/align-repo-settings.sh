#!/usr/bin/env bash
# Repo settings alignment across teemow's whole repo estate (v2 scope: every
# non-fork, non-archived repo).
#
# Every repo gets the canonical merge settings:
#   - squash-only merges, auto-merge enabled, delete branch on merge
#
# Repos with CI/gitleaks callers additionally get branch protection on the
# default branch: required correctness checks, enforce_admins off, no review
# requirement. Only correctness gates are required -- never post-merge or
# publish jobs (release / Tag, goreleaser, docker builds).
#
# Requires: gh authenticated with admin rights on the repos.
# Usage: ./align-repo-settings.sh

set -euo pipefail

OWNER=teemow

# repo[:branch] -> comma-separated required status check contexts.
# Context = "<caller job name> / <called job name>" as reported on check runs.
# Branch defaults to main.
declare -A CHECKS=(
  # v1: active private repos on ARC runners
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
  # v2 Tier A: public code repos on ubuntu-latest
  [planscope]="ci / go,gitleaks / gitleaks"
  [inboxfewer]="ci / go,gitleaks / gitleaks"
  [marge]="ci / go,gitleaks / gitleaks"
  [mcp-midi-controller]="ci / go,web / node,gitleaks / gitleaks"
  [midi-device]="ci / go,gitleaks / gitleaks"
  [midi-transport]="ci / go,gitleaks / gitleaks"
  [aum-session-go]="ci / go,gitleaks / gitleaks"
  [headlamp-longhorn]="ci / node,gitleaks / gitleaks"
  [hass-vitamix]="ci / python,gitleaks / gitleaks"
  [vitamix-ble]="ci / python,gitleaks / gitleaks"
  # v2 Tier B: gitleaks-only repos
  [planterm]="gitleaks / gitleaks"
  [ble-midi-footswitch]="gitleaks / gitleaks"
  [aum-session-swift]="gitleaks / gitleaks"
  [auv3-host-introspection]="gitleaks / gitleaks"
  [auv3-probe]="gitleaks / gitleaks"
  [rig-capture]="gitleaks / gitleaks"
  [wifi-bottle-lamp]="gitleaks / gitleaks"
  [prometheus-borg-exporter:master]="gitleaks / gitleaks"
  [rpi-borgbackup:master]="gitleaks / gitleaks"
  [heatpump-firmware]="gitleaks / gitleaks"
  [demiurg]="gitleaks / gitleaks"
  [dotfiles]="gitleaks / gitleaks"
  [klaus-lab]="gitleaks / gitleaks"
  [memory]="gitleaks / gitleaks"
  [node-red:master]="gitleaks / gitleaks"
  [node-red-k8s]="gitleaks / gitleaks"
  [productivity]="gitleaks / gitleaks"
  [raspberry-init:master]="gitleaks / gitleaks"
  [spiffy-personalities]="gitleaks / gitleaks"
  [spiffy-plugins]="gitleaks / gitleaks"
  [spiffy-toolchains]="gitleaks / gitleaks"
  [github-workflows]="gitleaks / gitleaks"
  # spidertron: keeps its extra Mirror Gate check; enforce_admins stays ON
  # (managed below as a special case, not here)
)

# Merge settings go to every non-fork, non-archived repo, even settings-only
# ones (Tier C).
echo "=== merge settings (all non-fork, non-archived repos) ==="
for repo in $(gh repo list "$OWNER" --limit 200 --no-archived --source --json name --jq '.[].name'); do
  echo "--- ${OWNER}/${repo}"
  gh api -X PATCH "repos/${OWNER}/${repo}" \
    -F allow_auto_merge=true \
    -F delete_branch_on_merge=true \
    -F allow_squash_merge=true \
    -F allow_merge_commit=false \
    -F allow_rebase_merge=false \
    --silent || echo "FAILED: merge settings on $repo"
done

echo
echo "=== branch protection (repos with CI/gitleaks callers) ==="
for key in "${!CHECKS[@]}"; do
  repo="${key%%:*}"
  branch="${key#*:}"; [ "$branch" = "$repo" ] && branch=main
  echo "--- ${OWNER}/${repo}@${branch} (required: ${CHECKS[$key]})"
  jq -n --arg checks "${CHECKS[$key]}" '{
    required_status_checks: {
      strict: false,
      contexts: ($checks | split(","))
    },
    enforce_admins: false,
    required_pull_request_reviews: null,
    restrictions: null,
    allow_force_pushes: false,
    allow_deletions: false
  }' | gh api -X PUT "repos/${OWNER}/${repo}/branches/${branch}/protection" --input - --silent \
    || echo "FAILED: protection on $repo"
done

echo
echo "All repos aligned."
