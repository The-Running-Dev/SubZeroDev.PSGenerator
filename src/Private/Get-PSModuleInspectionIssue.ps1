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
    # AppendIndex is a final tiebreaker that also makes every comparison decisive,
    # so [Array]::Sort's lack of a stability guarantee cannot affect the result.
    # Path and Code compare ordinally, matching the repository's other cross-host
    # deterministic sorts (for example Get-PSModulePlugin's filename ordering),
    # rather than Sort-Object's culture-sensitive, case-insensitive default.
    $ordered = @($Context.InspectionIssues)
    [Array]::Sort(
        $ordered,
        [System.Collections.Generic.Comparer[object]]::Create({
            param ($left, $right)

            $comparison = $left.InspectorExecutionOrder.CompareTo($right.InspectorExecutionOrder)
            if ($comparison -ne 0) { return $comparison }

            $comparison = [System.StringComparer]::Ordinal.Compare($left.Path, $right.Path)
            if ($comparison -ne 0) { return $comparison }

            $comparison = [System.StringComparer]::Ordinal.Compare($left.Code, $right.Code)
            if ($comparison -ne 0) { return $comparison }

            return $left.AppendIndex.CompareTo($right.AppendIndex)
        })
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
