<#
.SYNOPSIS
Validates repository ignore rules for generated build output.

.DESCRIPTION
Confirms that nested .NET bin and obj directories are ignored while every tracked
repository path remains visible to Git.
#>
[CmdletBinding()]
param ()

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$representativeBuildOutput = @(
    'tests/fixtures/directories/BuildAgent/src/Build/bin/Debug/example.dll'
    'tests/fixtures/directories/BuildAgent/src/Build/obj/project.assets.json'
)

Push-Location $repositoryRoot
try {
    foreach ($path in $representativeBuildOutput) {
        $match = & git check-ignore --no-index --verbose -- $path 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Expected .NET build output is not ignored: '$path'."
        }
        Write-Verbose ($match -join [Environment]::NewLine)
    }

    [string[]] $trackedPaths = @(& git ls-files)
    if ($LASTEXITCODE -ne 0) {
        throw "Listing tracked repository paths failed with exit code $LASTEXITCODE."
    }

    [string[]] $ignoredTrackedPaths = @(
        $trackedPaths | & git check-ignore --no-index --stdin
    )
    if ($LASTEXITCODE -notin @(0, 1)) {
        throw "Checking tracked repository paths failed with exit code $LASTEXITCODE."
    }
    if ($ignoredTrackedPaths.Count -gt 0) {
        throw (
            'The repository ignore rules hide tracked source paths: ' +
            ($ignoredTrackedPaths -join ', ')
        )
    }
}
finally {
    Pop-Location
}

Write-Host (
    "Repository hygiene checks passed across $($trackedPaths.Count) tracked path(s)."
) -ForegroundColor Green
