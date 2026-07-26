function Assert-PSModuleObjectIdentities {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Specification
    )

    $identities = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )

    $objects = [System.Collections.Generic.List[object]]::new()
    $objects.Add([pscustomobject] @{ Definition = $Specification; Location = 'specification' })
    if ($Specification.Contains('Commands')) {
        foreach ($command in $Specification['Commands']) {
            $objects.Add([pscustomobject] @{ Definition = $command; Location = "command '$($command['Name'])'" })
            if ($command.Contains('Parameters')) {
                foreach ($parameter in $command['Parameters']) {
                    $objects.Add([pscustomobject] @{
                        Definition = $parameter
                        Location = "parameter '$($parameter['Name'])' on command '$($command['Name'])'"
                    })
                }
            }
        }
    }

    foreach ($object in $objects) {
        if (-not $object.Definition.Contains('Id')) { continue }
        $id = $object.Definition['Id']
        if ($id -isnot [string] -or $id -notmatch '^[A-Za-z0-9][A-Za-z0-9_.-]*$') {
            throw [System.IO.InvalidDataException]::new(
                "The 'Id' property for $($object.Location) must be a non-empty identifier containing only letters, numbers, dots, underscores, and hyphens."
            )
        }
        if (-not $identities.Add($id)) {
            throw [System.IO.InvalidDataException]::new(
                "The Id '$id' for $($object.Location) is defined more than once. Ids are case-insensitive across the specification."
            )
        }
    }
}
