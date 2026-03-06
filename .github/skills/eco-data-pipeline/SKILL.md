---
name: eco-data-pipeline
description: 'Run the Eco data pipeline to update crafting data from a new Eco game server version. Use when asked to "update game data", "run the data pipeline", "import new Eco server data", "compare items and recipes", or "sync crafting data".'
---

# Eco Data Pipeline

Orchestrates the data pipeline from **EcoDataReader** → **EcoCraftingTool** when a new Eco game server version is released. Compares items and recipes against the current EcoCraftingTool data, identifies changes, merges new entries, removes obsolete ones, and verifies the frontend still works.

## When to Use This Skill

- A new Eco game server version has been downloaded and its path updated in `EcoDataReader/src/main/java/com/apex/Main.java`
- User asks to "update game data", "run the data pipeline", "compare items and recipes", or "sync crafting data"
- User wants to find differences between the current EcoCraftingTool data and a new Eco server version

## Prerequisites

- Java 17+ and Maven installed (for EcoDataReader)
- Node.js 20+ and npm installed (for EcoCraftingTool)
- The Eco server path in `Main.java` (`ECO_SERVER_PATH`) has been updated to point to the new server version
- The EcoCraftingTool path in `Main.java` (`ECO_CRAFTING_TOOL_PATH`) points to the correct location
- `npm ci` has been run in the `EcoCraftingTool/` directory

## Step-by-Step Workflow

### Step 1: Verify Paths in Main.java

Check that the constants at the top of `EcoDataReader/src/main/java/com/apex/Main.java` are correct:

```java
private static final String ECO_SERVER_PATH = "D:\\Eco Servers\\EcoServerPC_v0.12.0.7-beta\\Mods\\__core__\\";
private static final String ECO_CRAFTING_TOOL_PATH = "C:\\Users\\aritc\\IdeaProjects\\EcoCraftingTool\\src\\assets\\data\\";
```

Confirm the `ECO_SERVER_PATH` matches the user's downloaded server version.

### Step 2: Run EcoDataReader Comparison

From the `EcoDataReader/` directory:

```bash
mvn compile exec:java -Dexec.mainClass="com.apex.Main" -q
```

This runs `compareItemsAndRecipes()` which:
1. Reads all recipes and items from the Eco server C# files via `EcoServerFileService`
2. Reads the current recipes and items from EcoCraftingTool's TypeScript files via `CraftingToolFileService`
3. Compares them using `DataElementComparisonService`
4. Writes output files to `EcoDataReader/output/`:
   - `new-recipes.ts` — TypeScript-formatted new recipe entries
   - `new-items.ts` — TypeScript-formatted new item entries
   - `updated-recipes.ts` — recipes with changed properties
   - `removed-recipes.txt` — names of recipes no longer in the game
   - `removed-items.txt` — names of items no longer in the game
5. Prints a summary to stdout

### Step 3: Review the Comparison Results

Read the output files and present a summary to the user:

```
EcoDataReader/output/new-recipes.ts    → new recipe entries to add
EcoDataReader/output/new-items.ts      → new item entries to add
EcoDataReader/output/updated-recipes.ts → recipes with changed values
EcoDataReader/output/removed-recipes.txt → recipes to remove
EcoDataReader/output/removed-items.txt   → items to remove
```

**IMPORTANT:** Always show the user what will change before making any modifications.

### Step 4: Merge New Items into items.ts

If there are new items (`new-items.ts` is not empty or `[]`):

1. Read `EcoDataReader/output/new-items.ts`
2. Strip the outer `[]` brackets to get the individual item entries
3. Open `EcoCraftingTool/src/assets/data/items.ts`
4. Find the closing `];` of the `itemsArray` array (before the `export const items: Map...` line)
5. Insert the new item entries before that `];`, adding a comma after the last existing entry
6. Maintain alphabetical order by `name` if possible

**Data format for items.ts:**
```typescript
{
  'name': 'Item Name',
  'nameID': 'ItemNameID',
  'tag': false,
  'imageFile': 'UI_Icons_06.png',
  'xPos': 0,
  'yPos': 0
}
```

### Step 5: Merge New Recipes into recipes.ts

If there are new recipes (`new-recipes.ts` is not empty or `[]`):

1. Read `EcoDataReader/output/new-recipes.ts`
2. Strip the outer `[]` brackets to get the individual recipe entries
3. Open `EcoCraftingTool/src/assets/data/recipes.ts`
4. Find the closing `];` of the `recipesArray` array
5. Insert the new recipe entries before that `];`, adding a comma after the last existing entry
6. Maintain alphabetical order by `name` if possible

**Data format for recipes.ts:**
```typescript
{
  'name': 'Recipe Name',
  'nameID': 'RecipeNameID',
  'skill': getSkillByNameID('SkillNameID'),
  'level': 1,
  'labor': 100,
  'craftingTable': getCraftingTableByNameID('TableNameID'),
  'hidden': false,
  'ingredients': [
    { 'item': getItemByNameID('ItemNameID'), 'quantity': 1, 'reducible': true }
  ],
  'outputs': [
    { 'item': getItemByNameID('OutputItemNameID'), 'quantity': 1, 'reducible': false, 'primary': true }
  ]
}
```

### Step 6: Handle Updated Recipes

If `updated-recipes.ts` contains recipes that changed:

1. For each updated recipe, find the matching entry in `recipes.ts` by `nameID`
2. Replace the entire recipe object with the updated version
3. Show the user what changed (the `recipesAreEqual` method in `Recipe.java` logs field-level diffs)

### Step 7: Handle Removed Items and Recipes

If `removed-recipes.txt` or `removed-items.txt` are non-empty:

1. **Do NOT auto-remove entries.** Present the list to the user for confirmation.
2. Some removals may be intentional game changes; others may be parsing issues.
3. If the user confirms removal, find and delete the matching entries from the respective `.ts` files.

### Step 8: Run Smoke Tests

From the `EcoCraftingTool/` directory:

```bash
# 1. Run unit tests
npm run test-ci

# 2. Run production build to catch TypeScript errors
npm run build

# 3. Start dev server and check for console errors
npm run start
```

For the dev server check:
- Navigate to `http://localhost:4200`
- Open browser console and verify no errors
- Check that the recipes/items pages load correctly
- Stop the dev server after verification

### Automated Pipeline Script

A PowerShell script is available for steps 3-8:

```powershell
# From the workspace root
.\.github\skills\eco-data-pipeline\scripts\run-pipeline.ps1

# Skip tests
.\.github\skills\eco-data-pipeline\scripts\run-pipeline.ps1 -SkipTests
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `compareItemsAndRecipes()` throws `FileNotFoundException` | Verify `ECO_SERVER_PATH` points to the correct Eco server install with `Mods/__core__/` |
| `CraftingToolFileService` can't read TS files | Verify `ECO_CRAFTING_TOOL_PATH` points to `EcoCraftingTool/src/assets/data/` |
| New recipes reference unknown items | Add new items first (Step 4), then recipes (Step 5) |
| TypeScript build fails after merge | Check for syntax errors — likely a missing comma between entries |
| `getItemByNameID`, `getSkillByNameID`, or `getCraftingTableByNameID` returns undefined | The referenced item/skill/table doesn't exist in the data files yet — add it first |

## File Reference

| File | Location | Purpose |
|------|----------|---------|
| `Main.java` | `EcoDataReader/src/main/java/com/apex/Main.java` | Entry point with `compareItemsAndRecipes()` |
| `recipes.ts` | `EcoCraftingTool/src/assets/data/recipes.ts` | Recipe definitions consumed by the Angular app |
| `items.ts` | `EcoCraftingTool/src/assets/data/items.ts` | Item definitions consumed by the Angular app |
| `data-utils.ts` | `EcoCraftingTool/src/assets/data/util/data-utils.ts` | Helper functions (`getItemByNameID`, etc.) |
| `run-pipeline.ps1` | `.github/skills/eco-data-pipeline/scripts/run-pipeline.ps1` | Automated merge + test script |
