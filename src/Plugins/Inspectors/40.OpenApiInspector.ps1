param ([Parameter(Mandatory)] [psobject] $Context)

$names = '^(?i:(?:openapi|swagger).*)\.(?:json|ya?ml)$'
$items = @(Get-ChildItem -LiteralPath $Context.RepositoryPath -Recurse -File | Where-Object {
    $_.Name -match $names -and
    (Test-PSModuleInspectionPath -Context $Context -Path $_.FullName)
})
[Array]::Sort($items, [Collections.Generic.Comparer[object]]::Create({ param($a, $b) [StringComparer]::Ordinal.Compare($a.FullName, $b.FullName) }))

$documents = foreach ($item in $items) {
    $version = $null; $title = $null; $apiVersion = $null; $paths = @()
    if ($item.Extension -eq '.json') {
        $data = Get-Content -LiteralPath $item.FullName -Raw | ConvertFrom-Json
        if ($data.PSObject.Properties['openapi']) { $version = $data.openapi } elseif ($data.PSObject.Properties['swagger']) { $version = $data.swagger }
        if ($data.PSObject.Properties['info']) {
            if ($data.info.PSObject.Properties['title']) { $title = $data.info.title }
            if ($data.info.PSObject.Properties['version']) { $apiVersion = $data.info.version }
        }
        if ($data.PSObject.Properties['paths']) { $paths = @($data.paths.PSObject.Properties.Name) }
    }
    else {
        $section = $null; $sectionIndent = -1; $inInfo = $false
        foreach ($line in Get-Content -LiteralPath $item.FullName) {
            if ($line -match '^\s*(?:openapi|swagger):\s*["'']?(?<Value>[^"''#]+)') { $version = $Matches.Value.Trim(); continue }
            if ($line -match '^(?<Indent>\s*)info:\s*$') { $inInfo = $true; $sectionIndent = $Matches.Indent.Length; continue }
            if ($line -match '^(?<Indent>\s*)paths:\s*$') { $section = 'paths'; $inInfo = $false; $sectionIndent = $Matches.Indent.Length; continue }
            $indent = $line.Length - $line.TrimStart().Length
            if ($inInfo -and $indent -gt $sectionIndent -and $line -match '^\s*title:\s*["'']?(?<Value>.*?)["'']?\s*$') { $title = $Matches.Value }
            if ($inInfo -and $indent -gt $sectionIndent -and $line -match '^\s*version:\s*["'']?(?<Value>.*?)["'']?\s*$') { $apiVersion = $Matches.Value }
            if ($section -eq 'paths' -and $indent -gt $sectionIndent -and $line -match '^\s*(?<Path>/[^:]+):') { $paths += $Matches.Path }
        }
    }
    [Array]::Sort($paths, [StringComparer]::Ordinal)
    [ordered]@{ Path = [IO.Path]::GetRelativePath($Context.RepositoryPath, $item.FullName).Replace('\', '/'); SpecificationVersion = $version; Title = $title; ApiVersion = $apiVersion; Paths = $paths }
}
$Context.Inspection['OpenApiDocuments'] = @($documents)
