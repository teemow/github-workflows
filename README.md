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
| `release-go.yml` | GoReleaser on `v*` tag | `ubuntu-latest` |

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

`.github/workflows/release.yml` (Go repos with a `.goreleaser.yaml`):

```yaml
name: Release
on:
  push:
    tags: ['v*']
jobs:
  release:
    uses: teemow/github-workflows/.github/workflows/release-go.yml@main
    permissions:
      contents: write
```

## cliff.toml

`auto-release.yml` needs a `cliff.toml` in the calling repo's root. Copy the
canonical one from this repo and replace `REPO_NAME` with the repo name
(git-cliff uses the coordinates for GitHub PR lookups in release notes).
Releases only happen on conventional commits (`feat:` / `fix:` / breaking);
other commits produce no release, by design.

## Notes

- No artifact uploads anywhere: the account's Actions storage quota is
  exhausted, and uploads would fail otherwise-green jobs. Releases ship via
  GoReleaser / `gh release create` only.
- `@main` references mean a bad change here breaks all repos at once. Pin to
  a tag if that ever bites.
