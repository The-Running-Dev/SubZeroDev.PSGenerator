function Assert-PSModuleParameterCompletions {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Specification
    )

    if (-not $Specification.Contains('Commands')) { return }
    foreach ($command in $Specification['Commands']) {
        if (-not $command.Contains('Parameters')) { continue }
        foreach ($parameter in $command['Parameters']) {
            if (-not $parameter.Contains('Completions')) { continue }
            $completions = $parameter['Completions']
            if ($completions -isnot [System.Array]) {
                throw [System.IO.InvalidDataException]::new(
                    "The 'Completions' property for parameter '$($parameter['Name'])' on command '$($command['Name'])' must be an array."
                )
            }

            $allValues = [System.Collections.Generic.HashSet[string]]::new(
                [System.StringComparer]::OrdinalIgnoreCase
            )
            for ($index = 0; $index -lt $completions.Count; $index++) {
                $completion = $completions[$index]
                if ($completion -isnot [System.Collections.IDictionary]) {
                    throw [System.IO.InvalidDataException]::new(
                        "Completion at index $index for parameter '$($parameter['Name'])' must be an object."
                    )
                }
                if ($completion['Type'] -ne 'Static') {
                    throw [System.IO.InvalidDataException]::new(
                        "Completion type '$($completion['Type'])' for parameter '$($parameter['Name'])' is not supported."
                    )
                }
                $values = $completion['Values']
                if ($values -isnot [System.Array] -or $values.Count -eq 0 -or
                    @($values | Where-Object { $_ -isnot [string] -or [string]::IsNullOrWhiteSpace($_) }).Count -gt 0) {
                    throw [System.IO.InvalidDataException]::new(
                        "Static completion for parameter '$($parameter['Name'])' must define a non-empty string array 'Values'."
                    )
                }
                foreach ($value in $values) {
                    if (-not $allValues.Add($value)) {
                        throw [System.IO.InvalidDataException]::new(
                            "Completion value '$value' for parameter '$($parameter['Name'])' is defined more than once. Values are case-insensitive."
                        )
                    }
                }
            }
        }
    }
}
