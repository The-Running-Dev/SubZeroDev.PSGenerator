param (
    [Parameter(Mandatory)]
    [string] $Name,

    [switch] $Uppercase
)

$settingsPath = Join-Path $PSScriptRoot 'support' 'settings.json'
$settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
$greeting = "$($settings.Prefix), $Name!"

if ($Uppercase) {
    return $greeting.ToUpperInvariant()
}

return $greeting
