# CI/CD Pipeline

## Architecture

```
Yvictor/rshioaji (private, development)
  ├── .github/workflows/trigger-ci.yml        push/PR → dispatch CI to sinotrade
  └── .github/workflows/trigger-release.yml   release:published → dispatch release to sinotrade

sinotrade/rshioaji (public, CI runner + release)
  ├── .github/workflows/ci.yml                workflow_dispatch → clone private repo → test
  ├── .github/workflows/release.yml           workflow_dispatch → build → PyPI + GitHub Releases
  ├── install.sh                              curl install script (Linux/macOS)
  └── install.ps1                             PowerShell install script (Windows)
```

## CI Flow

```
Developer pushes/PRs to Yvictor/rshioaji
        │
        ▼
trigger-ci.yml (Yvictor)
  dispatches workflow_dispatch to sinotrade/rshioaji
  passes: ref (commit SHA), branch name
        │
        ▼
ci.yml (sinotrade)
  ├── Clone Yvictor/rshioaji via SSH deploy key
  ├── Clone Yvictor/rsolace (public dependency)
  │
  ├── rust-checks job:
  │     ├── Build dashboard (pnpm install && pnpm build)
  │     ├── Lint dashboard (pnpm lint)
  │     ├── cargo fmt --check
  │     ├── cargo clippy --all-targets
  │     └── cargo test --lib
  │
  └── python-tests job:
        ├── Build dashboard (pnpm install && pnpm build)
        ├── uv run maturin develop
        └── uv run pytest tests/unit/ -v
```

**Why sinotrade?** Public repos have unlimited GitHub Actions minutes. Private repos are limited.

## Release Flow

```
Developer creates GitHub Release on Yvictor/rshioaji
  gh release create v1.5.0 --title "v1.5.0" --notes "..."
        │
        ▼
trigger-release.yml (Yvictor)
  fires on release:published event
  dispatches workflow_dispatch to sinotrade/rshioaji
  passes: version (tag name), release_notes, prerelease flag
        │
        ▼
release.yml (sinotrade)
  ├── Clone Yvictor/rshioaji at tag via SSH deploy key
  ├── Clone Yvictor/rsolace
  │
  ├── build-wheels-linux (x86_64):
  │     ├── Build dashboard (pnpm)
  │     ├── Install LLVM (for rsolace-sys bindgen)
  │     ├── cargo build --release → standalone binary
  │     ├── Copy binary to python/shioaji.data/scripts/
  │     ├── maturin build --zig --compatibility manylinux2014
  │     │   (uses CARGO_TARGET_DIR to reuse cargo build artifacts)
  │     ├── Upload wheel artifact
  │     └── Upload binary artifact (.tar.gz)
  │
  ├── build-wheels-macos (aarch64):
  │     ├── Build dashboard (pnpm)
  │     ├── cargo build --release → standalone binary
  │     ├── Copy binary to python/shioaji.data/scripts/
  │     ├── maturin-action → wheel
  │     │   (uses CARGO_TARGET_DIR to reuse cargo build artifacts)
  │     ├── Upload wheel artifact
  │     └── Upload binary artifact (.tar.gz)
  │
  ├── build-wheels-windows (x86_64):
  │     ├── Build dashboard (pnpm)
  │     ├── Setup Clang + MSVC
  │     ├── cargo build --release → standalone binary
  │     ├── Copy binary to python/shioaji.data/scripts/
  │     ├── maturin-action → wheel
  │     │   (uses CARGO_TARGET_DIR to reuse cargo build artifacts)
  │     ├── Upload wheel artifact
  │     └── Upload binary artifact (.zip)
  │
  ├── publish-pypi:
  │     ├── Download all wheel artifacts
  │     └── Publish to PyPI via OIDC trusted publisher
  │
  └── github-release:
        ├── Download all artifacts (wheels + binaries)
        ├── Copy install.sh and install.ps1
        └── Create GitHub Release on sinotrade/rshioaji
```

## What's in the Wheel

Each platform wheel contains:
- `shioaji/_core.abi3.so` (or `.pyd`) — PyO3 Python extension (trading API)
- `shioaji.data/scripts/shioaji` (or `.exe`) — standalone CLI binary

After `pip install rshioaji` or `uv tool install rshioaji`:
- `import shioaji` — Python trading API
- `shioaji server` — native CLI binary on PATH

## Build Optimizations

**Shared CARGO_TARGET_DIR**: `cargo build --release` (binary) and `maturin build --release` (wheel) share the same target directory. The maturin build reuses all compiled dependencies from the cargo build (~0.4s vs ~8min).

**Linux: maturin + zig**: Linux uses `maturin build --zig` instead of maturin-action's Docker container. The manylinux Docker container lacks `libclang` (needed by `rsolace-sys` bindgen). The zig approach builds natively with LLVM installed via `install-llvm-action`.

## Secrets & Setup

| Secret | Repo | Purpose |
|--------|------|---------|
| `PRIVATE_REPO_DEPLOY_KEY` | sinotrade/rshioaji | SSH key to clone Yvictor/rshioaji (read-only) |
| `RELEASE_DISPATCH_TOKEN` | Yvictor/rshioaji | PAT to trigger workflow_dispatch on sinotrade |

**PyPI**: OIDC trusted publisher configured for sinotrade/rshioaji → `rshioaji` package.

**Deploy key setup**:
```bash
ssh-keygen -t ed25519 -f deploy_key -N ""
gh repo deploy-key add deploy_key.pub --repo Yvictor/rshioaji --title "sinotrade-ci"
gh secret set PRIVATE_REPO_DEPLOY_KEY --repo sinotrade/rshioaji < deploy_key
```

## Version Strategy

```
rshioaji 1.5.0b1  → beta (current)
rshioaji 1.5.0    → stable
--- Phase 2 (issue #101) ---
shioaji 1.5.0a1   → alpha on official shioaji PyPI package
shioaji 1.5.0     → stable (replaces Python shioaji)
```

## Install Methods

```bash
# Python wheel (all platforms)
pip install rshioaji
uv add rshioaji

# CLI tool install
uv tool install rshioaji
shioaji server

# Standalone binary (Linux/macOS)
curl -fsSL https://raw.githubusercontent.com/sinotrade/rshioaji/main/install.sh | sh

# Standalone binary (Windows)
irm https://raw.githubusercontent.com/sinotrade/rshioaji/main/install.ps1 | iex
```

## Platform Matrix

| Platform | Wheel | Binary | CI | Status |
|----------|-------|--------|-----|--------|
| Linux x86_64 | abi3 manylinux2014 | tar.gz | ubuntu-latest | Active |
| macOS aarch64 | abi3 | tar.gz | macos-latest | Active |
| Windows x86_64 | abi3 | zip | windows-latest | Active |
| Linux aarch64 | - | - | - | Commented out (slow) |
| macOS x86_64 | - | - | - | Commented out |
| Free-threaded (3.14t) | - | - | - | Commented out |
