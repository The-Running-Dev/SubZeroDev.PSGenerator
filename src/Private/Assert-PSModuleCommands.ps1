function Assert-PSModuleCommands {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Specification
    )

    if (-not $Specification.Contains('Commands')) {
        return
    }

    $commands = $Specification['Commands']
    if ($commands -isnot [System.Array]) {
        throw [System.IO.InvalidDataException]::new(
            "The 'Commands' property must be an array."
        )
    }

    $commandNames = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )

    for ($index = 0; $index -lt $commands.Count; $index++) {
        $command = $commands[$index]
        if ($command -isnot [System.Collections.IDictionary]) {
            throw [System.IO.InvalidDataException]::new(
                "Command at index $index must be an object."
            )
        }

        $name = $command['Name']
        if ($name -isnot [string] -or [string]::IsNullOrWhiteSpace($name)) {
            throw [System.IO.InvalidDataException]::new(
                "Command at index $index must define a non-empty string 'Name'."
            )
        }

        if ($name -notmatch '^[A-Za-z][A-Za-z0-9]*-[A-Za-z][A-Za-z0-9]*$') {
            throw [System.IO.InvalidDataException]::new(
                "Command name '$name' must use PowerShell Verb-Noun syntax with letters and numbers only."
            )
        }

        foreach ($propertyName in @('Synopsis', 'Description', 'Notes')) {
            if ($command.Contains($propertyName) -and
                ($command[$propertyName] -isnot [string] -or [string]::IsNullOrWhiteSpace($command[$propertyName]))) {
                throw [System.IO.InvalidDataException]::new(
                    "The '$propertyName' property for command '$name' must be a non-empty string."
                )
            }
        }

        if ($command.Contains('Examples')) {
            $examples = $command['Examples']
            if ($examples -isnot [System.Array]) {
                throw [System.IO.InvalidDataException]::new(
                    "The 'Examples' property for command '$name' must be an array."
                )
            }

            for ($exampleIndex = 0; $exampleIndex -lt $examples.Count; $exampleIndex++) {
                $example = $examples[$exampleIndex]
                if ($example -isnot [System.Collections.IDictionary]) {
                    throw [System.IO.InvalidDataException]::new(
                        "Example at index $exampleIndex for command '$name' must be an object."
                    )
                }
                foreach ($propertyName in @('Code', 'Description')) {
                    if (-not $example.Contains($propertyName) -or
                        $example[$propertyName] -isnot [string] -or
                        [string]::IsNullOrWhiteSpace($example[$propertyName])) {
                        throw [System.IO.InvalidDataException]::new(
                            "The '$propertyName' property for example at index $exampleIndex on command '$name' must be a non-empty string."
                        )
                    }
                }
            }
        }

        if (-not $commandNames.Add($name)) {
            throw [System.IO.InvalidDataException]::new(
                "Command name '$name' is defined more than once. Command names are case-insensitive."
            )
        }
    }
}
