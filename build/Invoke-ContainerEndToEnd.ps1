<#
.SYNOPSIS
Runs the Docker end-to-end suite.

.DESCRIPTION
Runs the Pester tests under tests-e2e with the pinned Pester version and writes NUnit 3
results. The tests build their own fixture image, so nothing needs to be built first.
Requires Docker.

.PARAMETER Output
Directory that will contain the NUnit results.

.PARAMETER InstallDependencies
Installs the pinned Pester version for the current user when unavailable.
#>
[CmdletBinding()]
param (
    [Parameter()]
    [string] $Output = 'artifacts/test-results/container-e2e',

    [Parameter()]
    [switch] $InstallDependencies
)

# Strict mode is deliberately off: the tests read $isAct in a -Skip expression at discovery
# time, before BeforeAll has set it, which strict mode turns into an error.
$ErrorActionPreference = 'Stop'

$requiredPesterVersion = [version] '5.5.0'
$availablePester = Get-Module -ListAvailable Pester |
    Where-Object Version -eq $requiredPesterVersion |
    Select-Object -First 1
if ($null -eq $availablePester) {
    if (-not $InstallDependencies) {
        throw (
            "Pester $requiredPesterVersion is required. " +
            'Rerun with -InstallDependencies or install that version from PSGallery.'
        )
    }

    Install-Module Pester `
        -RequiredVersion $requiredPesterVersion `
        -Scope CurrentUser `
        -Force `
        -SkipPublisherCheck `
        -ErrorAction Stop
}

Import-Module Pester -RequiredVersion $requiredPesterVersion -Force -ErrorAction Stop

$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$reportDirectory = [IO.Path]::GetFullPath($Output, $repositoryRoot)
New-Item -ItemType Directory -Path $reportDirectory -Force | Out-Null

$configuration = New-PesterConfiguration
$configuration.Run.Path = Join-Path $repositoryRoot 'tests-e2e'
$configuration.Run.Exit = $true
$configuration.Output.Verbosity = 'Detailed'
$configuration.TestResult.Enabled = $true
$configuration.TestResult.OutputFormat = 'NUnit3'
$configuration.TestResult.OutputPath = Join-Path $reportDirectory 'container-e2e.xml'
Invoke-Pester -Configuration $configuration
