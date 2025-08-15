---
paths:
  - "app/javascript/**"
  - "theme/**"
  - "vite.config.ts"
  - "postcss.config.js"
  - "tailwind.config.js"
  - "histoire.config.ts"
---

# Guidelines — Frontend (Vue 3 + Vite + TS)

- **Architecture:** use **Composition API** with `<script setup lang="ts">`. Avoid Options API in new code.
- **Styling:** Tailwind + PostCSS. Do not use CSS-in-JS; prefer utility classes for local styles.
- **Accessibility:** label controls; keyboard navigation; `aria-*` where needed.
- **State & effects:** create **composables** for reusable logic. Avoid coupling business rules to UI components.
- **HTTP calls:** use existing helpers; always handle loading/error states; expose response types.
- **Internationalization:** follow the project i18n pipeline. Do not hardcode strings—use translation keys.
- **Testing:**
  - Unit: Vitest + Testing Library. Cover behavior and prop contracts.
  - Snapshot/visual: **Histoire** where it makes sense.
- **Build:** Vite is the default. Do not propose Webpack.
- **Lint/format:** follow `.eslintrc.js` and `.prettierrc`. No `any` without justification.