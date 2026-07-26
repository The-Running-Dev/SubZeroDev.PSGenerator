param (
    [Parameter(Mandatory)]
    [psobject] $Context
)

function ConvertFrom-ComposeScalar {
    param ([string] $Value)

    $result = $Value.Trim()
    if ($result.Length -ge 2 -and (
        ($result.StartsWith("'") -and $result.EndsWith("'")) -or
        ($result.StartsWith('"') -and $result.EndsWith('"'))
    )) {
        return $result.Substring(1, $result.Length - 2)
    }

    return $result
}

$composeNames = @('compose.yaml', 'compose.yml', 'docker-compose.yaml', 'docker-compose.yml')
$composeItems = @(
    Get-ChildItem -LiteralPath $Context.DirectoryPath -File |
        Where-Object { $_.Name -in $composeNames }
)
[Array]::Sort(
    $composeItems,
    [System.Collections.Generic.Comparer[object]]::Create({
        param ($left, $right)
        [System.StringComparer]::Ordinal.Compare($left.Name, $right.Name)
    })
)

$composeFiles = @(
    foreach ($composeItem in $composeItems) {
        $services = [System.Collections.Generic.List[object]]::new()
        $servicesIndent = -1
        $serviceIndent = -1
        $currentService = $null
        $nestedProperty = $null
        $nestedIndent = -1

        foreach ($line in Get-Content -LiteralPath $composeItem.FullName) {
            if ($line -match '^\s*(?:#.*)?$') { continue }

            $indent = $line.Length - $line.TrimStart().Length
            $content = $line.Trim()

            if ($servicesIndent -lt 0) {
                if ($content -eq 'services:') { $servicesIndent = $indent }
                continue
            }

            if ($indent -le $servicesIndent) { break }

            if ($line -match '^\s*(?<Name>[A-Za-z0-9_.-]+):\s*(?:#.*)?$' -and (
                $serviceIndent -lt 0 -or $indent -eq $serviceIndent
            )) {
                $serviceIndent = $indent
                $currentService = [ordered] @{
                    Name  = $Matches.Name
                    Image = $null
                    Build = $null
                    Ports = [System.Collections.Generic.List[string]]::new()
                }
                $services.Add($currentService)
                $nestedProperty = $null
                continue
            }

            if ($null -eq $currentService -or $indent -le $serviceIndent) { continue }

            if ($nestedProperty -and $indent -le $nestedIndent) {
                $nestedProperty = $null
            }

            if ($nestedProperty -eq 'Build' -and $indent -gt $nestedIndent -and
                $content -match '^(?<Key>context|dockerfile):\s*(?<Value>.+)$') {
                $currentService.Build[$Matches.Key] = ConvertFrom-ComposeScalar $Matches.Value
                continue
            }

            if ($nestedProperty -eq 'Ports' -and $indent -gt $nestedIndent -and
                $content -match '^-\s*(?<Value>.+)$') {
                $currentService.Ports.Add((ConvertFrom-ComposeScalar $Matches.Value))
                continue
            }

            if ($content -match '^image:\s*(?<Value>.+)$') {
                $currentService.Image = ConvertFrom-ComposeScalar $Matches.Value
            }
            elseif ($content -match '^build:\s*(?<Value>.+)$') {
                $currentService.Build = [ordered] @{ Context = ConvertFrom-ComposeScalar $Matches.Value; Dockerfile = $null }
            }
            elseif ($content -eq 'build:') {
                $currentService.Build = [ordered] @{ Context = $null; Dockerfile = $null }
                $nestedProperty = 'Build'
                $nestedIndent = $indent
            }
            elseif ($content -eq 'ports:') {
                $nestedProperty = 'Ports'
                $nestedIndent = $indent
            }
        }

        [ordered] @{
            Path     = $composeItem.Name
            Services = @($services)
        }
    }
)

$Context.Inspection['ComposeFiles'] = $composeFiles
