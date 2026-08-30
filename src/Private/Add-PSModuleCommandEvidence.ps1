function Add-PSModuleCommandEvidence {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [psobject] $Context,

        [Parameter(Mandatory)]
        [ValidateSet('Project', 'NukeSchema', 'NukeConfig', 'CSharp', 'GeneratedMetadata', 'PowerShell')]
        [string] $Kind,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $SourcePath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Subject,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Property,

        [Parameter()]
        $Value,

        [Parameter(Mandatory)]
        [ValidateSet('Explicit', 'Strong', 'Heuristic')]
        [string] $Confidence,

        [Parameter()]
        [switch] $Authoritative,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Inspector
    )

    if (-not $Context.Inspection.Contains('CommandEvidence')) {
        $Context.Inspection['CommandEvidence'] = [System.Collections.Generic.List[object]]::new()
    }

    # A collection value is sorted and deduplicated ordinal-ignore-case, per
    # design/planning/build-agent-evidence-design.md's evidence model. The first
    # occurrence's spelling is kept; reconciling spelling across evidence records
    # from different sources is precedence-aware merge work, not record creation.
    $normalizedValue = $Value
    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
        $seen = [System.Collections.Generic.Dictionary[string, string]]::new(
            [System.StringComparer]::OrdinalIgnoreCase
        )
        foreach ($item in $Value) {
            $key = [string] $item
            if (-not $seen.ContainsKey($key)) {
                $seen[$key] = $key
            }
        }
        $normalizedValue = @($seen.Values)
        [Array]::Sort($normalizedValue, [System.StringComparer]::OrdinalIgnoreCase)
    }

    $evidence = [pscustomobject] @{
        PSTypeName    = 'SubZeroDev.PSGenerator.CommandEvidence'
        Kind          = $Kind
        SourcePath    = $SourcePath
        Subject       = $Subject
        Property      = $Property
        Value         = $normalizedValue
        Confidence    = $Confidence
        Authoritative = [bool] $Authoritative
        Inspector     = $Inspector
    }

    $Context.Inspection['CommandEvidence'].Add($evidence)
    $evidence
}
