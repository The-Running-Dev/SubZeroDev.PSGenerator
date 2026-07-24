<#
.SYNOPSIS
Tests ContainerPSGenerator against another local repository.

.DESCRIPTION
Imports the generator from this checkout, changes to the selected repository, and builds
its validated object model. Use Generate to continue through Build-ContainerModule.

.PARAMETER Repository
Path to the local repository to test.

.PARAMETER Specification
Specification path relative to Repository, or an absolute path.

.PARAMETER Output
Generation output path relative to Repository, or an absolute path.

.PARAMETER Generate
Runs Build-ContainerModule after model validation and returns the generated artifacts.

.PARAMETER ListCommands
Generates and globally imports the module, then returns its exported commands.

.PARAMETER NoInitialize
Fails when Specification is missing and prevents refreshing an empty scaffold.
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string] $Repository,

    [Parameter()]
    [string] $Specification = 'PSModule/PSModule.psd1',

    [Parameter()]
    [string] $Output = 'artifacts/PSModule',

    [Parameter()]
    [switch] $Generate,

    [Parameter()]
    [switch] $ListCommands,

    [Parameter()]
    [switch] $NoInitialize
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $Repository -PathType Container)) {
    throw [System.IO.DirectoryNotFoundException]::new(
        "Local repository was not found: '$Repository'."
    )
}

$repositoryPath = (Resolve-Path -LiteralPath $Repository).ProviderPath
$manifestPath = Join-Path $PSScriptRoot '..' 'src' 'SubZeroDev.ContainerPSGenerator.psd1'
Import-Module $manifestPath -Force -ErrorAction Stop

Push-Location $repositoryPath
try {
    $specificationInitialized = $false
    $specificationExists = Test-Path -LiteralPath $Specification -PathType Leaf
    $refreshEmptySpecification = $false
    $refreshGeneratedSpecification = $false
    if ($specificationExists -and -not $NoInitialize) {
        $existingDefinition = Import-PowerShellDataFile -LiteralPath $Specification -ErrorAction Stop
        $refreshEmptySpecification = (
            -not $existingDefinition.ContainsKey('Commands') -or
            @($existingDefinition.Commands).Count -eq 0
        )
        $existingCommands = @($existingDefinition.Commands)
        $isMarkedGeneratedSpecification = (
            $existingDefinition.ContainsKey('GeneratedBy') -and
            $existingDefinition.GeneratedBy -eq 'SubZeroDev.ContainerPSGenerator'
        )
        $isLegacyGeneratedSpecification = (
            $existingCommands.Count -gt 0 -and
            @($existingCommands | Where-Object {
                -not $_.ContainsKey('SourcePath') -or
                -not $_.ContainsKey('SourceKind') -or
                -not $_.ContainsKey('Description') -or
                $_.Description -notlike 'Scaffolded from *'
            }).Count -eq 0
        )
        $hasAuthoredMappings = @($existingCommands | Where-Object {
            $_.ContainsKey('Mappings') -or
            (
                $_.ContainsKey('Parameters') -and
                @($_.Parameters | Where-Object { $_.ContainsKey('Mappings') }).Count -gt 0
            )
        }).Count -gt 0
        $refreshGeneratedSpecification = (
            ($isMarkedGeneratedSpecification -or $isLegacyGeneratedSpecification) -and
            -not $hasAuthoredMappings
        )
    }

    if (-not $specificationExists -or $refreshEmptySpecification -or $refreshGeneratedSpecification) {
        if ($NoInitialize) {
            throw [System.IO.FileNotFoundException]::new(
                "Container module specification was not found: '$(Join-Path $repositoryPath $Specification)'."
            )
        }
        Initialize-ContainerModuleSpecification `
            -Repository $repositoryPath `
            -Specification $Specification `
            -Force:($refreshEmptySpecification -or $refreshGeneratedSpecification) |
            Out-Null
        $action = if ($specificationExists) { 'Refreshed' } else { 'Created' }
        Write-Host "$action inferred container module specification: $Specification" -ForegroundColor Green
        $specificationInitialized = $true
    }

    if ($Generate -or $ListCommands -or $specificationInitialized) {
        $artifact = Build-ContainerModule -Specification $Specification -Output $Output
        if ($specificationInitialized -and -not $Generate -and -not $ListCommands) {
            Write-Host "Generated inferred container module: $Output" -ForegroundColor Green
        }
    }

    if ($ListCommands) {
        $model = Get-ContainerModuleModel -Specification $Specification
        $outputPath = if ([IO.Path]::IsPathRooted($Output)) {
            $Output
        }
        else {
            Join-Path $repositoryPath $Output
        }
        $generatedManifest = Join-Path ([IO.Path]::GetFullPath($outputPath)) "$($model.ModuleName).psd1"
        $generatedModule = Import-Module $generatedManifest -Force -Global -PassThru -ErrorAction Stop
        $unmappedSourceCommands = @($model.Commands | Where-Object {
            $_.Definition.ContainsKey('SourcePath') -and
            $_.Definition['SourceKind'] -notin @('Script', 'ModuleFunction') -and
            @($_.Parameters | Where-Object { $_.Mappings.Count -gt 0 }).Count -eq 0
        })
        if ($unmappedSourceCommands.Count -gt 0) {
            Write-Warning (
                "$($unmappedSourceCommands.Count) discovered command(s) have source metadata but no runtime mappings. " +
                "They currently invoke the container image only; SourcePath does not select a script inside the container. " +
                "Use -WhatIf to preview or -Verbose to trace the Docker command."
            )
        }
        Get-Command -Module $generatedModule.Name | Sort-Object Name
        return
    }

    if ($Generate) {
        $artifact
        return
    }

    Get-ContainerModuleModel -Specification $Specification
}
finally {
    Pop-Location
}
