<#
.SYNOPSIS
Creates the generator's PowerShell NuGet package.

.DESCRIPTION
Stages the generator as a clean PowerShell module, compresses it into a genuine
NuGet package with Microsoft.PowerShell.PSResourceGet, and adds repository metadata
so GitHub Packages can associate the package with this repository.

.PARAMETER Output
Directory that will contain the generated .nupkg file.

.PARAMETER InstallDependencies
Installs the pinned Microsoft.PowerShell.PSResourceGet version for the current user
when a compatible Compress-PSResource command is unavailable.
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

$requiredPSResourceGetVersion = [version] '1.1.1'
$repositoryUrl = 'https://github.com/The-Running-Dev/SubZeroDev.PSGenerator.git'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$sourceRoot = Join-Path $repositoryRoot 'src'
$outputPath = [IO.Path]::GetFullPath(
    $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Output)
)
$outputPrefix = $outputPath.TrimEnd(
    [IO.Path]::DirectorySeparatorChar,
    [IO.Path]::AltDirectorySeparatorChar
) + [IO.Path]::DirectorySeparatorChar
$sourcePrefix = $sourceRoot.TrimEnd(
    [IO.Path]::DirectorySeparatorChar,
    [IO.Path]::AltDirectorySeparatorChar
) + [IO.Path]::DirectorySeparatorChar

if ($outputPath -eq [IO.Path]::GetPathRoot($outputPath) -or
    $outputPath.Equals($repositoryRoot, [StringComparison]::OrdinalIgnoreCase) -or
    $repositoryRoot.StartsWith($outputPrefix, [StringComparison]::OrdinalIgnoreCase) -or
    $outputPath.Equals($sourceRoot, [StringComparison]::OrdinalIgnoreCase) -or
    $outputPath.StartsWith($sourcePrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw [System.ArgumentException]::new(
        "NuGet package output path is unsafe: '$outputPath'.",
        'Output'
    )
}

$compressCommand = Get-Command Compress-PSResource -ErrorAction SilentlyContinue |
    Where-Object { $_.Module.Version -ge [version] '1.1.0' } |
    Sort-Object { $_.Module.Version } -Descending |
    Select-Object -First 1

if (-not $compressCommand -and $InstallDependencies) {
    Install-Module Microsoft.PowerShell.PSResourceGet `
        -RequiredVersion $requiredPSResourceGetVersion `
        -Scope CurrentUser `
        -Force `
        -SkipPublisherCheck `
        -ErrorAction Stop

    $compressCommand = Get-Command Compress-PSResource -ErrorAction SilentlyContinue |
        Where-Object { $_.Module.Version -ge [version] '1.1.0' } |
        Sort-Object { $_.Module.Version } -Descending |
        Select-Object -First 1
}

if (-not $compressCommand) {
    throw "Compress-PSResource from Microsoft.PowerShell.PSResourceGet 1.1.0 or later is required. Run this script with -InstallDependencies."
}

$null = New-Item -Path $outputPath -ItemType Directory -Force
$temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) (
    'SubZeroDev.PSGenerator.Package.{0}' -f [guid]::NewGuid()
)

try {
    $moduleRoot = Join-Path $temporaryRoot 'SubZeroDev.PSGenerator'
    $manifest = & (Join-Path $PSScriptRoot 'New-GeneratorModulePackage.ps1') -Output $moduleRoot
    $manifestData = Test-ModuleManifest -Path $manifest.FullName -ErrorAction Stop
    $packagePath = Join-Path $outputPath (
        'SubZeroDev.PSGenerator.{0}.nupkg' -f $manifestData.Version
    )

    if (Test-Path -LiteralPath $packagePath -PathType Leaf) {
        Remove-Item -LiteralPath $packagePath -Force
    }

    & $compressCommand -Path $moduleRoot -DestinationPath $outputPath -ErrorAction Stop
    if (-not (Test-Path -LiteralPath $packagePath -PathType Leaf)) {
        throw "Compress-PSResource did not produce the expected package: '$packagePath'."
    }

    Add-Type -AssemblyName System.IO.Compression
    $archive = [IO.Compression.ZipFile]::Open(
        $packagePath,
        [IO.Compression.ZipArchiveMode]::Update
    )
    try {
        $nuspecEntries = @($archive.Entries | Where-Object { $_.Name -like '*.nuspec' })
        if ($nuspecEntries.Count -ne 1) {
            throw "Expected one NuSpec file in '$packagePath', but found $($nuspecEntries.Count)."
        }

        $nuspecEntry = $nuspecEntries[0]
        $reader = [IO.StreamReader]::new($nuspecEntry.Open())
        try {
            [xml] $nuspec = $reader.ReadToEnd()
        }
        finally {
            $reader.Dispose()
        }

        $metadata = $nuspec.package.metadata
        $existingRepository = $metadata.SelectSingleNode(
            "*[local-name()='repository']"
        )
        if ($existingRepository) {
            $null = $metadata.RemoveChild($existingRepository)
        }
        $repository = $nuspec.CreateElement('repository', $metadata.NamespaceURI)
        $repository.SetAttribute('type', 'git')
        $repository.SetAttribute('url', $repositoryUrl)
        $null = $metadata.AppendChild($repository)

        $nuspecEntryName = $nuspecEntry.FullName
        $nuspecEntry.Delete()
        $replacementEntry = $archive.CreateEntry(
            $nuspecEntryName,
            [IO.Compression.CompressionLevel]::Optimal
        )
        $writerSettings = [Xml.XmlWriterSettings]::new()
        $writerSettings.Encoding = [Text.UTF8Encoding]::new($false)
        $writerSettings.Indent = $true
        $writer = [Xml.XmlWriter]::Create($replacementEntry.Open(), $writerSettings)
        try {
            $nuspec.Save($writer)
        }
        finally {
            $writer.Dispose()
        }
    }
    finally {
        $archive.Dispose()
    }

    Get-Item -LiteralPath $packagePath
}
finally {
    if (Test-Path -LiteralPath $temporaryRoot) {
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
    }
}
