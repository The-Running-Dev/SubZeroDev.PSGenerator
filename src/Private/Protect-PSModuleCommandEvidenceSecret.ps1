function Protect-PSModuleCommandEvidenceSecret {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [psobject] $Context
    )

    if (-not $Context.Inspection.Contains('CommandEvidence')) {
        return
    }

    $records = @($Context.Inspection['CommandEvidence'])

    # A parameter is secret the moment any source asserts Property = 'Secret',
    # Value = $true for its Subject - marking is per design's evidence model,
    # not precedence-ranked, so every source is checked regardless of Kind.
    $secretSubjects = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($record in $records) {
        if ($record.Property -eq 'Secret' -and $record.Value -eq $true) {
            [void] $secretSubjects.Add($record.Subject)
        }
    }

    if ($secretSubjects.Count -eq 0) {
        return
    }

    # 'Default' and 'ConfiguredValue' are this repository's two literal-value
    # property names - the only Property values an inspector may use to assert a
    # subject's actual default or configured value, per the design's "literal
    # default or configured value" redaction rule. Any other Property (Type,
    # Description, Mandatory, ...) never carries a literal that needs redacting.
    foreach ($record in $records) {
        if (-not $secretSubjects.Contains($record.Subject)) {
            continue
        }
        if ($record.Property -eq 'Default' -or $record.Property -eq 'ConfiguredValue') {
            $record.Value = '<redacted>'
        }
    }
}
