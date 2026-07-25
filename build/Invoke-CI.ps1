[CmdletBinding()]
param ()

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$actCommand = Get-Command act -ErrorAction SilentlyContinue
if (-not $actCommand) {
    throw "The 'act' command was not found. Install it from https://nektosact.com/installation/index.html."
}

$dockerCommand = Get-Command docker -ErrorAction SilentlyContinue
if (-not $dockerCommand) {
    throw "The 'docker' command was not found. Install and start Docker before running local CI."
}

& $dockerCommand.Source info --format '{{.ServerVersion}}' | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw 'Docker is not available. Start Docker before running local CI.'
}

$repositoryRoot = Split-Path $PSScriptRoot -Parent
$workflowPath = Join-Path $repositoryRoot '.github' 'workflows' 'test.yml'
$runnerDockerfile = Join-Path $repositoryRoot '.act' 'Dockerfile'
$runnerImage = 'subzerodev-containerpsgenerator-act:latest'

$dockerBuildArguments = @(
    'build'
    '--file', $runnerDockerfile
    '--tag', $runnerImage
    $repositoryRoot
)

& $dockerCommand.Source $dockerBuildArguments

if ($LASTEXITCODE -ne 0) {
    throw "Building the local CI runner image failed with exit code $LASTEXITCODE."
}

foreach ($job in @(
        'powershell-baseline',
        'quality',
        'documentation',
        'pester',
        'nuget-package',
        'container-e2e')) {
    $actArguments = @(
        'pull_request'
        '--workflows', $workflowPath
        '--job', $job
        '--platform', "ubuntu-latest=$runnerImage"
        '--pull=false'
    )
    if ($job -in @('powershell-baseline', 'pester')) {
        $actArguments += @('--matrix', 'os:ubuntu-latest')
    }

    & $actCommand.Source $actArguments

    if ($LASTEXITCODE -ne 0) {
        throw "Local CI job '$job' failed with exit code $LASTEXITCODE."
    }
}
