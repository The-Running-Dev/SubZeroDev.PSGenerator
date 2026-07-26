function Get-PSModuleInspection {
    <#
    .SYNOPSIS
    Inspects a repository without generating a module.

    .DESCRIPTION
    Loads a repository specification, runs the ordered inspector plugin stage, and
    returns typed in-memory inspection data and plugin execution records. No build
    output is created.

    .PARAMETER Specification
    Path to the repository PowerShell data-file specification.

    .PARAMETER PluginPath
    One or more additional plugin roots. When omitted, a Plugins directory beside
    the specification is used when it exists.
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [string] $Specification = 'PSModule/PSModule.psd1',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]] $PluginPath
    )

    $parameters = @{ Specification = $Specification }
    if ($PSBoundParameters.ContainsKey('PluginPath')) {
        $parameters.PluginPath = $PluginPath
        $parameters.PluginPathSpecified = $true
    }

    $context = Invoke-PSModuleInspection @parameters
    [pscustomobject] @{
        PSTypeName       = 'SubZeroDev.PSGenerator.InspectionResult'
        RepositoryPath   = $context.RepositoryPath
        SpecificationPath = $context.SpecificationPath
        Data             = $context.Inspection
        PluginExecutions = @($context.PluginExecutions)
    }
}
