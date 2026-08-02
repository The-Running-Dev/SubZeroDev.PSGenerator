function Write-PSModuleOutputMarker {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $OutputPath
    )

    $metadataDirectory = Join-Path ([IO.Path]::GetFullPath($OutputPath)) 'Metadata'
    $markerPath = Join-Path $metadataDirectory 'output.json'
    $marker = [ordered] @{
        SchemaVersion = 1
        Generator     = 'SubZeroDev.PSGenerator'
        ArtifactType  = 'GeneratedPowerShellModule'
    }
    $normalizedJson = ($marker | ConvertTo-Json -Depth 3).Replace("`r`n", "`n") + "`n"

    $null = New-Item -Path $metadataDirectory -ItemType Directory -Force
    [IO.File]::WriteAllText(
        $markerPath,
        $normalizedJson,
        [Text.UTF8Encoding]::new($false)
    )

    Get-Item -LiteralPath $markerPath
}
