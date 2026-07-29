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

    $current = $root.TrimEnd(
        [IO.Path]::DirectorySeparatorChar,
        [IO.Path]::AltDirectorySeparatorChar
    )
    if (-not $current) { $current = [string] [IO.Path]::DirectorySeparatorChar }

    $hops = 0
    foreach ($segment in $segments) {
        $current = Join-Path $current $segment

        # A path segment may itself be a reparse point (symlink or junction). Resolve
        # each one as it is encountered, rather than only the final path, so a link
        # anywhere in the chain - not just at the leaf - cannot smuggle a real location
        # outside the repository past a purely lexical check. Bounded so a link chain
        # that cycles back on itself terminates instead of looping.
        while ($true) {
            $attributes = $null
            try {
                $attributes = [IO.File]::GetAttributes($current)
            }
            catch [System.IO.IOException], [System.UnauthorizedAccessException] {
                break
            }

            if (-not $attributes.HasFlag([IO.FileAttributes]::ReparsePoint)) {
                break
            }

            $hops++
            if ($hops -gt 32) {
                throw [System.IO.IOException]::new(
                    "Symlink resolution for '$Path' exceeded the maximum depth."
                )
            }

            $target = $null
            if ($attributes.HasFlag([IO.FileAttributes]::Directory)) {
                $target = [IO.Directory]::ResolveLinkTarget($current, $false)
            }
            if (-not $target) {
                $target = [IO.File]::ResolveLinkTarget($current, $false)
            }
            if (-not $target) { break }

            $current = $target.FullName
        }
    }

    return $current
}
