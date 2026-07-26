function Write-PSModuleMetadata {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [psobject] $Context
    )

    $metadataDirectory = Join-Path $Context.OutputPath 'Metadata'
    $metadataPath = Join-Path $metadataDirectory 'model.json'
    $metadata = ConvertTo-PSModuleMetadata -Model $Context.Model
    $json = $metadata | ConvertTo-Json -Depth 20
    $normalizedJson = $json.Replace("`r`n", "`n") + "`n"

    $null = New-Item -Path $metadataDirectory -ItemType Directory -Force
    [System.IO.File]::WriteAllText(
        $metadataPath,
        $normalizedJson,
        [System.Text.UTF8Encoding]::new($false)
    )

    Get-Item -LiteralPath $metadataPath
}
