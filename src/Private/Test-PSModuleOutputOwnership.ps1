function Test-PSModuleOutputOwnership {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $OutputPath
    )

    $resolvedOutputPath = [IO.Path]::GetFullPath($OutputPath)
    $markerPath = Join-Path $resolvedOutputPath 'Metadata' 'output.json'

    $newResult = {
        param ([string] $State, [string] $Reason)

        [pscustomobject] @{
            PSTypeName = 'SubZeroDev.PSGenerator.OutputOwnership'
            State      = $State
            MarkerPath = $markerPath
            Reason     = $Reason
        }
    }
    $hasActualLinkTarget = {
        param ([System.IO.FileSystemInfo] $Item)

        if (-not $Item.Attributes.HasFlag([IO.FileAttributes]::ReparsePoint)) {
            return $false
        }

        $target = if ($Item.PSIsContainer) {
            [IO.Directory]::ResolveLinkTarget($Item.FullName, $false)
        }
        else {
            [IO.File]::ResolveLinkTarget($Item.FullName, $false)
        }
        return $null -ne $target
    }

    if (-not (Test-Path -LiteralPath $resolvedOutputPath)) {
        return & $newResult 'Missing' 'The output path does not exist.'
    }
    if (-not (Test-Path -LiteralPath $resolvedOutputPath -PathType Container)) {
        return & $newResult 'Unowned' 'The output path is not a directory.'
    }

    if (Test-Path -LiteralPath $markerPath) {
        if (-not (Test-Path -LiteralPath $markerPath -PathType Leaf)) {
            return & $newResult 'InvalidMarker' 'The output marker is not a regular file.'
        }

        $markerItem = Get-Item -LiteralPath $markerPath -Force -ErrorAction Stop
        if (& $hasActualLinkTarget $markerItem) {
            return & $newResult 'InvalidMarker' 'The output marker is a linked file.'
        }

        try {
            $marker = Get-Content -LiteralPath $markerPath -Raw -ErrorAction Stop |
                ConvertFrom-Json -Depth 10 -ErrorAction Stop
        }
        catch {
            return & $newResult 'InvalidMarker' 'The output marker is not valid JSON.'
        }

        $propertyNames = @($marker.PSObject.Properties.Name)
        $expectedNames = @('SchemaVersion', 'Generator', 'ArtifactType')
        if ($propertyNames.Count -ne $expectedNames.Count -or
            @($propertyNames | Where-Object { $_ -cnotin $expectedNames }).Count -gt 0 -or
            -not $marker.PSObject.Properties['SchemaVersion'] -or
            $marker.SchemaVersion -isnot [long] -or
            $marker.SchemaVersion -ne 1 -or
            -not $marker.PSObject.Properties['Generator'] -or
            $marker.Generator -isnot [string] -or
            $marker.Generator -cne 'SubZeroDev.PSGenerator' -or
            -not $marker.PSObject.Properties['ArtifactType'] -or
            $marker.ArtifactType -isnot [string] -or
            $marker.ArtifactType -cne 'GeneratedPowerShellModule') {
            return & $newResult 'InvalidMarker' 'The output marker does not match the supported schema.'
        }

        return & $newResult 'Owned' 'The output contains a valid PSGenerator ownership marker.'
    }

    try {
        $entries = @(Get-ChildItem -LiteralPath $resolvedOutputPath -Force -ErrorAction Stop)
    }
    catch {
        return & $newResult 'Unowned' 'The output directory could not be enumerated safely.'
    }
    if ($entries.Count -eq 0) {
        return & $newResult 'Empty' 'The output directory is empty.'
    }

    $modelPath = Join-Path $resolvedOutputPath 'Metadata' 'model.json'
    if (Test-Path -LiteralPath $modelPath -PathType Leaf) {
        $modelItem = Get-Item -LiteralPath $modelPath -Force -ErrorAction Stop
        if (-not (& $hasActualLinkTarget $modelItem)) {
            try {
                $model = Get-Content -LiteralPath $modelPath -Raw -ErrorAction Stop |
                    ConvertFrom-Json -Depth 20 -ErrorAction Stop
                $moduleName = if ($model.PSObject.Properties['ModuleName']) {
                    $model.ModuleName
                }
                else {
                    $null
                }
                $legacyManifestPath = Join-Path $resolvedOutputPath "$moduleName.psd1"
                $legacyLoaderPath = Join-Path $resolvedOutputPath "$moduleName.psm1"
                $legacyPathsValid = (
                    $model.PSObject.Properties['SchemaVersion'] -and
                    $model.SchemaVersion -is [long] -and
                    $model.SchemaVersion -eq 1 -and
                    $moduleName -is [string] -and
                    $moduleName -match '^[A-Za-z][A-Za-z0-9_.-]*$' -and
                    (Test-Path -LiteralPath $legacyManifestPath -PathType Leaf) -and
                    (Test-Path -LiteralPath $legacyLoaderPath -PathType Leaf)
                )
                if ($legacyPathsValid) {
                    foreach ($legacyFilePath in @($legacyManifestPath, $legacyLoaderPath)) {
                        $legacyFile = Get-Item -LiteralPath $legacyFilePath -Force
                        if (& $hasActualLinkTarget $legacyFile) {
                            $legacyPathsValid = $false
                            break
                        }
                    }
                }
                if ($legacyPathsValid) {
                    foreach ($directoryName in @('Public', 'Documentation', 'Scripts')) {
                        $legacyDirectoryPath = Join-Path $resolvedOutputPath $directoryName
                        if (-not (Test-Path -LiteralPath $legacyDirectoryPath)) {
                            continue
                        }
                        if (-not (Test-Path -LiteralPath $legacyDirectoryPath -PathType Container)) {
                            $legacyPathsValid = $false
                            break
                        }
                        $legacyDirectory = Get-Item -LiteralPath $legacyDirectoryPath -Force
                        if (& $hasActualLinkTarget $legacyDirectory) {
                            $legacyPathsValid = $false
                            break
                        }
                    }
                }
                if ($legacyPathsValid) {
                    return & $newResult 'Legacy' 'The output matches a pre-marker generated package.'
                }
            }
            catch {
                $legacyPathsValid = $false
            }
        }
    }

    return & $newResult 'Unowned' 'The output is non-empty and is not recognized as generated output.'
}
