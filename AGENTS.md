# Copilot Instructions — Eco Calc Workspace

This is a monorepo (git submodules) containing two projects that work together to
power [eco-calc.com](https://eco-calc.com), a crafting calculator for the game *Eco Global Survival*.

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
- Hardcoded local paths in `Main.java` point to the Eco server install and EcoCraftingTool source directory.

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
mvn test                # JUnit 5 + AssertJ tests
mvn package             # build JAR
```

Run a single test:

```bash
mvn test -Dtest=CraftingToolFileServiceTest
```

### CI

GitHub Actions (in `EcoCraftingTool/.github/workflows/node.js.yml`) runs on push/PR to `master` and `develop`:
`npm ci → npm run build → npm run test-ci` across Node 18.x and 20.x.

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
