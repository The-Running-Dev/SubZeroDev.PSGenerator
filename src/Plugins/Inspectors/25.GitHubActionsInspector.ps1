param ([Parameter(Mandatory)] [psobject] $Context)

$workflowRoot = Join-Path $Context.DirectoryPath '.github' 'workflows'
[object[]] $items = @()
if (Test-Path -LiteralPath $workflowRoot -PathType Container) {
    $items = @(Get-ChildItem -LiteralPath $workflowRoot -File | Where-Object { $_.Extension -in @('.yml', '.yaml') })
}
[Array]::Sort($items, [Collections.Generic.Comparer[object]]::Create({ param($a, $b) [StringComparer]::Ordinal.Compare($a.Name, $b.Name) }))

$workflows = foreach ($item in $items) {
    $name = $null
    $jobs = [Collections.Generic.List[string]]::new()
    $triggers = [Collections.Generic.List[string]]::new()
    $section = $null
    $sectionIndent = -1
    foreach ($line in Get-Content -LiteralPath $item.FullName) {
        if (-not $name -and $line -match '^name:\s*["'']?(?<Value>.*?)["'']?\s*$') { $name = $Matches.Value; continue }
        if ($line -match '^(?<Indent>\s*)on:\s*(?<Value>.*)$') {
            $section = 'on'; $sectionIndent = $Matches.Indent.Length
            $value = $Matches.Value.Trim().Trim('[', ']')
            if ($value) { foreach ($entry in $value -split ',') { $triggers.Add($entry.Trim()) } }
            continue
        }
        if ($line -match '^(?<Indent>\s*)jobs:\s*$') { $section = 'jobs'; $sectionIndent = $Matches.Indent.Length; continue }
        $indent = $line.Length - $line.TrimStart().Length
        if ($section -and $line.Trim() -and $indent -le $sectionIndent) { $section = $null }
        if ($section -eq 'on' -and $indent -eq ($sectionIndent + 2) -and $line -match '^\s+(?<Key>[A-Za-z0-9_-]+):') { $triggers.Add($Matches.Key) }
        if ($section -eq 'jobs' -and $indent -eq ($sectionIndent + 2) -and $line -match '^\s+(?<Key>[A-Za-z0-9_-]+):\s*$') { $jobs.Add($Matches.Key) }
    }
    [ordered]@{ Path = ".github/workflows/$($item.Name)"; Name = $name; Triggers = @($triggers); Jobs = @($jobs) }
}
$Context.Inspection['GitHubActions'] = @($workflows)
