# github-workflows

Central reusable GitHub Actions workflows for all `teemow/*` repos. Repos
reference these `@main`, so updating a workflow here updates every repo
instantly -- alignment by construction, no sync machinery.

Requires (already set on this repo): Settings → Actions → General → Access →
"Accessible from repositories owned by the user 'teemow'".

## Workflows

| Workflow | Purpose | Runner |
| --- | --- | --- |
| `ci-go.yml` | tidy drift check, vet, build, `test -race`, golangci-lint | ARC (`runs-on` input) |
| `ci-node.yml` | `npm ci`, lint/typecheck/test/build (`--if-present`) | ARC (`runs-on` input) |
| `ci-rust.yml` | `cargo fmt --check`, clippy, test | ARC (`runs-on` input) |
| `ci-python.yml` | ruff check + format, pytest if tests exist | ARC (`runs-on` input) |
| `gitleaks.yml` | secret scan (full history) | ARC (`runs-on` input) |
| `auto-release.yml` | git-cliff tag + GitHub Release on push to main | `ubuntu-latest` |
| `release-go.yml` | GoReleaser artifacts for a tag (chained or `v*` push) | `ubuntu-latest` |

CI/gitleaks workflows take a required `runs-on` input because ARC runner
scale sets are per-repo (`arc-runner-set-amd64-<repo>`, defined in the
spidertron cluster repo). Each CI workflow is deliberately a single job:
one job = one ARC pod, and with scale-to-zero every extra job costs a cold
start.

## Caller stubs

`.github/workflows/ci.yml` in a Go repo:

```yaml
name: CI
on:
  pull_request:
  push:
    branches: [main]
jobs:
  ci:
    uses: teemow/github-workflows/.github/workflows/ci-go.yml@main
    with:
      runs-on: arc-runner-set-amd64-<repo>
  gitleaks:
    uses: teemow/github-workflows/.github/workflows/gitleaks.yml@main
    with:
      runs-on: arc-runner-set-amd64-<repo>
    permissions:
      contents: read
      pull-requests: write
```

`.github/workflows/auto-release.yml`:

```yaml
name: Auto-release
on:
  push:
    branches: [main]
jobs:
  release:
    uses: teemow/github-workflows/.github/workflows/auto-release.yml@main
    permissions:
      contents: write
      pull-requests: read
```

Go repos with a `.goreleaser.yaml` chain GoReleaser off auto-release in the
SAME caller (a separate `push: tags` workflow would never fire -- tags pushed
with `GITHUB_TOKEN` don't trigger other workflows):

```yaml
name: Auto-release
on:
  push:
    branches: [main]
jobs:
  release:
    uses: teemow/github-workflows/.github/workflows/auto-release.yml@main
    permissions:
      contents: write
      pull-requests: read
  goreleaser:
    needs: release
    if: needs.release.outputs.tag != ''
    uses: teemow/github-workflows/.github/workflows/release-go.yml@main
    with:
      tag: ${{ needs.release.outputs.tag }}
    permissions:
      contents: write
```

`release-go.yml` also takes a `working-directory` input for repos whose Go
module lives in a subdirectory (e.g. minecraft-mods' `mcctl/`). GoReleaser's
release mode defaults to keep-existing, so it attaches artifacts to the
release auto-release created without clobbering the git-cliff notes.

## cliff.toml

The git-cliff config lives ONLY here (`cliff-config/cliff.toml`); calling
repos carry no copy. `auto-release.yml` stages it via the `cliff-config`
composite action and injects the repo coordinates through the `GITHUB_REPO`
env var, so release behavior (bump rules, commit grouping, notes template)
is tuned centrally for every repo at once. Releases only happen on
conventional commits (`feat:` / `fix:` / breaking); other commits produce
no release, by design.

## Notes

- No artifact uploads anywhere: the account's Actions storage quota is
  exhausted, and uploads would fail otherwise-green jobs. Releases ship via
  GoReleaser / `gh release create` only.
- `@main` references mean a bad change here breaks all repos at once. Pin to
  a tag if that ever bites.
