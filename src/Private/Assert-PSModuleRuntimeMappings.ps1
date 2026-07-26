function Assert-PSModuleRuntimeMappings {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Specification
    )

    if (-not $Specification.Contains('Commands')) { return }

    foreach ($command in $Specification['Commands']) {
        if (-not $command.Contains('Parameters')) { continue }
        $workingDirectoryCount = 0
        foreach ($parameter in $command['Parameters']) {
            if (-not $parameter.Contains('Mappings')) { continue }
            foreach ($mapping in $parameter['Mappings']) {
                switch ($mapping['Type']) {
                    'Device' {
                        if ($parameter['Type'] -notin @('string', 'FileInfo', 'System.IO.FileInfo')) {
                            throw [System.IO.InvalidDataException]::new(
                                "Device mapping parameter '$($parameter['Name'])' on command '$($command['Name'])' must use type 'string' or 'FileInfo'."
                            )
                        }
                        if ($mapping.Contains('Target')) {
                            $target = $mapping['Target']
                            if ($target -isnot [string] -or $target -notmatch '^/[^:,]+$') {
                                throw [System.IO.InvalidDataException]::new(
                                    "The 'Target' property for Device mapping on parameter '$($parameter['Name'])' must be an absolute container path without colons or commas."
                                )
                            }
                        }
                        if ($mapping.Contains('Permissions') -and $mapping['Permissions'] -notmatch '^(?=.+$)r?w?m?$') {
                            throw [System.IO.InvalidDataException]::new(
                                "The 'Permissions' property for Device mapping on parameter '$($parameter['Name'])' must be an ordered combination of 'r', 'w', and 'm'."
                            )
                        }
                    }
                    'Gpu' {
                        if ($parameter['Type'] -ne 'string') {
                            throw [System.IO.InvalidDataException]::new(
                                "Gpu mapping parameter '$($parameter['Name'])' on command '$($command['Name'])' must use type 'string'."
                            )
                        }
                    }
                    'ResourceLimit' {
                        $resource = $mapping['Resource']
                        if ($resource -notin @('Memory', 'Cpus')) {
                            throw [System.IO.InvalidDataException]::new(
                                "The 'Resource' property for ResourceLimit mapping on parameter '$($parameter['Name'])' must be 'Memory' or 'Cpus'."
                            )
                        }
                        if ($resource -eq 'Memory' -and $parameter['Type'] -ne 'string') {
                            throw [System.IO.InvalidDataException]::new(
                                "Memory ResourceLimit mapping parameter '$($parameter['Name'])' must use type 'string'."
                            )
                        }
                        if ($resource -eq 'Cpus' -and $parameter['Type'] -notin @('int', 'long', 'double', 'decimal')) {
                            throw [System.IO.InvalidDataException]::new(
                                "Cpus ResourceLimit mapping parameter '$($parameter['Name'])' must use a numeric type."
                            )
                        }
                    }
                    'Secret' {
                        if ($parameter['Type'] -notin @('string', 'FileInfo', 'System.IO.FileInfo')) {
                            throw [System.IO.InvalidDataException]::new(
                                "Secret mapping parameter '$($parameter['Name'])' on command '$($command['Name'])' must use type 'string' or 'FileInfo'."
                            )
                        }
                        $name = $mapping['Name']
                        if ($name -isnot [string] -or $name -notmatch '^[A-Za-z0-9][A-Za-z0-9_.-]*$') {
                            throw [System.IO.InvalidDataException]::new(
                                "The 'Name' property for Secret mapping on parameter '$($parameter['Name'])' must be a safe non-empty file name."
                            )
                        }
                        if ($mapping.Contains('Target')) {
                            $target = $mapping['Target']
                            if ($target -isnot [string] -or $target -notmatch '^/[^,]+$') {
                                throw [System.IO.InvalidDataException]::new(
                                    "The 'Target' property for Secret mapping on parameter '$($parameter['Name'])' must be an absolute container path without commas."
                                )
                            }
                        }
                    }
                    'WorkingDirectory' {
                        $workingDirectoryCount++
                        if ($parameter['Type'] -ne 'string') {
                            throw [System.IO.InvalidDataException]::new(
                                "WorkingDirectory mapping parameter '$($parameter['Name'])' on command '$($command['Name'])' must use type 'string'."
                            )
                        }
                    }
                    'Port' {
                        if ($parameter['Type'] -notin @('int', 'long', 'System.Int32', 'System.Int64')) {
                            throw [System.IO.InvalidDataException]::new(
                                "Port mapping parameter '$($parameter['Name'])' on command '$($command['Name'])' must use an integer type."
                            )
                        }
                        $containerPort = $mapping['ContainerPort']
                        if ($containerPort -isnot [int] -or $containerPort -lt 1 -or $containerPort -gt 65535) {
                            throw [System.IO.InvalidDataException]::new(
                                "The 'ContainerPort' property for Port mapping on parameter '$($parameter['Name'])' must be an integer from 1 through 65535."
                            )
                        }
                        if ($mapping.Contains('Protocol') -and $mapping['Protocol'] -notin @('tcp', 'udp')) {
                            throw [System.IO.InvalidDataException]::new(
                                "The 'Protocol' property for Port mapping on parameter '$($parameter['Name'])' must be 'tcp' or 'udp'."
                            )
                        }
                    }
                    'Volume' {
                        if ($parameter['Type'] -ne 'string') {
                            throw [System.IO.InvalidDataException]::new(
                                "Volume mapping parameter '$($parameter['Name'])' on command '$($command['Name'])' must use type 'string'."
                            )
                        }
                        $target = $mapping['Target']
                        if ($target -isnot [string] -or $target -notmatch '^/[^,]+$') {
                            throw [System.IO.InvalidDataException]::new(
                                "The 'Target' property for Volume mapping on parameter '$($parameter['Name'])' must be an absolute container path without commas."
                            )
                        }
                        if ($mapping['Access'] -notin @('ReadOnly', 'ReadWrite')) {
                            throw [System.IO.InvalidDataException]::new(
                                "The 'Access' property for Volume mapping on parameter '$($parameter['Name'])' must be 'ReadOnly' or 'ReadWrite'."
                            )
                        }
                    }
                    'RuntimeOption' {
                        $name = $mapping['Name']
                        if ($name -isnot [string] -or $name -notmatch '^--[a-z0-9][a-z0-9-]*$') {
                            throw [System.IO.InvalidDataException]::new(
                                "The 'Name' property for RuntimeOption mapping on parameter '$($parameter['Name'])' must be a lowercase long Docker option beginning with '--'."
                            )
                        }
                    }
                }
            }
        }
        if ($workingDirectoryCount -gt 1) {
            throw [System.IO.InvalidDataException]::new(
                "Command '$($command['Name'])' may define at most one WorkingDirectory mapping."
            )
        }
    }
}
