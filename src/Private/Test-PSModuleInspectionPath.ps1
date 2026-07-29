function Test-PSModuleInspectionPath {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)] [psobject] $Context,
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [System.Collections.Generic.HashSet[string]] $VisitedRealPaths
    )

    # Windows and macOS filesystems are case-insensitive by default; Linux is not.
    $comparison = if ($IsLinux) {
        [StringComparison]::Ordinal
    }
    else {
        [StringComparison]::OrdinalIgnoreCase
    }
    $segmentComparer = if ($IsLinux) {
        [StringComparer]::Ordinal
    }
    else {
        [StringComparer]::OrdinalIgnoreCase
    }
    $excludedSegments = [System.Collections.Generic.HashSet[string]]::new(
        [string[]] @('.git', 'node_modules', 'artifacts', 'bin', 'obj'),
        $segmentComparer
    )

    # Resolve real (symlink/junction-resolved) locations rather than trusting the
    # lexical path. A linked file's own location can look like it is inside the
    # repository while its content actually comes from wherever the link points.
    try {
        $realPath = Resolve-PSModuleInspectionRealPath -Path $Path
        $realDirectoryPath = Resolve-PSModuleInspectionRealPath -Path $Context.DirectoryPath
        $realOutputPath = Resolve-PSModuleInspectionRealPath -Path $Context.OutputPath
    }
    catch [System.IO.IOException] {
        return $false
    }

    $realDirectoryPrefix = $realDirectoryPath.TrimEnd(
        [IO.Path]::DirectorySeparatorChar,
        [IO.Path]::AltDirectorySeparatorChar
    ) + [IO.Path]::DirectorySeparatorChar
    if (-not $realPath.StartsWith($realDirectoryPrefix, $comparison)) {
        return $false
    }

    $realOutputPrefix = $realOutputPath.TrimEnd(
        [IO.Path]::DirectorySeparatorChar,
        [IO.Path]::AltDirectorySeparatorChar
    ) + [IO.Path]::DirectorySeparatorChar
    if ($realPath.StartsWith($realOutputPrefix, $comparison)) { return $false }

    $segments = @($realPath.Substring($realDirectoryPath.Length).Split(
        [IO.Path]::DirectorySeparatorChar,
        [IO.Path]::AltDirectorySeparatorChar,
        [StringSplitOptions]::RemoveEmptyEntries
    ))
    if ($segments | Where-Object { $excludedSegments.Contains($_) }) {
        return $false
    }

    $directory = Split-Path $realPath -Parent
    while ($directory -and -not [string]::Equals($directory, $realDirectoryPath, $comparison)) {
        if (Test-Path -LiteralPath (Join-Path $directory '.git')) { return $false }
        $parent = Split-Path $directory -Parent
        if ($parent -eq $directory) { break }
        $directory = $parent
    }

    # Deduplicate a real file reached through two different admitted paths (for
    # example two symlinks pointing at the same target) within this traversal.
    if (-not $VisitedRealPaths.Add($realPath)) {
        return $false
    }

    return $true
}
