function Import-PSModuleSpecification {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string] $Path
    )

    $resolvedPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)

    if ([System.IO.Path]::GetExtension($resolvedPath) -ne '.psd1') {
        throw [System.ArgumentException]::new(
            "The container module specification must be a PowerShell data file with a '.psd1' extension: '$resolvedPath'.",
            'Path'
        )
    }

    if (-not (Test-Path -LiteralPath $resolvedPath -PathType Leaf)) {
        throw [System.IO.FileNotFoundException]::new(
            "Container module specification was not found: '$resolvedPath'.",
            $resolvedPath
        )
    }

    try {
        return Import-PowerShellDataFile -LiteralPath $resolvedPath -ErrorAction Stop
    }
    catch {
        throw [System.IO.InvalidDataException]::new(
            "Container module specification is not a valid PowerShell data file: '$resolvedPath'.",
            $_.Exception
        )
    }
}
