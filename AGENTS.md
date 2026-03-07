# Agent Instructions — Eco Calc Workspace

This is a monorepo (git submodules) containing two projects that work together to
power [eco-calc.com](https://eco-calc.com), a crafting calculator for the game *Eco Global Survival*.

## Pre-Session Checklist

**Always do these at the start of a session**

- [ ] Review `.docs/DEVELOPMENT_JOURNAL.md` - recent sessions

## Critical Rules

### Never

1. Bypass established architectural patterns
2. Consider changes finished without tests
3. Skip journal updates
4. Commit secrets or credentials

### Always

1. Follow patterns defined in this file
2. Write tests for new code
3. Update documentation
4. Update journal every session

## Post-Session Checklist

**Always do these at the end of a session**

- [ ] Update `.docs/DEVELOPMENT_JOURNAL.md` with details of the changes
- [ ] Ensure tests are written for any new code
- [ ] Verify there are no build or test failures
- [ ] For new features or bugs, also test manually using /chrome-devtools in the app

## Development Journal

**MANDATORY after every session**: Update `.docs/DEVELOPMENT_JOURNAL.md`

### Structure

- **Main Index**: Add sessions **above** "Archive Index" section
- **Weekly Archives**: Move completed week to `journal/YYYY-MM-DD-WEEK.md` (using Monday's date)
- **Keep Lightweight**: Main journal under 500 lines

### Session Entry Template

```markdown
## Session: YYYY-MM-DD.[n] - [Brief Title]

### Work Completed

- [High-level bullet points]

### Problems & Solutions

- [Issues and resolutions]

### Files Modified

- `path/to/file` - [Description]

### Testing

- [Tests added]

### Technical Debt

- [Technical debt items to address later]

### Next Steps

- [Recommendations]
```

## Architecture

| Submodule           | Tech                                                 | Purpose                                                                                                                              |
|---------------------|------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------|
| **EcoCraftingTool** | Angular 20, TypeScript, Tailwind 3, Angular Material | The web frontend — users select skills, recipes, and see crafting calculations                                                       |
| **EcoDataReader**   | Java 17, Maven, Gson, Lombok                         | CLI tool that reads C# source files from an Eco game server and converts them into TypeScript data files consumed by EcoCraftingTool |

### Data pipeline

1. A new Eco game version ships with updated C# source files in its server `Mods/__core__/` directory.
2. **EcoDataReader** parses those C# files, compares them against the current EcoCraftingTool data, and generates
   updated TypeScript arrays.
3. The generated output is pasted into `EcoCraftingTool/src/assets/data/` (recipes.ts, items.ts, skills.ts,
   crafting-tables.ts, etc.).
4. Translation strings come from a Crowdin CSV (`defaultstrings.csv`) → `locale-data.ts`.

Use the /eco-data-pipeline skill for details on how to run the pipeline.

### EcoCraftingTool architecture

- **Standalone components** (no NgModules) bootstrapped via `app.config.ts`.
- **Signal-based state management** — `CraftingService` uses Angular `WritableSignal` and `computed` signals for all
  reactive state. No NgRx or other state library.
- State is persisted to browser storage via `ngx-webstorage-service`.
- Folder layout: `app/crafting/` (main feature), `app/header/`, `app/footer/`, `app/service/`, `app/model/`,
  `assets/data/`.

### EcoDataReader architecture

- Entry point is `Main.java` — all operations are called as methods there (no REST/web layer).
- Services: `EcoServerFileService` (parses C# game files), `CraftingToolFileService` (reads existing TS data),
  `DataElementComparisonService` (diffs old vs new).
- Eco server path and EcoCraftingTool data path are passed as command-line arguments to `Main.java`.

## Build & Test

### EcoCraftingTool (run from `EcoCraftingTool/`)

```bash
npm ci                  # install dependencies
npm run start           # dev server at localhost:4200
npm run build           # production build → dist/eco-crafting-tool/
npm run test            # Vite tests
npm run test-ci         # single-run tests (used in CI)
```

Run a single test file by editing `angular.json` or using `--include`:

```bash
npx ng test --include='**/crafting.service.spec.ts'
```

Generate code with the Angular CLI:

```bash
ng g c folder/component-name    # new standalone component
ng g s folder/service-name      # new service
```

### EcoDataReader (run from `EcoDataReader/`)

```bash
mvn compile             # compile
mvn package             # build JAR
```

### CI

GitHub Actions (in `EcoCraftingTool/.github/workflows/node.js.yml`) runs on push/PR to `master` and `develop`:
`npm ci → npm run build → npm run test-ci` across Node 20.x, 22.x, and 24.x.

## Code Conventions

### EcoCraftingTool

- **Use Angular CLI** to generate components / services / tests.
- **OnPush change detection** on every component.
- **Signals over observables** for component/service state. Use `takeUntilDestroyed()` when observables are unavoidable.
- **Tailwind classes** preferred over SCSS for styling.
- **Explicit return types** on public methods; avoid `any`.
- **Kebab-case** file names (`my-feature.component.ts`).
- Spec files are co-located with source files (`*.spec.ts`).
- `.editorconfig`: 2-space indent, single quotes in TypeScript.

### EcoDataReader

- **Lombok** for model boilerplate (getters, setters, builders).
- **Gson** with custom `TypeAdapter`s (`ItemNameAdapter`, `SkillNameAdapter`, `TableNameAdapter`) for serialization.
- Models use manual `equals()`/`hashCode()` with detailed diff logging for comparison workflows.

## Git Workflow

Feature branches → PR to `develop` → test at develop domain → merge to `master` (auto-deploys to eco-calc.com).
