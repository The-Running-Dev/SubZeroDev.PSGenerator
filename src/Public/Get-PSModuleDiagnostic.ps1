function Get-PSModuleDiagnostic {
    <#
    .SYNOPSIS
    Returns ordered directory inspector execution diagnostics.

    .DESCRIPTION
    Returns typed plugin execution diagnostics from an existing inspection result,
    or runs directory inspection and returns its diagnostics directly.

    .PARAMETER InputObject
    An inspection result returned by Get-PSModuleInspection.

    .PARAMETER Specification
    Path to the specification when running a new inspection.

    .PARAMETER PluginPath
    One or more additional plugin roots when running a new inspection.

    .PARAMETER Detailed
    Includes plugin paths, start times, and error text for troubleshooting.

    .PARAMETER IncludeIssues
    Also emits structured inspection issues, typed
    SubZeroDev.PSGenerator.InspectionIssueDiagnostic, after every plugin-execution
    record in the same stream. The default output is unchanged when this switch is
    omitted.
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
        [switch] $Detailed,

        [Parameter()]
        [switch] $IncludeIssues
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

        if ($IncludeIssues) {
            foreach ($issue in $inspection.Issues) {
                [pscustomobject] @{
                    PSTypeName    = 'SubZeroDev.PSGenerator.InspectionIssueDiagnostic'
                    Severity      = $issue.Severity
                    Code          = $issue.Code
                    Inspector     = $issue.Inspector
                    Path          = $issue.Path
                    Message       = $issue.Message
                    ExceptionType = $issue.ExceptionType
                    Details       = $issue.Details
                }
            }
        }
    }
}
