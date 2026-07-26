function Test-PSModuleInspectionPath {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)] [psobject] $Context,
        [Parameter(Mandatory)] [string] $Path
    )

    $fullPath = [IO.Path]::GetFullPath($Path)
    $outputPrefix = $Context.OutputPath.TrimEnd(
        [IO.Path]::DirectorySeparatorChar,
        [IO.Path]::AltDirectorySeparatorChar
    ) + [IO.Path]::DirectorySeparatorChar
    if ($fullPath.StartsWith($outputPrefix, [StringComparison]::OrdinalIgnoreCase)) { return $false }

    $segments = @($fullPath.Substring($Context.RepositoryPath.Length).Split(
        [IO.Path]::DirectorySeparatorChar,
        [StringSplitOptions]::RemoveEmptyEntries
    ))
    if ($segments | Where-Object { $_ -in @('.git', 'node_modules', 'artifacts', 'bin', 'obj') }) {
        return $false
    }

    $directory = Split-Path $fullPath -Parent
    while ($directory -and -not [string]::Equals(
        $directory,
        $Context.RepositoryPath,
        [StringComparison]::OrdinalIgnoreCase
    )) {
        if (Test-Path -LiteralPath (Join-Path $directory '.git')) { return $false }
        $parent = Split-Path $directory -Parent
        if ($parent -eq $directory) { break }
        $directory = $parent
    }
    return $true
}
