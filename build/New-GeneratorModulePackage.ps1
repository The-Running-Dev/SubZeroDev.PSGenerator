<#
.SYNOPSIS
Assembles a clean, importable generator module package.

.DESCRIPTION
Copies the complete module source layout into a newly created output directory and
returns the packaged module manifest. Existing output is removed only after the
resolved path is verified not to be a filesystem root, repository ancestor, or part
of the source module tree.

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

$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$sourceRoot = Join-Path $repositoryRoot 'src'
$outputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Output)
$outputPath = [IO.Path]::GetFullPath($outputPath)
$directorySeparator = [IO.Path]::DirectorySeparatorChar
$outputPrefix = $outputPath.TrimEnd(
    [IO.Path]::DirectorySeparatorChar,
    [IO.Path]::AltDirectorySeparatorChar
) + $directorySeparator
$sourcePrefix = $sourceRoot.TrimEnd(
    [IO.Path]::DirectorySeparatorChar,
    [IO.Path]::AltDirectorySeparatorChar
) + $directorySeparator
if ($outputPath -eq [IO.Path]::GetPathRoot($outputPath) -or
    $outputPath.Equals($repositoryRoot, [StringComparison]::OrdinalIgnoreCase) -or
    $repositoryRoot.StartsWith($outputPrefix, [StringComparison]::OrdinalIgnoreCase) -or
    $outputPath.Equals($sourceRoot, [StringComparison]::OrdinalIgnoreCase) -or
    $outputPath.StartsWith($sourcePrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw [System.ArgumentException]::new(
        "Generator package output path is unsafe: '$outputPath'.",
        'Output'
    )
}

if (Test-Path -LiteralPath $outputPath) {
    Remove-Item -LiteralPath $outputPath -Recurse -Force
}

$null = New-Item -Path $outputPath -ItemType Directory -Force
foreach ($sourceItem in Get-ChildItem -LiteralPath $sourceRoot) {
    Copy-Item -LiteralPath $sourceItem.FullName -Destination $outputPath -Recurse -Force
}

$manifestPath = Join-Path $outputPath 'SubZeroDev.PSGenerator.psd1'
$null = Test-ModuleManifest -Path $manifestPath -ErrorAction Stop
Get-Item -LiteralPath $manifestPath
