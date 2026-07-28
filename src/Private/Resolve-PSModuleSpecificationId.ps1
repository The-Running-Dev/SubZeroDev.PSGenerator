function Resolve-PSModuleSpecificationId {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $SpecificationPath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $InferredId
    )

    # An existing specification already carries this directory's identity. Reuse it
    # so refreshing stays byte-identical and a generated module keeps matching its
    # own earlier build.
    if (Test-Path -LiteralPath $SpecificationPath -PathType Leaf) {
        $existingDefinition = $null
        try {
            $existingDefinition = Import-PowerShellDataFile `
                -LiteralPath $SpecificationPath `
                -ErrorAction Stop
        }
        catch {
            $existingDefinition = $null
        }

        if ($existingDefinition -is [System.Collections.IDictionary] -and
            $existingDefinition.Contains('Id')) {
            $existingId = [string] $existingDefinition['Id']
            if ($existingId -match '^[A-Za-z0-9._-]+$') {
                return $existingId
            }
        }
    }

    # The inferred prefix is derived from the module name alone, so it cannot tell
    # two directories with the same name apart. A durable random suffix minted once
    # per specification supplies the missing identity without embedding a
    # source-directory path or any other machine-specific value.
    '{0}.{1}' -f $InferredId, [guid]::NewGuid().ToString('n')
}
