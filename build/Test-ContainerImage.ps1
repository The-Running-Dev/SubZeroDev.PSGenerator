<#
.SYNOPSIS
Smoke-tests the built container image from the outside, as a consumer would.

.DESCRIPTION
The Dockerfile already fails the build if the module cannot be imported. This checks
that pwsh is the entry point on the PowerShell 7.4 baseline and that every command in
the module manifest is present in the image.

.PARAMETER Image
Image to test.
#>
[CmdletBinding()]
param (
    [Parameter()]
    [string] $Image = 'psgenerator:ci'
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))

$version = docker run --rm $Image -NoLogo -NoProfile -Command '$PSVersionTable.PSVersion.ToString()'
if ($LASTEXITCODE -ne 0) { throw 'The image did not start pwsh.' }
if ($version -notmatch '^7\.4\.') {
    throw "Image reports PowerShell '$version'; the module manifest requires 7.4."
}

$manifest = Test-ModuleManifest (Join-Path $repositoryRoot 'src' 'SubZeroDev.PSGenerator.psd1')
$expected = @($manifest.ExportedFunctions.Keys | Sort-Object)
$actual = @(
    docker run --rm $Image -NoLogo -NoProfile -Command `
        '(Get-Command -Module SubZeroDev.PSGenerator).Name | Sort-Object'
)
if ($LASTEXITCODE -ne 0) { throw 'The image could not list module commands.' }
if (Compare-Object $expected $actual) {
    throw "Image commands do not match the manifest. Expected: $($expected -join ', '). Actual: $($actual -join ', ')."
}

Write-Host "Image runs PowerShell $version and exposes $($actual.Count) commands."
