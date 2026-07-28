function Get-PSModuleInspectionIssue {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [psobject] $Context
    )

    if (-not $Context.PSObject.Properties['InspectionIssues']) {
        return @()
    }

    # Order is inspector execution order, then repository-relative path, then code.
    # AppendIndex is the final tiebreaker so ordering never depends on Sort-Object's
    # own stability guarantees.
    $ordered = @($Context.InspectionIssues) | Sort-Object -Property @(
        @{ Expression = { $_.InspectorExecutionOrder } }
        @{ Expression = { $_.Path } }
        @{ Expression = { $_.Code } }
        @{ Expression = { $_.AppendIndex } }
    )

    foreach ($issue in $ordered) {
        [pscustomobject] @{
            PSTypeName    = 'SubZeroDev.PSGenerator.InspectionIssue'
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
