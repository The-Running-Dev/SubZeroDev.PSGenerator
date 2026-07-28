<#
.SYNOPSIS
Runs the repository PowerShell static-analysis and formatting gate.

.DESCRIPTION
Runs the pinned PSScriptAnalyzer version against repository-owned PowerShell source,
build tooling, examples, and tests. The shared settings file contains the enforced
correctness, safety, and formatting rules.

.PARAMETER InstallDependencies
Installs the pinned PSScriptAnalyzer version for the current user when unavailable.
#>
[CmdletBinding()]
param (
    [Parameter()]
    [switch] $InstallDependencies
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$requiredAnalyzerVersion = [version] '1.25.0'
$availableAnalyzer = Get-Module -ListAvailable PSScriptAnalyzer |
    Where-Object Version -eq $requiredAnalyzerVersion |
    Select-Object -First 1
if ($null -eq $availableAnalyzer) {
    if (-not $InstallDependencies) {
        throw (
            "PSScriptAnalyzer $requiredAnalyzerVersion is required. " +
            'Rerun with -InstallDependencies or install that version from PSGallery.'
        )
    }

    Install-Module PSScriptAnalyzer `
        -RequiredVersion $requiredAnalyzerVersion `
        -Scope CurrentUser `
        -Force `
        -SkipPublisherCheck `
        -ErrorAction Stop
}

Import-Module PSScriptAnalyzer `
    -RequiredVersion $requiredAnalyzerVersion `
    -Force `
    -ErrorAction Stop

$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$settingsPath = Join-Path $repositoryRoot '.config' 'PSScriptAnalyzerSettings.psd1'
$analysisRoots = @(
    @{ Path = 'src'; ExcludeRules = @() }
    @{ Path = 'build'; ExcludeRules = @() }
    @{ Path = 'examples'; ExcludeRules = @() }
    # Pester BeforeAll variables are consumed in generated test scopes, which the
    # analyzer cannot follow reliably.
    @{ Path = 'tests'; ExcludeRules = @('PSUseDeclaredVarsMoreThanAssignments') }
    @{ Path = 'tests-e2e'; ExcludeRules = @('PSUseDeclaredVarsMoreThanAssignments') }
)

$findings = @(
    foreach ($root in $analysisRoots) {
        $parameters = @{
            Path = Join-Path $repositoryRoot $root.Path
            Recurse = $true
            Settings = $settingsPath
        }
        if ($root.ExcludeRules.Count -gt 0) {
            $parameters.ExcludeRule = $root.ExcludeRules
        }
        Invoke-ScriptAnalyzer @parameters
    }
)

if ($findings.Count -gt 0) {
    foreach ($finding in $findings | Sort-Object ScriptPath, Line, Column, RuleName) {
        $relativePath = [IO.Path]::GetRelativePath(
            $repositoryRoot,
            $finding.ScriptPath
        ).Replace('\', '/')
        Write-Host (
            "$relativePath`:$($finding.Line):$($finding.Column) " +
            "[$($finding.Severity)] $($finding.RuleName): $($finding.Message)"
        )
    }

    throw "PowerShell quality checks failed with $($findings.Count) finding(s)."
}

Write-Host (
    "PowerShell quality checks passed with PSScriptAnalyzer $requiredAnalyzerVersion " +
    "across $($analysisRoots.Count) owned source roots."
) -ForegroundColor Green

& (Join-Path $PSScriptRoot 'Test-RepositoryHygiene.ps1')
