---
name: eco-app-testing
description: 'Test and interact with the EcoCraftingTool web app via Chrome DevTools. Use when asked to test recipes, verify crafting calculations, compare server configurations, set ingredient prices, or automate UI interactions on localhost:4200.'
---

# EcoCraftingTool Web App Testing

A skill for interacting with the EcoCraftingTool Angular app (localhost:4200) using Chrome DevTools MCP tools. Provides patterns for adding recipes, setting prices, reading costs, switching servers, and running comparison tests.

## When to Use This Skill

- Testing recipe cost calculations with specific ingredient prices
- Comparing recipe output between Vanilla and modded servers (e.g., White Tiger)
- Verifying UI behavior after code changes
- Setting up specific calculator states for debugging

## Prerequisites

- Dev server running: `cd EcoCraftingTool && npm run start` (localhost:4200)
- Chrome DevTools MCP connected to the browser

## App Layout

The app has three columns:

| Column | Section | Key Elements |
|--------|---------|--------------|
| Left | **Skills & Tables** | Skill search, skill level inputs, lavish checkboxes, table upgrade selects |
| Center | **Ingredients** | Calorie cost, default profit %, ingredient price inputs, byproduct prices |
| Right | **Outputs** | Recipe search, output base cost (readonly), profit % override, sale price (readonly) |

The **header** contains: server selector dropdown, locale selector, import/export, settings.

## Aria-Label Reference

All interactive elements have aria-labels for reliable targeting via `take_snapshot`:

### Ingredients Column
| Element | aria-label Pattern | Example |
|---------|-------------------|---------|
| Calorie cost input | `aria-labelledby="caloriesInputLabel"` | — |
| Default profit input | `aria-labelledby="profitInputLabel"` | — |
| Ingredient price input | `{ItemName} price` | `"Sun Cheese price"` |
| Byproduct price input | `{ItemName} price` | `"Charcoal price"` |

### Outputs Column
| Element | aria-label Pattern | Example |
|---------|-------------------|---------|
| Recipe search | `"Search for a recipe to add"` | — |
| Base cost (readonly) | `{ItemName} base cost` | `"Agouti Enchiladas base cost"` |
| Profit % override | `{ItemName} profit %` | `"Agouti Enchiladas profit %"` |
| Sale price (readonly) | `{ItemName} sale price` | `"Agouti Enchiladas sale price"` |
| Info button | `{ItemName} recipe details` | `"Agouti Enchiladas recipe details"` |
| Remove button | `Remove {ItemName}` | `"Remove Agouti Enchiladas"` |
| Skill group remove | `Remove {SkillName} skill group` | `"Remove Advanced Cooking skill group"` |

### Skills Column
| Element | aria-label Pattern | Example |
|---------|-------------------|---------|
| Skill search | `"Search for a skill to add"` | — |
| Skill level input | `{SkillName} level` | `"Advanced Cooking level"` |
| Skill remove button | `Remove {SkillName}` | `"Remove Advanced Cooking"` |
| Table search | `"Search for a crafting table to add"` | — |
| Table upgrade select | `{TableName} upgrade module` | `"Stove upgrade module"` |
| Table remove button | `Remove {TableName}` | `"Remove Stove"` |

> **Note**: `mat-select` accessible name shows the *selected value* (e.g., "No Upgrade") rather than
> the aria-label ("Stove upgrade module"). Find the combobox by its current value or by position
> relative to the table name.

### Header
| Element | aria-label | Notes |
|---------|-----------|-------|
| Server selector | `"Select server"` | Contains optgroups for Predefined/Custom |
| Locale selector | `"Select locale"` | — |

## Workflow: Add a Recipe

```
1. take_snapshot → find the recipe search input (aria-label: "Search for a recipe to add")
2. fill(uid=<search-uid>, value="Agouti Enchiladas")
3. take_snapshot → find the mat-option with "Agouti Enchiladas"
   NOTE: mat-option elements may not appear in the a11y snapshot.
   Fallback: evaluate_script to click the option:
     () => {
       const options = document.querySelectorAll('mat-option');
       for (const opt of options) {
         if (opt.textContent.trim() === 'Agouti Enchiladas') {
           opt.click();
           return true;
         }
       }
       return false;
     }
4. wait_for(["Agouti Enchiladas"]) — confirm it appeared in the outputs section
```

## Workflow: Set Ingredient Prices

After adding a recipe, ingredient inputs appear automatically.

```
1. take_snapshot → find inputs by aria-label (e.g., "Sun Cheese price")
2. fill(uid=<input-uid>, value="10")
3. IMPORTANT: Angular change detection requires focus loss to trigger.
   After filling, either:
   - click another element, OR
   - press_key(key="Tab")
   This triggers the (focusout) handler that updates the price signal.
4. take_snapshot → verify the base cost and sale price updated
```

### Setting Multiple Prices Efficiently

Use `fill_form` to set multiple prices at once, then Tab and Escape:

```
1. take_snapshot → collect UIDs for all ingredient price inputs
2. fill_form(elements=[
     {uid: "<cornmeal-uid>", value: "5"},
     {uid: "<papaya-uid>", value: "3"},
     {uid: "<sun-cheese-uid>", value: "10"}
   ])
3. press_key(key="Tab") — trigger change detection for the last field
4. press_key(key="Escape") — close the recipe search dropdown that Tab may open
```

## Workflow: Read Output Cost

```
1. take_snapshot → find the readonly input with aria-label "{ItemName} base cost"
   The value attribute contains the computed cost.
2. For sale price: find aria-label "{ItemName} sale price"
```

## Workflow: Switch Server

### Non-Vanilla Server (e.g., White Tiger)

```
1. take_snapshot → find the server selector (aria-label: "Select server")
2. click(uid=<selector-uid>) to open the dropdown
3. evaluate_script to find and click the server mat-option:
     () => {
       const options = document.querySelectorAll('mat-option');
       for (const opt of options) {
         if (opt.textContent.trim() === 'White Tiger') {
           opt.click();
           return 'clicked';
         }
       }
       return 'not found';
     }
4. A dialog opens. take_snapshot → find "Test Connection" button, click it.
5. wait_for(["Save Connection"]) — connection test completed
6. take_snapshot → find "Save Connection" button, click it.
7. Dialog closes. The app now uses server-modified recipe data.
```

### Vanilla Server (restoring defaults)

```
1. take_snapshot → find the server selector, click it
2. evaluate_script to click the "Vanilla" mat-option
3. A "Restore Default Config" dialog opens (no Test Connection needed)
4. take_snapshot → click "Save Connection" to restore vanilla data
5. Dialog closes. The app now uses default recipe data.
```

## Workflow: Vanilla vs Modded Server Comparison Test

Full end-to-end comparison (example: Agouti Enchiladas, Vanilla vs White Tiger):

```
Phase 1: Vanilla baseline
  1. Ensure Vanilla server selected (default)
  2. Add Agouti Enchiladas recipe
  3. Set ingredient prices (e.g., Cornmeal=5, Papaya=3, PrimeCut=10, SunCheese=8, Tomato=2)
  4. Tab out of last field to trigger recalculation
  5. Read base cost and sale price → record as vanilla values

Phase 2: Switch to modded server
  6. Switch to White Tiger server (see workflow above)
  7. The recipe stays in outputs but now uses modded quantities
  8. Read base cost and sale price → record as modded values

Phase 3: Compare
  9. Calculate expected difference based on known recipe modifications
     (e.g., White Tiger changes Sun Cheese qty from 4 → 2)
```

## Important Interaction Quirks

### Change Detection
- **Price inputs require focusout**: Filling a value alone doesn't trigger Angular's change detection.
  Always Tab or click elsewhere after setting a value.
- **Deselecting profit checkbox**: Clicking off the default profit field causes it to recalculate.

### Tab Navigation Hazards
- After filling the **last ingredient price**, Tab moves focus to the **recipe search combobox**,
  which opens its dropdown. Press `Escape` immediately after Tab to close it.
- After filling a **skill level**, Tab moves focus to the **skill's remove button**. Do NOT
  press Enter — it would remove the skill. Click elsewhere instead.

### mat-option Elements
- Angular Material dropdown options (`mat-option`) are often NOT visible in the a11y snapshot
  because they're in a CDK overlay.
- **Always use `evaluate_script`** with `document.querySelectorAll('mat-option')` to find and click options.

### UIDs Change on Re-render
- After any state change (adding a recipe, switching server, changing a price), UIDs in the snapshot
  may change. Always take a fresh `take_snapshot` before interacting.

### Dialog Handling
- Server dialog, recipe info dialog, and settings dialog are Material dialogs.
- **Close dialogs with `press_key(key="Escape")`** — safer than clicking close buttons which
  may share icons with remove buttons.

### Recipe Info Dialog
- Click the `info_outline` icon next to a recipe name to open recipe details.
- Shows ingredients with quantities, skill, crafting table, and labor cost.
- Close with Escape.

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Price doesn't update after fill | Tab or click elsewhere to trigger focusout |
| mat-option not in snapshot | Use evaluate_script to query and click mat-option elements |
| Stale UIDs after state change | Take a fresh snapshot before every interaction |
| Server dialog shows "done" but data is stale | This was Bug 2 — now fixed, dialog forces re-test |
| Cost unchanged after server switch | This was Bug 1 — now fixed, selectedRecipes refreshed automatically |
| Recipe search dropdown opens unexpectedly | Tabbing out of a price field sometimes focuses the search — just press Escape |
