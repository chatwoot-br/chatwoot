# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [v4.8.0+5] - 2026-01-20

### Fork Changes
- fix(whatsapp): remove phone_number_id param from media retrieval for incoming messages (cherry-picked from upstream v4.10.1)

### Chart Changes (4.8.6)
- fix(helm): separate container and pod security contexts for better Kubernetes compliance
- feat(helm): add default runAsNonRoot and runAsUser to podSecurityContext

## [v4.8.0+4] - 2025-12-11

### Fork Changes
- feat(whatsapp): add message history import for WhatsApp Web (#10)
- fix(whatsapp): preserve sync status when updating inbox settings
- fix(whatsapp): search both Brazil phone variants to prevent duplicate conversations
- fix(whatsapp): skip group chats during history import when ignore_group_messages is enabled
- fix(whatsapp): fix sync status indicator getting stuck after connection
- fix(whatsapp): validate bearer token in connection test

## [v4.8.0+3] - 2025-12-09

### Fork Changes
- fix(docker): update evolution-api image version and correct WhatsApp port mapping
- feat(whatsapp): add option to ignore messages from groups
- fix(whatsapp): show all gateway settings in inbox edit mode
- fix(whatsapp): add basic auth to gateway readiness check

## [v4.8.0+2] - 2025-12-08

### Fork Changes
- feat(whatsapp): add dynamic instance provisioning via Admin API (#9)
- fix(helm): default image tag to appVersion when not specified

## [v4.8.0+1] - 2025-12-06

### Fork Changes
- feat(helm): add Helm chart for Kubernetes deployment
- fix(ci): update docker workflow to build Chatwoot image
- fix(tests): resolve test failures in inbox, openai, and whatsapp specs
- fix(tests): resolve remaining spec failures in evolution and transcription
- fix(tests): resolve Evolution channel test failures
- fix(rubocop): resolve linting offenses in app and lib code
- docs: add fork versioning strategy for Chatwoot-BR
- feat(v4.7): chatwoot-br custom features
