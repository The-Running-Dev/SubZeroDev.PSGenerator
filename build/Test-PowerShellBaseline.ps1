<#
.SYNOPSIS
Validates the generator and generated modules on the PowerShell 7.4 baseline.

.DESCRIPTION
Requires an exact PowerShell 7.4 runtime, packages and imports the generator from a
clean temporary location, generates a module from the minimal example, and verifies
that both manifests declare and run on the Version 1 minimum PowerShell version.
#>
[CmdletBinding()]
param ()

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$requiredPowerShellVersion = [version] '7.4'
$currentPowerShellVersion = $PSVersionTable.PSVersion
if (
    $currentPowerShellVersion.Major -ne $requiredPowerShellVersion.Major -or
    $currentPowerShellVersion.Minor -ne $requiredPowerShellVersion.Minor
) {
    throw (
        "PowerShell $requiredPowerShellVersion.x is required for this baseline check; " +
        "the current runtime is $currentPowerShellVersion."
    )
}

$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$temporaryRoot = Join-Path (
    [IO.Path]::GetTempPath()
) ('SubZeroDev.PSGenerator.Baseline.' + [guid]::NewGuid().ToString('N'))
$generatorModule = $null
$generatedModule = $null

try {
    $packageRoot = Join-Path $temporaryRoot 'Generator'
    $packagedManifest = & (Join-Path $PSScriptRoot 'New-GeneratorModulePackage.ps1') `
        -Output $packageRoot
    $generatorManifest = Test-ModuleManifest -Path $packagedManifest.FullName -ErrorAction Stop
    if ($generatorManifest.PowerShellVersion -ne $requiredPowerShellVersion) {
        throw (
            "The packaged generator requires PowerShell " +
            "$($generatorManifest.PowerShellVersion), expected $requiredPowerShellVersion."
        )
    }

    $generatorModule = Import-Module $packagedManifest.FullName -Force -PassThru -ErrorAction Stop
    $generatedModulePath = Join-Path $temporaryRoot 'Generated'
    $specificationPath = Join-Path $repositoryRoot 'examples' 'Minimal' 'PSModule' 'PSModule.psd1'
    Build-PSModule `
        -Specification $specificationPath `
        -Output $generatedModulePath |
        Out-Null

    $generatedManifestPath = Join-Path $generatedModulePath 'ExampleContainer.psd1'
    $generatedManifest = Test-ModuleManifest -Path $generatedManifestPath -ErrorAction Stop
    if ($generatedManifest.PowerShellVersion -ne $requiredPowerShellVersion) {
        throw (
            "The generated module requires PowerShell " +
            "$($generatedManifest.PowerShellVersion), expected $requiredPowerShellVersion."
        )
    }

    $generatedModule = Import-Module $generatedManifestPath -Force -PassThru -ErrorAction Stop
    if ($null -eq $generatedModule.ExportedCommands['Invoke-Example']) {
        throw "The generated module did not export the expected 'Invoke-Example' command."
    }

    Write-Host (
        "PowerShell $currentPowerShellVersion baseline validation passed for the " +
        'packaged generator and generated module.'
    ) -ForegroundColor Green
}
finally {
    if ($null -ne $generatedModule) {
        Remove-Module $generatedModule -Force -ErrorAction SilentlyContinue
    }
    if ($null -ne $generatorModule) {
        Remove-Module $generatorModule -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path -LiteralPath $temporaryRoot) {
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
    }
}
