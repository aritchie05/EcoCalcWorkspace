<#
.SYNOPSIS
    Eco Data Pipeline — merges new items/recipes from EcoDataReader output into EcoCraftingTool data files.

.DESCRIPTION
    Reads the output files produced by EcoDataReader's compareItemsAndRecipes() method
    and inserts new items/recipes into the EcoCraftingTool TypeScript data files.
    Also runs smoke tests to verify nothing is broken.

.PARAMETER EcoDataReaderPath
    Path to the EcoDataReader project root.

.PARAMETER EcoCraftingToolPath
    Path to the EcoCraftingTool project root.

.PARAMETER SkipTests
    Skip running EcoCraftingTool tests after merging.
#>
param(
    [string]$EcoDataReaderPath = (Join-Path $PSScriptRoot "..\..\..\..\EcoDataReader"),
    [string]$EcoCraftingToolPath = (Join-Path $PSScriptRoot "..\..\..\..\EcoCraftingTool"),
    [switch]$SkipTests
)

$ErrorActionPreference = "Stop"

$outputDir = Join-Path $EcoDataReaderPath "output"
$dataDir = Join-Path $EcoCraftingToolPath "src\assets\data"

# ── Step 1: Verify output files exist ──
Write-Host "`n=== Step 1: Checking EcoDataReader output ===" -ForegroundColor Cyan

$requiredFiles = @("new-recipes.ts", "new-items.ts", "removed-recipes.txt", "removed-items.txt")
foreach ($file in $requiredFiles) {
    $path = Join-Path $outputDir $file
    if (-not (Test-Path $path)) {
        Write-Host "ERROR: Missing output file: $path" -ForegroundColor Red
        Write-Host "Run compareItemsAndRecipes() in EcoDataReader first." -ForegroundColor Yellow
        exit 1
    }
}
Write-Host "All output files found." -ForegroundColor Green

# ── Step 2: Read and display summary ──
Write-Host "`n=== Step 2: Data Change Summary ===" -ForegroundColor Cyan

$newRecipes = Get-Content (Join-Path $outputDir "new-recipes.ts") -Raw
$newItems = Get-Content (Join-Path $outputDir "new-items.ts") -Raw
$removedRecipes = Get-Content (Join-Path $outputDir "removed-recipes.txt") -ErrorAction SilentlyContinue
$removedItems = Get-Content (Join-Path $outputDir "removed-items.txt") -ErrorAction SilentlyContinue

$hasNewRecipes = $newRecipes.Trim() -ne "[]" -and $newRecipes.Trim().Length -gt 2
$hasNewItems = $newItems.Trim() -ne "[]" -and $newItems.Trim().Length -gt 2
$hasRemovedRecipes = $removedRecipes -and ($removedRecipes | Where-Object { $_.Trim() }).Count -gt 0
$hasRemovedItems = $removedItems -and ($removedItems | Where-Object { $_.Trim() }).Count -gt 0

if ($hasNewRecipes) { Write-Host "  New recipes to add" -ForegroundColor Green }
if ($hasNewItems) { Write-Host "  New items to add" -ForegroundColor Green }
if ($hasRemovedRecipes) {
    Write-Host "  Removed recipes:" -ForegroundColor Yellow
    $removedRecipes | Where-Object { $_.Trim() } | ForEach-Object { Write-Host "    - $_" -ForegroundColor Yellow }
}
if ($hasRemovedItems) {
    Write-Host "  Removed items:" -ForegroundColor Yellow
    $removedItems | Where-Object { $_.Trim() } | ForEach-Object { Write-Host "    - $_" -ForegroundColor Yellow }
}

if (-not $hasNewRecipes -and -not $hasNewItems -and -not $hasRemovedRecipes -and -not $hasRemovedItems) {
    Write-Host "  No changes detected. Data is up to date!" -ForegroundColor Green
    exit 0
}

# ── Step 3: Merge new items into items.ts ──
if ($hasNewItems) {
    Write-Host "`n=== Step 3a: Merging new items into items.ts ===" -ForegroundColor Cyan
    $itemsFile = Join-Path $dataDir "items.ts"
    $itemsContent = Get-Content $itemsFile -Raw

    # Strip the outer [] from the new items array to get individual entries
    $newItemEntries = $newRecipes = $newItems.Trim()
    if ($newItemEntries.StartsWith("[")) {
        $newItemEntries = $newItemEntries.Substring(1)
    }
    if ($newItemEntries.EndsWith("]")) {
        $newItemEntries = $newItemEntries.Substring(0, $newItemEntries.Length - 1)
    }
    $newItemEntries = $newItemEntries.Trim()

    # Insert before the closing ];
    # Find the last ]; that closes the itemsArray
    $closingPattern = "];`r?`n`r?`nexport const items:"
    $insertPoint = $itemsContent.LastIndexOf("];")
    if ($insertPoint -gt 0) {
        $before = $itemsContent.Substring(0, $insertPoint)
        $after = $itemsContent.Substring($insertPoint)
        $itemsContent = $before.TrimEnd() + ",`n" + "    " + $newItemEntries + "`n" + $after
        Set-Content $itemsFile -Value $itemsContent -NoNewline
        Write-Host "  New items merged into items.ts" -ForegroundColor Green
    } else {
        Write-Host "  ERROR: Could not find insertion point in items.ts" -ForegroundColor Red
    }
}

# ── Step 4: Merge new recipes into recipes.ts ──
if ($hasNewRecipes) {
    Write-Host "`n=== Step 3b: Merging new recipes into recipes.ts ===" -ForegroundColor Cyan
    $recipesFile = Join-Path $dataDir "recipes.ts"
    $recipesContent = Get-Content $recipesFile -Raw

    $newRecipeEntries = $newRecipes.Trim()
    if ($newRecipeEntries.StartsWith("[")) {
        $newRecipeEntries = $newRecipeEntries.Substring(1)
    }
    if ($newRecipeEntries.EndsWith("]")) {
        $newRecipeEntries = $newRecipeEntries.Substring(0, $newRecipeEntries.Length - 1)
    }
    $newRecipeEntries = $newRecipeEntries.Trim()

    $insertPoint = $recipesContent.LastIndexOf("];")
    if ($insertPoint -gt 0) {
        $before = $recipesContent.Substring(0, $insertPoint)
        $after = $recipesContent.Substring($insertPoint)
        $recipesContent = $before.TrimEnd() + ",`n" + "    " + $newRecipeEntries + "`n" + $after
        Set-Content $recipesFile -Value $recipesContent -NoNewline
        Write-Host "  New recipes merged into recipes.ts" -ForegroundColor Green
    } else {
        Write-Host "  ERROR: Could not find insertion point in recipes.ts" -ForegroundColor Red
    }
}

# ── Step 5: Run smoke tests ──
if (-not $SkipTests) {
    Write-Host "`n=== Step 4: Running EcoCraftingTool smoke tests ===" -ForegroundColor Cyan
    Push-Location $EcoCraftingToolPath

    Write-Host "  Running unit tests..." -ForegroundColor White
    npm run test-ci 2>&1 | Tee-Object -Variable testOutput
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  Unit tests FAILED" -ForegroundColor Red
        Pop-Location
        exit 1
    }
    Write-Host "  Unit tests passed" -ForegroundColor Green

    Write-Host "  Running production build..." -ForegroundColor White
    npm run build 2>&1 | Tee-Object -Variable buildOutput
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  Build FAILED" -ForegroundColor Red
        Pop-Location
        exit 1
    }
    Write-Host "  Build succeeded" -ForegroundColor Green

    Pop-Location
}

Write-Host "`n=== Pipeline complete ===" -ForegroundColor Cyan
Write-Host "Review the changes in the data files, then commit." -ForegroundColor White
