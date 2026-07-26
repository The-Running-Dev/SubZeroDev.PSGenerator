function Write-PSModuleLoader {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [psobject] $Context
    )

    $loaderPath = Join-Path $Context.OutputPath "$($Context.Model.ModuleName).psm1"
    $source = ConvertTo-PSModuleLoaderSource
    $null = New-Item -Path $Context.OutputPath -ItemType Directory -Force
    [System.IO.File]::WriteAllText(
        $loaderPath,
        $source,
        [System.Text.UTF8Encoding]::new($false)
    )
}
