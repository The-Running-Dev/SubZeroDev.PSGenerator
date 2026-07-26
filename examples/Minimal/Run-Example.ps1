<#
.SYNOPSIS
Runs the complete minimal container-module lifecycle.

.DESCRIPTION
Generates the module, builds its container image, installs and imports the embedded
module, invokes its command, displays command help, and removes generated resources.

.PARAMETER KeepArtifacts
Keeps generated and installed module files after the container image is removed.
#>
[CmdletBinding()]
param (
    [Parameter()]
    [switch] $KeepArtifacts
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$exampleRoot = $PSScriptRoot
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $exampleRoot '..' '..'))
$generatorManifest = Join-Path $repositoryRoot 'src' 'SubZeroDev.PSGenerator.psd1'
$artifactRoot = Join-Path $exampleRoot 'artifacts'
$generatedModulePath = Join-Path $artifactRoot 'PSModule'
$installedModulePath = Join-Path $artifactRoot 'Installed' 'ExampleContainer'
$image = 'subzerodev-psgenerator-minimal:local'
$generatedModule = $null
$imageBuilt = $false

if ($null -eq (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw 'Docker is required to run the minimal example but was not found on PATH.'
}

Import-Module $generatorManifest -Force -ErrorAction Stop

try {
    Write-Host '1/8 Generate the PowerShell module'
    Build-PSModule `
        -Specification (Join-Path $exampleRoot 'PSModule' 'PSModule.psd1') `
        -Output $generatedModulePath |
        Out-Null

    Write-Host '2/8 Build the container image'
    & docker build --tag $image $exampleRoot | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -ne 0) {
        throw "Building the minimal example image failed with exit code $LASTEXITCODE."
    }
    $imageBuilt = $true

    Write-Host '3/8 Install the module embedded at /PSModule'
    Install-PSModule $image -Destination $installedModulePath | Out-Null

    Write-Host '4/8 Import the installed module'
    $generatedModule = Import-Module (
        Join-Path $installedModulePath 'ExampleContainer.psd1'
    ) -Force -PassThru -ErrorAction Stop

    Write-Host '5/8 Invoke its generated command'
    $invocation = Invoke-Example `
        -Directory (Get-Item -LiteralPath $exampleRoot) `
        -Message 'hello-from-minimal' |
        ConvertFrom-Json

    Write-Host '6/8 Read generated command help'
    $help = Get-Help Invoke-Example -Full

    Write-Host '7/8 Read the installed Markdown command reference'
    $documentationPath = Join-Path $installedModulePath `
        'Documentation' 'Invoke-Example.md'
    $documentation = Get-Content -LiteralPath $documentationPath -Raw

    [pscustomobject] @{
        PSTypeName = 'SubZeroDev.PSGenerator.MinimalExampleResult'
        Image = $image
        Module = $generatedModule.Name
        Command = 'Invoke-Example'
        Synopsis = $help.Synopsis
        DocumentationHeading = ($documentation -split "`r?`n")[0]
        Invocation = $invocation
    }
}
finally {
    Write-Host '8/8 Clean up'
    if ($null -ne $generatedModule) {
        Remove-Module $generatedModule -Force -ErrorAction SilentlyContinue
    }
    if ($imageBuilt) {
        & docker image rm --force $image 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Docker could not remove the minimal example image '$image'."
        }
    }
    if (-not $KeepArtifacts -and (Test-Path -LiteralPath $artifactRoot)) {
        Remove-Item -LiteralPath $artifactRoot -Recurse -Force
    }
}
