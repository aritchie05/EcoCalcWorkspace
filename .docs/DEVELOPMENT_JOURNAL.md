# Development Journal

## Session: 2026-03-10.7 - Upgrade 5 Locale Entries

### Work Completed

- Added `ModernUpgrade5`, `BasicUpgrade5`, and `AdvancedUpgrade5` to the final `upgrades` block in `locale-data.ts`
- Reused the existing translation patterns from the corresponding Upgrade 4 entries, updating only the numeric suffixes

### Problems & Solutions

- The file contains multiple repeated upgrade blocks; updated only the final block at the end of the file as requested

### Files Modified

- `EcoCraftingTool/src/assets/data/locale/locale-data.ts` - Added the three new Upgrade 5 locale entries
- `.docs/DEVELOPMENT_JOURNAL.md` - Recorded the locale data update

### Testing

- `npm run build`

### Technical Debt

- `locale-data.ts` contains repeated upgrade sections that are easy to desynchronize if future additions are applied
  selectively

### Next Steps

- If these new upgrade IDs are needed in earlier repeated locale blocks as well, sync the same entries there too

## Session: 2026-03-10.6 - INP Performance Optimizations Implementation

### Work Completed

- Implemented all 7 prioritized INP performance optimizations from audit sessions .4 and .5
- **INP improved from 1,543ms → 263ms (83% reduction)** under 4× CPU throttle with 7+ skills loaded
- Presentation delay improved from 1,232ms → 96ms (92% reduction) — the dominant bottleneck
- DOM elements reduced from 6,281 → 3,626 (42% reduction) with similar skill count

#### Changes Made

1. **Created `LocaleNumberPipe`** — pure pipe wrapping `toLocaleString` with Angular pipe memoization, replacing method
   calls in templates
2. **Replaced readonly `mat-form-field` in outputs** — 3 instances (base cost, sale price, sub-recipe cost) replaced
   with lightweight `<div class="readonly-field">` elements, eliminating ~45 DOM nodes per recipe
3. **Replaced readonly `mat-form-field` in recipe-dialog** — all 10 instances replaced with
   `<span class="readonly-field">`, removed MatFormFieldModule/MatInputModule imports entirely
4. **Added lazy expansion panels** — `<ng-template matExpansionPanelContent>` defers rendering of collapsed recipe
   groups; only first group expanded by default
5. **Debounced `computePricesAsync`** — 150ms debounce via setTimeout/clearTimeout pattern, reads signal deps
   synchronously then defers computation
6. **Removed all ~15 `console.debug` calls** per recipe from `computePricesAsync` loop
7. **Batched signal updates in `selectTable()`** — collects all recipes/skills, updates signals once instead of
   per-recipe
8. **Set-based deduplication** in `selectedInputs`/`selectedByproducts` linkedSignals replacing O(n²) `Array.some()`
9. **Map-based price lookups** in `computePricesAsync` for O(1) instead of O(n) `Array.find()`
10. **Sorted insertion** at all mutation points (selectSkill, selectTable, selectRecipe), replacing removed sorting
    effects that wrote to signals they read
11. **Added `autoFocus: false`** to recipe dialog config to prevent forced reflow on dialog open
12. **Added global `.readonly-field` and `.readonly-label` CSS** in `styles.scss` for shared readonly styling

### Problems & Solutions

- Initial runtime error `TypeError: Cannot read properties of undefined (reading 'nameID')` after reload — caused by
  stale persisted state from previous trace session with recipes that had undefined `primaryOutput.item`; resolved by
  clearing localStorage (pre-existing data integrity issue, not caused by changes)
- The previous sorting effects wrote to the same signal they read, risking infinite loops — replaced with sorted
  insertion at each mutation point for deterministic ordering

### Files Modified

- `EcoCraftingTool/src/app/pipe/locale-number.pipe.ts` — New pure pipe for localized number formatting
- `EcoCraftingTool/src/app/pipe/locale-number.pipe.spec.ts` — 7 tests for the pipe
- `EcoCraftingTool/src/styles.scss` — Added `.readonly-field` and `.readonly-label` global CSS
- `EcoCraftingTool/src/app/crafting/outputs/outputs.component.html` — Replaced readonly mat-form-fields, added lazy
  expansion panels
- `EcoCraftingTool/src/app/crafting/outputs/outputs.component.ts` — Added LocaleNumberPipe import, autoFocus: false
- `EcoCraftingTool/src/app/crafting/recipe-dialog/recipe-dialog.component.html` — Replaced all 10 readonly
  mat-form-fields
- `EcoCraftingTool/src/app/crafting/recipe-dialog/recipe-dialog.component.ts` — Removed unused Material imports, added
  LocaleNumberPipe
- `EcoCraftingTool/src/app/crafting/recipe-dialog/recipe-dialog.component.scss` — Removed dead mat-form-field CSS
- `EcoCraftingTool/src/app/service/crafting.service.ts` — Debounced effect, removed console.debug, batched selectTable,
  Set dedup, Map lookups, sorted insertion

### Testing

- All 65 tests pass (including 7 new `LocaleNumberPipe` tests)
- Build succeeds with no errors
- Manual verification: added 9 skills, interacted with all UI sections, opened recipe dialogs, updated prices — no
  console errors
- Performance trace comparison (4× CPU throttle):
  | Metric | Before | After | Improvement |
  |--------|--------|-------|-------------|
  | INP | 1,543ms 🔴 | 263ms 🟡 | 83% ↓ |
  | Presentation delay | 1,232ms | 96ms | 92% ↓ |
  | Processing duration | 300ms | 160ms | 47% ↓ |
  | DOM elements (8-9 skills) | 6,281 | 3,626 | 42% ↓ |

### Technical Debt

- Remaining editable `mat-form-field` instances in inputs.component.html (173 total) — these are necessary for user
  input but contribute to DOM size
- Further DOM reduction possible with virtual scrolling for large recipe/input lists
- The `selectedInputs`/`selectedByproducts` linkedSignals could benefit from a null guard on
  `recipe.primaryOutput?.item` for robustness against corrupt persisted state

### Next Steps

- Consider virtual scrolling (`@angular/cdk/scrolling`) for inputs list when many skills selected
- Consider `@defer` blocks for below-fold content (inputs, outputs sections)
- Monitor CrUX data after deploy to validate field INP improvement

## Session: 2026-03-10.5 - Performance Audit Trace 2 (Heavy DOM)

### Work Completed

- Set up heavy test scenario: 8 skills (Oil Drilling, Smelting, Masonry, Carpentry, Cooking, Tailoring, Advanced
  Smelting, Mining), 190 input prices, 60 recipes
- Ran systematic interactive performance trace with 4× CPU throttling, covering every interaction type left-to-right:
    - Add/remove skills, change skill levels, add/remove crafting tables, update upgrade modules
    - Update calories price, default profit, individual input prices (6 items), output profit overrides (2 items)
    - Open/close recipe detail dialogs (2 times), remove recipes (4 times)
- **INP: 1,543ms** 🔴 Poor (>500ms) — vs 314ms in lighter trace 1
- INP breakdown: 12ms input delay, 300ms processing, **1,232ms presentation delay (80%)**
- DOM: 6,281 elements (↑89% from 3,328), style recalcs affecting 6,872 elements (336ms worst)
- Forced reflow: 671ms total (removeChild: 652ms, getHighContrastMode: 239ms)
- **Critical finding: INP scales super-linearly with DOM** — 89% more DOM causes 391% worse INP

### Problems & Solutions

- All findings from Trace 1 confirmed and amplified at scale
- **Presentation delay dominates** at 80% of total INP — same root cause at any scale
- Processing duration also grew significantly (42ms → 300ms), confirming `computePricesAsync` overhead with many recipes
- Forced reflow doubled (286ms → 671ms) because dialog closes force style recalc on more elements
- The `selected-items-container` div has 129 children — one of the widest DOM nodes

### Files Modified

- `.docs/DEVELOPMENT_JOURNAL.md` — Added this session entry
- Session plan.md — Updated with Trace 2 comparison data and scaling analysis

### Testing

- Manual Chrome DevTools performance trace with 8 skills loaded, 4× CPU throttling
- Systematic interaction coverage: all input types from left to right across the entire app

### Technical Debt

- Same items as Session 2026-03-10.4 — all confirmed at larger scale

### Next Steps

- Implement the 7 prioritized recommendations from the audit
- Priority 1: Replace readonly `mat-form-field` (biggest DOM reduction — targets the 80% presentation delay)
- Priority 2: Lazy expansion panels (defer rendering of collapsed recipe groups)
- Priority 3: Debounce `computePricesAsync` (targets the 300ms processing duration)
- Re-measure after each change to validate improvement

## Session: 2026-03-10.4 - Performance Audit (INP & TBT)

### Work Completed

- Ran Lighthouse audits (100/100 on accessibility, best practices, SEO)
- Captured performance traces with Chrome DevTools — unthrottled and with 4× CPU throttling
- Measured INP: 90ms (unthrottled), **314ms** (4× CPU throttle, "Needs Improvement")
- Identified that **85.7% of INP (269ms) is presentation delay** — style recalculation and layout, not JS processing
- Analyzed DOM statistics: 3,328 elements, style recalcs affecting 3,694 elements (267ms), forced reflow on dialog
  close (286ms)
- Performed full code review of templates, services, and change detection patterns
- Documented 7 prioritized recommendations in session plan

### Problems & Solutions

- The dominant INP bottleneck is **DOM complexity from readonly `mat-form-field` wrappers** — each adds ~12-15 internal
  nodes but only displays a static value. Replacing with plain `<span>` elements would eliminate ~960 unnecessary DOM
  nodes
- **Expansion panels always expanded** prevents lazy DOM creation for off-screen recipe groups
- `computePricesAsync` fires on every individual price input change with no debounce, plus ~15 `console.debug` calls per
  recipe per loop
- `selectTable()` updates signals inside a loop (per-recipe), causing cascading rerenders instead of batching

### Files Modified

- `.docs/DEVELOPMENT_JOURNAL.md` — Added performance audit session entry

### Testing

- Manual Chrome DevTools performance traces on http://localhost:4200
- Interactive traces with skill addition, recipe search, price input changes, dialog open/close

### Technical Debt

- Readonly `mat-form-field` wrappers used throughout outputs, inputs, and recipe dialog templates should be replaced
  with plain elements
- `computePricesAsync` lacks debouncing and has excessive console.debug calls
- `selectTable()` and `selectSkill()` methods update signals in loops rather than batching
- Expansion panels render all content eagerly regardless of collapsed state

### Next Steps

- Implement the 7 prioritized recommendations from the audit (see session plan)
- Priority 1: Replace readonly `mat-form-field` with plain styled elements
- Priority 2: Add lazy content to expansion panels
- Priority 3: Create a `LocaleNumberPipe` for template formatting
- Re-measure INP after each change to validate improvement

## Session: 2026-03-10.3 - Remote Vercel Proxy Verification

### Work Completed

- Verified the deployed develop site at `https://eco-crafting-tool.vercel.app/` using Chrome DevTools in a clean browser
  context
- Confirmed the predefined Greenleaf server now succeeds on the deployed HTTPS app through the new Vercel proxy path
- Confirmed saving the successful Greenleaf connection updates the selected server in the deployed UI

### Problems & Solutions

- While testing a control case, the predefined White Tiger HTTPS server did not connect from the deployed app because
  the
  browser blocked both cross-origin XHR requests due to missing `Access-Control-Allow-Origin` headers; this is separate
  from the Greenleaf mixed-content fix and indicates a remaining CORS constraint on that server

### Files Modified

- `.docs/DEVELOPMENT_JOURNAL.md` - Recorded the deployed proxy verification session and the White Tiger CORS finding

### Testing

- Manual browser validation on `https://eco-crafting-tool.vercel.app/` via Chrome DevTools:
    - Greenleaf predefined server:
        - `Test Connection` succeeded
        - Dialog showed `New Items: 228`, `New Recipes: 103`, and `Modified Recipes: 87`
        - Network requests used `POST https://eco-crafting-tool.vercel.app/api/server-proxy` and returned `200`
        - `Save Connection` succeeded and the header server selector changed to `Greenleaf`
    - White Tiger predefined server:
        - Browser attempted direct `GET https://white-tiger.play.eco/api/v1/plugins/EcoPriceCalculator/allItems`
          and `/recipes`
        - Both requests failed with `net::ERR_FAILED`
        - Console errors reported CORS blocking because no `Access-Control-Allow-Origin` header was present for origin
          `https://eco-crafting-tool.vercel.app`
        - Direct top-level navigation to the White Tiger `allItems` endpoint still loaded, confirming the failure is the
          cross-origin browser fetch, not basic endpoint reachability

### Technical Debt

- White Tiger and any other HTTPS servers without browser CORS support will still fail on the deployed app unless they
  add
  CORS headers or are also proxied

### Next Steps

- If desired, extend the proxy strategy beyond HTTP-only servers so deployed HTTPS servers with missing CORS headers can
  also be routed through the Vercel backend

## Session: 2026-03-10.2 - Vercel HTTP Server Proxy

### Work Completed

- Added a Vercel serverless proxy endpoint that accepts a validated public `host[:port]`, fetches the fixed Eco Price
  Calculator `allItems` and `recipes` HTTP endpoints, and returns both payloads in one response
- Updated `PriceCalculatorServerService` to route insecure HTTP servers through the proxy only when the app itself is
  running over HTTPS, while preserving the existing direct-request behavior for local HTTP development and normal HTTPS
  servers
- Added service tests covering the proxied HTTP path, the non-HTTPS local fallback, and the preserved direct HTTPS path

### Problems & Solutions

- A TypeScript Vercel function would have required additional Node type setup in this frontend package, so the proxy was
  implemented as a plain JavaScript Vercel function instead to keep the deployment surface simple and avoid unnecessary
  frontend dependency changes
- Local Angular dev serving does not host Vercel Functions, so the browser-side manual check focused on confirming the
  local HTTP app still stays on the direct-request path while unit tests covered the HTTPS/proxy branch selection

### Files Modified

- `EcoCraftingTool/api/server-proxy.js` - Added the Vercel proxy handler with host validation, SSRF guards, and combined
  upstream fetches
- `EcoCraftingTool/src/app/model/server-api/server-data-response.ts` - Added the shared combined server data response
  interface
- `EcoCraftingTool/src/app/service/price-calculator-server.service.ts` - Routed insecure HTTP servers through the proxy
  only in HTTPS page contexts
- `EcoCraftingTool/src/app/service/price-calculator-server.service.spec.ts` - Added proxy path and direct-path
  regression
  coverage
- `EcoCraftingTool/src/environments/environment.ts` - Added the proxy route configuration
- `EcoCraftingTool/src/environments/environment.preview.ts` - Added the proxy route configuration
- `EcoCraftingTool/src/environments/environment.prod.ts` - Added the proxy route configuration
- `.docs/DEVELOPMENT_JOURNAL.md` - Recorded this proxy implementation session

### Testing

- `npm run build`
- `npm run test-ci`
- `node --check api\\server-proxy.js`
- Proxy handler smoke checks:
    - `POST` with `localhost:3000` -> `400` (`Local hostnames are not allowed.`)
    - `POST` with `eco.greenleafserver.com:3021/path` -> `400` (`Host must only contain host[:port].`)
    - `GET` request -> `405` (`Method not allowed`)
- Manual browser validation on `http://localhost:4200` via Chrome DevTools:
    - Confirmed the local app context reports `window.location.protocol === 'http:'`
    - Confirmed the predefined Greenleaf server still has `useInsecureHttp = true`
    - Confirmed `PriceCalculatorServerService.shouldUseServerProxy(greenleaf)` returns `false` locally, preserving the
      existing direct-request behavior during local development

### Technical Debt

- None introduced

### Next Steps

- After deployment, verify the full end-to-end HTTP server flow on a Vercel preview or production domain so the new
  `/api/server-proxy` route is exercised in a real HTTPS page context

## Session: 2026-03-10.1 - External Server Mixed Content Analysis

### Work Completed

- Investigated why a deployed external server connection fails immediately with `blocked:mixed-content` while the same
  URL responds when opened directly in the browser
- Traced the frontend connection flow to the browser-side `HttpClient` request that switches between `http://` and
  `https://` based on `useInsecureHttp`
- Wrote a dedicated analysis document in the workspace explaining the root cause, the local-vs-deployed difference, and
  practical resolution options

### Problems & Solutions

- No code defect was identified in the request flow; the failure is consistent with browser mixed-content blocking when
  an HTTPS app tries to fetch an HTTP API endpoint

### Files Modified

- `.docs/EXTERNAL_SERVER_MIXED_CONTENT_ANALYSIS.md` - Added the analysis of the mixed-content block and recommended
  fixes
- `.docs/DEVELOPMENT_JOURNAL.md` - Recorded this analysis/documentation session

### Testing

- Not run (documentation-only analysis)

### Technical Debt

- None introduced

### Next Steps

- If this external server should work from the deployed app, expose the API through HTTPS or an HTTPS proxy and then
  verify whether any CORS configuration is also required

## Session: 2026-03-09.2 - Sulfur Output Static Override

### Work Completed

- Extended the inferred server output `IsStatic` exceptions so `Sulfur` is treated as non-static when the same recipe
  also returns a different additional output
- Reused the new shared multi-output exception path so the prior Barrel override and the Ashlar/Crushed behavior stay in
  one place
- Added regression coverage for both the multi-output Sulfur case and the single-output Sulfur fallback

### Problems & Solutions

- No new implementation issues surfaced; the existing helper introduced for the Barrel follow-up made the Sulfur
  extension
  a small, behavior-safe change

### Files Modified

- `EcoCraftingTool/src/app/service/price-calculator-server.service.ts` - Added `Sulfur` to the inferred multi-output
  non-static exceptions
- `EcoCraftingTool/src/app/service/price-calculator-server.service.spec.ts` - Added Sulfur-specific regression tests
- `.docs/DEVELOPMENT_JOURNAL.md` - Recorded this follow-up output-static session

### Testing

- `npm run build`
- `npm run test-ci`
- Manual browser validation on `http://127.0.0.1:4200` via Chrome DevTools:
    - Confirmed multi-output `Sulfur` recipes infer `IsStatic = false`
    - Confirmed single-output `Sulfur` recipes still infer `IsStatic = true`
    - Confirmed the prior multi-output `Barrel` override still infers `IsStatic = false`

### Technical Debt

- None introduced

### Next Steps

- Keep extending the shared inferred-output exception helper if future server data reveals more output-static mismatches

## Session: 2026-03-09.1 - Barrel Output Static Override

### Work Completed

- Extended inferred server output `IsStatic` handling in `PriceCalculatorServerService` so `Barrel` outputs are treated
  as
  non-static when a recipe returns `Barrel` alongside other outputs
- Kept the existing Ashlar/Crushed override intact while extracting the inferred-output-static logic into focused
  helpers
- Added unit coverage for the Ashlar byproduct case, the new multi-output Barrel case, and the single-output Barrel
  fallback

### Problems & Solutions

- The first test run failed because the project uses Vitest-style boolean matchers rather than Jasmine `toBeTrue()` /
  `toBeFalse()` helpers; the new spec assertions were updated to `toBe(true)` / `toBe(false)` and the suite passed

### Files Modified

- `EcoCraftingTool/src/app/service/price-calculator-server.service.ts` - Added a reusable inferred-output-static helper
  and the new multi-output Barrel exception
- `EcoCraftingTool/src/app/service/price-calculator-server.service.spec.ts` - Added regression coverage for inferred
  output static flags
- `.docs/DEVELOPMENT_JOURNAL.md` - Recorded this service update session

### Testing

- `npm run build`
- `npm run test-ci`
- Manual browser validation on `http://127.0.0.1:4200` via Chrome DevTools:
    - Confirmed Ashlar recipes still infer `Crushed` byproducts as `IsStatic = false`
    - Confirmed multi-output recipes infer `Barrel` outputs as `IsStatic = false`
    - Confirmed single-output `Barrel` recipes still infer `IsStatic = true`

### Technical Debt

- None introduced

### Next Steps

- If a live external server exposes another mismatched output-static edge case, add it to the same inference helper and
  extend the regression spec coverage

## Session: 2026-03-07.3 - Server Dropdown Localization Follow-up

### Work Completed

- Localized the server selector dropdown group headers and the `Add New...` option through `MessageService`
- Switched server group metadata to message IDs and resolved the group/option labels at render time so stored custom
  server names remain untouched
- Added the remaining dropdown message keys and locale values, using Lara Translate for the available locales and short
  fallback translations for the final blocked locales after Lara quota exhaustion

### Problems & Solutions

- Lara Translate hit the `api_translation_chars` quota while translating the final four locales for the three dropdown
  labels; the completed Lara output was kept for the translated locales, a retry still failed, and temporary fallback
  translations were added for Polish, Korean, Chinese, and Japanese so the UI would not ship partially untranslated

### Files Modified

- `EcoCraftingTool/src/app/model/server-api/server-config.ts` - Replaced hardcoded server group names with localized
  message IDs
- `EcoCraftingTool/src/app/header/header.component.ts` - Added helper methods to resolve localized server group and
  option labels
- `EcoCraftingTool/src/app/header/header.component.html` - Rendered localized server group labels and the localized
  add-new option in the server selector
- `EcoCraftingTool/src/app/header/header.component.spec.ts` - Added coverage for localized dropdown labels
- `EcoCraftingTool/src/app/service/message.service.ts` - Added server dropdown localization keys and translations
- `.docs/DEVELOPMENT_JOURNAL.md` - Recorded this follow-up localization session

### Testing

- `npm run build`
- `npm run test-ci`
- Manual browser validation on `http://127.0.0.1:4200`:
  - English locale: server dropdown showed `Predefined Servers`, `Custom Servers`, and `Add New...`
  - French locale: server dropdown showed `Serveurs prédéfinis`, `Serveurs personnalisés`, and `Ajouter un nouveau...`

### Technical Debt

- Re-run Lara Translate for the Polish, Korean, Chinese, and Japanese dropdown labels once quota is available so those
  fallback translations can be tool-verified

### Next Steps

- Continue the broader template-localization pass for the remaining non-server hardcoded strings when that follow-up is
  prioritized

## Session: 2026-03-07.2 - External Server UI Localization

### Work Completed

- Replaced hardcoded English strings in the external server connection dialog with `message.service` lookups
- Localized the server selector header label and aria-label, and added Lara-translated server-related message keys for
  every supported locale
- Added a server dialog spec assertion to verify localized dialog text renders through `MessageService`

### Problems & Solutions

- The first build failed after switching the dialog to `inject()` because constructor setup still referenced
  `serverService` directly; updating those references to `this.serverService` fixed the regression
- Chrome DevTools browser automation was initially blocked by a stale MCP Chrome profile process, so the orphaned
  browser processes were stopped before completing the manual UI spot-check

### Files Modified

- `EcoCraftingTool/src/app/header/server/server-dialog.component.html` - Replaced hardcoded dialog copy with localized
  `message(...)` bindings
- `EcoCraftingTool/src/app/header/server/server-dialog.component.ts` - Injected `MessageService` and added the template
  localization helper
- `EcoCraftingTool/src/app/header/server/server-dialog.component.spec.ts` - Mocked `MessageService` and asserted
  localized dialog text is rendered
- `EcoCraftingTool/src/app/header/header.component.html` - Localized the server selector beta label and aria-label
- `EcoCraftingTool/src/app/service/message.service.ts` - Added new external-server/header localization keys and
  translated values for all supported locales
- `.docs/DEVELOPMENT_JOURNAL.md` - Recorded this localization session

### Testing

- `npm run build`
- `npm run test-ci`
- Manual browser validation on `http://127.0.0.1:4200`:
  - English locale: header showed `Server (Beta)` and the Add New server dialog showed localized title, tooltip,
    warning, labels, and action buttons
  - French locale: header showed `Serveur (Bêta)` and the Add New server dialog showed French localized title, tooltip,
    warning, labels, and action buttons

### Technical Debt

- Other hardcoded accessibility labels and supporting text still exist outside the server integration surface, such as
  non-server aria-labels and some import/export dialog helper text

### Next Steps

- Continue the same `message.service` conversion pattern for remaining non-server hardcoded template strings when the
  broader localization pass is prioritized

## Session: 2026-03-07.1 - Workspace README Refresh

### Work Completed

- Replaced the nearly empty root `README.md` with a workspace-focused overview of the monorepo
- Documented the purpose of each submodule, how the data pipeline flows between them, and the main repo layout
- Added practical bootstrap, dependency, and workflow guidance for contributors working at the workspace level

### Problems & Solutions

- `AGENTS.md` still referenced older platform versions, so the README was written from the current
  `EcoCraftingTool/package.json`, `EcoDataReader/pom.xml`, and frontend CI workflow instead

### Files Modified

- `README.md` - Added a full workspace overview, setup guidance, common workflows, and contributor pointers
- `.docs/DEVELOPMENT_JOURNAL.md` - Recorded this documentation session

### Testing

- Not run (documentation-only change)

### Technical Debt

- `AGENTS.md` still appears to contain older Angular and Java version references than the current project metadata

### Next Steps

- If contributor docs are updated again soon, align the version references in `AGENTS.md` with the current frontend and
  Java project files

## Session: 2026-03-06.7 - Predefined External Server Audit and Cleanup

### Work Completed

- Audited every predefined non-vanilla external server from the app browser context against the live Eco Price
  Calculator `allItems` and `recipes` endpoints
- Confirmed White Tiger, Greenleaf, Silvermoon, and BeEco still connect successfully with valid JSON responses
- Removed the failing `Eco Antics` predefined server entry from the app configuration
- Rebuilt the app, reran the test suite, and verified the rebuilt server dropdown no longer lists `Eco Antics`

### Problems & Solutions

- `Eco Antics` no longer established a usable browser connection from the web app context; both endpoint requests
  failed, so the stale predefined entry was removed
- Per follow-up clarification, kept the cleanup minimal and did not add any extra fallback or migration logic

### Files Modified

- `EcoCraftingTool/src/app/model/server-api/server-config.ts` - Removed the stale `Eco Antics` predefined server entry
- `.docs/DEVELOPMENT_JOURNAL.md` - Recorded the audit results and cleanup work

### Testing

- Browser endpoint audit from the running app context:
  - `White Tiger` (`https://white-tiger.play.eco`) -> `allItems` 200 / 1918 items, `recipes` 200 / 1188 recipes
  - `Greenleaf` (`http://148.251.154.60:3021`) -> `allItems` 200 / 2103 items, `recipes` 200 / 1178 recipes
  - `Silvermoon` (`http://79.137.98.112:3001`) -> `allItems` 200 / 1942 items, `recipes` 200 / 1154 recipes
  - `BeEco` (`http://51.255.77.221:3001`) -> `allItems` 200 / 2579 items, `recipes` 200 / 1668 recipes
  - `Eco Antics` (`http://98.142.1.172:3001`) -> failed browser fetches for both endpoints
- UI spot-check: rebuilt predefined dropdown contains `Vanilla`, `White Tiger`, `Greenleaf`, `Silvermoon`, and `BeEco`,
  with no `Eco Antics`
- `npm run build`
- `npm run test-ci`

### Technical Debt

- None introduced beyond the remaining unrelated dialog accessibility warnings already noted in the prior session

### Next Steps

- If more predefined servers go stale later, repeat the same browser-side endpoint audit before pruning additional
  entries

## Session: 2026-03-06.6 - External Server Integration Regression Retest

### Work Completed

- Ran a fresh EcoCraftingTool baseline validation with `npm run build` and `npm run test-ci` before browser testing
- Cleared app storage and manually retested the external server integration flow against Vanilla, White Tiger, and a
  saved custom server entry
- Verified recipe data refresh and state preservation across server switches using Agouti Enchiladas with skill, table,
  lavish, calorie, price, and profit overrides
- Confirmed custom server persistence across reload plus draft edit reset/cancel behavior in the server dialog

### Problems & Solutions

- No functional regressions were found in the external server integration flow during this retest
- Chrome DevTools continued to report generic form-label issues during dialog testing; captured as follow-up technical
  debt because they did not block connection, switching, or persistence behavior

### Files Modified

- `.docs/DEVELOPMENT_JOURNAL.md` - Recorded this session's testing, findings, and follow-up notes

### Testing

- `npm run build`
- `npm run test-ci`
- Manual browser validation:
  - White Tiger predefined server flow: `Test Connection` succeeded repeatedly and the dialog showed 1 new table, 59 new
    items, 88 new recipes, and 184 modified recipes
  - Vanilla restore flow: `Restore Default Config` dialog showed no `Test Connection` button and saving added no extra
    fetch/xhr requests
  - State preservation flow: Vanilla `Agouti Enchiladas` with skill level 6, `Advanced Upgrade 4`, calorie cost 10,
    profit 25%, and ingredient prices `5/3/10/15/2` produced base/sale `30.43/38.04`; switching to White Tiger refreshed
    the recipe to `22.18/27.72` without removing or re-adding it
  - Lavish preservation flow: White Tiger cost `21.08`, Vanilla cost `28.92`, then White Tiger returned to `21.08` after
    reconnecting, with lavish and all other state preserved
  - Custom server persistence flow: added `WT Custom Persist` for `white-tiger.play.eco`, reloaded the app, and
    confirmed both the selected server and recipe state were restored from storage
  - Draft/reset flow: editing the custom host after a successful test immediately switched the dialog back from
    `Save Connection` to `Test Connection`, and `Cancel` discarded the unsaved host change

### Technical Debt

- Investigate the remaining DevTools accessibility issues for missing/mismatched form labels in the server dialog and
  related form controls

### Next Steps

- If needed, do a focused accessibility pass on the server dialog fields to resolve the remaining label warnings

## Session: 2026-03-06.5 - Accessibility, App Testing Skill & Bug Fix Verification

### Work Completed
- Added aria-labels to all interactive form elements across the app for Chrome DevTools accessibility
- Created `.github/skills/eco-app-testing/SKILL.md` skill with documented workflows for automated app testing
- Tested all 10 skill workflows via Chrome DevTools — all pass
- Discovered and fixed additional aria-label gaps (remove buttons, info buttons)
- Updated skill with test findings (Tab hazards, mat-select quirk, Vanilla dialog flow)
- Discovered mat-option elements ARE accessible via `take_snapshot(verbose=true)` — not an Angular Material bug
- **Performed comprehensive 6-phase manual verification of Bug 1 & Bug 2 fixes — 32/32 tests pass**

### Accessibility Changes
Added `aria-label` / `[attr.aria-label]` to these elements:
- **inputs.component.html**: Ingredient price inputs (`{name} price`), byproduct price inputs (`{name} price`)
- **outputs.component.html**: Recipe search, base cost, profit %, sale price, remove buttons (`Remove {name}`), info buttons (`{name} recipe details`), skill group remove, sub-recipe buttons
- **skills.component.html**: Skill/table search, skill level, table upgrade select, skill remove (`Remove {name}`), table remove (`Remove {name}`)

### Bug Fix Verification (32/32 pass)

Comprehensive 6-phase test across 6 server switches (Vanilla → WT → WT-modify → Vanilla → WT → Vanilla+lavish → WT):

| Phase         | Server      | Tests | Key Verification                                                  |
|---------------|-------------|-------|-------------------------------------------------------------------|
| P1: Setup     | Vanilla     | 7/7 ✅ | Baseline: skill=3, AU2, cal=10, SC=15, profit=20% → cost=39.23    |
| P2: Switch    | White Tiger | 6/6 ✅ | All state preserved, cost changed to 27.98 (Sun Cheese 4→2)       |
| P3: Modify    | White Tiger | 6/6 ✅ | Changed: skill=6, AU4, profit=30%, SC=25 → cost=26.03             |
| P4: Return    | Vanilla     | 7/7 ✅ | All P3 mods preserved, cost=39.78 (Vanilla quantities restored)   |
| P5: Re-switch | White Tiger | 2/2 ✅ | Cost=26.03 exactly matches P3, all state intact                   |
| P6: Lavish    | Both        | 4/4 ✅ | Lavish checkbox checked → cost=24.74, preserved across 2 switches |

**State preserved across all switches:**

- ✅ Skill level (recipe object — Bug 1 fix)
- ✅ Table upgrade module (table object — Bug 1 fix)
- ✅ Lavish workspace checkbox (skill object — Bug 1 fix)
- ✅ All ingredient prices (item objects — Bug 1 fix)
- ✅ Recipe profit override (recipe object — Bug 1 fix)
- ✅ Calorie cost (global setting)
- ✅ Recipe quantities updated correctly (Vanilla: SC×4, WT: SC×2)
- ✅ "Test Connection" always shown for White Tiger (Bug 2 fix)

### Skill Workflow Tests (10/10 pass)
| Test                    | Result | Notes                                   |
|-------------------------|--------|-----------------------------------------|
| aria-labels in snapshot | ✅      | All labels found and descriptive        |
| Set single price        | ✅      | fill + Tab triggers focusout            |
| Set multiple prices     | ✅      | fill_form + Tab + Escape works          |
| Read output cost        | ✅      | Value readable from snapshot attributes |
| Change profit %         | ✅      | fill + Tab updates sale price correctly |
| Change skill level      | ✅      | Level change reduces calorie cost       |
| Change table upgrade    | ✅      | evaluate_script needed for mat-option   |
| Remove recipe           | ✅      | Aria-labeled button unambiguous         |
| Add recipe              | ✅      | Search + evaluate_script for mat-option |
| Switch server           | ✅      | State preserved, cost changes correctly |

### Key Findings
- mat-select accessible name shows selected value, not aria-label (Angular Material behavior)
- Tab after last ingredient price opens recipe search dropdown — need Escape
- Tab after skill level lands on remove button — hazardous
- Vanilla server dialog differs from non-Vanilla (no Test Connection)
- mat-option elements ARE accessible via `take_snapshot(verbose=true)` — use verbose mode for dropdown interactions
- `fill()` does NOT work on mat-select (not native `<select>`); use verbose snapshot + click

### Files Modified
- `src/app/crafting/inputs/inputs.component.html` — aria-labels on ingredient/byproduct prices
- `src/app/crafting/outputs/outputs.component.html` — aria-labels on search, costs, profit, remove, info buttons
- `src/app/crafting/skills/skills.component.html` — aria-labels on search, level, upgrade, remove buttons
- `.github/skills/eco-app-testing/SKILL.md` — new skill, updated with test findings

---

## Session: 2026-03-06.4 - Server Switch Bug Fixes

### Work Completed
- Implemented fixes for both server-switch bugs discovered in session 2026-03-06.3
- Generalized Bug 1 fix to cover all entity types (recipes, skills, tables, items) not just recipes
- Added 10 new unit tests covering both fixes

### Problems & Solutions

#### Bug 2 Fix: Server reconnection skips API fetch
**Fix:** Changed `server-dialog.component.ts` line 69 to always initialize `draftConnectionEstablished` to `false` for non-vanilla servers: `signal(this.isVanillaServer && this.serverConfig.connectionEstablished())`. This forces a fresh "Test Connection" on every dialog open, ensuring fresh API data.

#### Bug 1 Fix: Stale object references after server switch
**Fix:** Added `refreshSelectedData()` method to `CraftingService` that re-maps `selectedRecipes`, `selectedSkills`, and `selectedTables` to current objects in the `CraftingDataService` central Maps after `saveConnection()`. The method preserves user state (skill levels, lavish settings, table upgrades, recipe profit overrides, input/byproduct prices) by capturing it before the swap and restoring after.

### Files Modified
- `src/app/header/server/server-dialog.component.ts` — Bug 2 fix (draftConnectionEstablished init)
- `src/app/service/crafting.service.ts` — Bug 1 fix (refreshSelectedData method)
- `src/app/service/price-calculator-server.service.ts` — Inject CraftingService, call refreshSelectedData in saveConnection
- `src/app/header/server/server-dialog.component.spec.ts` — Updated existing test, added vanilla server test
- `src/app/service/crafting.service.spec.ts` — Added 8 new tests for refreshSelectedData

### Testing
- All 48 tests pass (39 existing + 9 new)
- Build succeeds
- ✅ Manual retest completed in session 2026-03-06.5 (32/32 tests pass)

### Next Steps

- ~~Manual Chrome DevTools retest of the full Vanilla ↔ White Tiger switching flow~~ ✅ Done
- ~~Verify cost updates without remove/re-add when switching servers~~ ✅ Confirmed

---

## Session: 2026-03-06.3 - Server Switch Recipe Bugs: Testing & Root Cause Analysis

### Work Completed
- Performed comprehensive before/after comparison testing of the Agouti Enchiladas recipe on Vanilla vs White Tiger server using Chrome DevTools automation
- Ran 4 test scenarios per server (isolated ingredient, all ingredients, +calorie cost, +profit%) and verified all calculations mathematically
- Discovered and root-caused **two bugs** related to server switching

### Problems & Solutions

#### Bug 1: Selected recipes use stale quantities after server switch
**Symptoms:** When a recipe is already added to Outputs and the user switches servers (e.g., Vanilla → White Tiger), the cost calculation continues using the old server's ingredient quantities. The recipe info dialog may show updated quantities, but the actual cost doesn't change.

**Root cause:** `removeCustomData()` (crafting-data.service.ts:156) and `processServerRecipes()` (line 240) both create **new Recipe objects** via `new Recipe(iRecipe)`. However, `CraftingService.selectedRecipes` (crafting.service.ts:35) holds **old Recipe object references** by value. The cost computation effect (line 136) reads from `selectedRecipes()`, which still points to the orphaned old objects with stale `Ingredient.quantity` values (plain numbers, not signals). The reactive chain is severed because:
1. New Recipe objects are created in the central `recipes` Map
2. `selectedRecipes` array still holds old object references
3. No mechanism refreshes `selectedRecipes` to point to the new objects

**Workaround:** Remove and re-add the recipe after switching servers.

#### Bug 2: Reconnecting to a previously-tested server skips API fetch
**Symptoms:** Connect to White Tiger → switch to Vanilla → switch back to White Tiger → recipes are vanilla despite showing "White Tiger" as selected server.

**Root cause:** Predefined servers in `server-config.ts` are **mutable singletons** with `connectionEstablished: WritableSignal<boolean>`. When `attemptConnection()` succeeds (price-calculator-server.service.ts:85), it mutates `server.connectionEstablished.set(true)` on the singleton. When the dialog reopens, it reads this persisted `true` value (server-dialog.component.ts:69), hides "Test Connection", and shows "Save Connection" directly. Clicking "Save Connection" without testing means `tempNewRecipes` is empty (never populated by `attemptConnection()`), so `processServerRecipes([])` adds nothing.

**Workaround:** Clear browser localStorage before reconnecting to the same server.

### Files Modified
- None (testing and analysis only)

### Testing
- 8 test scenarios recorded in session SQL database
- Key comparison results:

| Scenario | Vanilla Cost | White Tiger Cost | Δ |
|---|---|---|---|
| Isolated Sun Cheese=10 | 20 | 10 | -50% |
| All ingredients priced | 41 | 33 | -19.5% |
| + Calorie cost=5 | 41.13 | 33.13 | -19.4% |
| + 15% recipe profit | 47.3 (sell) | 38.1 (sell) | -19.5% |

### Technical Debt
- **Bug 1** (stale selectedRecipes): Needs fix in `saveConnection()` or `CraftingService` to refresh selected recipe references after server data changes
- **Bug 2** (singleton connectionEstablished leak): Needs fix to reset `connectionEstablished` on predefined servers when the dialog opens, or always re-fetch on save

### Next Steps
- Implement fixes for both bugs (see detailed plan below)
- Write unit tests for the fix
- Manual retest the Vanilla ↔ White Tiger switching flow

---

## Session: 2026-03-06.2 - Standardize processServer* Map Immutability

### Work Completed
- Refactored `processServerSkills`, `processServerItems`, and `processServerRecipes` in `CraftingDataService` to follow the same immutable Map pattern as `processServerTables`: create a `new Map(existing)` copy, mutate the copy, return it.
- This also eliminates redundant signal notifications — previously each item triggered a separate `signal.update()` call (N updates for N items), now each method triggers exactly one update.

### Problems & Solutions
- **Module-level Map mutation**: The old pattern `this.skills.update(skills => skills.set(...))` returned the same Map reference after mutating it in-place, polluting the module-level exported Maps and causing test isolation issues. The new pattern creates a copy first, which is the correct signal immutability approach.

### Files Modified
- `EcoCraftingTool/src/app/service/crafting-data.service.ts` - Refactored `processServerSkills`, `processServerItems`, `processServerRecipes` to use immutable Map copy pattern

### Testing
- All 39 tests pass across 21 test files
- Build passes

### Technical Debt
- None introduced

### Next Steps
- None outstanding

---

## Session: 2026-03-06.1 - Fix Vanilla Revert In-Memory Bug & Server Dialog Copy Config

### Work Completed
- **Fixed in-memory data cleanup on vanilla revert**: When reverting from an external server (e.g., White Tiger) back to Vanilla, custom skills, tables, items, and recipes were only cleared from localStorage — the in-memory Maps retained stale entries until a page refresh. Now they are cleaned immediately.
- **Added "Copy Config" button to server connection dialog**: The warning banner in the server dialog previously told users to use the Export function to back up their config. A new inline "Copy Config" button now copies the full calculator config JSON to the clipboard directly from the dialog, with a snackbar confirmation.

### Problems & Solutions
- **Root cause of vanilla revert bug**: `processServerSkills/Tables/Items/Recipes([])` methods only iterate and add entries — passing empty arrays did nothing, leaving custom entries in the Maps.
  - *Solution*: Added `removeCustomData()` to `CraftingDataService` that filters Maps back to vanilla-only keys (computed from the original arrays which are never mutated) and rebuilds recipes from `recipesArray`.
- **Map mutation side effect**: `processServerSkills`, `processServerItems`, and `processServerRecipes` mutate the original module-level imported Maps in-place via `signal.update()` + `map.set()`. This caused test isolation issues since module-level Maps carried state across TestBed instances.
  - *Solution*: The fix works correctly despite this because vanilla keys are computed from the arrays (never mutated). Test isolation was handled by computing expected counts from the arrays rather than hardcoded values.
- **Data quirk**: `itemsArray` has 1666 entries but produces 1664 Map entries (2 duplicate nameIDs). Tests account for this.

### Files Modified
- `EcoCraftingTool/src/app/service/crafting-data.service.ts` - Added `removeCustomData()` method and imported array exports
- `EcoCraftingTool/src/app/service/price-calculator-server.service.ts` - Call `removeCustomData()` before `processServer*()` in `saveConnection()`
- `EcoCraftingTool/src/app/service/crafting-data.service.spec.ts` - Expanded from 1 test to 10 tests covering `removeCustomData()`
- `EcoCraftingTool/src/app/header/server/server-dialog.component.ts` - Added `Clipboard`, `MatSnackBar`, `WebStorageService` injections and `copyConfig()` method
- `EcoCraftingTool/src/app/header/server/server-dialog.component.html` - Added "Copy Config" button with icon inline with warning, shortened warning text

### Testing
- 10 new unit tests for `removeCustomData()`: remove custom skills/tables/items, preserve vanilla entries, restore recipes from baseline, idempotency, re-add after removal
- All 39 tests pass across 21 test files
- Manual browser testing confirmed:
  - Connecting to White Tiger → saving → custom "Marketplace Table" visible in autocomplete
  - Reverting to Vanilla → custom entries immediately gone from autocomplete (no refresh needed)
  - localStorage correctly emptied
  - Copy Config button copies JSON to clipboard and shows snackbar

### Technical Debt
- ~~`processServerSkills/Items/Recipes` mutate module-level Maps in-place~~ — resolved same session (see below)
- The server dialog could benefit from visual feedback if clipboard copy fails (currently fails silently)

### Next Steps
- None outstanding from this session

---

## Archive Index
*(Move completed weeks to `journal/YYYY-MM-DD-WEEK.md`)*
