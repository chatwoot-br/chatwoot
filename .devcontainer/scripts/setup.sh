#!/bin/bash
set -e

# Copy environment file
cp .env.example .env

# Configure database and services for container environment
sed -i -e '/REDIS_URL/ s/=.*/=redis:\/\/localhost:6379/' .env
sed -i -e '/POSTGRES_HOST/ s/=.*/=localhost/' .env
sed -i -e '/SMTP_ADDRESS/ s/=.*/=localhost/' .env

# Configure frontend URL for GitHub Codespaces if available
if [ -n "$CODESPACE_NAME" ]; then
  sed -i -e "/FRONTEND_URL/ s/=.*/=https:\/\/$CODESPACE_NAME-3000.app.github.dev/" .env
  
  # Make codespace ports public if gh CLI is available
  if command -v gh &> /dev/null; then
    gh codespace ports visibility 3000:public 3036:public 8025:public -c $CODESPACE_NAME || echo "Warning: Could not set port visibility"
  fi
fi

# Setup Claude Code API key if available
if [ -n "$CLAUDE_CODE_API_KEY" ]; then
  mkdir -p ~/.claude
  echo '{"apiKeyHelper": "~/.claude/anthropic_key.sh"}' > ~/.claude/settings.json
  echo "echo \"$CLAUDE_CODE_API_KEY\"" > ~/.claude/anthropic_key.sh
  chmod +x ~/.claude/anthropic_key.sh
fi
