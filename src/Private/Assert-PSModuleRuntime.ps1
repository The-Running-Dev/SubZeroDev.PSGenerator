function Assert-PSModuleRuntime {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Specification
    )

    if (-not $Specification.Contains('ContainerImage')) {
        return
    }

    $containerImage = $Specification['ContainerImage']
    if ($containerImage -isnot [string] -or $containerImage -notmatch '^[A-Za-z0-9][A-Za-z0-9._/:@-]*$') {
        throw [System.IO.InvalidDataException]::new(
            "The 'ContainerImage' property must be a non-empty container image reference without whitespace."
        )
    }
}
