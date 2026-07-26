Set-StrictMode -Version 3.0

$privateFunctions = Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'Private') -Filter '*.ps1'
$publicFunctions = Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'Public') -Filter '*.ps1'

$privateFunctions | ForEach-Object {
    . $_.FullName
}

foreach ($function in $publicFunctions) {
    . $function.FullName
}

Export-ModuleMember -Function $publicFunctions.BaseName
