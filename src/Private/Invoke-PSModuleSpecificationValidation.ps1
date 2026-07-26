function Invoke-PSModuleSpecificationValidation {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Specification,

        [Parameter(Mandatory)]
        [string] $SpecificationPath
    )

    try {
        Assert-PSModuleSpecification -Specification $Specification
    }
    catch {
        $sourcePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($SpecificationPath)
        $objectIds = [System.Collections.Generic.List[string]]::new()

        foreach ($command in @($Specification['Commands'])) {
            if ($command -isnot [System.Collections.IDictionary]) { continue }

            $commandName = $command['Name']
            if ($command.Contains('Id') -and $commandName -and $_.Exception.Message.Contains("'$commandName'")) {
                $objectIds.Add([string] $command['Id'])
            }

            foreach ($parameter in @($command['Parameters'])) {
                if ($parameter -isnot [System.Collections.IDictionary]) { continue }
                $parameterName = $parameter['Name']
                if ($parameter.Contains('Id') -and $parameterName -and $_.Exception.Message.Contains("'$parameterName'")) {
                    $objectIds.Add([string] $parameter['Id'])
                }
            }
        }

        $context = "Source: '$sourcePath'"
        $uniqueIds = @($objectIds | Select-Object -Unique)
        if ($uniqueIds.Count -gt 0) {
            $context += "; Object Id: '$($uniqueIds -join "', '")'"
        }

        $exception = [System.IO.InvalidDataException]::new(
            "$($_.Exception.Message) [$context]",
            $_.Exception
        )
        $exception.Data['PSModule.PreserveType'] = $true
        throw $exception
    }
}
