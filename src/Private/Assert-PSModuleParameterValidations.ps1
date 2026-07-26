function Assert-PSModuleParameterValidations {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Specification
    )

    if (-not $Specification.Contains('Commands')) {
        return
    }

    foreach ($command in $Specification['Commands']) {
        if (-not $command.Contains('Parameters')) { continue }
        foreach ($parameter in $command['Parameters']) {
            if (-not $parameter.Contains('Validations')) { continue }
            $validations = $parameter['Validations']
            if ($validations -isnot [System.Array]) {
                throw [System.IO.InvalidDataException]::new(
                    "The 'Validations' property for parameter '$($parameter['Name'])' on command '$($command['Name'])' must be an array."
                )
            }

            for ($index = 0; $index -lt $validations.Count; $index++) {
                $validation = $validations[$index]
                if ($validation -isnot [System.Collections.IDictionary]) {
                    throw [System.IO.InvalidDataException]::new("Validation at index $index for parameter '$($parameter['Name'])' must be an object.")
                }
                $type = $validation['Type']
                if ($type -notin @('ValidateSet', 'ValidateRange', 'ValidatePattern')) {
                    throw [System.IO.InvalidDataException]::new(
                        "Validation type '$type' for parameter '$($parameter['Name'])' is not supported."
                    )
                }

                switch ($type) {
                    'ValidateSet' {
                        $values = $validation['Values']
                        if ($values -isnot [System.Array] -or $values.Count -eq 0 -or @($values | Where-Object { $_ -isnot [string] -or [string]::IsNullOrWhiteSpace($_) }).Count -gt 0) {
                            throw [System.IO.InvalidDataException]::new("ValidateSet for parameter '$($parameter['Name'])' must define a non-empty string array 'Values'.")
                        }
                    }
                    'ValidateRange' {
                        $minimum = $validation['Minimum']
                        $maximum = $validation['Maximum']
                        $numericTypes = @([byte], [short], [int], [long], [float], [double], [decimal])
                        if ($null -eq $minimum -or $null -eq $maximum -or $minimum.GetType() -notin $numericTypes -or $maximum.GetType() -notin $numericTypes -or [decimal] $minimum -gt [decimal] $maximum) {
                            throw [System.IO.InvalidDataException]::new("ValidateRange for parameter '$($parameter['Name'])' must define numeric 'Minimum' and 'Maximum' values in ascending order.")
                        }
                    }
                    'ValidatePattern' {
                        $pattern = $validation['Pattern']
                        if ($pattern -isnot [string] -or [string]::IsNullOrWhiteSpace($pattern)) {
                            throw [System.IO.InvalidDataException]::new("ValidatePattern for parameter '$($parameter['Name'])' must define a non-empty string 'Pattern'.")
                        }
                        try { $null = [regex]::new($pattern) }
                        catch { throw [System.IO.InvalidDataException]::new("ValidatePattern for parameter '$($parameter['Name'])' contains an invalid regular expression.", $_.Exception) }
                    }
                }
            }
        }
    }
}
