<#
.SYNOPSIS
Runs the PowerShell 7.4 baseline validation under an exact PowerShell 7.4 runtime.

.DESCRIPTION
Installs the pinned PowerShell 7.4 release as a local .NET tool under artifacts, then
runs Test-PowerShellBaseline.ps1 with it. Requires the .NET SDK.

.PARAMETER Version
PowerShell 7.4 release to install.
#>
[CmdletBinding()]
param (
    [Parameter()]
    [string] $Version = '7.4.17'
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$toolPath = Join-Path $repositoryRoot 'artifacts' 'pwsh-7.4'
$executable = Join-Path $toolPath $(if ($IsWindows) { 'pwsh.exe' } else { 'pwsh' })

if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) {
    dotnet tool install PowerShell --version $Version --tool-path $toolPath
    if ($LASTEXITCODE -ne 0) {
        throw "Installing the PowerShell 7.4 baseline failed with exit code $LASTEXITCODE."
    }
}

& $executable -NoLogo -NoProfile -File (Join-Path $PSScriptRoot 'Test-PowerShellBaseline.ps1')
if ($LASTEXITCODE -ne 0) {
    throw "PowerShell 7.4 baseline validation failed with exit code $LASTEXITCODE."
}
