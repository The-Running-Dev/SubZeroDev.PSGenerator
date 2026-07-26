function Test-PSModuleSpecification {
    <#
    .SYNOPSIS
    Validates a container module specification.

    .DESCRIPTION
    Loads a PowerShell data-file specification and runs the built-in Version 1
    validators. Returns true when the specification is valid. Invalid specifications
    produce a terminating error with source and object identity context when available.

    .PARAMETER Specification
    Path to the directory's PowerShell data-file specification.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter()]
        [string] $Specification = 'PSModule/PSModule.psd1'
    )

    $specificationPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Specification)
    $context = New-PSModuleBuildContext `
        -SpecificationPath $specificationPath `
        -OutputPath (Join-Path (Split-Path $specificationPath -Parent) '.container-module-validation')
    $null = Invoke-PSModulePluginPipeline `
        -Context $context `
        -Path (Join-Path $PSScriptRoot '..' 'Plugins') `
        -Stage Validators

    return $true
}
