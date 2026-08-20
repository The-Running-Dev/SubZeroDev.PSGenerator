function Test-PSModulePathAncestor {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $CandidateAncestor,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [Parameter()]
        [StringComparison] $Comparison = $(
            if ($IsLinux) { [StringComparison]::Ordinal }
            else { [StringComparison]::OrdinalIgnoreCase }
        )
    )

    # Normalize before trimming. A trimmed Windows root such as 'D:' is a
    # process-relative drive path if it is passed back through GetFullPath.
    $ancestorPath = [IO.Path]::GetFullPath($CandidateAncestor)
    $descendantPath = [IO.Path]::GetFullPath($Path)
    $separators = [char[]] @(
        [IO.Path]::DirectorySeparatorChar,
        [IO.Path]::AltDirectorySeparatorChar
    )
    $ancestorForComparison = $ancestorPath.TrimEnd($separators)
    $descendantForComparison = $descendantPath.TrimEnd($separators)

    if ([string]::Equals($ancestorForComparison, $descendantForComparison, $Comparison)) {
        return $false
    }

    $ancestorPrefix = $ancestorForComparison + [IO.Path]::DirectorySeparatorChar
    return $descendantForComparison.StartsWith($ancestorPrefix, $Comparison)
}
