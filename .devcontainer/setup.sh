#!/bin/bash

log() { printf '[setup:%s] %s\n' "$1" "$2"; }
warn() { printf '[setup:%s] WARN: %s\n' "$1" "$2" >&2; }

case "$1" in
  init)
    # Runs on host before container creation — ensure bind mount sources exist
    for dir in .claude .config .local/share .local/state .claude-mem .codex; do
      mkdir -p "${LOCAL_WORKSPACE_FOLDER}/../${dir}"
    done
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
    if [ ! -x ~/.local/bin/claude ]; then
      log create "Installing Claude CLI (native)"
      curl -fsSL https://claude.ai/install.sh | bash || warn create "Claude CLI install failed"
    fi

    # Restore claude config from backup if needed, then symlink into mounted dir
    if [ ! -f ~/.claude/.claude.json ] && ls ~/.claude/backups/.claude.json.backup.* &>/dev/null; then
      cp "$(ls -t ~/.claude/backups/.claude.json.backup.* | head -1)" ~/.claude/.claude.json
    fi
    ln -sf ~/.claude/.claude.json ~/.claude.json

    # Codex CLI (global npm package)
    if ! command -v codex &>/dev/null; then
      log create "Installing Codex CLI"
      sudo npm install -g @openai/codex || warn create "Codex CLI install failed"
    fi

    # LazyVim (bootstrap starter config if not already present)
    if [ ! -d ~/.config/nvim ]; then
      log create "Bootstrapping LazyVim"
      git clone https://github.com/LazyVim/starter ~/.config/nvim
      rm -rf ~/.config/nvim/.git
    fi
    ;;

  start)
    # Runs every container start — refresh symlinks and services

    # Claude config symlink
    ln -sf ~/.claude/.claude.json ~/.claude.json

    # Ensure /home/node points to actual home so hook paths resolve
    if [ ! -e /home/node ] && [ "$HOME" != "/home/node" ]; then
      sudo ln -s "$HOME" /home/node 2>/dev/null || true
    fi

    # Codespaces: make ports public
    if [ -n "$CODESPACE_NAME" ] && command -v gh >/dev/null 2>&1; then
      gh codespace ports visibility 3000:public 3036:public 8025:public -c "$CODESPACE_NAME" || true
    fi
    ;;

  *)
    echo "Usage: setup.sh {init|create|start}" >&2
    exit 1
    ;;
esac
