# Chatwoot Code Style and Conventions

## Ruby/Rails Conventions

### Style Rules
- **Line Length**: Maximum 150 characters
- **Class Length**: Maximum 175 lines (except Message and Conversation models)
- **Method Length**: Maximum 19 lines
- **String Literals**: No frozen string literal comments required
- **Documentation**: Style/Documentation is disabled (not required)
- **Module/Class Definitions**: Use compact style (`module::class`) instead of nested

### RuboCop Configuration
- Uses plugins: rubocop-performance, rubocop-rails, rubocop-rspec, rubocop-factory_bot
- Custom cops in `./rubocop/` directory
- Auto-fix with: `bundle exec rubocop -a`

### Rails Best Practices
- Use strong parameters in controllers
- Add proper validations and indexes to models
- Use custom exceptions from `lib/custom_exceptions/`
- Follow RESTful conventions
- Use service objects for complex business logic
- Use finders for complex queries
- Use presenters for view logic

### Testing (RSpec)
- Maximum example length: 25 lines
- Use FactoryBot for test data
- Use shoulda-matchers for model specs
- Avoid writing specs unless explicitly requested

## JavaScript/Vue Conventions

### Vue 3 Composition API
- **Always** use Composition API with `<script setup>`
- Script block must come FIRST, then template, then style
- Component name casing: PascalCase
- Event name casing: camelCase
- Props declaration: Use runtime declaration style

### ESLint Rules (Airbnb + Vue 3)
- Use Prettier for formatting
- No bare strings in templates (use i18n)
- Component import names must match component names
- Define props before emits
- No multi-word component names enforcement disabled

### Vue Component Structure
```vue
<script setup>
// imports
// props definition
// emits definition
// composables
// reactive data
// computed properties
// methods
// lifecycle hooks
</script>

<template>
  <!-- template content -->
</template>

<style>
/* NO custom CSS - Tailwind only! */
</style>
```

## Styling Guidelines

### Tailwind CSS ONLY
- **NEVER** write custom CSS
- **NEVER** use scoped styles
- **NEVER** use inline styles
- **ALWAYS** use Tailwind utility classes
- Colors defined in `tailwind.config.js`

### Component Styling Example
```vue
<!-- GOOD -->
<div class="flex items-center justify-between p-4 bg-white rounded-lg shadow-md">

<!-- BAD -->
<div style="display: flex; padding: 16px;">
<div class="custom-container">
```

## General Conventions

### File Naming
- Ruby files: `snake_case.rb`
- Vue components: `PascalCase.vue`
- JavaScript files: `camelCase.js`
- Test files: `*.spec.js` or `*_spec.rb`

### Git Conventions
- Branch naming: `username/feature-name`
- Commit format: Conventional commits
  - `feat(scope): add new feature`
  - `fix(scope): fix bug`
  - `chore(scope): update dependencies`
- **NEVER** include "Claude" in commit messages
- No attribution to AI tools in commits

### Internationalization
- Backend: Use `en.yml` for Rails i18n
- Frontend: Use `en.json` for Vue i18n
- Only update English files - community handles other languages
- No bare strings in templates

### Code Quality Principles
- MVP focus: Least code change, happy-path only
- No unnecessary defensive programming
- Remove dead/unreachable/unused code
- Pick one approach and implement it (no multiple versions)
- Break complex tasks into small, testable units
- Use `components-next/` for message bubbles

## Enterprise Edition Considerations
- Check for corresponding files in `enterprise/` directory
- Keep behavior compatible across OSS and Enterprise
- Search both trees before editing: `rg -n "Pattern" app enterprise`
- Add extension points instead of hardcoding plan-specific behavior
- Mirror changes in both OSS and Enterprise directories
- Add Enterprise specs under `spec/enterprise`

## PropTypes and Type Safety
- Use PropTypes in Vue components
- Use strong params in Rails controllers
- Validate data against JSON schemas where applicable
- Use proper type declarations in method signatures