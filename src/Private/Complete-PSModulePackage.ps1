function Complete-PSModulePackage {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [psobject] $Context
    )

    $requiredPaths = [ordered] @{
        Manifest = Join-Path $Context.OutputPath "$($Context.Model.ModuleName).psd1"
        Loader   = Join-Path $Context.OutputPath "$($Context.Model.ModuleName).psm1"
        Metadata = Join-Path $Context.OutputPath 'Metadata' 'model.json'
    }

    foreach ($requiredPath in $requiredPaths.GetEnumerator()) {
        if (-not (Test-Path -LiteralPath $requiredPath.Value -PathType Leaf)) {
            throw [System.IO.InvalidDataException]::new(
                "Generated PSModule package is incomplete: $($requiredPath.Key) '$($requiredPath.Value)' was not found."
            )
        }
    }

    foreach ($artifactName in @('Manifest', 'Metadata')) {
        if (-not $Context.Artifacts.Contains($artifactName)) {
            throw [System.IO.InvalidDataException]::new(
                "Generated PSModule package is incomplete: the $artifactName artifact was not published."
            )
        }

        $actualPath = [System.IO.Path]::GetFullPath($Context.Artifacts[$artifactName].FullName)
        if (-not $actualPath.Equals(
            [System.IO.Path]::GetFullPath($requiredPaths[$artifactName]),
            [System.StringComparison]::OrdinalIgnoreCase
        )) {
            throw [System.IO.InvalidDataException]::new(
                "Generated PSModule package has an unexpected $artifactName artifact path: '$actualPath'."
            )
        }
    }

    foreach ($command in $Context.Model.Commands) {
        foreach ($relativePath in @(
            (Join-Path 'Public' "$($command.Name).ps1"),
            (Join-Path 'Documentation' "$($command.Name).md")
        )) {
            $commandPath = Join-Path $Context.OutputPath $relativePath
            if (-not (Test-Path -LiteralPath $commandPath -PathType Leaf)) {
                throw [System.IO.InvalidDataException]::new(
                    "Generated PSModule package is incomplete: command artifact '$commandPath' was not found."
                )
            }
        }
    }

    try {
        $null = Test-ModuleManifest -Path $requiredPaths.Manifest -ErrorAction Stop
    }
    catch {
        throw [System.IO.InvalidDataException]::new(
            "Generated PSModule package manifest is invalid: $($_.Exception.Message)",
            $_.Exception
        )
    }

    $package = Get-Item -LiteralPath $Context.OutputPath
    $package.PSObject.TypeNames.Insert(0, 'SubZeroDev.PSGenerator.PackageArtifact')
    return $package
}
