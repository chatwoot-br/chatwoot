# The below image is created out of the Dockerfile.base
# It has the dependencies already installed so that codespace will boot up fast
FROM ghcr.io/chatwoot/chatwoot_codespace:latest

# Set environment variables
ENV RAILS_ENV=development
ENV NODE_ENV=development

# Set the working directory
WORKDIR /workspace

# Note: Dependencies will be installed via postCreateCommand to avoid cache issues
