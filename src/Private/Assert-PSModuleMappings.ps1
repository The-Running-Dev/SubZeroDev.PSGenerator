function Assert-PSModuleMappings {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Specification
    )

    if (-not $Specification.Contains('Commands')) {
        return
    }

    foreach ($command in $Specification['Commands']) {
        if (-not $command.Contains('Parameters')) {
            continue
        }

        foreach ($parameter in $command['Parameters']) {
            if (-not $parameter.Contains('Mappings')) {
                continue
            }

            $mappings = $parameter['Mappings']
            if ($mappings -isnot [System.Array]) {
                throw [System.IO.InvalidDataException]::new(
                    "The 'Mappings' property for parameter '$($parameter['Name'])' on command '$($command['Name'])' must be an array."
                )
            }

            for ($index = 0; $index -lt $mappings.Count; $index++) {
                $mapping = $mappings[$index]
                if ($mapping -isnot [System.Collections.IDictionary]) {
                    throw [System.IO.InvalidDataException]::new(
                        "Mapping at index $index for parameter '$($parameter['Name'])' on command '$($command['Name'])' must be an object."
                    )
                }

                $type = $mapping['Type']
                if ($type -isnot [string] -or [string]::IsNullOrWhiteSpace($type)) {
                    throw [System.IO.InvalidDataException]::new(
                        "Mapping at index $index for parameter '$($parameter['Name'])' on command '$($command['Name'])' must define a non-empty string 'Type'."
                    )
                }
                if ($type -notin @('Argument', 'Device', 'Environment', 'Gpu', 'Mount', 'Port', 'ResourceLimit', 'RuntimeOption', 'Secret', 'Volume', 'WorkingDirectory')) {
                    throw [System.IO.InvalidDataException]::new(
                        "Mapping type '$type' for parameter '$($parameter['Name'])' on command '$($command['Name'])' is not supported."
                    )
                }
            }
        }
    }
}
