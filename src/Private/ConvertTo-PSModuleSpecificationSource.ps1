function ConvertTo-PSModuleSpecificationSource {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Specification
    )

    function ConvertValue {
        param ([object] $Value, [int] $Indent = 0)

        $padding = ' ' * $Indent
        if ($null -eq $Value) { return '$null' }
        if ($Value -is [bool]) { return ('$' + $Value.ToString().ToLowerInvariant()) }
        if ($Value -is [string]) { return "'$($Value.Replace("'", "''"))'" }
        if ($Value -is [System.Collections.IDictionary]) {
            $lines = [System.Collections.Generic.List[string]]::new()
            $lines.Add('@{')
            foreach ($key in $Value.Keys) {
                $rendered = ConvertValue -Value $Value[$key] -Indent ($Indent + 4)
                $renderedLines = @($rendered -split '\r?\n')
                $lines.Add("$(' ' * ($Indent + 4))$key = $($renderedLines[0])")
                foreach ($line in $renderedLines | Select-Object -Skip 1) { $lines.Add($line) }
            }
            $lines.Add("$padding}")
            return $lines -join [Environment]::NewLine
        }
        if ($Value -is [System.Collections.IEnumerable]) {
            $values = @($Value)
            if ($values.Count -eq 0) { return '@()' }
            $lines = [System.Collections.Generic.List[string]]::new()
            $lines.Add('@(')
            foreach ($item in $values) {
                $rendered = ConvertValue -Value $item -Indent ($Indent + 4)
                foreach ($line in @($rendered -split '\r?\n')) { $lines.Add($line) }
            }
            $lines.Add("$padding)")
            return $lines -join [Environment]::NewLine
        }
        return [string] $Value
    }

    (ConvertValue -Value $Specification) + [Environment]::NewLine
}
