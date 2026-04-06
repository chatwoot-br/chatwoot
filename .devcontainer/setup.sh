#!/bin/bash

log() { printf '[setup:%s] %s\n' "$1" "$2"; }
warn() { printf '[setup:%s] WARN: %s\n' "$1" "$2" >&2; }

case "$1" in
  init)
    # Runs on host before container creation — ensure bind mount sources exist
    for dir in .claude .config .local/share .local/state .claude-mem .codex .agents notebook; do
      mkdir -p "${LOCAL_WORKSPACE_FOLDER}/../${dir}"
    done

    # Ensure .env.devcontainer exists (runArgs --env-file requires it)
    touch "${LOCAL_WORKSPACE_FOLDER}/.env.devcontainer"

    # Shared volume between chatwoot and notebook devcontainers
    if command -v docker &>/dev/null && ! docker volume inspect woot-code &>/dev/null 2>&1; then
      docker volume create woot-code
    fi
    ;;

  create)
    # === Chatwoot app setup (idempotent) ===
    if [ ! -f .env ]; then
      log create "Creating .env from .env.example"
      cp .env.example .env
      sed -i -e '/REDIS_URL/ s/=.*/=redis:\/\/localhost:6379/' .env
      sed -i -e '/POSTGRES_HOST/ s/=.*/=localhost/' .env
      sed -i -e '/SMTP_ADDRESS/ s/=.*/=localhost/' .env
      if [ -n "$CODESPACE_NAME" ]; then
        sed -i -e "/FRONTEND_URL/ s/=.*/=https:\/\/$CODESPACE_NAME-3000.app.github.dev/" .env
      fi
    else
      log create ".env already exists, skipping"
    fi

    # Setup Claude Code API key if available (Codespaces path)
    if [ -n "$CLAUDE_CODE_API_KEY" ]; then
      mkdir -p ~/.claude
      printf '%s' "$CLAUDE_CODE_API_KEY" > ~/.claude/api_key
      chmod 600 ~/.claude/api_key
      printf '#!/bin/sh\ncat ~/.claude/api_key\n' > ~/.claude/anthropic_key.sh
      chmod +x ~/.claude/anthropic_key.sh
      echo '{"apiKeyHelper": "~/.claude/anthropic_key.sh"}' > ~/.claude/settings.json
    fi

    # === DevX tooling setup ===

    # Claude CLI — native installer puts binary at ~/.local/bin/claude
    # Not pinned: installer auto-updates on each run; guard prevents re-install
    if [ ! -x ~/.local/bin/claude ]; then
      log create "Installing Claude CLI (native)"
      curl -fsSL https://claude.ai/install.sh | bash || warn create "Claude CLI install failed"
    fi

    # Restore claude config from backup if needed, then symlink into mounted dir
    if [ ! -f ~/.claude/.claude.json ] && ls ~/.claude/backups/.claude.json.backup.* &>/dev/null; then
      cp "$(ls -t ~/.claude/backups/.claude.json.backup.* | head -1)" ~/.claude/.claude.json
    fi
    ln -sf ~/.claude/.claude.json ~/.claude.json

    # Codex CLI (user-local npm package)
    if ! command -v codex &>/dev/null; then
      log create "Installing Codex CLI"
      npm install --prefix ~/.local -g @openai/codex || warn create "Codex CLI install failed"
    fi

    # agent-browser skills for Claude Code (~/.agents is bind-mounted, persists)
    if [ ! -f ~/.agents/.skill-lock.json ]; then
      log create "Installing agent-browser skills"
      npx -y skills@1.4.9 add vercel-labs/agent-browser --skill agent-browser -g -y || warn create "agent-browser skill install failed"
      npx -y skills@1.4.9 add vercel-labs/agent-browser --skill dogfood -g -y || warn create "dogfood skill install failed"
    fi

    # LazyVim (bootstrap starter config if not already present)
    LAZYVIM_STARTER_TAG=v4.43.0
    if [ ! -d ~/.config/nvim ]; then
      log create "Bootstrapping LazyVim (${LAZYVIM_STARTER_TAG})"
      git clone --depth 1 --branch "$LAZYVIM_STARTER_TAG" https://github.com/LazyVim/starter ~/.config/nvim
      rm -rf ~/.config/nvim/.git
    fi
    ;;

  db-prepare)
    # Runs after create — fails by default so broken DBs are caught early.
    # Set DEVCONTAINER_DB_SOFT_FAIL=1 to allow container creation to proceed anyway.
    if POSTGRES_STATEMENT_TIMEOUT=600s bundle exec rake db:chatwoot_prepare; then
      log db-prepare "Database ready"
    else
      if [ "${DEVCONTAINER_DB_SOFT_FAIL:-0}" = "1" ]; then
        warn db-prepare "db:chatwoot_prepare failed (soft-fail enabled — run manually later)"
      else
        warn db-prepare "db:chatwoot_prepare failed. Set DEVCONTAINER_DB_SOFT_FAIL=1 in .env.devcontainer to skip."
        exit 1
      fi
    fi
    ;;

  start)
    # Runs every container start — refresh symlinks and services

    # Claude config symlink
    ln -sf ~/.claude/.claude.json ~/.claude.json

    # claude-mem plugin hardcodes /home/node paths (from notebook devcontainer origin).
    # Symlink so those paths resolve when running as vscode user.
    if [ ! -e /home/node ] && [ "$HOME" != "/home/node" ]; then
      sudo ln -s "$HOME" /home/node 2>/dev/null || true
    fi

    # Codespaces: make ports public
    if [ -n "$CODESPACE_NAME" ] && command -v gh >/dev/null 2>&1; then
      gh codespace ports visibility 3000:public 3036:public 8025:public -c "$CODESPACE_NAME" || true
    fi
    ;;

  *)
    echo "Usage: setup.sh {init|create|db-prepare|start}" >&2
    exit 1
    ;;
esac
