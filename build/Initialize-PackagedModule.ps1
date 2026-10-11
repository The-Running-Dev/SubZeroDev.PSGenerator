<#
.SYNOPSIS
Stages the packaged generator module for a Pester run.

.DESCRIPTION
Assembles the clean module package and, when running in GitHub Actions, exports its
manifest path as PSGENERATOR_MODULE_PATH for the steps that follow. The tests then
import the packaged layout instead of the development tree, which can mask a file
missing from the package. Outside GitHub Actions it only stages the package.

.PARAMETER Output
Directory that will contain the packaged module.
#>
[CmdletBinding()]
param (
    [Parameter()]
    [string] $Output = 'artifacts/module/SubZeroDev.PSGenerator'
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$packagedManifest = & (Join-Path $PSScriptRoot 'New-GeneratorModulePackage.ps1') -Output $Output

if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_ENV)) {
    "PSGENERATOR_MODULE_PATH=$($packagedManifest.FullName)" |
        Add-Content -LiteralPath $env:GITHUB_ENV -Encoding utf8
}

Write-Host "Packaged generator module staged at '$($packagedManifest.DirectoryName)'."
