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

    # The unary comma prevents the pipeline from enumerating the HashSet: without it,
    # a freshly constructed (always empty) set emits zero output objects, so every
    # caller would capture $null instead of the set itself.
    , [System.Collections.Generic.HashSet[string]]::new($comparer)
}
