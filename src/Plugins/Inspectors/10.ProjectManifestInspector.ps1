param (
    [Parameter(Mandatory)]
    [psobject] $Context
)

function Get-FirstXmlValue {
    param (
        [Parameter(Mandatory)] [xml] $Document,
        [Parameter(Mandatory)] [string] $Name
    )

    $node = $Document.SelectSingleNode("//*[local-name()='PropertyGroup']/*[local-name()='$Name']")
    if ($node) { return $node.InnerText.Trim() }
    return $null
}

function Get-SortedPropertyNames {
    param ([psobject] $Object)

    if ($null -eq $Object) { return @() }
    $names = @($Object.PSObject.Properties.Name)
    [Array]::Sort($names, [System.StringComparer]::Ordinal)
    return $names
}

function Get-JsonPropertyValue {
    param (
        [psobject] $Object,
        [string] $Name,
        $Default = $null
    )

    if ($null -ne $Object -and $Object.PSObject.Properties[$Name]) {
        return $Object.$Name
    }
    return $Default
}

$manifestItems = @(
    Get-ChildItem -LiteralPath $Context.RepositoryPath -Recurse -File |
        Where-Object {
            ($_.Extension -eq '.csproj' -or $_.Name -eq 'package.json') -and
            (Test-ContainerModuleInspectionPath -Context $Context -Path $_.FullName)
        }
)
[Array]::Sort(
    $manifestItems,
    [System.Collections.Generic.Comparer[object]]::Create({
        param ($left, $right)
        [System.StringComparer]::Ordinal.Compare($left.FullName, $right.FullName)
    })
)

$dotNetProjects = [System.Collections.Generic.List[object]]::new()
$nodeProjects = [System.Collections.Generic.List[object]]::new()
$repositoryPrefix = $Context.RepositoryPath.TrimEnd(
    [IO.Path]::DirectorySeparatorChar,
    [IO.Path]::AltDirectorySeparatorChar
) + [IO.Path]::DirectorySeparatorChar

foreach ($manifestItem in $manifestItems) {
    $relativePath = [System.IO.Path]::GetRelativePath($Context.RepositoryPath, $manifestItem.FullName).Replace('\', '/')

    if ($manifestItem.Extension -eq '.csproj') {
        [xml] $document = Get-Content -LiteralPath $manifestItem.FullName -Raw
        $targetFrameworks = Get-FirstXmlValue -Document $document -Name 'TargetFrameworks'
        if (-not $targetFrameworks) {
            $targetFrameworks = Get-FirstXmlValue -Document $document -Name 'TargetFramework'
        }

        $packageReferences = @(
            foreach ($reference in $document.SelectNodes("//*[local-name()='PackageReference']")) {
                $versionNode = $reference.SelectSingleNode("./*[local-name()='Version']")
                [ordered] @{
                    Name    = $reference.GetAttribute('Include')
                    Version = if ($reference.GetAttribute('Version')) {
                        $reference.GetAttribute('Version')
                    }
                    elseif ($versionNode) {
                        $versionNode.InnerText.Trim()
                    }
                    else {
                        $null
                    }
                }
            }
        )
        $projectReferences = @(
            foreach ($reference in $document.SelectNodes("//*[local-name()='ProjectReference']")) {
                $include = $reference.GetAttribute('Include')
                if ([string]::IsNullOrWhiteSpace($include)) { continue }
                try {
                    $resolvedPath = [IO.Path]::GetFullPath((Join-Path $manifestItem.DirectoryName $include))
                }
                catch {
                    continue
                }
                if (-not $resolvedPath.StartsWith(
                    $repositoryPrefix,
                    [StringComparison]::OrdinalIgnoreCase
                )) {
                    continue
                }
                if (-not (Test-ContainerModuleInspectionPath -Context $Context -Path $resolvedPath)) {
                    continue
                }
                [ordered]@{
                    Path    = [IO.Path]::GetRelativePath($Context.RepositoryPath, $resolvedPath).Replace('\', '/')
                    Aliases = if ($reference.GetAttribute('Aliases')) {
                        @($reference.GetAttribute('Aliases') -split '[,;]' |
                            ForEach-Object { $_.Trim() } | Where-Object { $_ })
                    }
                    else { @() }
                }
            }
        )
        $projectReferences = @($projectReferences | Sort-Object Path)

        $outputType = Get-FirstXmlValue -Document $document -Name 'OutputType'
        $assemblyName = Get-FirstXmlValue -Document $document -Name 'AssemblyName'
        $isTestProjectValue = Get-FirstXmlValue -Document $document -Name 'IsTestProject'
        $packageReferenceNames = @($packageReferences | ForEach-Object { $_.Name })
        $isTestProject = $isTestProjectValue -eq 'true' -or
            $packageReferenceNames -contains 'Microsoft.NET.Test.Sdk'

        $dotNetProjects.Add([ordered] @{
            Path              = $relativePath
            Name              = if ($assemblyName) { $assemblyName } else { $manifestItem.BaseName }
            Sdk               = $document.DocumentElement.GetAttribute('Sdk')
            TargetFrameworks  = @($targetFrameworks -split ';' | Where-Object { $_ } | ForEach-Object { $_.Trim() })
            OutputType        = $outputType
            IsExecutable      = $outputType -in @('Exe', 'WinExe')
            IsTestProject     = $isTestProject
            AssemblyName      = $assemblyName
            PackageId         = Get-FirstXmlValue -Document $document -Name 'PackageId'
            NukeRootDirectory = Get-FirstXmlValue -Document $document -Name 'NukeRootDirectory'
            NukeScriptDirectory = Get-FirstXmlValue -Document $document -Name 'NukeScriptDirectory'
            PackageReferences = $packageReferences
            ProjectReferences = $projectReferences
        })
        continue
    }

    $package = Get-Content -LiteralPath $manifestItem.FullName -Raw | ConvertFrom-Json
    $privateValue = Get-JsonPropertyValue -Object $package -Name 'private' -Default $false
    $nodeProjects.Add([ordered] @{
        Path            = $relativePath
        Name            = Get-JsonPropertyValue -Object $package -Name 'name'
        Version         = Get-JsonPropertyValue -Object $package -Name 'version'
        Private         = [bool] $privateValue
        PackageManager  = Get-JsonPropertyValue -Object $package -Name 'packageManager'
        Scripts         = @(Get-SortedPropertyNames (Get-JsonPropertyValue -Object $package -Name 'scripts'))
        Dependencies    = @(Get-SortedPropertyNames (Get-JsonPropertyValue -Object $package -Name 'dependencies'))
        DevDependencies = @(Get-SortedPropertyNames (Get-JsonPropertyValue -Object $package -Name 'devDependencies'))
    })
}

$Context.Inspection['DotNetProjects'] = @($dotNetProjects)
$Context.Inspection['NodeProjects'] = @($nodeProjects)
