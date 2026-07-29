param ([Parameter(Mandatory)] [psobject] $Context)

$visitedRealPaths = New-PSModuleInspectionVisitedPathSet
$items = @(Get-ChildItem -LiteralPath $Context.DirectoryPath -Recurse -File -Filter '*.json' -FollowSymlink:$false | Where-Object {
    Test-PSModuleInspectionPath -Context $Context -Path $_.FullName -VisitedRealPaths $visitedRealPaths
})
[Array]::Sort($items, [Collections.Generic.Comparer[object]]::Create({ param($a, $b) [StringComparer]::Ordinal.Compare($a.FullName, $b.FullName) }))

$schemas = foreach ($item in $items) {
    try {
        $data = Get-Content -LiteralPath $item.FullName -Raw | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        if ($item.Name -match '\.schema\.json$') {
            throw [System.IO.InvalidDataException]::new(
                "Configuration schema '$($item.FullName)' is not valid JSON.",
                $_.Exception
            )
        }
        continue
    }
    if ($item.Name -notmatch '\.schema\.json$' -and -not $data.PSObject.Properties['$schema']) { continue }
    [string[]] $properties = @(
        if ($null -ne $data.PSObject.Properties['properties'] -and $null -ne $data.properties) {
            $data.properties.PSObject.Properties | ForEach-Object Name
        }
    )
    [Array]::Sort($properties, [StringComparer]::Ordinal)
    [string[]] $required = @(
        if ($null -ne $data.PSObject.Properties['required'] -and $null -ne $data.required) {
            $data.required
        }
    )
    [Array]::Sort($required, [StringComparer]::Ordinal)
    [ordered]@{
        Path = ConvertTo-PSModuleInspectionRelativePath -Context $Context -Path $item.FullName
        Schema = if ($data.PSObject.Properties['$schema']) { $data.'$schema' } else { $null }
        Id = if ($data.PSObject.Properties['$id']) { $data.'$id' } else { $null }
        Title = if ($data.PSObject.Properties['title']) { $data.title } else { $null }
        Type = if ($data.PSObject.Properties['type']) { $data.type } else { $null }
        Required = $required
        Properties = $properties
    }
}
$Context.Inspection['ConfigurationSchemas'] = @($schemas)
