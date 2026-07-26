function Assert-PSModuleMountMappings {
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
                if ($mapping['Type'] -ne 'Mount') {
                    continue
                }

                $target = $mapping['Target']
                if ($target -isnot [string] -or [string]::IsNullOrWhiteSpace($target)) {
                    throw [System.IO.InvalidDataException]::new(
                        "The 'Target' property for Mount mapping on parameter '$($parameter['Name'])' in command '$($command['Name'])' must be a non-empty string."
                    )
                }

                $access = $mapping['Access']
                if ($access -isnot [string] -or [string]::IsNullOrWhiteSpace($access)) {
                    throw [System.IO.InvalidDataException]::new(
                        "The 'Access' property for Mount mapping on parameter '$($parameter['Name'])' in command '$($command['Name'])' must be a non-empty string."
                    )
                }

                if ($access -notin @('ReadOnly', 'ReadWrite')) {
                    throw [System.IO.InvalidDataException]::new(
                        "The 'Access' property for Mount mapping on parameter '$($parameter['Name'])' in command '$($command['Name'])' must be 'ReadOnly' or 'ReadWrite'."
                    )
                }
            }
        }
    }
}
