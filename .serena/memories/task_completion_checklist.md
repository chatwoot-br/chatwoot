# Task Completion Checklist

When you complete a coding task in the Chatwoot project, follow these steps to ensure code quality and consistency:

## 1. Code Quality Checks

### Format and Lint Code
```bash
# For Ruby/Rails changes
bundle exec rubocop -a

# For JavaScript/Vue changes
pnpm eslint:fix

# For both
pnpm ruby:prettier && pnpm eslint:fix
```

## 2. Run Tests

### Test Modified Code
```bash
# For Ruby changes - run related specs
bundle exec rspec spec/path/to/modified_spec.rb

# For JavaScript/Vue changes
pnpm test
# OR for watch mode during development
pnpm test:watch
```

### Run Full Test Suite (before committing)
```bash
# Ruby tests
bundle exec rspec

# JavaScript tests
pnpm test
```

## 3. Check for Enterprise Impact

If you modified core functionality:
```bash
# Search for related files in enterprise directory
rg -n "ClassName|method_name" enterprise/

# Check if enterprise has corresponding files
ls enterprise/app/path/to/your/file.rb
```

## 4. Verify Internationalization

- Ensure no bare strings in Vue templates
- Check that all user-facing text uses i18n
- Update `en.yml` (backend) or `en.json` (frontend) if needed

## 5. Check Tailwind Usage

For any UI changes:
- Verify NO custom CSS was added
- Ensure only Tailwind utility classes are used
- Check responsive behavior with Tailwind breakpoints

## 6. Pre-commit Verification

```bash
# This runs automatically with git hooks, but you can run manually
pnpm eslint && bundle exec rubocop

# Check bundle size if you added dependencies
pnpm size
```

## 7. Final Checks Before Pushing

- [ ] All tests pass
- [ ] Code is properly formatted and linted
- [ ] No console.log or debugging code left
- [ ] Translations added for new user-facing text
- [ ] Enterprise compatibility checked
- [ ] Changes follow MVP principle (least code, happy path)
- [ ] Dead code removed
- [ ] Tailwind-only styling (no custom CSS)

## 8. Git Operations

```bash
# Stage changes
git add .

# Create conventional commit
git commit -m "type(scope): description"
# Examples:
# feat(inbox): add message threading
# fix(api): resolve authentication issue
# chore(deps): update vue to latest

# Push to remote
git push origin username/feature-name
```

## Common Issues to Check

1. **RuboCop failures**: Run `bundle exec rubocop -a` to auto-fix
2. **ESLint errors**: Run `pnpm eslint:fix` to auto-fix
3. **Test failures**: Check test output and fix failing tests
4. **i18n missing**: Add translations to en.yml/en.json
5. **Enterprise conflicts**: Coordinate changes with enterprise directory
6. **Build size exceeded**: Check widget size limit (300KB) and SDK size (40KB)

## When in Doubt

- Follow existing patterns in the codebase
- Check similar files for conventions
- Prioritize readability and maintainability
- Keep changes minimal and focused