# Chatwoot Project Overview

## About
Chatwoot is an open-source customer support platform that serves as an alternative to Intercom, Zendesk, and Salesforce Service Cloud. It's a modern, self-hosted solution designed to help businesses deliver exceptional customer support experiences.

## Key Features
- **Captain AI Agent**: AI-powered support automation for handling common queries
- **Omnichannel Support**: Centralized inbox for all customer conversations (website live chat, email, Facebook, Instagram, Twitter, WhatsApp, Telegram, Line, SMS)
- **Help Center Portal**: Built-in knowledge base for publishing help articles and FAQs
- **Team Collaboration**: Private notes, @mentions, labels, canned responses, auto-assignment
- **Customer Management**: Contact profiles with interaction history, segments, custom attributes
- **Integrations**: Slack, Dialogflow, Shopify, Google Translate, Linear
- **Analytics**: Comprehensive reports on conversations, agents, inboxes, teams, and CSAT

## Repository Structure
- **Main Branch**: `next` (development branch using git-flow model)
- **Stable Branch**: `master` (stable releases with version tags v1.x.x)
- **Current Branch**: `release/v4.7`

## Special Considerations
- **Enterprise Edition**: Enterprise overlay under `enterprise/` directory that extends/overrides OSS code
- **Internationalization**: Community-managed translations via Crowdin
- **OpenSpec**: Change proposal system for managing architectural changes and new features

## Version Information
- Current Version: 4.7.0
- Ruby Version: 3.4.4
- Node Version: 23.x
- pnpm Version: 10.x

## Documentation
- Main documentation: https://www.chatwoot.com/help-center
- Translation guide: https://www.chatwoot.com/docs/contributing/translating-chatwoot-to-your-language
- Enterprise development: https://chatwoot.help/hc/handbook/articles/developing-enterprise-edition-features-38