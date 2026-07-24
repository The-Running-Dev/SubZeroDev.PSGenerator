param ([Parameter(Mandatory)] [psobject] $Context)

function Get-JsonProperty {
    param ([object] $Object, [string] $Name)
    if ($null -ne $Object -and $Object.PSObject.Properties[$Name]) { return $Object.$Name }
    return $null
}

function Resolve-SchemaDefinition {
    param ([object] $Schema, [object] $Node)
    $reference = Get-JsonProperty -Object $Node -Name '$ref'
    if ($reference -and $reference -match '^#/definitions/(?<Name>[^/]+)$') {
        return Get-JsonProperty -Object $Schema.definitions -Name $Matches.Name
    }
    return $Node
}

$nukeDirectory = Join-Path $Context.RepositoryPath '.nuke'
[string[]] $configuredParameterNames = @()
$parameterFile = Join-Path $nukeDirectory 'parameters.json'
if (Test-Path -LiteralPath $parameterFile -PathType Leaf) {
    $data = Get-Content -LiteralPath $parameterFile -Raw | ConvertFrom-Json
    $configuredParameterNames = @($data.PSObject.Properties.Name | Where-Object { $_ -notlike '$*' })
    [Array]::Sort($configuredParameterNames, [StringComparer]::Ordinal)
}

$schemaPath = Join-Path $nukeDirectory 'build.schema.json'
$schemaParameters = [Collections.Generic.List[object]]::new()
[string[]] $targets = @()
if (Test-Path -LiteralPath $schemaPath -PathType Leaf) {
    $schema = Get-Content -LiteralPath $schemaPath -Raw | ConvertFrom-Json
    $targetDefinition = Get-JsonProperty -Object $schema.definitions -Name 'ExecutableTarget'
    if ($targetDefinition) {
        $targets = @($targetDefinition.enum | ForEach-Object { [string] $_ })
        [Array]::Sort($targets, [StringComparer]::Ordinal)
    }

    $propertySets = [Collections.Generic.List[object]]::new()
    foreach ($entry in @($schema.allOf)) {
        $resolvedEntry = Resolve-SchemaDefinition -Schema $schema -Node $entry
        $properties = Get-JsonProperty -Object $resolvedEntry -Name 'properties'
        if ($properties) { $propertySets.Add($properties) }
    }

    $parameterNames = @($propertySets | ForEach-Object { $_.PSObject.Properties.Name } | Select-Object -Unique)
    [Array]::Sort($parameterNames, [StringComparer]::Ordinal)
    foreach ($name in $parameterNames) {
        $definition = $null
        foreach ($propertySet in $propertySets) {
            if ($propertySet.PSObject.Properties[$name]) {
                $definition = $propertySet.$name
                break
            }
        }
        $resolvedDefinition = Resolve-SchemaDefinition -Schema $schema -Node $definition
        $itemDefinition = Resolve-SchemaDefinition -Schema $schema -Node (
            Get-JsonProperty -Object $resolvedDefinition -Name 'items'
        )
        $schemaParameters.Add([ordered]@{
            Name        = $name
            Type        = Get-JsonProperty -Object $resolvedDefinition -Name 'type'
            Description = Get-JsonProperty -Object $definition -Name 'description'
            Enum        = @(@(Get-JsonProperty -Object $resolvedDefinition -Name 'enum') |
                Where-Object { $null -ne $_ })
            ItemType    = Get-JsonProperty -Object $itemDefinition -Name 'type'
            ItemEnum    = @(@(Get-JsonProperty -Object $itemDefinition -Name 'enum') |
                Where-Object { $null -ne $_ })
            Default     = Get-JsonProperty -Object $definition -Name 'default'
        })
    }
}
[string[]] $projectPaths = @()
if ($Context.Inspection.Contains('DotNetProjects')) {
    $projectPaths = @($Context.Inspection.DotNetProjects | Where-Object {
        @($_.PackageReferences | ForEach-Object { $_.Name }) -contains 'Nuke.Common'
    } | ForEach-Object Path)
}
[string[]] $buildScripts = @()
$buildScriptItems = @(Get-ChildItem -LiteralPath $Context.RepositoryPath -Recurse -File -Filter 'build.ps1' |
    Where-Object { Test-ContainerModuleInspectionPath -Context $Context -Path $_.FullName })
if ($buildScriptItems.Count -gt 0) {
    $buildScripts = @($buildScriptItems | ForEach-Object {
        [IO.Path]::GetRelativePath($Context.RepositoryPath, $_.FullName).Replace('\', '/')
    })
    [Array]::Sort($buildScripts, [StringComparer]::Ordinal)
}
$Context.Inspection['Nuke'] = [ordered]@{
    IsConfigured             = (Test-Path -LiteralPath $nukeDirectory -PathType Container) -or $projectPaths.Count -gt 0
    SchemaPath               = if (Test-Path -LiteralPath $schemaPath -PathType Leaf) { '.nuke/build.schema.json' } else { $null }
    ParameterNames           = if ($schemaParameters.Count -gt 0) { @($schemaParameters.Name) } else { $configuredParameterNames }
    ConfiguredParameterNames = $configuredParameterNames
    Parameters               = @($schemaParameters)
    Targets                  = $targets
    ProjectPaths             = $projectPaths
    BuildScripts             = $buildScripts
}
