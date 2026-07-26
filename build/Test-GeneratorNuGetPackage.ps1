<#
.SYNOPSIS
Builds and verifies the generator's PowerShell NuGet package.

.DESCRIPTION
Creates the package, validates its NuSpec identity and repository metadata, then
installs it from a temporary local PSResource repository and imports the installed
module.

.PARAMETER Output
Directory that will contain the generated .nupkg file.

.PARAMETER InstallDependencies
Installs the pinned Microsoft.PowerShell.PSResourceGet version for the current user
when required commands are unavailable.
#>
[CmdletBinding()]
param (
    [Parameter()]
    [string] $Output = 'artifacts/packages',

    [Parameter()]
    [switch] $InstallDependencies
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$package = & (Join-Path $PSScriptRoot 'New-GeneratorNuGetPackage.ps1') `
    -Output $Output `
    -InstallDependencies:$InstallDependencies
$repositoryName = 'SubZeroDevPackageTest-{0}' -f [guid]::NewGuid().ToString('N')
$installRoot = Join-Path ([IO.Path]::GetTempPath()) (
    'SubZeroDev.PSGenerator.Install.{0}' -f [guid]::NewGuid()
)

try {
    Add-Type -AssemblyName System.IO.Compression
    $archive = [IO.Compression.ZipFile]::OpenRead($package.FullName)
    try {
        $nuspecEntry = @($archive.Entries | Where-Object { $_.Name -like '*.nuspec' })
        if ($nuspecEntry.Count -ne 1) {
            throw "Expected one NuSpec file in '$($package.FullName)', but found $($nuspecEntry.Count)."
        }

        $reader = [IO.StreamReader]::new($nuspecEntry[0].Open())
        try {
            [xml] $nuspec = $reader.ReadToEnd()
        }
        finally {
            $reader.Dispose()
        }
    }
    finally {
        $archive.Dispose()
    }

    $metadata = $nuspec.package.metadata
    if ($metadata.id -ne 'SubZeroDev.PSGenerator') {
        throw "Unexpected package ID '$($metadata.id)'."
    }
    if ([string]::IsNullOrWhiteSpace([string] $metadata.version)) {
        throw 'The package version is missing.'
    }
    if ($metadata.repository.type -ne 'git' -or
        $metadata.repository.url -ne 'https://github.com/The-Running-Dev/SubZeroDev.PSGenerator.git') {
        throw 'The package does not contain the expected GitHub repository metadata.'
    }

    $null = New-Item -Path $installRoot -ItemType Directory -Force
    $repositoryUri = [uri]::new(
        [IO.Path]::GetFullPath($package.DirectoryName),
        [UriKind]::Absolute
    )
    Register-PSResourceRepository `
        -Name $repositoryName `
        -Uri $repositoryUri.AbsoluteUri `
        -ApiVersion Local `
        -Trusted `
        -ErrorAction Stop

    Save-PSResource `
        -Name $metadata.id `
        -Version $metadata.version `
        -Repository $repositoryName `
        -Path $installRoot `
        -TrustRepository `
        -ErrorAction Stop

    $installedManifest = Get-ChildItem `
        -LiteralPath $installRoot `
        -Filter 'SubZeroDev.PSGenerator.psd1' `
        -File `
        -Recurse |
        Select-Object -First 1
    if (-not $installedManifest) {
        throw "The locally installed package did not contain the module manifest."
    }

    $installedModule = Import-Module $installedManifest.FullName -Force -PassThru -ErrorAction Stop
    $buildCommand = Get-Command Build-PSModule `
        -Module $installedModule.Name `
        -ErrorAction SilentlyContinue
    if (-not $buildCommand) {
        throw 'The installed package did not export Build-PSModule.'
    }

    Write-Host "Verified NuGet package '$($package.Name)' by installing and importing it from a local repository."
    $package
}
finally {
    if (Get-PSResourceRepository -Name $repositoryName -ErrorAction SilentlyContinue) {
        Unregister-PSResourceRepository -Name $repositoryName -ErrorAction SilentlyContinue
    }
    Remove-Module SubZeroDev.PSGenerator -Force -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $installRoot) {
        Remove-Item -LiteralPath $installRoot -Recurse -Force
    }
}
