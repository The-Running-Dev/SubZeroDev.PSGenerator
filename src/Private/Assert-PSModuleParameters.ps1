function Assert-PSModuleParameters {
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

        $parameters = $command['Parameters']
        if ($parameters -isnot [System.Array]) {
            throw [System.IO.InvalidDataException]::new(
                "The 'Parameters' property for command '$($command['Name'])' must be an array."
            )
        }

        $parameterNames = [System.Collections.Generic.HashSet[string]]::new(
            [System.StringComparer]::OrdinalIgnoreCase
        )

        for ($index = 0; $index -lt $parameters.Count; $index++) {
            $parameter = $parameters[$index]
            if ($parameter -isnot [System.Collections.IDictionary]) {
                throw [System.IO.InvalidDataException]::new(
                    "Parameter at index $index for command '$($command['Name'])' must be an object."
                )
            }

            $name = $parameter['Name']
            if ($name -isnot [string] -or [string]::IsNullOrWhiteSpace($name)) {
                throw [System.IO.InvalidDataException]::new(
                    "Parameter at index $index for command '$($command['Name'])' must define a non-empty string 'Name'."
                )
            }

            if ($name -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') {
                throw [System.IO.InvalidDataException]::new(
                    "Parameter name '$name' on command '$($command['Name'])' is not a valid PowerShell identifier."
                )
            }

            $type = $parameter['Type']
            if ($type -isnot [string] -or [string]::IsNullOrWhiteSpace($type)) {
                throw [System.IO.InvalidDataException]::new(
                    "Parameter '$name' for command '$($command['Name'])' must define a non-empty string 'Type'."
                )
            }

            if ($type -notmatch '^[A-Za-z_][A-Za-z0-9_.]*(?:\[\])?$') {
                throw [System.IO.InvalidDataException]::new(
                    "Parameter type '$type' for '$name' on command '$($command['Name'])' is not a supported PowerShell type name."
                )
            }

            if ($parameter.Contains('Mandatory') -and $parameter['Mandatory'] -isnot [bool]) {
                throw [System.IO.InvalidDataException]::new(
                    "The 'Mandatory' property for parameter '$name' on command '$($command['Name'])' must be Boolean."
                )
            }

            if ($parameter.Contains('Description')) {
                $description = $parameter['Description']
                if ($description -isnot [string] -or [string]::IsNullOrWhiteSpace($description)) {
                    throw [System.IO.InvalidDataException]::new(
                        "The 'Description' property for parameter '$name' on command '$($command['Name'])' must be a non-empty string."
                    )
                }
            }

            if (-not $parameterNames.Add($name)) {
                throw [System.IO.InvalidDataException]::new(
                    "Parameter name '$name' is defined more than once on command '$($command['Name'])'. Parameter names are case-insensitive."
                )
            }
        }
    }
}
