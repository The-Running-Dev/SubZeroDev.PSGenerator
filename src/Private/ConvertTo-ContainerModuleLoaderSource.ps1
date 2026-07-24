function ConvertTo-ContainerModuleLoaderSource {
    [CmdletBinding()]
    param ()

    @'
Set-StrictMode -Version 3.0

$publicPath = Join-Path $PSScriptRoot 'Public'
$publicFunctions = @(
    if (Test-Path -LiteralPath $publicPath -PathType Container) {
        Get-ChildItem -LiteralPath $publicPath -Filter '*.ps1' |
            Sort-Object -Property Name
    }
)

foreach ($function in $publicFunctions) {
    . $function.FullName
}

$exportedFunctions = @($publicFunctions | ForEach-Object BaseName)
Export-ModuleMember -Function $exportedFunctions
'@.Replace("`r`n", "`n") + "`n"
}
