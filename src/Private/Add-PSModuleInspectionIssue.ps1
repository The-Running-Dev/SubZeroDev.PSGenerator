function Add-PSModuleInspectionIssue {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [psobject] $Context,

        [Parameter(Mandatory)]
        [ValidateSet('Warning', 'Error')]
        [string] $Severity,

        [Parameter(Mandatory)]
        [ValidatePattern('^[A-Z][A-Z0-9]*(_[A-Z0-9]+)+$')]
        [string] $Code,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Inspector,

        [Parameter()]
        [string] $Path,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Message,

        [Parameter()]
        [string] $ExceptionType,

        [Parameter()]
        $Details
    )

    if (-not $Context.PSObject.Properties['InspectionIssues']) {
        $Context | Add-Member -MemberType NoteProperty -Name InspectionIssues -Value (
            [System.Collections.Generic.List[object]]::new()
        )
    }

    # Plugins run one at a time, so the number of executions already recorded is the
    # currently running plugin's position. Capturing it here, rather than trusting
    # append order alone, lets a later stable sort restore inspector execution order
    # even when one inspector appends issues for several paths out of order.
    $executionOrder = if ($Context.PSObject.Properties['PluginExecutions']) {
        @($Context.PluginExecutions).Count
    }
    else {
        0
    }

    $issue = [pscustomobject] @{
        PSTypeName              = 'SubZeroDev.PSGenerator.InspectionIssue'
        Severity                = $Severity
        Code                    = $Code
        Inspector               = $Inspector
        Path                    = $Path
        Message                 = $Message
        ExceptionType           = $ExceptionType
        Details                 = $Details
        InspectorExecutionOrder = $executionOrder
        AppendIndex             = $Context.InspectionIssues.Count
    }

    $Context.InspectionIssues.Add($issue)
    $issue
}
