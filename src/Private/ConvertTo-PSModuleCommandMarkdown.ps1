function ConvertTo-PSModuleCommandMarkdown {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [psobject] $Command
    )

    $synopsis = if (-not [string]::IsNullOrWhiteSpace($Command.Synopsis)) {
        $Command.Synopsis
    }
    elseif (-not [string]::IsNullOrWhiteSpace($Command.Description)) {
        $Command.Description
    }
    else {
        "Runs the $($Command.Name) container command."
    }

    $syntaxParts = [System.Collections.Generic.List[string]]::new()
    $syntaxParts.Add($Command.Name)
    foreach ($parameter in $Command.Parameters) {
        $part = "-$($parameter.Name) <$($parameter.Type)>"
        if (-not $parameter.Mandatory) { $part = "[$part]" }
        $syntaxParts.Add($part)
    }
    $syntaxParts.Add('[<CommonParameters>]')

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("# $($Command.Name)")
    $lines.Add('')
    $lines.Add($synopsis)
    $lines.Add('')
    $lines.Add('## Syntax')
    $lines.Add('')
    $lines.Add('```powershell')
    $lines.Add($syntaxParts -join ' ')
    $lines.Add('```')

    if (-not [string]::IsNullOrWhiteSpace($Command.Description) -and $Command.Description -ne $synopsis) {
        $lines.Add('')
        $lines.Add('## Description')
        $lines.Add('')
        $lines.Add($Command.Description)
    }

    if ($Command.Parameters.Count -gt 0) {
        $lines.Add('')
        $lines.Add('## Parameters')
        foreach ($parameter in $Command.Parameters) {
            $lines.Add('')
            $lines.Add("### ``-$($parameter.Name)``")
            $lines.Add('')
            $lines.Add("Type: ``$($parameter.Type)``  ")
            $lines.Add("Required: $(if ($parameter.Mandatory) { 'Yes' } else { 'No' })")
            if (-not [string]::IsNullOrWhiteSpace($parameter.Description)) {
                $lines.Add('')
                $lines.Add($parameter.Description)
            }
        }
    }

    if ($Command.Examples.Count -gt 0) {
        $lines.Add('')
        $lines.Add('## Examples')
        for ($index = 0; $index -lt $Command.Examples.Count; $index++) {
            $example = $Command.Examples[$index]
            $lines.Add('')
            $lines.Add("### Example $($index + 1)")
            $lines.Add('')
            foreach ($codeLine in $example.Code -split "`r?`n") {
                $lines.Add("    $codeLine")
            }
            $lines.Add('')
            $lines.Add($example.Description)
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($Command.Notes)) {
        $lines.Add('')
        $lines.Add('## Notes')
        $lines.Add('')
        $lines.Add($Command.Notes)
    }

    return ($lines -join "`n") + "`n"
}
