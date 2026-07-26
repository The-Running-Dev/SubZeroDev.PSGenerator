function Initialize-PSModuleSpecification {
    <#
    .SYNOPSIS
    Creates an initial container module specification from directory inspection.

    .DESCRIPTION
    Creates a missing PSModule specification using the directory name, documented
    container image references, standalone scripts beneath the directory's scripts
    directory, and functions explicitly exported by modules beneath that same boundary.

    The generated specification is a scaffold. Review inferred commands and add their
    descriptions and help before publishing. Inferred scripts and exported module
    functions execute from the packaged scripts tree. Add explicit runtime mappings
    only for authored commands that invoke a container; inference does not guess
    container intent specific to the inspected directory.

    .PARAMETER Directory
    Directory to inspect.

    .PARAMETER Specification
    Specification path relative to Directory, or an absolute path.

    .PARAMETER Force
    Replaces an existing specification.

    .PARAMETER PassThru
    Returns the created specification file.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter()]
        [string] $Directory = '.',

        [Parameter()]
        [string] $Specification = 'PSModule/PSModule.psd1',

        [Parameter()]
        [switch] $Force,

        [Parameter()]
        [switch] $PassThru
    )

    if (-not (Test-Path -LiteralPath $Directory -PathType Container)) {
        throw [System.IO.DirectoryNotFoundException]::new("Directory was not found: '$Directory'.")
    }
    $directoryPath = [IO.Path]::TrimEndingDirectorySeparator(
        [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $Directory).ProviderPath)
    )
    $specificationPath = if ([IO.Path]::IsPathRooted($Specification)) {
        [IO.Path]::GetFullPath($Specification)
    }
    else {
        [IO.Path]::GetFullPath((Join-Path $directoryPath $Specification))
    }

    if ((Test-Path -LiteralPath $specificationPath -PathType Leaf) -and -not $Force) {
        throw [System.IO.IOException]::new(
            "Container module specification already exists: '$specificationPath'. Use -Force to replace it."
        )
    }
    if (-not $PSCmdlet.ShouldProcess($specificationPath, 'Create container module specification')) { return }

    $definition = Get-PSModuleSpecificationCandidate -DirectoryPath $directoryPath
    Write-Verbose (
        "Discovered {0} command candidate(s) while initializing '{1}'." -f
        @($definition.Commands).Count,
        $directoryPath
    )
    $source = ConvertTo-PSModuleSpecificationSource -Specification $definition
    $directory = Split-Path $specificationPath -Parent
    $null = New-Item -Path $directory -ItemType Directory -Force
    Set-Content -LiteralPath $specificationPath -Value $source -Encoding utf8NoBOM -NoNewline

    if ($PassThru) { Get-Item -LiteralPath $specificationPath }
}
