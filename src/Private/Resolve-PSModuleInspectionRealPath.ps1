function Resolve-PSModuleInspectionRealPath {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Path
    )

    $full = [IO.Path]::GetFullPath($Path)
    $root = [IO.Path]::GetPathRoot($full)
    $segments = @($full.Substring($root.Length).Split(
        [IO.Path]::DirectorySeparatorChar,
        [IO.Path]::AltDirectorySeparatorChar,
        [StringSplitOptions]::RemoveEmptyEntries
    ))

    $resolved = $root.TrimEnd(
        [IO.Path]::DirectorySeparatorChar,
        [IO.Path]::AltDirectorySeparatorChar
    )
    if (-not $resolved) { $resolved = [string] [IO.Path]::DirectorySeparatorChar }

    $remaining = [System.Collections.Generic.Stack[string]]::new()
    for ($i = $segments.Count - 1; $i -ge 0; $i--) {
        $remaining.Push($segments[$i])
    }

    # A path segment may itself be a reparse point (symlink or junction), including a
    # segment that only appears after substituting an earlier link's own target. When a
    # link is found, its (always absolute) target is decomposed back into segments and
    # pushed onto this same work stack, rather than trusted as an already-resolved unit
    # - so a reparse point anywhere along the target's own chain, not only at its final
    # component, is also resolved. Bounded so a chain that cycles back on itself
    # terminates instead of looping.
    $hops = 0
    while ($remaining.Count -gt 0) {
        $segment = $remaining.Pop()
        $candidate = Join-Path $resolved $segment

        $attributes = $null
        try {
            $attributes = [IO.File]::GetAttributes($candidate)
        }
        catch [System.IO.IOException], [System.UnauthorizedAccessException] {
            $resolved = $candidate
            continue
        }

        if (-not $attributes.HasFlag([IO.FileAttributes]::ReparsePoint)) {
            $resolved = $candidate
            continue
        }

        $hops++
        if ($hops -gt 32) {
            throw [System.IO.IOException]::new(
                "Symlink resolution for '$Path' exceeded the maximum depth."
            )
        }

        $target = $null
        if ($attributes.HasFlag([IO.FileAttributes]::Directory)) {
            $target = [IO.Directory]::ResolveLinkTarget($candidate, $false)
        }
        if (-not $target) {
            $target = [IO.File]::ResolveLinkTarget($candidate, $false)
        }
        if (-not $target) {
            $resolved = $candidate
            continue
        }

        $targetRoot = [IO.Path]::GetPathRoot($target.FullName)
        $targetSegments = @($target.FullName.Substring($targetRoot.Length).Split(
            [IO.Path]::DirectorySeparatorChar,
            [IO.Path]::AltDirectorySeparatorChar,
            [StringSplitOptions]::RemoveEmptyEntries
        ))
        for ($i = $targetSegments.Count - 1; $i -ge 0; $i--) {
            $remaining.Push($targetSegments[$i])
        }

        $resolved = $targetRoot.TrimEnd(
            [IO.Path]::DirectorySeparatorChar,
            [IO.Path]::AltDirectorySeparatorChar
        )
        if (-not $resolved) { $resolved = [string] [IO.Path]::DirectorySeparatorChar }
    }

    return $resolved
}
