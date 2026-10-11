<#
.SYNOPSIS
Tags the built container image and pushes it to its registry.

.DESCRIPTION
Pushes a date-based version tag, which gives consumers something immutable to pin, and
latest, which tracks main. The caller logs in to the registry first.

.PARAMETER Repository
Image repository to push, without a tag.

.PARAMETER Image
Locally built image to tag.
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string] $Repository,

    [Parameter()]
    [string] $Image = 'psgenerator:ci'
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$version = Get-Date -Format 'yyyy.MM.dd'
foreach ($tag in @("${Repository}:$version", "${Repository}:latest")) {
    docker tag $Image $tag
    if ($LASTEXITCODE -ne 0) { throw "Tagging '$tag' failed." }

    docker push $tag
    if ($LASTEXITCODE -ne 0) { throw "Pushing '$tag' failed with exit code $LASTEXITCODE." }

    Write-Host "Pushed $tag"
}
