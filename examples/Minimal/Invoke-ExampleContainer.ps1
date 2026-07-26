Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$messageIndex = [Array]::IndexOf([object[]] $args, '--message')
$message = if ($messageIndex -ge 0 -and $messageIndex + 1 -lt $args.Count) {
    $args[$messageIndex + 1]
}
else {
    $null
}
$readmePath = '/workspace/README.md'
$cacheMarkerPath = '/cache/e2e-marker.txt'
$secretPath = '/run/secrets/api-token'
$cacheMounted = Test-Path -LiteralPath '/cache' -PathType Container
if ($cacheMounted) {
    Set-Content -LiteralPath $cacheMarkerPath -Value 'cache-mounted' -NoNewline
}

[ordered] @{
    Message            = $message
    EnvironmentMessage = $env:EXAMPLE_MESSAGE
    MountedReadme      = Test-Path -LiteralPath $readmePath -PathType Leaf
    WorkingDirectory   = (Get-Location).Path
    CacheWritable      = Test-Path -LiteralPath $cacheMarkerPath -PathType Leaf
    Hostname           = [Environment]::MachineName
    Secret             = if (Test-Path -LiteralPath $secretPath -PathType Leaf) {
        Get-Content -LiteralPath $secretPath -Raw
    }
    else {
        $null
    }
} | ConvertTo-Json -Compress
