function Get-PSModuleModel {
    <#
    .SYNOPSIS
    Builds the normalized model for a container module specification.

    .DESCRIPTION
    Loads and validates a PowerShell data-file specification, then returns the normalized
    object model consumed by later generator stages.

    .PARAMETER Specification
    Path to the repository's PowerShell data-file specification.
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [string] $Specification = 'PSModule/PSModule.psd1'
    )

    $specificationPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Specification)
    $context = New-PSModuleBuildContext `
        -SpecificationPath $specificationPath `
        -OutputPath (Join-Path (Split-Path $specificationPath -Parent) '.container-module-model')
    $builtInPluginRoot = Join-Path $PSScriptRoot '..' 'Plugins'

    $null = Invoke-PSModulePluginPipeline -Context $context -Path $builtInPluginRoot -Stage Validators
    $null = Invoke-PSModulePluginPipeline -Context $context -Path $builtInPluginRoot -Stage ObjectModelProcessors

    return $context.Model
}
