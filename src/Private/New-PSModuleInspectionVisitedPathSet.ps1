function New-PSModuleInspectionVisitedPathSet {
    [CmdletBinding()]
    param ()

    # Windows and macOS filesystems are case-insensitive by default; Linux is not.
    # Matches the comparison Test-PSModuleInspectionPath applies to the same paths.
    $comparer = if ($IsLinux) {
        [StringComparer]::Ordinal
    }
    else {
        [StringComparer]::OrdinalIgnoreCase
    }

    [System.Collections.Generic.HashSet[string]]::new($comparer)
}
