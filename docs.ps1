<#
.SYNOPSIS
    Build and run the Docusaurus docs site from docs/ using docs/Dockerfile.

.DESCRIPTION
    Generates docs/docs/index.md from the root README.md so the repository and
    documentation site share one landing page. The generated page receives stable
    Docusaurus frontmatter and origin-relative documentation links before the docs
    image is built.

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
    Image tag to build. Default 'psgenerator-docs'.

.PARAMETER BaseImage
    Base image passed as the Dockerfile BASE_IMAGE build-arg.

.PARAMETER CreateVersion
    Cut a documentation version snapshot and exit without running a container.

    Runs `docusaurus docs:version <version>` inside the built image with docs/
    bind-mounted, then writes versioned_docs/, versioned_sidebars/, and
    versions.json back to docs/ on the host. docs-build.ps1 copies those to
    /template during CI, so the snapshot ships with the site.

    Cut a snapshot only when the documented content is final for that version;
    every later edit to docs/docs leaves the frozen copy stale.

    Cut the snapshot before pointing `lastVersion` at it in docusaurus.config.ts.
    Docusaurus fails to load a config whose `lastVersion` names a version that
    versions.json does not list, so re-cutting an existing snapshot means
    temporarily removing that setting first.

.EXAMPLE
    ./docs.ps1                 # build, run baked, serve http://localhost:3000
.EXAMPLE
    ./docs.ps1 -Live           # build, run with hot-reload from docs/
.EXAMPLE
    ./docs.ps1 -BuildOnly      # just build the image
.EXAMPLE
    ./docs.ps1 -CreateVersion 1.0.0    # freeze the current docs as version 1.0.0
#>
[CmdletBinding()]
param(
    [switch]$Live,
    [switch]$BuildOnly,
    [int]$Port = 3000,
    [string]$Tag = 'psgenerator-docs',
    [string]$BaseImage = 'ghcr.io/the-running-dev/docs-template:latest',
    [string]$CreateVersion
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

$frontmatter = @(
    '---'
    'title: PSGenerator'
    'description: Generate native PowerShell modules for containerized applications.'
    'sidebar_position: 1'
    '---'
    ''
) -join "`n"
$readmeContent = (Get-Content -LiteralPath $readme -Raw) -replace "`r`n?", "`n"
$indexBody = $readmeContent.Replace(
    'https://psgenerator.subzerodev.com/',
    '/'
)
$indexContent = $frontmatter + "`n" + $indexBody
[IO.File]::WriteAllText(
    $index,
    $indexContent,
    [Text.UTF8Encoding]::new($false)
)
Write-Host (
    'Generated docs/docs/index.md from README.md with Docusaurus frontmatter ' +
    'and origin-relative documentation links.'
) -ForegroundColor Cyan

Write-Host "Building '$Tag' from $context (base: $BaseImage) ..." -ForegroundColor Cyan
docker build --build-arg "BASE_IMAGE=$BaseImage" -f $dockerfile -t $Tag $context
if ($LASTEXITCODE -ne 0) { throw "docker build failed (exit $LASTEXITCODE)" }

if ($BuildOnly) {
    Write-Host "Built '$Tag'. (build-only)" -ForegroundColor Green
    return
}

# Docker Desktop wants forward-slash absolute paths for bind mounts.
$ctx = ($context -replace '\\', '/')

if ($CreateVersion) {
    # docusaurus writes these at the project root, not inside docs/. Create them
    # on the host first so the bind mounts attach to existing paths instead of
    # Docker creating root-owned directories.
    $versionedDocs = Join-Path $context 'versioned_docs'
    $versionedSidebars = Join-Path $context 'versioned_sidebars'
    $versionsFile = Join-Path $context 'versions.json'

    foreach ($directory in @($versionedDocs, $versionedSidebars)) {
        if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
            New-Item -ItemType Directory -Path $directory -Force | Out-Null
        }
    }
    if (-not (Test-Path -LiteralPath $versionsFile -PathType Leaf)) {
        [IO.File]::WriteAllText($versionsFile, "[]`n", [Text.UTF8Encoding]::new($false))
    }

    Write-Host "Cutting documentation version '$CreateVersion' ..." -ForegroundColor Cyan
    docker run --rm `
        -v "${ctx}/docs:/template/docs" `
        -v "${ctx}/versioned_docs:/template/versioned_docs" `
        -v "${ctx}/versioned_sidebars:/template/versioned_sidebars" `
        -v "${ctx}/versions.json:/template/versions.json" `
        -w /template `
        $Tag `
        pnpm run docusaurus docs:version $CreateVersion
    if ($LASTEXITCODE -ne 0) { throw "docusaurus docs:version failed (exit $LASTEXITCODE)" }

    Write-Host (
        "Created docs/versioned_docs/version-$CreateVersion, its sidebar, and " +
        'updated docs/versions.json.'
    ) -ForegroundColor Green
    return
}

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
