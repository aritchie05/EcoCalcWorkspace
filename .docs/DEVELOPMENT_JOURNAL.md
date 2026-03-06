# Development Journal

## Session: 2026-03-06.5 - Accessibility & App Testing Skill

### Work Completed
- Added aria-labels to all interactive form elements across the app for Chrome DevTools accessibility
- Created `.github/skills/eco-app-testing/SKILL.md` skill with documented workflows for automated app testing

### Accessibility Changes
Added `aria-label` attributes to these elements:
- **inputs.component.html**: Ingredient price inputs (`{name} price`), byproduct price inputs (`{name} price`)
- **outputs.component.html**: Recipe search, base cost (`{name} base cost`), profit override (`{name} profit %`), sale price (`{name} sale price`), remove buttons (`Remove {name}`)
- **skills.component.html**: Skill search, skill level inputs (`{name} level`), table search, table upgrade selects (`{name} upgrade module`)

### Eco App Testing Skill
Created a new skill documenting how to interact with the EcoCraftingTool via Chrome DevTools MCP:
- Aria-label reference table for all interactive elements
- Step-by-step workflows: add recipe, set prices, read costs, switch servers, run comparisons
- Documented interaction quirks (focusout for change detection, mat-option visibility, UID refreshes)

### Files Modified
- `src/app/crafting/inputs/inputs.component.html` — aria-labels on ingredient/byproduct price inputs
- `src/app/crafting/outputs/outputs.component.html` — aria-labels on recipe search, costs, profit, remove
- `src/app/crafting/skills/skills.component.html` — aria-labels on skill/table search, level, upgrade
- `.github/skills/eco-app-testing/SKILL.md` — new app testing skill

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
- Manual retest pending

### Next Steps
- Manual Chrome DevTools retest of the full Vanilla ↔ White Tiger switching flow
- Verify cost updates without remove/re-add when switching servers

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
