function Write-PSModuleManifest {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [psobject] $Context
    )

    $manifestPath = Join-Path $Context.OutputPath "$($Context.Model.ModuleName).psd1"
    $source = ConvertTo-PSModuleManifestSource -Model $Context.Model
    $null = New-Item -Path $Context.OutputPath -ItemType Directory -Force
    [System.IO.File]::WriteAllText(
        $manifestPath,
        $source,
        [System.Text.UTF8Encoding]::new($false)
    )

    Get-Item -LiteralPath $manifestPath
}
