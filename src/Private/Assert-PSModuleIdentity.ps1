function Assert-PSModuleIdentity {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Specification
    )

    if ($Specification.Contains('ModuleName')) {
        $moduleName = $Specification['ModuleName']
        if ($moduleName -isnot [string] -or $moduleName -notmatch '^[A-Za-z][A-Za-z0-9_.-]*$') {
            throw [System.IO.InvalidDataException]::new(
                "The 'ModuleName' property must be a non-empty, file-name-safe string beginning with a letter."
            )
        }
    }

    if ($Specification.Contains('ModuleVersion')) {
        $moduleVersion = $Specification['ModuleVersion']
        $parsedVersion = $null
        if ($moduleVersion -isnot [string] -or -not [version]::TryParse($moduleVersion, [ref] $parsedVersion)) {
            throw [System.IO.InvalidDataException]::new(
                "The 'ModuleVersion' property must be a valid version string."
            )
        }
    }
}
