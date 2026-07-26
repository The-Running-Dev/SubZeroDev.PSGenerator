function Assert-PSModuleNamedMappings {
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

            foreach ($mapping in $parameter['Mappings']) {
                if ($mapping['Type'] -notin @('Argument', 'Environment')) {
                    continue
                }

                $name = $mapping['Name']
                if ($name -isnot [string] -or [string]::IsNullOrWhiteSpace($name)) {
                    throw [System.IO.InvalidDataException]::new(
                        "The 'Name' property for $($mapping['Type']) mapping on parameter '$($parameter['Name'])' in command '$($command['Name'])' must be a non-empty string."
                    )
                }
            }
        }
    }
}
