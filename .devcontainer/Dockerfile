# The below image is created out of the Dockerfile.base
# It has the dependencies already installed so that codespace will boot up fast
ARG DEVX_IMAGE=ghcr.io/chatwoot-br/chatwoot_codespace_devx:latest
FROM ${DEVX_IMAGE}

# Do the set up required for chatwoot app
WORKDIR /workspace/chatwoot

# Copy dependency files first for better caching
COPY --chown=vscode:vscode package.json pnpm-lock.yaml ./
COPY --chown=vscode:vscode Gemfile Gemfile.lock ./

# Install dependencies (will be cached if files don't change)
RUN pnpm install --frozen-lockfile && \
    gem install bundler && \
    bundle install --jobs=$(nproc)

# Copy source code after dependencies are installed
COPY --chown=vscode:vscode . /workspace/chatwoot
