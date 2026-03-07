# Eco Calc Workspace

Eco Calc Workspace is the coordination repo for the projects behind [eco-calc.com](https://eco-calc.com), a crafting
calculator for *Eco Global Survival*.
It keeps the frontend app, the data-import tool, and workspace-level docs together so changes that span both projects
can be developed and released in one place.

## What lives here

This repository uses Git submodules:

| Project            | Stack                                                  | Purpose                                                                                                                |
|--------------------|--------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------|
| `EcoCraftingTool/` | Angular 21, TypeScript, Angular Material, Tailwind CSS | The web app users interact with to search recipes, tune skills and upgrades, and calculate crafting costs and profits. |
| `EcoDataReader/`   | Java 25, Maven, Gson, Lombok                           | A CLI tool that reads Eco server source files and helps generate the TypeScript data consumed by the frontend.         |
| `.docs/`           | Markdown                                               | Workspace-level notes, including the ongoing development journal.                                                      |

The root repository mainly serves as the workspace shell: it tracks submodule revisions, keeps shared documentation, and
provides a single place to manage cross-project work.

## How the workspace fits together

1. An Eco server update changes data in the game's `Mods/__core__/` source files.
2. `EcoDataReader` parses those files and compares the results with the current calculator data.
3. The generated TypeScript data is copied into `EcoCraftingTool/src/assets/data/`.
4. `EcoCraftingTool` is rebuilt and tested, then deployed through its normal GitHub Actions flow.

If you are updating game data, this repo gives you the full pipeline in one workspace: import and compare in
`EcoDataReader`, then validate the app behavior in `EcoCraftingTool`.

## Repository layout

```text
EcoCalcWorkspace/
|- AGENTS.md                 # Workspace-specific contributor instructions
|- README.md                 # This file
|- .docs/
|  |- DEVELOPMENT_JOURNAL.md # Session log for recent work
|  `- journal/               # Archived weekly journal entries
|- EcoCraftingTool/         # Angular frontend submodule
`- EcoDataReader/           # Java CLI submodule
```

## Getting started

### 1. Clone with submodules

```bash
git clone --recurse-submodules https://github.com/aritchie05/EcoCalcWorkspace.git
```

If you already cloned the repo without submodules:

```bash
git submodule update --init --recursive
```

### 2. Install the tools each project needs

- Node.js: use a version supported by the frontend CI matrix (20.x, 22.x, or 24.x)
- Java: use Java 25 to match `EcoDataReader/pom.xml`
- Maven: required for the Java CLI workflows

### 3. Install frontend dependencies

From the repo root:

```bash
cd EcoCraftingTool
npm ci
```

There is no root-level package manager or build command; work inside the relevant submodule.

## Common workflows

### Frontend development (`EcoCraftingTool/`)

```bash
cd EcoCraftingTool
npm ci
npm run start
npm run build
npm run test
npm run test-ci
```

Use this project when you are changing UI behavior, Angular services, styling, browser storage, or recipe calculation
logic.

### Data pipeline work (`EcoDataReader/`)

```bash
cd EcoDataReader
mvn compile
mvn package
```

Use this project when you need to parse fresh Eco server source data, compare it with the calculator's current data set,
or generate updated TypeScript data inputs for the app.

## CI and release flow

- Frontend CI lives in `EcoCraftingTool/.github/workflows/node.js.yml`
- The frontend workflow runs `npm run build` and `npm run test-ci`
- The current matrix covers Node.js 20.x, 22.x, and 24.x
- The usual branch flow is: feature branch -> `develop` -> validation -> `master`

## Working in this workspace

- Read `AGENTS.md` before making changes; it documents the workspace architecture, conventions, and required session
  workflow.
- Update `.docs/DEVELOPMENT_JOURNAL.md` for each session so cross-project changes stay discoverable.
- Keep project-specific implementation details inside the relevant submodule; keep this root README focused on how the
  workspace is organized.

## When to look deeper

- Go to `EcoCraftingTool/` for app behavior, Angular architecture, tests, and deployment details.
- Go to `EcoDataReader/` for importer behavior, parsing logic, and data comparison workflows.
- Go to `.docs/DEVELOPMENT_JOURNAL.md` for recent history and troubleshooting context across sessions.
