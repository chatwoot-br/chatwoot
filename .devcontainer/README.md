# Chatwoot BR Devcontainer

Development environment for the [Chatwoot BR](https://github.com/chatwoot-br/chatwoot) fork with Rails, PostgreSQL, Redis, and developer experience tooling.

## Architecture

Three-layer Docker build chain, each cached independently on GHCR:

```
Dockerfile.base    (app infra: Ruby, Node, Overmind, GH CLI)
       |
       v
  ghcr.io/chatwoot-br/chatwoot_codespace:latest
       |
Dockerfile.devx    (devx tools: Fish, Neovim, lazygit, etc.)
       |
       v
  ghcr.io/chatwoot-br/chatwoot_codespace_devx:latest
       |
Dockerfile         (thin layer: copy source + install deps)
```

**Why three layers?**

- `Dockerfile.base` stays close to upstream Chatwoot — easy to sync
- `Dockerfile.devx` changes independently (tool version bumps)
- `Dockerfile` rebuilds every `devcontainer up` (fast, just deps + source)
- Contributors who don't need devx tools can skip the middle layer

## What's in each layer

### Dockerfile.base (app infrastructure)

- Ubuntu 22.04 (MS devcontainer base)
- Node.js 24.14.1, Ruby 3.4.4 (rbenv)
- PostgreSQL client, imagemagick, libpq-dev
- Overmind 2.5.1 (process manager)
- GitHub CLI 2.88.1
- pnpm (via npm), Bundler

### Dockerfile.devx (developer experience)

- Fish 4.6.0 (default shell), Starship 1.22.1 (prompt)
- Neovim 0.12.0 (with LazyVim bootstrapped on first create)
- lazygit 0.60.0, git-delta 0.19.1
- yazi 26.1.22 (file manager), glow 2.1.1 (markdown), chafa 1.18.1 (images)
- Playwright + Chromium (E2E testing)
- Claude Code CLI, bun 1.2.17
- Ghostty terminal integration
- pnpm 10.33.0 (via corepack, overrides base)

### Dockerfile (app layer)

- Copies `Gemfile`, `pnpm-lock.yaml` for dependency caching
- Runs `bundle install` and `pnpm install --frozen-lockfile`
- Copies full source code

## Services

Defined in `docker-compose.yml`:

| Service | Image | Purpose |
|---------|-------|---------|
| `app` | Built from Dockerfile | Rails app + devx tools |
| `db` | `pgvector/pgvector:pg16` | PostgreSQL with vector extension |
| `redis` | `redis:latest` | Cache and background jobs |
| `mailhog` | `mailhog/mailhog` | Local email testing (UI on port 8025) |

All services share a network via `network_mode: service:db`.

## Ports

| Port | Service |
|------|---------|
| 3000 | Rails server |
| 3036 | Vite dev server |
| 8025 | Mailhog UI |
| 37777 | Memory server |

## Setup lifecycle

The `setup.sh` script runs in three phases:

1. **`init`** (initializeCommand) — Creates bind mount source directories on the host
2. **`create`** (postCreateCommand) — Idempotent `.env` setup, Claude CLI install, LazyVim bootstrap, then runs `db:chatwoot_prepare` and `pnpm install`
3. **`start`** (postStartCommand) — Refreshes symlinks, sets Codespaces port visibility

## Persistent mounts

These directories survive container rebuilds via bind mounts:

| Mount | Purpose |
|-------|---------|
| `~/.claude` | Claude Code config and API keys |
| `~/.config` | Neovim, fish, starship configs |
| `~/.local/share` | XDG data (shell history, etc.) |
| `~/.local/state` | XDG state |
| `~/.claude-mem` | Claude memory |
| `~/.codex` | Codex CLI config |
| `/workspace/notebook` | Notebook repo (bind mount) |
| `/workspace/code` | Sibling repos (Docker volume) |

## Environment variables

- Create `.env.devcontainer` at the repo root for secrets (gitignored)
- On first create, `.env` is generated from `.env.example` with devcontainer defaults
- If `CLAUDE_CODE_API_KEY` is set (e.g., in Codespaces secrets), it's automatically configured

## Building and publishing images

### Prerequisites

```bash
# Authenticate to GHCR via GitHub CLI (recommended)
gh auth login
gh auth token | docker login ghcr.io -u $(gh api user -q .login) --password-stdin

# Or with a personal access token (needs write:packages scope)
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin
```

### Build and push

Images must be built in order — devx depends on base.

```bash
# Build and push base image
docker compose -f .devcontainer/docker-compose.base.yml build base
docker push ghcr.io/chatwoot-br/chatwoot_codespace:latest

# Build and push devx image
docker compose -f .devcontainer/docker-compose.base.yml build devx
docker push ghcr.io/chatwoot-br/chatwoot_codespace_devx:latest
```

### GitHub Actions (CI)

Images are automatically built and pushed to GHCR when `.devcontainer/` files change on the `main` branch. The workflow lives at `.github/workflows/devcontainer-images.yml`.

To trigger a manual build, use the GitHub Actions UI or:

```bash
gh workflow run devcontainer-images.yml --ref main
```

The workflow builds base first, then devx (sequential, since devx depends on base). Both images are tagged with `latest` and the commit SHA for rollback.

### Tagging releases

Tag images with a version alongside `latest` for rollback:

```bash
docker tag ghcr.io/chatwoot-br/chatwoot_codespace:latest \
           ghcr.io/chatwoot-br/chatwoot_codespace:2026.04.03
docker push ghcr.io/chatwoot-br/chatwoot_codespace:2026.04.03
```

### Multi-architecture builds

The Dockerfiles handle `TARGETARCH` for arm64/amd64. Use buildx for multi-arch:

```bash
docker buildx create --use
docker buildx build --platform linux/amd64,linux/arm64 \
  -f .devcontainer/Dockerfile.base -t ghcr.io/chatwoot-br/chatwoot_codespace:latest \
  --push ..
```

### When to rebuild

| Change | Rebuild |
|--------|---------|
| Ruby/Node version bump | base + devx |
| System deps (apt packages) | base or devx (depending on which layer) |
| Tool version bump (neovim, lazygit, etc.) | devx only |
| Gemfile/pnpm-lock changes | No rebuild needed (handled by Dockerfile at devcontainer up) |
| Source code changes | No rebuild needed (handled by Dockerfile at devcontainer up) |

## File reference

```
.devcontainer/
  Dockerfile.base            # Layer 1: app infrastructure
  Dockerfile.devx            # Layer 2: developer experience tools
  Dockerfile                 # Layer 3: thin app layer (deps + source)
  devcontainer.json           # VS Code / Codespaces configuration
  docker-compose.yml          # Dev services (app, db, redis, mailhog)
  docker-compose.base.yml     # Build targets for GHCR images
  setup.sh                    # Three-phase lifecycle script
  ghostty/                    # Ghostty terminal integration files
    xterm-ghostty.terminfo
    ghostty-shell-integration.fish

.github/workflows/
  publish_codespace_image.yml # CI: builds and pushes base + devx images
```
