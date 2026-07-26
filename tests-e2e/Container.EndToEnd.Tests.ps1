BeforeAll {
    $repositoryRoot = Split-Path $PSScriptRoot -Parent
    $generatorManifest = Join-Path $repositoryRoot 'src' 'SubZeroDev.PSGenerator.psd1'
    $fixtureSource = Join-Path $repositoryRoot 'examples' 'Minimal'
    $fixturePath = Join-Path $TestDrive 'Minimal'
    $generatedModulePath = Join-Path $fixturePath 'artifacts' 'PSModule'
    $installedModulePath = Join-Path $TestDrive 'Installed' 'ExampleContainer'
    $isAct = $env:ACT -eq 'true'
    $mountedRepositoryPath = if ($isAct) { '/tmp' } else { Join-Path $TestDrive 'Repository' }
    $secretPath = Join-Path $TestDrive 'api-token.txt'
    $volumeName = 'psgenerator-e2e-' + [guid]::NewGuid().ToString('N')
    $image = 'subzerodev-psgenerator-minimal:local'

    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        throw 'Docker is required for the container end-to-end tests.'
    }
    & docker info --format '{{.ServerVersion}}' | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw 'Docker is not available for the container end-to-end tests.'
    }

    Copy-Item -LiteralPath $fixtureSource -Destination $fixturePath -Recurse
    Import-Module $generatorManifest -Force

    Push-Location $fixturePath
    try {
        $null = Build-PSModule -Specification './PSModule/PSModule.psd1' -Output './artifacts/PSModule'
    }
    finally {
        Pop-Location
    }

    & docker build --tag $image $fixturePath
    if ($LASTEXITCODE -ne 0) {
        throw "Building the end-to-end fixture image failed with exit code $LASTEXITCODE."
    }

    $null = Install-PSModule $image -Destination $installedModulePath
    Import-Module (Join-Path $installedModulePath 'ExampleContainer.psd1') -Force

    if (-not $isAct) {
        $null = New-Item -Path $mountedRepositoryPath -ItemType Directory -Force
        Set-Content -LiteralPath (Join-Path $mountedRepositoryPath 'README.md') `
            -Value 'mounted-content' -NoNewline
    }
    Set-Content -LiteralPath $secretPath -Value 'secret-from-e2e' -NoNewline
}

AfterAll {
    Remove-Module ExampleContainer -Force -ErrorAction SilentlyContinue
    Remove-Module SubZeroDev.PSGenerator -Force -ErrorAction SilentlyContinue
    & docker image rm --force $image 2>&1 | Out-Null
    & docker volume rm --force $volumeName 2>&1 | Out-Null
}

Describe 'Container module end-to-end workflow' {
    It 'embeds and installs the generated module from /PSModule' {
        Test-Path -LiteralPath (Join-Path $installedModulePath 'ExampleContainer.psd1') -PathType Leaf |
            Should -BeTrue
        Get-Command Invoke-Example -Module ExampleContainer | Should -Not -BeNullOrEmpty
    }

    It 'installs the generated Markdown command reference unchanged' {
        $generatedDocumentation = Join-Path $generatedModulePath `
            'Documentation' 'Invoke-Example.md'
        $installedDocumentation = Join-Path $installedModulePath `
            'Documentation' 'Invoke-Example.md'

        Test-Path -LiteralPath $generatedDocumentation -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $installedDocumentation -PathType Leaf | Should -BeTrue
        [Convert]::ToHexString([IO.File]::ReadAllBytes($installedDocumentation)) |
            Should -Be ([Convert]::ToHexString([IO.File]::ReadAllBytes($generatedDocumentation)))

        $markdown = Get-Content -LiteralPath $installedDocumentation -Raw
        $markdown | Should -Match '^# Invoke-Example\n'
        $markdown | Should -Match 'Runs the example container\.'
        $markdown | Should -Match '## Syntax'
        $markdown | Should -Match '### `-Repository`'
        $markdown | Should -Match '### `-Message`'
        $markdown | Should -Match '## Examples'
        $markdown | Should -Match ([regex]::Escape(
            "Invoke-Example -Repository . -Message 'hello'"
        ))
        $markdown | Should -Match '## Notes'
        $markdown | Should -Match 'Docker must be available on PATH unless using -WhatIf\.'
    }

    It 'runs the generated command through Docker with arguments, environment, and a mount' {
        $result = Invoke-Example `
            -Repository (Get-Item -LiteralPath $mountedRepositoryPath) `
            -Message 'hello-from-e2e' |
            ConvertFrom-Json

        $result.Message | Should -Be 'hello-from-e2e'
        $result.EnvironmentMessage | Should -Be 'hello-from-e2e'
        if ($isAct) {
            $result.MountedReadme | Should -BeFalse
        }
        else {
            $result.MountedReadme | Should -BeTrue
        }
    }

    It 'runs portable container options through Docker' {
        $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
        $listener.Start()
        try {
            $hostPort = ([Net.IPEndPoint] $listener.LocalEndpoint).Port
        }
        finally {
            $listener.Stop()
        }

        $result = Invoke-Example `
            -Repository (Get-Item -LiteralPath $mountedRepositoryPath) `
            -Message 'mapping-e2e' `
            -HostPort $hostPort `
            -WorkingDirectory '/app' `
            -CacheVolume $volumeName `
            -Network 'bridge' `
            -Hostname 'mapping-e2e' `
            -Memory '256m' `
            -Cpus 0.5 |
            ConvertFrom-Json

        $result.WorkingDirectory | Should -Be '/app'
        $result.CacheWritable | Should -BeTrue
        $result.Hostname | Should -Be 'mapping-e2e'
    }

    It 'mounts a host secret through Docker' -Skip:$isAct {
        $result = Invoke-Example `
            -Repository (Get-Item -LiteralPath $mountedRepositoryPath) `
            -Message 'secret-e2e' `
            -SecretFile (Get-Item -LiteralPath $secretPath) |
            ConvertFrom-Json

        $result.Secret | Should -BeExactly 'secret-from-e2e'
    }

    It 'provides generated help and previews without running Docker' {
        (Get-Help Invoke-Example).Synopsis | Should -Be 'Runs the example container.'

        $previewResult = @(
            Invoke-Example `
                -Repository (Get-Item -LiteralPath $mountedRepositoryPath) `
                -Message 'preview' `
                -WhatIf
        )

        $previewResult.Count | Should -Be 0
    }
}
