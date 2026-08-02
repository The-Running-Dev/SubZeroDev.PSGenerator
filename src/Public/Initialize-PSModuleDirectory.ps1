function Initialize-PSModuleDirectory {
    <#
    .SYNOPSIS
    Prepares a directory for PSGenerator and reports what it produced.

    .DESCRIPTION
    Points the generator at a directory and takes it as far as it can go in one
    call: scaffolds a specification when none exists, generates the module,
    imports it globally so its commands are immediately callable, and returns
    either the normalized model, the generated artifact, or the exported
    commands.

    An authored specification is never overwritten. A missing specification is
    created, and an empty or generator-owned scaffold without authored runtime
    mappings is refreshed. Once mappings are added, the specification is treated
    as authored and preserved.

    This is the entry point for pointing the generator at a directory you have
    mounted or checked out, rather than running from inside it.

    .PARAMETER Directory
    Directory to prepare.

    .PARAMETER Specification
    Specification path relative to Directory, or an absolute path.

    .PARAMETER Output
    Generation output path relative to Directory, or an absolute path.

    .PARAMETER Generate
    Generates and globally imports the module, then returns the generated
    artifact.

    .PARAMETER ListCommands
    Generates and globally imports the module, then returns its exported
    commands. Warns when a discovered command carries source metadata but no
    runtime mappings, because it would invoke the container image rather than
    the packaged source.

    .PARAMETER NoInitialize
    Fails when Specification is missing instead of scaffolding one, and
    prevents refreshing an empty scaffold.

    .EXAMPLE
    Initialize-PSModuleDirectory -Directory /workspace -ListCommands

    Scaffolds, generates, imports, and lists the commands for a mounted
    directory.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Directory,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $Specification = 'PSModule/PSModule.psd1',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $Output = 'artifacts/PSModule',

        [Parameter()]
        [switch] $Generate,

        [Parameter()]
        [switch] $ListCommands,

        [Parameter()]
        [switch] $NoInitialize,

        [Parameter()]
        [switch] $ForceOutput
    )

    if (-not (Test-Path -LiteralPath $Directory -PathType Container)) {
        throw [System.IO.DirectoryNotFoundException]::new(
            "Directory was not found: '$Directory'."
        )
    }

    $directoryPath = (Resolve-Path -LiteralPath $Directory).ProviderPath

    Push-Location $directoryPath
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
                $existingDefinition.GeneratedBy -eq 'SubZeroDev.PSGenerator'
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
                    "Container module specification was not found: '$(Join-Path $directoryPath $Specification)'."
                )
            }
            Initialize-PSModuleSpecification `
                -Directory $directoryPath `
                -Specification $Specification `
                -Force:($refreshEmptySpecification -or $refreshGeneratedSpecification) |
                Out-Null
            $action = if ($specificationExists) { 'Refreshed' } else { 'Created' }
            Write-Host "$action inferred container module specification: $Specification" -ForegroundColor Green
            $specificationInitialized = $true
        }

        if ($Generate -or $ListCommands -or $specificationInitialized) {
            $buildParameters = @{
                Specification = $Specification
                Output        = $Output
            }
            if ($ForceOutput) {
                $buildParameters['Force'] = $true
            }
            $artifact = Build-PSModule @buildParameters
            $model = Get-PSModuleModel -Specification $Specification
            $outputPath = if ([IO.Path]::IsPathRooted($Output)) {
                $Output
            }
            else {
                Join-Path $directoryPath $Output
            }
            $generatedManifest = Join-Path ([IO.Path]::GetFullPath($outputPath)) "$($model.ModuleName).psd1"
            $generatedModule = Import-Module $generatedManifest -Force -Global -PassThru -ErrorAction Stop
            if ($specificationInitialized -and -not $Generate -and -not $ListCommands) {
                Write-Host "Generated inferred container module: $Output" -ForegroundColor Green
            }
        }

        if ($ListCommands) {
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
            return Get-Command -Module $generatedModule.Name | Sort-Object Name
        }

        if ($Generate) {
            return $artifact
        }

        return Get-PSModuleModel -Specification $Specification
    }
    finally {
        Pop-Location
    }
}
