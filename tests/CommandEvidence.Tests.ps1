BeforeAll {
    $manifestPath = if (-not [string]::IsNullOrWhiteSpace($env:PSGENERATOR_MODULE_PATH)) {
        [IO.Path]::GetFullPath($env:PSGENERATOR_MODULE_PATH)
    }
    else {
        Join-Path $PSScriptRoot '..' 'src' 'SubZeroDev.PSGenerator.psd1'
    }
    Import-Module $manifestPath -Force
}

Describe 'Command evidence schema' {
    It 'rejects an invalid kind or confidence' {
        InModuleScope SubZeroDev.PSGenerator {
            $context = [pscustomobject] @{ Inspection = [ordered] @{} }

            {
                Add-PSModuleCommandEvidence -Context $context -Kind 'Unknown' -SourcePath 'a' `
                    -Subject 's' -Property 'p' -Confidence 'Explicit' -Inspector 'Fake'
            } | Should -Throw

            {
                Add-PSModuleCommandEvidence -Context $context -Kind 'CSharp' -SourcePath 'a' `
                    -Subject 's' -Property 'p' -Confidence 'Certain' -Inspector 'Fake'
            } | Should -Throw
        }
    }

    It 'appends a record with the documented fields, defaulting Authoritative to false' {
        InModuleScope SubZeroDev.PSGenerator {
            $context = [pscustomobject] @{ Inspection = [ordered] @{} }

            $evidence = Add-PSModuleCommandEvidence -Context $context -Kind 'CSharp' `
                -SourcePath 'src/Build/DockerBuildParams.cs' -Subject 'Docker' -Property 'Description' `
                -Value 'Build a Docker image.' -Confidence 'Explicit' -Inspector 'CSharpInspector'

            $evidence.Kind | Should -Be 'CSharp'
            $evidence.SourcePath | Should -Be 'src/Build/DockerBuildParams.cs'
            $evidence.Subject | Should -Be 'Docker'
            $evidence.Property | Should -Be 'Description'
            $evidence.Value | Should -Be 'Build a Docker image.'
            $evidence.Confidence | Should -Be 'Explicit'
            $evidence.Authoritative | Should -BeFalse
            $evidence.Inspector | Should -Be 'CSharpInspector'

            $context.Inspection['CommandEvidence'].Count | Should -Be 1
            $context.Inspection['CommandEvidence'][0] | Should -Be $evidence
        }
    }

    It 'marks a record authoritative when requested' {
        InModuleScope SubZeroDev.PSGenerator {
            $context = [pscustomobject] @{ Inspection = [ordered] @{} }

            $evidence = Add-PSModuleCommandEvidence -Context $context -Kind 'PowerShell' -SourcePath 'a.psm1' `
                -Subject 'Docker' -Property 'Name' -Value 'Invoke-DockerBuild' -Confidence 'Explicit' `
                -Authoritative -Inspector 'PowerShellInspector'

            $evidence.Authoritative | Should -BeTrue
        }
    }

    It 'sorts and deduplicates a collection value ordinal-ignore-case, keeping first-seen spelling' {
        InModuleScope SubZeroDev.PSGenerator {
            $context = [pscustomobject] @{ Inspection = [ordered] @{} }

            $evidence = Add-PSModuleCommandEvidence -Context $context -Kind 'NukeSchema' -SourcePath '.nuke/build.schema.json' `
                -Subject 'Nuke' -Property 'Targets' -Value @('Test', 'docker', 'Docker', 'Forge', 'test') `
                -Confidence 'Explicit' -Inspector 'NukeInspector'

            $evidence.Value | Should -Be @('docker', 'Forge', 'Test')
        }
    }

    It 'leaves a scalar value untouched' {
        InModuleScope SubZeroDev.PSGenerator {
            $context = [pscustomobject] @{ Inspection = [ordered] @{} }

            $evidence = Add-PSModuleCommandEvidence -Context $context -Kind 'NukeConfig' -SourcePath '.nuke/parameters.json' `
                -Subject 'Docker' -Property 'ConfiguredValue' -Value 'release' -Confidence 'Strong' -Inspector 'NukeInspector'

            $evidence.Value | Should -Be 'release'
        }
    }
}

Describe 'Command evidence secret redaction' {
    It 'redacts a Default and a ConfiguredValue record once any source marks the subject secret' {
        InModuleScope SubZeroDev.PSGenerator {
            $context = [pscustomobject] @{ Inspection = [ordered] @{} }

            Add-PSModuleCommandEvidence -Context $context -Kind 'CSharp' -SourcePath 'src/Build/DockerBuildParams.cs' `
                -Subject 'RegistryToken' -Property 'Default' -Value 'super-secret-value' -Confidence 'Explicit' `
                -Inspector 'CSharpInspector' | Out-Null
            Add-PSModuleCommandEvidence -Context $context -Kind 'NukeConfig' -SourcePath '.nuke/parameters.json' `
                -Subject 'RegistryToken' -Property 'ConfiguredValue' -Value 'configured-secret' -Confidence 'Strong' `
                -Inspector 'NukeInspector' | Out-Null
            Add-PSModuleCommandEvidence -Context $context -Kind 'CSharp' -SourcePath 'src/Build/DockerBuildParams.cs' `
                -Subject 'RegistryToken' -Property 'Secret' -Value $true -Confidence 'Explicit' `
                -Inspector 'CSharpInspector' | Out-Null
            Add-PSModuleCommandEvidence -Context $context -Kind 'CSharp' -SourcePath 'src/Build/DockerBuildParams.cs' `
                -Subject 'RegistryToken' -Property 'Description' -Value 'Registry auth token.' -Confidence 'Explicit' `
                -Inspector 'CSharpInspector' | Out-Null
            Add-PSModuleCommandEvidence -Context $context -Kind 'CSharp' -SourcePath 'src/Build/DockerBuildParams.cs' `
                -Subject 'ImageTag' -Property 'Default' -Value 'latest' -Confidence 'Explicit' `
                -Inspector 'CSharpInspector' | Out-Null

            Protect-PSModuleCommandEvidenceSecret -Context $context

            $records = @($context.Inspection['CommandEvidence'])
            ($records | Where-Object { $_.Subject -eq 'RegistryToken' -and $_.Property -eq 'Default' }).Value |
                Should -Be '<redacted>'
            ($records | Where-Object { $_.Subject -eq 'RegistryToken' -and $_.Property -eq 'ConfiguredValue' }).Value |
                Should -Be '<redacted>'
            ($records | Where-Object { $_.Subject -eq 'RegistryToken' -and $_.Property -eq 'Description' }).Value |
                Should -Be 'Registry auth token.'
            ($records | Where-Object { $_.Subject -eq 'RegistryToken' -and $_.Property -eq 'Secret' }).Value |
                Should -BeTrue
            ($records | Where-Object { $_.Subject -eq 'ImageTag' -and $_.Property -eq 'Default' }).Value |
                Should -Be 'latest'
        }
    }

    It 'redacts regardless of whether the Secret record was added before or after the literal value' {
        InModuleScope SubZeroDev.PSGenerator {
            $context = [pscustomobject] @{ Inspection = [ordered] @{} }

            Add-PSModuleCommandEvidence -Context $context -Kind 'CSharp' -SourcePath 'src/Build/DockerBuildParams.cs' `
                -Subject 'ApiKey' -Property 'Secret' -Value $true -Confidence 'Explicit' `
                -Inspector 'CSharpInspector' | Out-Null
            Add-PSModuleCommandEvidence -Context $context -Kind 'CSharp' -SourcePath 'src/Build/DockerBuildParams.cs' `
                -Subject 'ApiKey' -Property 'Default' -Value 'front-loaded-secret' -Confidence 'Explicit' `
                -Inspector 'CSharpInspector' | Out-Null

            Protect-PSModuleCommandEvidenceSecret -Context $context

            (@($context.Inspection['CommandEvidence']) |
                Where-Object { $_.Subject -eq 'ApiKey' -and $_.Property -eq 'Default' }).Value |
                Should -Be '<redacted>'
        }
    }

    It 'does nothing when no record is present' {
        InModuleScope SubZeroDev.PSGenerator {
            $context = [pscustomobject] @{ Inspection = [ordered] @{} }
            { Protect-PSModuleCommandEvidenceSecret -Context $context } | Should -Not -Throw
        }
    }
}

Describe 'Command evidence in the inspection pipeline' {
    BeforeEach {
        $pluginRoot = Join-Path $TestDrive 'EvidencePlugins'
        if (Test-Path -LiteralPath $pluginRoot) {
            Remove-Item -LiteralPath $pluginRoot -Recurse -Force
        }
        New-Item -Path (Join-Path $pluginRoot 'Inspectors') -ItemType Directory -Force | Out-Null

        $directoryPath = Join-Path $TestDrive 'EvidenceDirectory'
        if (Test-Path -LiteralPath $directoryPath) {
            Remove-Item -LiteralPath $directoryPath -Recurse -Force
        }
        New-Item -Path (Join-Path $directoryPath 'PSModule') -ItemType Directory -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $directoryPath 'PSModule' 'PSModule.psd1') -Value '@{ Commands = @() }'
    }

    It 'surfaces an empty collection in Data.CommandEvidence when no inspector adds evidence' {
        $inspection = Get-PSModuleInspection -Specification (Join-Path $directoryPath 'PSModule' 'PSModule.psd1')
        @($inspection.Data.CommandEvidence).Count | Should -Be 0
    }

    It 'surfaces redacted evidence added by a plugin through Get-PSModuleInspection' {
        Set-Content -LiteralPath (Join-Path $pluginRoot 'Inspectors' '00.Fake.ps1') -Value @'
param ([psobject] $Context)
Add-PSModuleCommandEvidence -Context $Context -Kind CSharp -SourcePath 'src/Build/DockerBuildParams.cs' `
    -Subject RegistryToken -Property Secret -Value $true -Confidence Explicit -Inspector Fake
Add-PSModuleCommandEvidence -Context $Context -Kind CSharp -SourcePath 'src/Build/DockerBuildParams.cs' `
    -Subject RegistryToken -Property Default -Value 'leaked-if-not-redacted' -Confidence Explicit -Inspector Fake
'@

        $inspection = Get-PSModuleInspection -Specification (Join-Path $directoryPath 'PSModule' 'PSModule.psd1') `
            -PluginPath $pluginRoot

        $records = @($inspection.Data.CommandEvidence)
        $records.Count | Should -Be 2
        ($records | Where-Object Property -eq 'Default').Value | Should -Be '<redacted>'
    }
}
