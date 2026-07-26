param (
    [Parameter(Mandatory)]
    [psobject] $Context
)

$readmeItems = @(
    Get-ChildItem -LiteralPath $Context.DirectoryPath -File |
        Where-Object { $_.Name -match '^(?i:readme)(?:\.(?:md|markdown|txt))?$' }
)
[Array]::Sort(
    $readmeItems,
    [System.Collections.Generic.Comparer[object]]::Create({
        param ($left, $right)
        [System.StringComparer]::Ordinal.Compare($left.Name, $right.Name)
    })
)

$readmes = @(
    foreach ($readmeItem in $readmeItems) {
        $headings = [System.Collections.Generic.List[object]]::new()
        $codeLanguages = [System.Collections.Generic.List[object]]::new()
        $title = $null
        $insideFence = $false
        $fenceCharacter = $null

        foreach ($line in Get-Content -LiteralPath $readmeItem.FullName) {
            if ($line -match '^\s*(?<Fence>`{3,}|~{3,})\s*(?<Language>[A-Za-z0-9_+.-]*)') {
                $currentCharacter = $Matches.Fence.Substring(0, 1)
                if (-not $insideFence) {
                    $insideFence = $true
                    $fenceCharacter = $currentCharacter
                    $language = if ($Matches.Language) { $Matches.Language } else { $null }
                    $codeLanguages.Add($language)
                }
                elseif ($currentCharacter -eq $fenceCharacter) {
                    $insideFence = $false
                    $fenceCharacter = $null
                }
                continue
            }

            if (-not $insideFence -and $line -match '^\s*(?<Marker>#{1,6})\s+(?<Text>.+?)\s*#*\s*$') {
                $heading = [ordered] @{
                    Level = $Matches.Marker.Length
                    Text  = $Matches.Text
                }
                $headings.Add($heading)
                if ($null -eq $title -and $heading.Level -eq 1) {
                    $title = $heading.Text
                }
            }
            elseif ($null -eq $title -and $readmeItem.Extension -eq '.txt' -and $line.Trim()) {
                $title = $line.Trim()
            }
        }

        [ordered] @{
            Path          = $readmeItem.Name
            Title         = $title
            Headings      = @($headings)
            CodeLanguages = @($codeLanguages)
        }
    }
)

$Context.Inspection['Readmes'] = $readmes
