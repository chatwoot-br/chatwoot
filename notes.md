# Notes

## Getting started

```bash
cp .env.dev .env
make setup
docker compose -f docker-compose.dev.yaml up
make db

# make run
pnpm rails s -p 3000
pnpm dotenv bundle exec sidekiq -C config/sidekiq.yml

# chuting down
docker compose -f docker-compose.dev.yaml down --volumes
```

### Getting started with Docker

```bash
cp .enc.example .env
docker compose build base
docker compose run --rm rails bundle exec rails db:chatwoot_prepare

docker compose up --build
docker compose down --volumes
```

### Installing PNPM

```bash
corepack enable
corepack prepare pnpm@latest --activate
```

### Installing Ruby

```bash
rvm install ruby-3.4.4 --with-openssl-dir=$(brew --prefix openssl)
rvm use 3.4.4 --default
```

## Development Environment

Go to http://localhost:3000

```
john@acme.inc
P@ssw0rd
```

## Rebase with upstream

```bash
git fetch --all --prune
git checkout next
git rebase upstream/master --autostash

git checkout -B release/v4
git push --no-verify --set-upstream origin release/v4

git checkout next
git rebase upstream/master --autostash
```

## Build

```sh
git clean -fdx
git reset --hard

rm -rf enterprise
rm -rf spec/enterprise
echo -en '\nENV CW_EDITION="ce"' >> docker/Dockerfile

# docker buildx use crossplatform-builder
docker buildx build --load --platform linux/arm64 -t ghcr.io/chatwoot-br/chatwoot:next -f docker/Dockerfile .
docker buildx build --load --platform linux/arm64 -f docker/Dockerfile . --no-cache
docker buildx build --load --platform linux/amd64 -f docker/Dockerfile . --no-cache

# git rev-list --count upstream..HEAD
docker buildx build --platform linux/arm64 -t ghcr.io/chatwoot-br/chatwoot:next -f docker/Dockerfile --push .

docker buildx imagetools create \
  --tag ghcr.io/chatwoot-br/chatwoot:v4.4.0 \
  --tag ghcr.io/chatwoot-br/chatwoot:v4.4 \
  --tag ghcr.io/chatwoot-br/chatwoot:v4 \
  ghcr.io/chatwoot-br/chatwoot:next

docker buildx imagetools create \
  --tag ghcr.io/chatwoot-br/chatwoot:v3.18.0 \
  --tag ghcr.io/chatwoot-br/chatwoot:v3.18 \
  --tag ghcr.io/chatwoot-br/chatwoot:v3 \
  --tag ghcr.io/chatwoot-br/chatwoot:latest \
  ghcr.io/chatwoot-br/chatwoot:next

# docker buildx build --platform linux/arm64 -t ghcr.io/chatwoot-br/chatwoot:latest -f docker/Dockerfile --push .
# docker buildx build --platform linux/amd64,linux/arm64 -t ghcr.io/chatwoot-br/chatwoot:wavoip -f docker/Dockerfile --push .
```

## Keep tracking

Comparing changes between 3.x and master branches:

     https://github.com/chatwoot/chatwoot/compare/master...3.x

RAILS_ENV=development bundle exec rails db:chatwoot_prepare

```bash
curl -X GET "http://host.docker.internal:3001/app/status" -u "admin:password123"
curl -X GET "http://host.docker.internal:3001/5521995539939/app/status" -u "admin:password123"

curl -X GET "http://host.docker.internal:8088/admin/instances" \
 -H "Authorization: Bearer dev-token-123"

curl -X DELETE "http://host.docker.internal:8088/admin/instances/3001" \
  -H "Authorization: Bearer dev-token-123"

curl -X POST "http://host.docker.internal:8088/admin/instances" \
  -H "Authorization: Bearer dev-token-123" \
  -H "Content-Type: application/json" \
  -d '{
    "port": 3001,
    "basic_auth": "admin:password123",
    "debug": true,
    "base_path": "/5521995539939",
    "webhook": "http://host.docker.internal:5000/webhooks/whatsapp_web/5521995539939",
    "webhook_secret": "my-webhook-secret"
  }'
```

sudo apt-get update && sudo apt-get install -y libvips42 libvips-dev libvips-tools

# Mate todos os processos Rails

pkill -f rails
pkill -f sidekiq

make db_reset
