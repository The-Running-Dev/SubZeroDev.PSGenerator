param (
    [Parameter(Mandatory)]
    [psobject] $Context
)

$dockerfileItems = @(
    Get-ChildItem -LiteralPath $Context.DirectoryPath -File |
        Where-Object { $_.Name -eq 'Dockerfile' -or $_.Name -like 'Dockerfile.*' -or $_.Name -like '*.Dockerfile' }
)
[Array]::Sort(
    $dockerfileItems,
    [System.Collections.Generic.Comparer[object]]::Create({
        param ($left, $right)
        [System.StringComparer]::Ordinal.Compare($left.Name, $right.Name)
    })
)

$dockerfiles = @(
    $dockerfileItems | ForEach-Object {
            $stages = @(
                foreach ($line in Get-Content -LiteralPath $_.FullName) {
                    if ($line -match '^\s*FROM\s+(?:(?:--platform=(?<Platform>\S+))\s+)?(?<Image>\S+)(?:\s+AS\s+(?<Alias>\S+))?\s*(?:#.*)?$') {
                        [ordered] @{
                            Image    = $Matches.Image
                            Alias    = if ($Matches.ContainsKey('Alias')) { $Matches.Alias } else { $null }
                            Platform = if ($Matches.ContainsKey('Platform')) { $Matches.Platform } else { $null }
                        }
                    }
                }
            )

            [ordered] @{
                Path   = $_.Name
                Stages = $stages
            }
        }
)

$Context.Inspection['Dockerfiles'] = $dockerfiles
