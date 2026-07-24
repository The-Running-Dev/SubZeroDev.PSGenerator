<#
.SYNOPSIS
    Build and run the Docusaurus docs site from docs/ using docs/Dockerfile.

.DESCRIPTION
    Copies the root README.md to docs/docs/index.md so the repository and
    documentation site share one landing page, then builds the docs image.

    The image extends the published
    ghcr.io/the-running-dev/docs-template container image and overlays the docs/
    build context — our docusaurus.config.ts, sidebar.ts, and the markdown under
    docs/docs — over /template (Dockerfile `COPY . .`). No template repository
    checkout or Git submodule is required.

.PARAMETER Live
    Bind-mount docs/ over the running container so editing markdown or config
    hot-reloads in the browser without rebuilding. Omit for a baked run (the image
    is self-contained; re-run this script to pick up edits).

.PARAMETER BuildOnly
    Build the image and stop; do not run a container.

.PARAMETER Port
    Host port to publish (container serves on 3000). Default 3000.

.PARAMETER Tag
    Image tag to build. Default 'containerpsgenerator-docs'.

.PARAMETER BaseImage
    Base image passed as the Dockerfile BASE_IMAGE build-arg.

.EXAMPLE
    ./docs.ps1                 # build, run baked, serve http://localhost:3000
.EXAMPLE
    ./docs.ps1 -Live           # build, run with hot-reload from docs/
.EXAMPLE
    ./docs.ps1 -BuildOnly      # just build the image
#>
[CmdletBinding()]
param(
    [switch]$Live,
    [switch]$BuildOnly,
    [int]$Port = 3000,
    [string]$Tag = 'containerpsgenerator-docs',
    [string]$BaseImage = 'ghcr.io/the-running-dev/docs-template:latest'
)

$ErrorActionPreference = 'Stop'

# docs/ is both the Docker build context and the Docusaurus overlay.
$root    = Split-Path -Parent $MyInvocation.MyCommand.Definition
$context = Join-Path $root 'docs'
$dockerfile = Join-Path $context 'Dockerfile'
$readme = Join-Path $root 'README.md'
$index = Join-Path $context 'docs' 'index.md'

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw "docker not found on PATH. Install/launch Docker Desktop first."
}
if (-not (Test-Path $dockerfile)) {
    throw "Dockerfile not found at $dockerfile"
}
if (-not (Test-Path -LiteralPath $readme -PathType Leaf)) {
    throw "README not found at $readme"
}
if (-not (Test-Path -LiteralPath (Split-Path -Parent $index) -PathType Container)) {
    throw "Documentation directory not found at $(Split-Path -Parent $index)"
}

Copy-Item -LiteralPath $readme -Destination $index -Force
Write-Host "Copied README.md to docs/docs/index.md." -ForegroundColor Cyan

Write-Host "Building '$Tag' from $context (base: $BaseImage) ..." -ForegroundColor Cyan
docker build --build-arg "BASE_IMAGE=$BaseImage" -f $dockerfile -t $Tag $context
if ($LASTEXITCODE -ne 0) { throw "docker build failed (exit $LASTEXITCODE)" }

if ($BuildOnly) {
    Write-Host "Built '$Tag'. (build-only)" -ForegroundColor Green
    return
}

# Docker Desktop wants forward-slash absolute paths for bind mounts.
$ctx = ($context -replace '\\', '/')

$runArgs = @('run', '--rm', '-it', '-p', "${Port}:3000")

if ($Live) {
    Write-Host "Live mode: editing docs/ hot-reloads (bind-mounted over /template)." -ForegroundColor Yellow
    $runArgs += @(
        '-v', "${ctx}/docs:/template/docs",
        '-v', "${ctx}/docusaurus.config.ts:/template/docusaurus.config.ts",
        '-v', "${ctx}/sidebar.ts:/template/sidebar.ts"
    )
}

$runArgs += $Tag

Write-Host "Serving at http://localhost:$Port  (Ctrl+C to stop)" -ForegroundColor Green
docker @runArgs
