function Get-PSModuleDiagnostic {
    <#
    .SYNOPSIS
    Returns ordered repository inspector execution diagnostics.

    .DESCRIPTION
    Returns typed plugin execution diagnostics from an existing inspection result,
    or runs repository inspection and returns its diagnostics directly.

    .PARAMETER InputObject
    An inspection result returned by Get-PSModuleInspection.

    .PARAMETER Specification
    Path to the repository specification when running a new inspection.

    .PARAMETER PluginPath
    One or more additional plugin roots when running a new inspection.

    .PARAMETER Detailed
    Includes plugin paths, start times, and error text for troubleshooting.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Run')]
    param (
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'Input')]
        [ValidateNotNull()]
        [psobject] $InputObject,

        [Parameter(ParameterSetName = 'Run')]
        [string] $Specification = 'PSModule/PSModule.psd1',

        [Parameter(ParameterSetName = 'Run')]
        [ValidateNotNullOrEmpty()]
        [string[]] $PluginPath,

        [Parameter()]
        [switch] $Detailed
    )

    process {
        $inspection = if ($PSCmdlet.ParameterSetName -eq 'Input') {
            if ($InputObject.PSObject.TypeNames -notcontains 'SubZeroDev.PSGenerator.InspectionResult') {
                throw [System.ArgumentException]::new(
                    'InputObject must be returned by Get-PSModuleInspection.'
                )
            }
            $InputObject
        }
        else {
            $parameters = @{ Specification = $Specification }
            if ($PSBoundParameters.ContainsKey('PluginPath')) { $parameters.PluginPath = $PluginPath }
            Get-PSModuleInspection @parameters
        }

        foreach ($execution in $inspection.PluginExecutions) {
            $diagnostic = [ordered] @{
                PSTypeName           = 'SubZeroDev.PSGenerator.Diagnostic'
                Stage                = $execution.Stage
                ExecutionOrder       = $execution.ExecutionOrder
                Plugin               = $execution.Plugin
                DurationMilliseconds = [math]::Round($execution.Duration.TotalMilliseconds, 3)
                Succeeded            = $execution.Succeeded
            }
            if ($Detailed) {
                $diagnostic.Path = $execution.Path
                $diagnostic.StartedAt = $execution.StartedAt
                $diagnostic.Error = $execution.Error
            }
            [pscustomobject] $diagnostic
        }
    }
}
