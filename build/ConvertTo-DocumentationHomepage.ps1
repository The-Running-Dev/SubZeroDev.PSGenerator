<#
.SYNOPSIS
Builds the documentation homepage content from the root README.

.DESCRIPTION
Returns what `docs/docs/index.md` should contain: Docusaurus front matter
followed by the README, with the production documentation origin rewritten to a
root-relative path so the same links work on GitHub and on the site.

Both the generator and the drift check call this. Keeping one implementation is
the point: a second copy would be free to disagree with the first, which is the
failure this exists to catch.

.PARAMETER ReadmePath
Path to the root README.

.OUTPUTS
The expected file content as a single string, using LF line endings.
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $ReadmePath
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $ReadmePath -PathType Leaf)) {
    throw [System.IO.FileNotFoundException]::new(
        "README not found at '$ReadmePath'."
    )
}

$frontMatter = @(
    '---'
    'title: PSGenerator'
    'description: Generate native PowerShell modules for containerized applications.'
    'sidebar_position: 1'
    '---'
    ''
) -join "`n"

# Normalize to LF first so the comparison never turns into a line-ending diff.
$readme = (Get-Content -LiteralPath $ReadmePath -Raw) -replace "`r`n?", "`n"
$body = $readme.Replace('https://psgenerator.subzerodev.com/', '/')

return $frontMatter + "`n" + $body
