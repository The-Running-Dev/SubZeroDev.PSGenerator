BeforeAll {
    $manifestPath = if (
        -not [string]::IsNullOrWhiteSpace($env:CONTAINERPSGENERATOR_MODULE_PATH)
    ) {
        [IO.Path]::GetFullPath($env:CONTAINERPSGENERATOR_MODULE_PATH)
    }
    else {
        Join-Path $PSScriptRoot '..' 'src' 'SubZeroDev.ContainerPSGenerator.psd1'
    }
    Import-Module $manifestPath -Force
}

Describe 'SubZeroDev.ContainerPSGenerator module' {
    It 'has a valid module manifest' {
        $manifest = Test-ModuleManifest $manifestPath -ErrorAction Stop

        $manifest | Should -Not -BeNullOrEmpty
        $manifest.PowerShellVersion.ToString() | Should -Be '7.4'
    }

    It 'exports the public commands' {
        $exportedCommands = Get-Command -Module SubZeroDev.ContainerPSGenerator

        $exportedCommands.Name | Should -Contain 'Build-ContainerModule'
        $exportedCommands.Name | Should -Contain 'Get-ContainerModuleDiagnostic'
        $exportedCommands.Name | Should -Contain 'Get-ContainerModuleInspection'
        $exportedCommands.Name | Should -Contain 'Get-ContainerModuleModel'
        $exportedCommands.Name | Should -Contain 'Get-ContainerModulePlugin'
        $exportedCommands.Name | Should -Contain 'Install-ContainerModule'
        $exportedCommands.Name | Should -Contain 'Initialize-ContainerModuleSpecification'
        $exportedCommands.Name | Should -Contain 'Test-ContainerModuleSpecification'
    }

    It 'declares the specification and output parameters' {
        $command = Get-Command Build-ContainerModule -Module SubZeroDev.ContainerPSGenerator

        $command.Parameters.Specification.Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }) |
            Should -Not -BeNullOrEmpty
        $command.Parameters.Output.Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }) |
            Should -Not -BeNullOrEmpty
    }

    It 'documents the implemented Version 1 package and inference boundaries' {
        $buildDescription = (Get-Help Build-ContainerModule).Description.Text -join "`n"
        $installDescription = (Get-Help Install-ContainerModule).Description.Text -join "`n"
        $initializeDescription = (
            Get-Help Initialize-ContainerModuleSpecification
        ).Description.Text -join "`n"

        $buildDescription | Should -Match 'Markdown reference page per command'
        $buildDescription | Should -Match '(?s)returns.*Metadata/model\.json'
        $installDescription | Should -Match '(?s)including.*generated Markdown documentation'
        $installDescription | Should -Match 'WhatIf previews'
        $initializeDescription | Should -Match '(?s)execute.*packaged scripts tree'
        $initializeDescription | Should -Match 'inference does not guess'
    }
}

Describe 'Packaged generator module' {
    It 'rejects repository and source directories as package output' {
        $packagingScript = Join-Path $PSScriptRoot '..' 'build' 'New-GeneratorModulePackage.ps1'
        $repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))

        foreach ($unsafePath in @($repositoryRoot, (Join-Path $repositoryRoot 'src'))) {
            {
                & $packagingScript -Output $unsafePath
            } | Should -Throw "*Generator package output path is unsafe*"
        }
    }

    It 'assembles, imports, and runs from a clean location' {
        $packagingScript = Join-Path $PSScriptRoot '..' 'build' 'New-GeneratorModulePackage.ps1'
        $packageRoot = Join-Path $TestDrive 'packaged-generator'
        $null = New-Item -Path $packageRoot -ItemType Directory -Force
        Set-Content -LiteralPath (Join-Path $packageRoot 'stale.txt') -Value 'stale'
        $packagedManifest = & $packagingScript -Output $packageRoot

        Test-Path -LiteralPath (Join-Path $packageRoot 'stale.txt') | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $packageRoot 'Private') -PathType Container |
            Should -BeTrue
        Test-Path -LiteralPath (Join-Path $packageRoot 'Public') -PathType Container |
            Should -BeTrue
        Test-Path -LiteralPath (Join-Path $packageRoot 'Plugins') -PathType Container |
            Should -BeTrue

        Remove-Module SubZeroDev.ContainerPSGenerator -Force
        $packagedModule = Import-Module $packagedManifest.FullName -Force -PassThru -ErrorAction Stop
        try {
            $packagedModule.ModuleBase | Should -Be $packageRoot
            $packagedModule.Path | Should -Be (
                Join-Path $packageRoot 'SubZeroDev.ContainerPSGenerator.psm1'
            )
            $packagedModule.ExportedCommands.Keys | Should -Contain 'Build-ContainerModule'

            $specificationPath = Join-Path $TestDrive 'PackagedGenerator.psd1'
            $outputPath = Join-Path $TestDrive 'packaged-generator-output'
            Set-Content -LiteralPath $specificationPath -Value @'
@{ ModuleName = 'PackagedGeneratorSmoke'; Commands = @() }
'@

            $artifact = Build-ContainerModule `
                -Specification $specificationPath `
                -Output $outputPath

            $artifact.FullName | Should -Be (
                Join-Path $outputPath 'Metadata' 'model.json'
            )
            Test-ModuleManifest (
                Join-Path $outputPath 'PackagedGeneratorSmoke.psd1'
            ) -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }
        finally {
            Remove-Module $packagedModule -Force
            Import-Module $manifestPath -Force
        }
    }
}

Describe 'Container module inspection diagnostics' {
    BeforeEach {
        $repositoryPath = Join-Path $TestDrive 'DiagnosticRepository'
        $specificationDirectory = Join-Path $repositoryPath 'PSModule'
        New-Item -Path $specificationDirectory -ItemType Directory -Force | Out-Null
        $specificationPath = Join-Path $specificationDirectory 'PSModule.psd1'
        Set-Content -LiteralPath $specificationPath -Value '@{ Commands = @() }'
        Set-Content -LiteralPath (Join-Path $repositoryPath 'Dockerfile') -Value 'FROM alpine:3.20'
    }

    It 'returns typed inspection data without creating build output' {
        $result = Get-ContainerModuleInspection -Specification $specificationPath

        $result.PSObject.TypeNames | Should -Contain 'SubZeroDev.ContainerPSGenerator.InspectionResult'
        $result.RepositoryPath | Should -Be $repositoryPath
        $result.Data.Dockerfiles[0].Stages[0].Image | Should -Be 'alpine:3.20'
        $result.PluginExecutions.Count | Should -BeGreaterThan 0
        Test-Path -LiteralPath (Join-Path $specificationDirectory '.container-module-inspection') |
            Should -BeFalse
    }

    It 'returns ordered typed diagnostics from an inspection result' {
        $inspection = Get-ContainerModuleInspection -Specification $specificationPath

        $diagnostics = @($inspection | Get-ContainerModuleDiagnostic)

        $diagnostics.Count | Should -Be $inspection.PluginExecutions.Count
        $diagnostics[0].PSObject.TypeNames | Should -Contain 'SubZeroDev.ContainerPSGenerator.Diagnostic'
        $diagnostics.Plugin | Should -Be $inspection.PluginExecutions.Plugin
        $diagnostics.ExecutionOrder | Should -Be @(0..($diagnostics.Count - 1))
        $diagnostics.Succeeded | Should -Not -Contain $false
        $diagnostics.DurationMilliseconds | ForEach-Object { $_ | Should -BeGreaterOrEqual 0 }
        $diagnostics[0].PSObject.Properties.Name | Should -Not -Contain 'Path'
    }

    It 'returns detailed diagnostics for troubleshooting' {
        $diagnostic = Get-ContainerModuleDiagnostic -Specification $specificationPath -Detailed |
            Select-Object -First 1

        $diagnostic.Path | Should -Exist
        $diagnostic.StartedAt | Should -BeOfType ([DateTimeOffset])
        $diagnostic.PSObject.Properties.Name | Should -Contain 'Error'
    }

    It 'can run diagnostics directly from a specification' {
        $diagnostics = @(Get-ContainerModuleDiagnostic -Specification $specificationPath)

        $diagnostics.Plugin | Should -Contain 'DockerfileInspector'
        $diagnostics.Stage | Should -Not -Contain 'Validators'
    }

    It 'rejects an unrelated diagnostic input object' {
        { [pscustomobject]@{} | Get-ContainerModuleDiagnostic } |
            Should -Throw -ExceptionType ([System.ArgumentException]) -ExpectedMessage '*Get-ContainerModuleInspection*'
    }
}

Describe 'Get-ContainerModulePlugin' {
    BeforeEach {
        $pluginRoot = Join-Path $TestDrive 'Plugins'
        foreach ($stage in @(
            'Inspectors'
            'Validators'
            'ObjectModelProcessors'
            'RuntimeAdapters'
            'CodeGenerators'
            'TemplateRenderers'
            'PackagingProviders'
        )) {
            New-Item -Path (Join-Path $pluginRoot $stage) -ItemType Directory -Force |
                Out-Null
        }
    }

    It 'returns plugins in pipeline stage and lexical filename order' {
        Set-Content -LiteralPath (Join-Path $pluginRoot 'Inspectors' '10.ReadmeInspector.ps1') -Value '# plugin'
        Set-Content -LiteralPath (Join-Path $pluginRoot 'Inspectors' '00.DockerfileInspector.ps1') -Value '# plugin'
        Set-Content -LiteralPath (Join-Path $pluginRoot 'Validators' '00.SpecificationValidator.ps1') -Value '# plugin'
        Set-Content -LiteralPath (Join-Path $pluginRoot 'RuntimeAdapters' '00.Runtime.ps1') -Value '# plugin'
        Set-Content -LiteralPath (Join-Path $pluginRoot 'CodeGenerators' '00.Generator.ps1') -Value '# plugin'
        Set-Content -LiteralPath (Join-Path $pluginRoot 'TemplateRenderers' '00.Renderer.ps1') -Value '# plugin'

        $plugins = @(Get-ContainerModulePlugin -Path $pluginRoot)

        $plugins.FileName | Should -Be @(
            '00.DockerfileInspector.ps1'
            '10.ReadmeInspector.ps1'
            '00.SpecificationValidator.ps1'
            '00.Runtime.ps1'
            '00.Generator.ps1'
            '00.Renderer.ps1'
        )
        $plugins.Stage | Should -Be @(
            'Inspectors'
            'Inspectors'
            'Validators'
            'RuntimeAdapters'
            'CodeGenerators'
            'TemplateRenderers'
        )
        $plugins.ExecutionOrder | Should -Be @(0, 1, 2, 3, 4, 5)
        $plugins[0].PSObject.TypeNames | Should -Contain 'SubZeroDev.ContainerPSGenerator.PluginInfo'
    }

    It 'can limit discovery to selected stages' {
        Set-Content -LiteralPath (Join-Path $pluginRoot 'Inspectors' '00.DockerfileInspector.ps1') -Value '# plugin'
        Set-Content -LiteralPath (Join-Path $pluginRoot 'Validators' '00.SpecificationValidator.ps1') -Value '# plugin'

        $plugin = Get-ContainerModulePlugin -Path $pluginRoot -Stage Validators

        $plugin.Stage | Should -Be 'Validators'
        $plugin.Name | Should -Be 'SpecificationValidator'
        $plugin.Prefix | Should -Be 0
    }

    It 'rejects plugin filenames without a numeric ordering prefix' {
        Set-Content -LiteralPath (Join-Path $pluginRoot 'Inspectors' 'DockerfileInspector.ps1') -Value '# plugin'

        { Get-ContainerModulePlugin -Path $pluginRoot } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage "*numeric-prefix*"
    }

    It 'rejects a missing plugin root' {
        { Get-ContainerModulePlugin -Path (Join-Path $TestDrive 'missing') } |
            Should -Throw -ExceptionType ([System.IO.DirectoryNotFoundException]) -ExpectedMessage '*was not found*'
    }
}

Describe 'Container module plugin pipeline' {
    BeforeEach {
        $pluginRoot = Join-Path $TestDrive 'PipelinePlugins'
        if (Test-Path -LiteralPath $pluginRoot) {
            Remove-Item -LiteralPath $pluginRoot -Recurse -Force
        }
        New-Item -Path (Join-Path $pluginRoot 'Inspectors') -ItemType Directory -Force | Out-Null
        New-Item -Path (Join-Path $pluginRoot 'Validators') -ItemType Directory -Force | Out-Null
    }

    It 'invokes plugins in stage and lexical order against a shared context' {
        Set-Content -LiteralPath (Join-Path $pluginRoot 'Inspectors' '10.Second.ps1') -Value @'
param ([psobject] $Context)
$Context.Trace.Add('second')
'@
        Set-Content -LiteralPath (Join-Path $pluginRoot 'Inspectors' '00.First.ps1') -Value @'
param ([psobject] $Context)
$Context.Trace.Add('first')
'@
        Set-Content -LiteralPath (Join-Path $pluginRoot 'Validators' '00.Validate.ps1') -Value @'
param ([psobject] $Context)
$Context.Trace.Add('validate')
'@

        InModuleScope SubZeroDev.ContainerPSGenerator -Parameters @{ PluginRoot = $pluginRoot } {
            param ($PluginRoot)
            $context = [pscustomobject]@{ Trace = [System.Collections.Generic.List[string]]::new() }

            $result = Invoke-ContainerModulePluginPipeline -Context $context -Path $PluginRoot

            [object]::ReferenceEquals($result, $context) | Should -BeTrue
            $context.Trace | Should -Be @('first', 'second', 'validate')
            $context.PluginExecutions.Plugin | Should -Be @('First', 'Second', 'Validate')
            $context.PluginExecutions.Succeeded | Should -Not -Contain $false
            $context.PluginExecutions.Duration | ForEach-Object { $_ | Should -BeOfType ([TimeSpan]) }
        }
    }

    It 'requires plugins to declare the shared context contract' {
        Set-Content -LiteralPath (Join-Path $pluginRoot 'Inspectors' '00.Invalid.ps1') -Value "'no context'"

        InModuleScope SubZeroDev.ContainerPSGenerator -Parameters @{ PluginRoot = $pluginRoot } {
            param ($PluginRoot)
            { Invoke-ContainerModulePluginPipeline -Context ([pscustomobject]@{}) -Path $PluginRoot } |
                Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage "*declare a 'Context' parameter*"
        }
    }

    It 'records and identifies a failed plugin' {
        Set-Content -LiteralPath (Join-Path $pluginRoot 'Inspectors' '00.Fail.ps1') -Value @'
param ([psobject] $Context)
throw 'inspection failed'
'@

        InModuleScope SubZeroDev.ContainerPSGenerator -Parameters @{ PluginRoot = $pluginRoot } {
            param ($PluginRoot)
            $context = [pscustomobject]@{}

            { Invoke-ContainerModulePluginPipeline -Context $context -Path $PluginRoot } |
                Should -Throw -ExceptionType ([System.InvalidOperationException]) -ExpectedMessage "*Plugin 'Fail' in stage 'Inspectors' failed*"
            $context.PluginExecutions.Count | Should -Be 1
            $context.PluginExecutions[0].Succeeded | Should -BeFalse
            $context.PluginExecutions[0].Error | Should -Be 'inspection failed'
        }
    }
}

Describe 'Test-ContainerModuleSpecification' {
    It 'returns true for a valid specification' {
        $specificationPath = Join-Path $TestDrive 'Valid.psd1'
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    Commands = @(
        @{
            Name = 'Invoke-Example'
            Parameters = @(
                @{ Name = 'Message'; Type = 'string'; Mandatory = $true }
            )
        }
    )
}
'@

        Test-ContainerModuleSpecification -Specification $specificationPath | Should -BeTrue
    }

    It 'throws the validator error for an invalid specification' {
        $specificationPath = Join-Path $TestDrive 'Invalid.psd1'
        Set-Content -LiteralPath $specificationPath -Value @'
@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @(@{ Name = 'Message' }) }) }
'@

        { Test-ContainerModuleSpecification -Specification $specificationPath } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage "*non-empty string 'Type'*"
    }

    It 'includes source and object identity context in validation errors' {
        $specificationPath = Join-Path $TestDrive 'InvalidWithIds.psd1'
        Set-Content -LiteralPath $specificationPath -Value @'
@{ Commands = @(@{ Id = 'command.invoke-example'; Name = 'Invoke-Example'; Parameters = @(
    @{ Id = 'parameter.message'; Name = 'Message' }
) }) }
'@

        { Test-ContainerModuleSpecification -Specification $specificationPath } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) `
                -ExpectedMessage "*non-empty string 'Type'*Source: '$specificationPath'*Object Id: 'command.invoke-example', 'parameter.message'*"
    }
}

Describe 'Build-ContainerModule specification loading' {
    BeforeEach {
        New-Item -Path (Join-Path $TestDrive 'PSModule') -ItemType Directory -Force | Out-Null
        Remove-Item -LiteralPath (Join-Path $TestDrive 'PSModule' 'Plugins') -Recurse -Force -ErrorAction SilentlyContinue
        Set-Content -LiteralPath (Join-Path $TestDrive 'PSModule' 'PSModule.psd1') -Value '@{ Commands = @() }'
        Push-Location $TestDrive
    }

    AfterEach {
        Pop-Location
        Remove-Item -LiteralPath (Join-Path $TestDrive 'PSModule' 'Plugins') -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'loads the conventional specification path by default' {
        $artifact = Build-ContainerModule

        $artifact.FullName | Should -Be (Join-Path $TestDrive 'artifacts' 'PSModule' 'Metadata' 'model.json')
    }

    It 'loads an explicitly selected specification' {
        Set-Content -LiteralPath (Join-Path $TestDrive 'Custom.psd1') -Value '@{ Commands = @() }'

        $artifact = Build-ContainerModule -Specification './Custom.psd1' -Output './dist'

        $artifact.FullName | Should -Be (Join-Path $TestDrive 'dist' 'Metadata' 'model.json')
    }

    It 'rejects a missing specification' {
        { Build-ContainerModule -Specification './missing.psd1' } |
            Should -Throw -ExceptionType ([System.IO.FileNotFoundException]) -ExpectedMessage '*Container module specification was not found*'
    }

    It 'rejects a specification that is not a PSD1 file' {
        Set-Content -LiteralPath (Join-Path $TestDrive 'Specification.ps1') -Value '@{ Commands = @() }'

        { Build-ContainerModule -Specification './Specification.ps1' } |
            Should -Throw -ExceptionType ([System.ArgumentException]) -ExpectedMessage "*must be a PowerShell data file with a '.psd1' extension*"
    }

    It 'rejects malformed PSD1 content' {
        Set-Content -LiteralPath (Join-Path $TestDrive 'Invalid.psd1') -Value '@{ Commands = '

        { Build-ContainerModule -Specification './Invalid.psd1' } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage '*is not a valid PowerShell data file*'
    }

    It 'automatically invokes every conventional plugin stage at its build boundary' {
        $pluginRoot = Join-Path $TestDrive 'PSModule' 'Plugins'
        $tracePath = Join-Path $TestDrive 'plugin-trace.txt'
        $stages = @(
            'Inspectors'
            'Validators'
            'ObjectModelProcessors'
            'RuntimeAdapters'
            'CodeGenerators'
            'TemplateRenderers'
            'PackagingProviders'
        )

        foreach ($stage in $stages) {
            $stagePath = New-Item -Path (Join-Path $pluginRoot $stage) -ItemType Directory -Force
            Set-Content -LiteralPath (Join-Path $stagePath.FullName "00.$stage.ps1") -Value @"
param ([psobject] `$Context)
Add-Content -LiteralPath '$tracePath' -Value '$stage'
"@
        }

        $null = Build-ContainerModule

        Get-Content -LiteralPath $tracePath | Should -Be $stages
    }

    It 'runs built-in validation, model normalization, and generation through ordered plugins' {
        Set-Content -LiteralPath (
            Join-Path $TestDrive 'PSModule' 'PSModule.psd1'
        ) -Value @'
@{
    Commands = @(
        @{ Name = 'Invoke-First'; Parameters = @() }
        @{ Name = 'Invoke-Second'; Parameters = @() }
    )
}
'@

        $context = InModuleScope SubZeroDev.ContainerPSGenerator -Parameters @{
            SpecificationPath = Join-Path $TestDrive 'PSModule' 'PSModule.psd1'
            OutputPath = Join-Path $TestDrive 'generated'
            ModuleRoot = Split-Path $manifestPath -Parent
        } {
            param ($SpecificationPath, $OutputPath, $ModuleRoot)
            $context = New-ContainerModuleBuildContext `
                -SpecificationPath $SpecificationPath `
                -OutputPath $OutputPath
            $pluginRoot = Join-Path $ModuleRoot 'Plugins'

            $null = Invoke-ContainerModulePluginPipeline `
                -Context $context `
                -Path $pluginRoot `
                -Stage Validators, ObjectModelProcessors, RuntimeAdapters
            Reset-ContainerModuleOutput -Context $context
            $null = Invoke-ContainerModulePluginPipeline `
                -Context $context `
                -Path $pluginRoot `
                -Stage CodeGenerators
            $null = Invoke-ContainerModulePluginPipeline `
                -Context $context `
                -Path $pluginRoot `
                -Stage TemplateRenderers
            $null = Invoke-ContainerModulePluginPipeline `
                -Context $context `
                -Path $pluginRoot `
                -Stage PackagingProviders
            $context
        }

        $context.PluginExecutions.Stage | Should -Be @(
            'Validators'
            'ObjectModelProcessors'
            'RuntimeAdapters'
            'CodeGenerators'
            'CodeGenerators'
            'CodeGenerators'
            'CodeGenerators'
            'CodeGenerators'
            'TemplateRenderers'
            'TemplateRenderers'
            'TemplateRenderers'
            'TemplateRenderers'
            'TemplateRenderers'
            'PackagingProviders'
        )
        $context.PluginExecutions.Plugin | Should -Be @(
            'SpecificationValidator'
            'SpecificationModelProcessor'
            'DockerRuntimeAdapter'
            'MetadataGenerator'
            'CommandSourceGenerator'
            'CommandDocumentationGenerator'
            'LoaderGenerator'
            'ManifestGenerator'
            'MetadataRenderer'
            'CommandSourceRenderer'
            'CommandDocumentationRenderer'
            'LoaderRenderer'
            'ManifestRenderer'
            'PSModulePackagingProvider'
        )
        $context.Model.PSObject.TypeNames | Should -Contain 'SubZeroDev.ContainerPSGenerator.Model'
        $context.Model.Commands.RuntimeAdapter | Should -Be @('Docker', 'Docker')
        $context.RenderRequests | Should -Be @(
            'Metadata'
            'CommandSource'
            'CommandDocumentation'
            'Loader'
            'Manifest'
        )
        $context.Artifacts.Metadata.FullName | Should -Be (
            Join-Path $context.OutputPath 'Metadata' 'model.json'
        )
        $context.Artifacts.Manifest.FullName | Should -Be (
            Join-Path $context.OutputPath 'PSModule.psd1'
        )
        $context.Artifacts.Package.FullName | Should -Be $context.OutputPath
        $context.Artifacts.Package.PSObject.TypeNames |
            Should -Contain 'SubZeroDev.ContainerPSGenerator.PackageArtifact'
    }

    It 'uses explicitly selected plugin roots' {
        $pluginRoot = Join-Path $TestDrive 'CustomPlugins'
        $stagePath = New-Item -Path (Join-Path $pluginRoot 'Inspectors') -ItemType Directory -Force
        $markerPath = Join-Path $TestDrive 'explicit-plugin.txt'
        Set-Content -LiteralPath (Join-Path $stagePath.FullName '00.Explicit.ps1') -Value @"
param ([psobject] `$Context)
Set-Content -LiteralPath '$markerPath' -Value 'invoked'
"@

        $null = Build-ContainerModule -PluginPath $pluginRoot

        Get-Content -LiteralPath $markerPath | Should -Be 'invoked'
    }

    It 'validates the object-model boundary before invoking runtime adapters' {
        $pluginRoot = Join-Path $TestDrive 'ObjectModelBoundaryPlugins'
        $processorPath = New-Item -Path (
            Join-Path $pluginRoot 'ObjectModelProcessors'
        ) -ItemType Directory -Force
        $adapterPath = New-Item -Path (
            Join-Path $pluginRoot 'RuntimeAdapters'
        ) -ItemType Directory -Force
        $adapterMarker = Join-Path $TestDrive 'runtime-adapter-ran.txt'
        Set-Content -LiteralPath (
            Join-Path $processorPath.FullName '99.RemoveModel.ps1'
        ) -Value @'
param ([psobject] $Context)
$Context.Model = $null
'@
        Set-Content -LiteralPath (
            Join-Path $adapterPath.FullName '99.WriteMarker.ps1'
        ) -Value @"
param ([psobject] `$Context)
Set-Content -LiteralPath '$adapterMarker' -Value 'adapted'
"@

        {
            Build-ContainerModule -PluginPath $pluginRoot
        } | Should -Throw '*object-model processor stage did not produce*'
        Test-Path -LiteralPath $adapterMarker | Should -BeFalse
    }

    It 'validates rendered artifacts before invoking packaging providers' {
        $pluginRoot = Join-Path $TestDrive 'ArtifactValidationPlugins'
        $rendererPath = New-Item -Path (
            Join-Path $pluginRoot 'TemplateRenderers'
        ) -ItemType Directory -Force
        $packagingPath = New-Item -Path (
            Join-Path $pluginRoot 'PackagingProviders'
        ) -ItemType Directory -Force
        $packagingMarker = Join-Path $TestDrive 'packaging-ran.txt'
        Set-Content -LiteralPath (
            Join-Path $rendererPath.FullName '99.RemoveMetadata.ps1'
        ) -Value @'
param ([psobject] $Context)
$Context.Artifacts.Remove('Metadata')
'@
        Set-Content -LiteralPath (
            Join-Path $packagingPath.FullName '00.WriteMarker.ps1'
        ) -Value @"
param ([psobject] `$Context)
Set-Content -LiteralPath '$packagingMarker' -Value 'packaged'
"@

        {
            Build-ContainerModule -PluginPath $pluginRoot
        } | Should -Throw '*template-renderer stage did not produce the metadata artifact*'
        Test-Path -LiteralPath $packagingMarker | Should -BeFalse
    }

    It 'rejects an incomplete generated PSModule package' {
        $pluginRoot = Join-Path $TestDrive 'IncompletePackagePlugins'
        $rendererPath = New-Item -Path (
            Join-Path $pluginRoot 'TemplateRenderers'
        ) -ItemType Directory -Force
        Set-Content -LiteralPath (
            Join-Path $rendererPath.FullName '99.RemoveLoader.ps1'
        ) -Value @'
param ([psobject] $Context)
Remove-Item -LiteralPath (
    Join-Path $Context.OutputPath "$($Context.Model.ModuleName).psm1"
) -Force
'@

        {
            Build-ContainerModule -PluginPath $pluginRoot
        } | Should -Throw "*PSModulePackagingProvider*package is incomplete*Loader*was not found*"
    }

    It 'rejects an explicitly selected missing plugin root' {
        { Build-ContainerModule -PluginPath (Join-Path $TestDrive 'MissingPlugins') } |
            Should -Throw -ExceptionType ([System.IO.DirectoryNotFoundException]) -ExpectedMessage '*Plugin root*was not found*'
    }
}

Describe 'Container module build context' {
    BeforeAll {
        $specificationPath = Join-Path $TestDrive 'Specification.psd1'
        Set-Content -LiteralPath $specificationPath -Value '@{ Commands = @(@{ Name = ''Invoke-Example'' }) }'
    }

    It 'normalizes build paths and carries the imported specification' {
        InModuleScope SubZeroDev.ContainerPSGenerator -Parameters @{
            SpecificationPath = $specificationPath
            OutputPath = Join-Path $TestDrive 'generated' '..' 'output'
        } {
            param ($SpecificationPath, $OutputPath)

            $context = New-ContainerModuleBuildContext `
                -SpecificationPath $SpecificationPath `
                -OutputPath $OutputPath

            $context.PSObject.TypeNames | Should -Contain 'SubZeroDev.ContainerPSGenerator.BuildContext'
            $context.SpecificationPath | Should -Be ([System.IO.Path]::GetFullPath($SpecificationPath))
            $context.OutputPath | Should -Be ([System.IO.Path]::GetFullPath($OutputPath))
            $context.RepositoryPath | Should -Be (Split-Path $SpecificationPath -Parent)
            $context.Specification.Commands[0].Name | Should -Be 'Invoke-Example'
            $context.Inspection.Count | Should -Be 0
        }
    }

    It 'does not create the output directory while constructing the context' {
        $outputPath = Join-Path $TestDrive 'not-created'

        InModuleScope SubZeroDev.ContainerPSGenerator -Parameters @{
            SpecificationPath = $specificationPath
            OutputPath = $outputPath
        } {
            param ($SpecificationPath, $OutputPath)

            $null = New-ContainerModuleBuildContext `
                -SpecificationPath $SpecificationPath `
                -OutputPath $OutputPath

            Test-Path -LiteralPath $OutputPath | Should -BeFalse
        }
    }
}

Describe 'Dockerfile inspection' {
    BeforeEach {
        Remove-Item -LiteralPath (Join-Path $TestDrive 'Dockerfile') -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath (Join-Path $TestDrive 'tools.Dockerfile') -Force -ErrorAction SilentlyContinue
        New-Item -Path (Join-Path $TestDrive 'PSModule') -ItemType Directory -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $TestDrive 'PSModule' 'PSModule.psd1') -Value '@{ Commands = @() }'
        Push-Location $TestDrive
    }

    AfterEach {
        Pop-Location
    }

    It 'persists ordered multi-stage Dockerfile metadata' {
        Set-Content -LiteralPath (Join-Path $TestDrive 'Dockerfile') -Value @'
FROM --platform=linux/amd64 mcr.microsoft.com/dotnet/sdk:8.0 AS build
RUN dotnet build
FROM mcr.microsoft.com/dotnet/runtime:8.0 AS final
'@
        Set-Content -LiteralPath (Join-Path $TestDrive 'tools.Dockerfile') -Value 'FROM alpine:3.20'

        $artifact = Build-ContainerModule
        $metadata = Get-Content -LiteralPath $artifact.FullName -Raw | ConvertFrom-Json

        $metadata.Inspection.Dockerfiles.Path | Should -Be @('Dockerfile', 'tools.Dockerfile')
        $metadata.Inspection.Dockerfiles[0].Stages[0].Image | Should -Be 'mcr.microsoft.com/dotnet/sdk:8.0'
        $metadata.Inspection.Dockerfiles[0].Stages[0].Alias | Should -Be 'build'
        $metadata.Inspection.Dockerfiles[0].Stages[0].Platform | Should -Be 'linux/amd64'
        $metadata.Inspection.Dockerfiles[0].Stages[1].Alias | Should -Be 'final'
        $metadata.Inspection.Dockerfiles[1].Stages[0].Image | Should -Be 'alpine:3.20'
    }

    It 'persists an empty collection when no Dockerfile exists' {
        $artifact = Build-ContainerModule
        $metadata = Get-Content -LiteralPath $artifact.FullName -Raw | ConvertFrom-Json

        @($metadata.Inspection.Dockerfiles).Count | Should -Be 0
    }
}

Describe 'Docker Compose inspection' {
    BeforeEach {
        foreach ($name in @('compose.yaml', 'compose.yml', 'docker-compose.yaml', 'docker-compose.yml')) {
            Remove-Item -LiteralPath (Join-Path $TestDrive $name) -Force -ErrorAction SilentlyContinue
        }
        New-Item -Path (Join-Path $TestDrive 'PSModule') -ItemType Directory -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $TestDrive 'PSModule' 'PSModule.psd1') -Value '@{ Commands = @() }'
        Push-Location $TestDrive
    }

    AfterEach {
        Pop-Location
    }

    It 'persists ordered Compose service runtime and build metadata' {
        Set-Content -LiteralPath (Join-Path $TestDrive 'compose.yaml') -Value @'
services:
  api:
    build:
      context: .
      dockerfile: src/Api.Dockerfile
    ports:
      - "8080:80"
      - 8443:443
  worker:
    image: ghcr.io/example/worker:latest
'@
        Set-Content -LiteralPath (Join-Path $TestDrive 'docker-compose.yml') -Value @'
services:
  tools:
    build: ./tools
'@

        $artifact = Build-ContainerModule
        $metadata = Get-Content -LiteralPath $artifact.FullName -Raw | ConvertFrom-Json

        $metadata.Inspection.ComposeFiles.Path | Should -Be @('compose.yaml', 'docker-compose.yml')
        $api = $metadata.Inspection.ComposeFiles[0].Services[0]
        $api.Name | Should -Be 'api'
        $api.Build.Context | Should -Be '.'
        $api.Build.Dockerfile | Should -Be 'src/Api.Dockerfile'
        $api.Ports | Should -Be @('8080:80', '8443:443')
        $metadata.Inspection.ComposeFiles[0].Services[1].Image | Should -Be 'ghcr.io/example/worker:latest'
        $metadata.Inspection.ComposeFiles[1].Services[0].Build.Context | Should -Be './tools'
    }

    It 'persists an empty collection when no Compose file exists' {
        $artifact = Build-ContainerModule
        $metadata = Get-Content -LiteralPath $artifact.FullName -Raw | ConvertFrom-Json

        @($metadata.Inspection.ComposeFiles).Count | Should -Be 0
    }
}

Describe 'Project manifest inspection' {
    BeforeEach {
        Remove-Item -LiteralPath (Join-Path $TestDrive 'src') -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath (Join-Path $TestDrive 'node_modules') -Recurse -Force -ErrorAction SilentlyContinue
        New-Item -Path (Join-Path $TestDrive 'PSModule') -ItemType Directory -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $TestDrive 'PSModule' 'PSModule.psd1') -Value '@{ Commands = @() }'
        Push-Location $TestDrive
    }

    AfterEach {
        Pop-Location
    }

    It 'persists .NET and Node project metadata in normalized path order' {
        $dotNetPath = New-Item -Path (Join-Path $TestDrive 'src' 'Api') -ItemType Directory -Force
        Set-Content -LiteralPath (Join-Path $dotNetPath.FullName 'Api.csproj') -Value @'
<Project Sdk="Microsoft.NET.Sdk.Web">
  <PropertyGroup>
    <TargetFrameworks>net8.0;net9.0</TargetFrameworks>
    <OutputType>Exe</OutputType>
    <AssemblyName>Example.Api</AssemblyName>
    <PackageId>Example.Api.Package</PackageId>
    <NukeRootDirectory>../..</NukeRootDirectory>
    <NukeScriptDirectory>../build</NukeScriptDirectory>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Serilog" Version="3.1.1" />
    <PackageReference Include="Example.Package"><Version>1.2.3</Version></PackageReference>
    <ProjectReference Include="../Common/Common.csproj" Aliases="CommonAlias;SharedAlias" />
    <ProjectReference Include="../../../outside.csproj" />
  </ItemGroup>
</Project>
'@
        $commonPath = New-Item -Path (Join-Path $TestDrive 'src' 'Common') -ItemType Directory -Force
        Set-Content -LiteralPath (Join-Path $commonPath.FullName 'Common.csproj') -Value @'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup><TargetFramework>net8.0</TargetFramework></PropertyGroup>
</Project>
'@
        $testPath = New-Item -Path (Join-Path $TestDrive 'src' 'Api.Tests') -ItemType Directory -Force
        Set-Content -LiteralPath (Join-Path $testPath.FullName 'Api.Tests.csproj') -Value @'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup><TargetFramework>net8.0</TargetFramework><IsTestProject>true</IsTestProject></PropertyGroup>
</Project>
'@
        $nodePath = New-Item -Path (Join-Path $TestDrive 'src' 'Web') -ItemType Directory -Force
        Set-Content -LiteralPath (Join-Path $nodePath.FullName 'package.json') -Value @'
{
  "name": "example-web",
  "version": "1.0.0",
  "private": true,
  "packageManager": "pnpm@9.0.0",
  "scripts": { "test": "vitest", "build": "vite build" },
  "dependencies": { "react": "latest", "axios": "latest" },
  "devDependencies": { "vite": "latest" }
}
'@
        $ignoredPath = New-Item -Path (Join-Path $TestDrive 'node_modules' 'ignored') -ItemType Directory -Force
        Set-Content -LiteralPath (Join-Path $ignoredPath.FullName 'package.json') -Value '{ "name": "ignored" }'

        $artifact = Build-ContainerModule
        $metadata = Get-Content -LiteralPath $artifact.FullName -Raw | ConvertFrom-Json

        $dotNet = $metadata.Inspection.DotNetProjects | Where-Object Name -eq 'Example.Api'
        $dotNet.Path | Should -Be 'src/Api/Api.csproj'
        $dotNet.Name | Should -Be 'Example.Api'
        $dotNet.Sdk | Should -Be 'Microsoft.NET.Sdk.Web'
        $dotNet.TargetFrameworks | Should -Be @('net8.0', 'net9.0')
        $dotNet.IsExecutable | Should -BeTrue
        $dotNet.IsTestProject | Should -BeFalse
        $dotNet.NukeRootDirectory | Should -Be '../..'
        $dotNet.NukeScriptDirectory | Should -Be '../build'
        $dotNet.PackageReferences.Name | Should -Be @('Serilog', 'Example.Package')
        $dotNet.PackageReferences.Version | Should -Be @('3.1.1', '1.2.3')
        $dotNet.ProjectReferences.Path | Should -Be 'src/Common/Common.csproj'
        $dotNet.ProjectReferences.Aliases | Should -Be @('CommonAlias', 'SharedAlias')

        $testProject = $metadata.Inspection.DotNetProjects | Where-Object Name -eq 'Api.Tests'
        $testProject.IsTestProject | Should -BeTrue
        $testProject.IsExecutable | Should -BeFalse

        $node = $metadata.Inspection.NodeProjects[0]
        $node.Path | Should -Be 'src/Web/package.json'
        $node.Name | Should -Be 'example-web'
        $node.Private | Should -BeTrue
        $node.Scripts | Should -Be @('build', 'test')
        $node.Dependencies | Should -Be @('axios', 'react')
        $metadata.Inspection.NodeProjects.Count | Should -Be 1
    }

    It 'persists empty collections when no supported project manifests exist' {
        $artifact = Build-ContainerModule
        $metadata = Get-Content -LiteralPath $artifact.FullName -Raw | ConvertFrom-Json

        @($metadata.Inspection.DotNetProjects).Count | Should -Be 0
        @($metadata.Inspection.NodeProjects).Count | Should -Be 0
    }
}

Describe 'README inspection' {
    BeforeEach {
        foreach ($name in @('README.md', 'README.markdown', 'README.txt', 'README')) {
            Remove-Item -LiteralPath (Join-Path $TestDrive $name) -Force -ErrorAction SilentlyContinue
        }
        New-Item -Path (Join-Path $TestDrive 'PSModule') -ItemType Directory -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $TestDrive 'PSModule' 'PSModule.psd1') -Value '@{ Commands = @() }'
        Push-Location $TestDrive
    }

    AfterEach {
        Pop-Location
    }

    It 'persists ordered README headings and fenced-code languages' {
        Set-Content -LiteralPath (Join-Path $TestDrive 'README.md') -Value @'
# Example Tool

## Install

```powershell
Install-Module Example
# Not a heading
```

### Usage

~~~
unlabelled
~~~
'@
        Set-Content -LiteralPath (Join-Path $TestDrive 'README.txt') -Value "Plain text title`nDetails"

        $artifact = Build-ContainerModule
        $metadata = Get-Content -LiteralPath $artifact.FullName -Raw | ConvertFrom-Json

        $metadata.Inspection.Readmes.Path | Should -Be @('README.md', 'README.txt')
        $markdown = $metadata.Inspection.Readmes[0]
        $markdown.Title | Should -Be 'Example Tool'
        $markdown.Headings.Level | Should -Be @(1, 2, 3)
        $markdown.Headings.Text | Should -Be @('Example Tool', 'Install', 'Usage')
        $markdown.CodeLanguages[0] | Should -Be 'powershell'
        $markdown.CodeLanguages.Count | Should -Be 2
        $null -eq $markdown.CodeLanguages[1] | Should -BeTrue
        $metadata.Inspection.Readmes[1].Title | Should -Be 'Plain text title'
    }

    It 'persists an empty collection when no root README exists' {
        $artifact = Build-ContainerModule
        $metadata = Get-Content -LiteralPath $artifact.FullName -Raw | ConvertFrom-Json

        @($metadata.Inspection.Readmes).Count | Should -Be 0
    }
}

Describe 'Remaining repository inspector chain' {
    BeforeEach {
        foreach ($path in @('.github', '.nuke', 'build', 'scripts', 'schemas', 'api')) {
            Remove-Item -LiteralPath (Join-Path $TestDrive $path) -Recurse -Force -ErrorAction SilentlyContinue
        }
        New-Item -Path (Join-Path $TestDrive 'PSModule') -ItemType Directory -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $TestDrive 'PSModule' 'PSModule.psd1') -Value '@{ Commands = @() }'
        Push-Location $TestDrive
    }

    AfterEach { Pop-Location }

    It 'persists PowerShell, workflow, NUKE, schema, and OpenAPI metadata' {
        Set-Content -LiteralPath (Join-Path $TestDrive 'root-tool.ps1') -Value @'
param([Parameter(Mandatory)][string] $Name)
'@
        $scripts = New-Item -Path (Join-Path $TestDrive 'scripts') -ItemType Directory -Force
        Set-Content -LiteralPath (Join-Path $scripts.FullName 'run-tool.ps1') -Value 'param([switch] $Force)'
        Set-Content -LiteralPath (Join-Path $scripts.FullName 'Tools.psm1') -Value @'
class ToolOptions {}
function Invoke-Tool { param() }
'@

        $workflows = New-Item -Path (Join-Path $TestDrive '.github' 'workflows') -ItemType Directory -Force
        Set-Content -LiteralPath (Join-Path $workflows.FullName 'ci.yml') -Value @'
name: CI
on:
  push:
  pull_request:
jobs:
  test:
    runs-on: ubuntu-latest
'@

        $nuke = New-Item -Path (Join-Path $TestDrive '.nuke') -ItemType Directory -Force
        Set-Content -LiteralPath (Join-Path $nuke.FullName 'parameters.json') -Value @'
{ "$schema": "build.schema.json", "Configuration": "Release" }
'@
        Set-Content -LiteralPath (Join-Path $nuke.FullName 'build.schema.json') -Value @'
{
  "definitions": {
    "ExecutableTarget": { "type": "string", "enum": ["Test", "Build"] },
    "Configuration": { "type": "string", "enum": ["Debug", "Release"] },
    "NukeBuild": {
      "properties": {
        "Configuration": {
          "description": "Build configuration.",
          "$ref": "#/definitions/Configuration"
        },
        "Target": {
          "type": "array",
          "description": "Targets to execute.",
          "items": { "$ref": "#/definitions/ExecutableTarget" }
        }
      }
    }
  },
  "allOf": [
    {
      "properties": {
        "RegistryToken": {
          "type": "string",
          "description": "Registry token.",
          "default": "Secrets must be entered separately"
        },
        "Tags": {
          "type": "array",
          "description": "Image tags.",
          "items": { "type": "string" }
        }
      }
    },
    { "$ref": "#/definitions/NukeBuild" }
  ]
}
'@
        $build = New-Item -Path (Join-Path $TestDrive 'build') -ItemType Directory -Force
        Set-Content -LiteralPath (Join-Path $build.FullName 'Build.csproj') -Value @'
<Project Sdk="Microsoft.NET.Sdk"><ItemGroup><PackageReference Include="Nuke.Common" Version="8.0.0" /></ItemGroup></Project>
'@
        Set-Content -LiteralPath (Join-Path $build.FullName 'build.ps1') -Value 'function Invoke-Build { }'

        $schemas = New-Item -Path (Join-Path $TestDrive 'schemas') -ItemType Directory -Force
        Set-Content -LiteralPath (Join-Path $schemas.FullName 'settings.schema.json') -Value @'
{ "$schema": "https://json-schema.org/draft/2020-12/schema", "$id": "example.settings", "title": "Settings", "type": "object", "required": ["name"], "properties": { "port": {}, "name": {} } }
'@
        $api = New-Item -Path (Join-Path $TestDrive 'api') -ItemType Directory -Force
        Set-Content -LiteralPath (Join-Path $api.FullName 'openapi.json') -Value @'
{ "openapi": "3.1.0", "info": { "title": "Example API", "version": "1.2.0" }, "paths": { "/users": {}, "/health": {} } }
'@

        $artifact = Build-ContainerModule
        $inspection = (Get-Content -LiteralPath $artifact.FullName -Raw | ConvertFrom-Json).Inspection

        $powerShell = $inspection.PowerShellFiles | Where-Object Path -eq 'scripts/Tools.psm1'
        $powerShell.Functions | Should -Be @('Invoke-Tool')
        $powerShell.Classes | Should -Be @('ToolOptions')
        $powerShell.ParseErrors.Count | Should -Be 0

        $rootCommand = $inspection.PowerShellFiles | Where-Object Path -eq 'root-tool.ps1'
        $rootCommand | Should -BeNullOrEmpty

        $scriptCommand = $inspection.PowerShellFiles | Where-Object Path -eq 'scripts/run-tool.ps1'
        $scriptCommand.IsCommandCandidate | Should -BeTrue
        $scriptCommand.SuggestedCommandName | Should -Be 'Invoke-RunTool'

        $powerShell.IsCommandCandidate | Should -BeFalse
        $inspection.GitHubActions[0].Name | Should -Be 'CI'
        $inspection.GitHubActions[0].Triggers | Should -Be @('push', 'pull_request')
        $inspection.GitHubActions[0].Jobs | Should -Be @('test')

        $inspection.Nuke.IsConfigured | Should -BeTrue
        $inspection.Nuke.SchemaPath | Should -Be '.nuke/build.schema.json'
        $inspection.Nuke.ParameterNames | Should -Be @('Configuration', 'RegistryToken', 'Tags', 'Target')
        $inspection.Nuke.ConfiguredParameterNames | Should -Be @('Configuration')
        $inspection.Nuke.Targets | Should -Be @('Build', 'Test')
        $inspection.Nuke.ProjectPaths | Should -Be @('build/Build.csproj')
        $inspection.Nuke.BuildScripts | Should -Be @('build/build.ps1')
        $configurationParameter = $inspection.Nuke.Parameters |
            Where-Object Name -eq 'Configuration'
        $configurationParameter.Type | Should -Be 'string'
        $configurationParameter.Enum | Should -Be @('Debug', 'Release')
        $targetParameter = $inspection.Nuke.Parameters | Where-Object Name -eq 'Target'
        $targetParameter.Type | Should -Be 'array'
        $targetParameter.ItemType | Should -Be 'string'
        $targetParameter.ItemEnum | Should -Be @('Test', 'Build')
        ($inspection.Nuke.Parameters | Where-Object Name -eq 'Tags').ItemType |
            Should -Be 'string'

        $schema = $inspection.ConfigurationSchemas | Where-Object Id -eq 'example.settings'
        $schema.Id | Should -Be 'example.settings'
        $schema.Required | Should -Be @('name')
        $schema.Properties | Should -Be @('name', 'port')

        $openApi = $inspection.OpenApiDocuments[0]
        $openApi.SpecificationVersion | Should -Be '3.1.0'
        $openApi.Title | Should -Be 'Example API'
        $openApi.Paths | Should -Be @('/health', '/users')
    }

    It 'does not inspect files inside nested Git repositories' {
        $nestedPath = New-Item -Path (Join-Path $TestDrive 'nested') -ItemType Directory -Force
        Set-Content -LiteralPath (Join-Path $nestedPath '.git') -Value 'gitdir: ../.git/modules/nested'
        Set-Content -LiteralPath (Join-Path $nestedPath 'invalid.schema.json') -Value 'definitely not json'
        Set-Content -LiteralPath (Join-Path $nestedPath 'Nested.ps1') -Value 'function Invoke-Nested { }'

        $artifact = Build-ContainerModule
        $inspection = (Get-Content -LiteralPath $artifact.FullName -Raw | ConvertFrom-Json).Inspection

        @($inspection.ConfigurationSchemas).Count | Should -Be 0
        $inspection.PowerShellFiles.Path | Should -Not -Contain 'nested/Nested.ps1'
    }

    It 'persists schemas with missing, empty, or null property collections' {
        $schemas = New-Item -Path (Join-Path $TestDrive 'schemas') -ItemType Directory -Force
        Set-Content -LiteralPath (Join-Path $schemas.FullName 'missing.schema.json') -Value @'
{ "$schema": "https://json-schema.org/draft/2020-12/schema", "type": "string" }
'@
        Set-Content -LiteralPath (Join-Path $schemas.FullName 'empty.schema.json') -Value @'
{ "$schema": "https://json-schema.org/draft/2020-12/schema", "properties": {}, "required": [] }
'@
        Set-Content -LiteralPath (Join-Path $schemas.FullName 'null.schema.json') -Value @'
{ "$schema": "https://json-schema.org/draft/2020-12/schema", "properties": null, "required": null }
'@
        Set-Content -LiteralPath (Join-Path $schemas.FullName 'cache.json') -Value 'definitely not json'

        $artifact = Build-ContainerModule
        $inspection = (Get-Content -LiteralPath $artifact.FullName -Raw | ConvertFrom-Json).Inspection

        $inspection.ConfigurationSchemas.Path | Should -Be @(
            'schemas/empty.schema.json'
            'schemas/missing.schema.json'
            'schemas/null.schema.json'
        )
        foreach ($schema in $inspection.ConfigurationSchemas) {
            @($schema.Properties).Count | Should -Be 0
            @($schema.Required).Count | Should -Be 0
        }
    }

    It 'rejects malformed files explicitly named as configuration schemas' {
        $schemas = New-Item -Path (Join-Path $TestDrive 'schemas') -ItemType Directory -Force
        $schemaPath = Join-Path $schemas.FullName 'invalid.schema.json'
        Set-Content -LiteralPath $schemaPath -Value 'definitely not json'

        { Build-ContainerModule } |
            Should -Throw "*Configuration schema '$schemaPath' is not valid JSON*"
    }
}

Describe 'Build-ContainerModule command validation' {
    BeforeEach {
        Push-Location $TestDrive
    }

    AfterEach {
        Pop-Location
    }

    It 'allows a specification with no commands' {
        Set-Content -LiteralPath './Specification.psd1' -Value '@{}'

        { Build-ContainerModule -Specification './Specification.psd1' } | Should -Not -Throw
    }

    It 'requires Commands to be an array' {
        Set-Content -LiteralPath './Specification.psd1' -Value '@{ Commands = @{ Name = ''Invoke-Example'' } }'

        { Build-ContainerModule -Specification './Specification.psd1' } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage "*'Commands' property must be an array*"
    }

    It 'requires each command to be an object' {
        Set-Content -LiteralPath './Specification.psd1' -Value '@{ Commands = @(''Invoke-Example'') }'

        { Build-ContainerModule -Specification './Specification.psd1' } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage '*Command at index 0 must be an object*'
    }

    It 'requires each command to have a non-empty string name' {
        Set-Content -LiteralPath './Specification.psd1' -Value '@{ Commands = @(@{ Name = '' '' }) }'

        { Build-ContainerModule -Specification './Specification.psd1' } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage "*must define a non-empty string 'Name'*"
    }

    It 'rejects case-insensitive duplicate command names' {
        Set-Content -LiteralPath './Specification.psd1' -Value @'
@{
    Commands = @(
        @{ Name = 'Invoke-Example' }
        @{ Name = 'invoke-example' }
    )
}

Describe 'Container module identity validation' {
    It 'rejects an unsafe module name' {
        $specificationPath = Join-Path $TestDrive 'UnsafeModuleName.psd1'
        Set-Content -LiteralPath $specificationPath -Value "@{ ModuleName = '../Unsafe'; Commands = @() }"

        { Test-ContainerModuleSpecification -Specification $specificationPath } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage "*'ModuleName' property must be*"
    }

    It 'rejects an invalid module version' {
        $specificationPath = Join-Path $TestDrive 'InvalidModuleVersion.psd1'
        Set-Content -LiteralPath $specificationPath -Value "@{ ModuleVersion = 'latest'; Commands = @() }"

        { Test-ContainerModuleSpecification -Specification $specificationPath } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage "*'ModuleVersion' property must be a valid version string*"
    }
}
'@

        { Build-ContainerModule -Specification './Specification.psd1' } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage '*defined more than once*'
    }

    It 'requires PowerShell Verb-Noun command syntax' {
        Set-Content -LiteralPath './Specification.psd1' -Value '@{ Commands = @(@{ Name = ''../../Example'' }) }'

        { Build-ContainerModule -Specification './Specification.psd1' } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage '*must use PowerShell Verb-Noun syntax*'
    }
}

Describe 'Build-ContainerModule parameter validation' {
    BeforeEach {
        Push-Location $TestDrive
    }

    AfterEach {
        Pop-Location
    }

    It 'allows a command with no parameters' {
        Set-Content -LiteralPath './Specification.psd1' -Value '@{ Commands = @(@{ Name = ''Invoke-Example'' }) }'

        { Build-ContainerModule -Specification './Specification.psd1' } | Should -Not -Throw
    }

    It 'allows a valid parameter array' {
        Set-Content -LiteralPath './Specification.psd1' -Value @'
@{
    Commands = @(
        @{
            Name = 'Invoke-Example'
            Parameters = @(
                @{ Name = 'Path'; Type = 'string'; Mandatory = $true }
                @{ Name = 'Force'; Type = 'switch' }
            )
        }
    )
}
'@

        { Build-ContainerModule -Specification './Specification.psd1' } | Should -Not -Throw
    }

    It 'requires Parameters to be an array' {
        Set-Content -LiteralPath './Specification.psd1' -Value @'
@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @{ Name = 'Path'; Type = 'string' } }) }
'@

        { Build-ContainerModule -Specification './Specification.psd1' } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage "*'Parameters' property for command 'Invoke-Example' must be an array*"
    }

    It 'requires each parameter to be an object' {
        Set-Content -LiteralPath './Specification.psd1' -Value @'
@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @('Path') }) }
'@

        { Build-ContainerModule -Specification './Specification.psd1' } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage '*Parameter at index 0*must be an object*'
    }

    It 'requires each parameter to have a non-empty string name' {
        Set-Content -LiteralPath './Specification.psd1' -Value @'
@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @(@{ Name = ''; Type = 'string' }) }) }
'@

        { Build-ContainerModule -Specification './Specification.psd1' } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage "*must define a non-empty string 'Name'*"
    }

    It 'requires each parameter to have a non-empty string type' {
        Set-Content -LiteralPath './Specification.psd1' -Value @'
@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @(@{ Name = 'Path' }) }) }
'@

        { Build-ContainerModule -Specification './Specification.psd1' } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage "*must define a non-empty string 'Type'*"
    }

    It 'requires Mandatory to be Boolean when specified' {
        Set-Content -LiteralPath './Specification.psd1' -Value @'
@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @(@{ Name = 'Path'; Type = 'string'; Mandatory = 'yes' }) }) }
'@

        { Build-ContainerModule -Specification './Specification.psd1' } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage "*'Mandatory' property*must be Boolean*"
    }

    It 'rejects case-insensitive duplicate parameter names within a command' {
        Set-Content -LiteralPath './Specification.psd1' -Value @'
@{
    Commands = @(
        @{
            Name = 'Invoke-Example'
            Parameters = @(
                @{ Name = 'Path'; Type = 'string' }
                @{ Name = 'path'; Type = 'string' }
            )
        }
    )
}
'@

        { Build-ContainerModule -Specification './Specification.psd1' } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage '*defined more than once*'
    }

    It 'requires a valid PowerShell parameter identifier' {
        Set-Content -LiteralPath './Specification.psd1' -Value @'
@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @(@{ Name = 'bad-name'; Type = 'string' }) }) }
'@

        { Build-ContainerModule -Specification './Specification.psd1' } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage '*is not a valid PowerShell identifier*'
    }

    It 'requires a supported PowerShell type name' {
        Set-Content -LiteralPath './Specification.psd1' -Value @'
@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @(@{ Name = 'Value'; Type = 'string]; Write-Host bad; [string' }) }) }
'@

        { Build-ContainerModule -Specification './Specification.psd1' } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage '*is not a supported PowerShell type name*'
    }
}

Describe 'Container module mapping validation' {
    It 'allows a valid mappings array' {
        $specificationPath = Join-Path $TestDrive 'ValidMappings.psd1'
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    Commands = @(
        @{
            Name = 'Invoke-Example'
            Parameters = @(
                @{
                    Name = 'Message'
                    Type = 'string'
                    Mappings = @(
                        @{ Type = 'Environment'; Name = 'EXAMPLE_MESSAGE' }
                        @{ Type = 'Argument'; Name = '--message' }
                    )
                }
            )
        }
    )
}
'@

        Test-ContainerModuleSpecification -Specification $specificationPath | Should -BeTrue
    }

    It 'requires Mappings to be an array' {
        $specificationPath = Join-Path $TestDrive 'ScalarMappings.psd1'
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    Commands = @(
        @{ Name = 'Invoke-Example'; Parameters = @(
            @{ Name = 'Message'; Type = 'string'; Mappings = @{ Type = 'Environment' } }
        ) }
    )
}
'@

        { Test-ContainerModuleSpecification -Specification $specificationPath } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage "*'Mappings' property*must be an array*"
    }

    It 'requires each mapping to be an object' {
        $specificationPath = Join-Path $TestDrive 'ScalarMapping.psd1'
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    Commands = @(
        @{ Name = 'Invoke-Example'; Parameters = @(
            @{ Name = 'Message'; Type = 'string'; Mappings = @('Environment') }
        ) }
    )
}
'@

        { Test-ContainerModuleSpecification -Specification $specificationPath } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage '*Mapping at index 0*must be an object*'
    }

    It 'requires each mapping to have a non-empty string type' {
        $specificationPath = Join-Path $TestDrive 'MissingMappingType.psd1'
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    Commands = @(
        @{ Name = 'Invoke-Example'; Parameters = @(
            @{ Name = 'Message'; Type = 'string'; Mappings = @(@{ Name = 'EXAMPLE_MESSAGE' }) }
        ) }
    )
}
'@

        { Test-ContainerModuleSpecification -Specification $specificationPath } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage "*must define a non-empty string 'Type'*"
    }

    It 'rejects unsupported mapping types' {
        $specificationPath = Join-Path $TestDrive 'UnsupportedMapping.psd1'
        Set-Content -LiteralPath $specificationPath -Value @'
@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @(
    @{ Name = 'Value'; Type = 'string'; Mappings = @(@{ Type = 'CustomRuntimeBehavior' }) }
) }) }
'@

        { Test-ContainerModuleSpecification -Specification $specificationPath } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage "*Mapping type 'CustomRuntimeBehavior'*is not supported*"
    }
}

Describe 'Container module object identities' {
    It 'normalizes root, command, and parameter IDs into model metadata' {
        $specificationPath = Join-Path $TestDrive 'Identities.psd1'
        $outputPath = Join-Path $TestDrive 'identity-output'
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    Id = 'module.example'
    Commands = @(@{
        Id = 'command.example'
        Name = 'Invoke-Example'
        Parameters = @(@{ Id = 'parameter.value'; Name = 'Value'; Type = 'string' })
    })
}
'@

        $model = Get-ContainerModuleModel -Specification $specificationPath
        Build-ContainerModule -Specification $specificationPath -Output $outputPath | Out-Null
        $metadata = Get-Content -LiteralPath (Join-Path $outputPath 'Metadata/model.json') -Raw | ConvertFrom-Json

        $model.Id | Should -Be 'module.example'
        $model.Commands[0].Id | Should -Be 'command.example'
        $model.Commands[0].Parameters[0].Id | Should -Be 'parameter.value'
        $metadata.Id | Should -Be 'module.example'
    }

    It 'requires IDs to use the supported identifier syntax' {
        $specificationPath = Join-Path $TestDrive 'InvalidIdentity.psd1'
        Set-Content -LiteralPath $specificationPath -Value "@{ Commands = @(@{ Id = 'command example'; Name = 'Invoke-Example' }) }"

        { Test-ContainerModuleSpecification -Specification $specificationPath } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage "*'Id' property for command*"
    }

    It 'requires IDs to be globally unique without regard to case' {
        $specificationPath = Join-Path $TestDrive 'DuplicateIdentity.psd1'
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    Id = 'shared.identity'
    Commands = @(@{
        Name = 'Invoke-Example'
        Parameters = @(@{ Id = 'SHARED.IDENTITY'; Name = 'Value'; Type = 'string' })
    })
}
'@

        { Test-ContainerModuleSpecification -Specification $specificationPath } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage "*Id 'SHARED.IDENTITY'*defined more than once*"
    }
}

Describe 'Named mapping validation' {
    It 'allows named Argument and Environment mappings' {
        $specificationPath = Join-Path $TestDrive 'NamedMappings.psd1'
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    Commands = @(
        @{ Name = 'Invoke-Example'; Parameters = @(
            @{
                Name = 'Message'
                Type = 'string'
                Mappings = @(
                    @{ Type = 'Argument'; Name = '--message' }
                    @{ Type = 'Environment'; Name = 'EXAMPLE_MESSAGE' }
                )
            }
        ) }
    )
}
'@

        Test-ContainerModuleSpecification -Specification $specificationPath | Should -BeTrue
    }

    It 'requires an Argument mapping name' {
        $specificationPath = Join-Path $TestDrive 'UnnamedArgument.psd1'
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    Commands = @(
        @{ Name = 'Invoke-Example'; Parameters = @(
            @{ Name = 'Message'; Type = 'string'; Mappings = @(@{ Type = 'Argument' }) }
        ) }
    )
}
'@

        { Test-ContainerModuleSpecification -Specification $specificationPath } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage "*'Name' property for Argument mapping*must be a non-empty string*"
    }

    It 'requires an Environment mapping name' {
        $specificationPath = Join-Path $TestDrive 'UnnamedEnvironment.psd1'
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    Commands = @(
        @{ Name = 'Invoke-Example'; Parameters = @(
            @{ Name = 'Message'; Type = 'string'; Mappings = @(@{ Type = 'Environment'; Name = ' ' }) }
        ) }
    )
}
'@

        { Test-ContainerModuleSpecification -Specification $specificationPath } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage "*'Name' property for Environment mapping*must be a non-empty string*"
    }
}

Describe 'Mount mapping validation' {
    It 'allows a Mount mapping with a target and access mode' {
        $specificationPath = Join-Path $TestDrive 'ValidMount.psd1'
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    Commands = @(
        @{ Name = 'Invoke-Example'; Parameters = @(
            @{
                Name = 'Repository'
                Type = 'DirectoryInfo'
                Mappings = @(@{ Type = 'Mount'; Target = '/repository'; Access = 'ReadOnly' })
            }
        ) }
    )
}
'@

        Test-ContainerModuleSpecification -Specification $specificationPath | Should -BeTrue
    }

    It 'requires a Mount mapping target' {
        $specificationPath = Join-Path $TestDrive 'MissingMountTarget.psd1'
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    Commands = @(
        @{ Name = 'Invoke-Example'; Parameters = @(
            @{ Name = 'Repository'; Type = 'DirectoryInfo'; Mappings = @(
                @{ Type = 'Mount'; Access = 'ReadOnly' }
            ) }
        ) }
    )
}
'@

        { Test-ContainerModuleSpecification -Specification $specificationPath } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage "*'Target' property for Mount mapping*must be a non-empty string*"
    }

    It 'requires a Mount mapping access mode' {
        $specificationPath = Join-Path $TestDrive 'MissingMountAccess.psd1'
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    Commands = @(
        @{ Name = 'Invoke-Example'; Parameters = @(
            @{ Name = 'Repository'; Type = 'DirectoryInfo'; Mappings = @(
                @{ Type = 'Mount'; Target = '/repository'; Access = ' ' }
            ) }
        ) }
    )
}
'@

        { Test-ContainerModuleSpecification -Specification $specificationPath } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage "*'Access' property for Mount mapping*must be a non-empty string*"
    }

    It 'rejects an unsupported Mount mapping access mode' {
        $specificationPath = Join-Path $TestDrive 'InvalidMountAccess.psd1'
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    Commands = @(
        @{ Name = 'Invoke-Example'; Parameters = @(
            @{ Name = 'Repository'; Type = 'DirectoryInfo'; Mappings = @(
                @{ Type = 'Mount'; Target = '/repository'; Access = 'OwnerOnly' }
            ) }
        ) }
    )
}
'@

        { Test-ContainerModuleSpecification -Specification $specificationPath } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage "*must be 'ReadOnly' or 'ReadWrite'*"
    }
}

Describe 'Port and working-directory mappings' {
    It 'generates Docker publish and working-directory options before the image' {
        $specificationPath = Join-Path $TestDrive 'RuntimeMappings.psd1'
        $outputPath = Join-Path $TestDrive 'runtime-mapping-output'
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    ModuleName = 'RuntimeMappingExample'
    ContainerImage = 'example/runtime-tool'
    Commands = @(@{ Name = 'Invoke-RuntimeMappingExample'; Parameters = @(
        @{ Name = 'HostPort'; Type = 'int'; Mappings = @(
            @{ Type = 'Port'; ContainerPort = 8080; Protocol = 'udp' }
        ) }
        @{ Name = 'ContainerPath'; Type = 'string'; Mappings = @(
            @{ Type = 'WorkingDirectory' }
        ) }
    ) })
}
'@

        Build-ContainerModule -Specification $specificationPath -Output $outputPath | Out-Null
        $module = Import-Module (Join-Path $outputPath 'RuntimeMappingExample.psd1') -Force -PassThru
        $global:capturedDockerArguments = $null
        function global:docker { $global:capturedDockerArguments = @($args); $global:LASTEXITCODE = 0 }
        try {
            Invoke-RuntimeMappingExample -HostPort 9000 -ContainerPath '/workspace'

            $global:capturedDockerArguments | Should -Be @(
                'run', '--rm', '--publish', '9000:8080/udp',
                '--workdir', '/workspace', 'example/runtime-tool'
            )
        }
        finally {
            Remove-Item Function:\docker -Force
            Remove-Variable capturedDockerArguments -Scope Global -Force
            Remove-Module $module -Force
        }
    }

    It 'rejects invalid bound runtime values before calling Docker' {
        $specificationPath = Join-Path $TestDrive 'RuntimeValues.psd1'
        $outputPath = Join-Path $TestDrive 'runtime-value-output'
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    ModuleName = 'RuntimeValueExample'
    Commands = @(@{ Name = 'Invoke-RuntimeValueExample'; Parameters = @(
        @{ Name = 'HostPort'; Type = 'int'; Mappings = @(
            @{ Type = 'Port'; ContainerPort = 80 }
        ) }
        @{ Name = 'ContainerPath'; Type = 'string'; Mappings = @(
            @{ Type = 'WorkingDirectory' }
        ) }
    ) })
}
'@

        Build-ContainerModule -Specification $specificationPath -Output $outputPath | Out-Null
        $module = Import-Module (Join-Path $outputPath 'RuntimeValueExample.psd1') -Force -PassThru
        $global:dockerWasInvoked = $false
        function global:docker { $global:dockerWasInvoked = $true }
        try {
            { Invoke-RuntimeValueExample -HostPort 70000 } | Should -Throw -ExceptionType ([System.ArgumentOutOfRangeException])
            { Invoke-RuntimeValueExample -ContainerPath ' ' } | Should -Throw -ExceptionType ([System.ArgumentException])
            $global:dockerWasInvoked | Should -BeFalse
        }
        finally {
            Remove-Item Function:\docker -Force
            Remove-Variable dockerWasInvoked -Scope Global -Force
            Remove-Module $module -Force
        }
    }

    It 'rejects malformed runtime mapping definitions' {
        $invalidPortPath = Join-Path $TestDrive 'InvalidPort.psd1'
        $invalidProtocolPath = Join-Path $TestDrive 'InvalidProtocol.psd1'
        $invalidWorkdirTypePath = Join-Path $TestDrive 'InvalidWorkdirType.psd1'
        $duplicateWorkdirPath = Join-Path $TestDrive 'DuplicateWorkdir.psd1'
        Set-Content $invalidPortPath "@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @(@{ Name = 'Port'; Type = 'int'; Mappings = @(@{ Type = 'Port'; ContainerPort = 70000 }) }) }) }"
        Set-Content $invalidProtocolPath "@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @(@{ Name = 'Port'; Type = 'int'; Mappings = @(@{ Type = 'Port'; ContainerPort = 80; Protocol = 'sctp' }) }) }) }"
        Set-Content $invalidWorkdirTypePath "@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @(@{ Name = 'Path'; Type = 'DirectoryInfo'; Mappings = @(@{ Type = 'WorkingDirectory' }) }) }) }"
        Set-Content $duplicateWorkdirPath "@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @(@{ Name = 'One'; Type = 'string'; Mappings = @(@{ Type = 'WorkingDirectory' }) }, @{ Name = 'Two'; Type = 'string'; Mappings = @(@{ Type = 'WorkingDirectory' }) }) }) }"

        { Test-ContainerModuleSpecification $invalidPortPath } | Should -Throw -ExpectedMessage "*'ContainerPort'*1 through 65535*"
        { Test-ContainerModuleSpecification $invalidProtocolPath } | Should -Throw -ExpectedMessage "*'Protocol'*'tcp' or 'udp'*"
        { Test-ContainerModuleSpecification $invalidWorkdirTypePath } | Should -Throw -ExpectedMessage "*WorkingDirectory*must use type 'string'*"
        { Test-ContainerModuleSpecification $duplicateWorkdirPath } | Should -Throw -ExpectedMessage '*at most one WorkingDirectory*'
    }
}

Describe 'Volume and runtime-option mappings' {
    It 'generates named volume mounts and repeated pre-image runtime options' {
        $specificationPath = Join-Path $TestDrive 'VolumeOptions.psd1'
        $outputPath = Join-Path $TestDrive 'volume-option-output'
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    ModuleName = 'VolumeOptionExample'
    ContainerImage = 'example/volume-tool'
    Commands = @(@{ Name = 'Invoke-VolumeOptionExample'; Parameters = @(
        @{ Name = 'Cache'; Type = 'string'; Mappings = @(
            @{ Type = 'Volume'; Target = '/cache'; Access = 'ReadOnly' }
        ) }
        @{ Name = 'Labels'; Type = 'string[]'; Mappings = @(
            @{ Type = 'RuntimeOption'; Name = '--label' }
        ) }
        @{ Name = 'Privileged'; Type = 'switch'; Mappings = @(
            @{ Type = 'RuntimeOption'; Name = '--privileged' }
        ) }
    ) })
}
'@

        Build-ContainerModule -Specification $specificationPath -Output $outputPath | Out-Null
        $module = Import-Module (Join-Path $outputPath 'VolumeOptionExample.psd1') -Force -PassThru
        $global:capturedDockerArguments = $null
        function global:docker { $global:capturedDockerArguments = @($args); $global:LASTEXITCODE = 0 }
        try {
            Invoke-VolumeOptionExample -Cache 'build-cache' -Labels @('team=dev', 'stage=test') -Privileged

            $global:capturedDockerArguments | Should -Be @(
                'run', '--rm', '--mount', 'type=volume,source=build-cache,target=/cache,readonly',
                '--label', 'team=dev', '--label', 'stage=test', '--privileged',
                'example/volume-tool'
            )
        }
        finally {
            Remove-Item Function:\docker -Force
            Remove-Variable capturedDockerArguments -Scope Global -Force
            Remove-Module $module -Force
        }
    }

    It 'rejects an unsafe bound Docker volume name before invocation' {
        $specificationPath = Join-Path $TestDrive 'VolumeValue.psd1'
        $outputPath = Join-Path $TestDrive 'volume-value-output'
        Set-Content -LiteralPath $specificationPath -Value @'
@{ ModuleName = 'VolumeValueExample'; Commands = @(@{ Name = 'Invoke-VolumeValueExample'; Parameters = @(
    @{ Name = 'Cache'; Type = 'string'; Mappings = @(
        @{ Type = 'Volume'; Target = '/cache'; Access = 'ReadWrite' }
    ) }
) }) }
'@

        Build-ContainerModule -Specification $specificationPath -Output $outputPath | Out-Null
        $module = Import-Module (Join-Path $outputPath 'VolumeValueExample.psd1') -Force -PassThru
        $global:dockerWasInvoked = $false
        function global:docker { $global:dockerWasInvoked = $true }
        try {
            { Invoke-VolumeValueExample -Cache '../unsafe' } | Should -Throw -ExceptionType ([System.ArgumentException])
            $global:dockerWasInvoked | Should -BeFalse
        }
        finally {
            Remove-Item Function:\docker -Force
            Remove-Variable dockerWasInvoked -Scope Global -Force
            Remove-Module $module -Force
        }
    }

    It 'rejects malformed volume and runtime-option definitions' {
        $invalidVolumeTypePath = Join-Path $TestDrive 'InvalidVolumeType.psd1'
        $invalidVolumeTargetPath = Join-Path $TestDrive 'InvalidVolumeTarget.psd1'
        $invalidVolumeAccessPath = Join-Path $TestDrive 'InvalidVolumeAccess.psd1'
        $invalidOptionPath = Join-Path $TestDrive 'InvalidRuntimeOption.psd1'
        Set-Content $invalidVolumeTypePath "@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @(@{ Name = 'Volume'; Type = 'int'; Mappings = @(@{ Type = 'Volume'; Target = '/cache'; Access = 'ReadOnly' }) }) }) }"
        Set-Content $invalidVolumeTargetPath "@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @(@{ Name = 'Volume'; Type = 'string'; Mappings = @(@{ Type = 'Volume'; Target = 'cache'; Access = 'ReadOnly' }) }) }) }"
        Set-Content $invalidVolumeAccessPath "@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @(@{ Name = 'Volume'; Type = 'string'; Mappings = @(@{ Type = 'Volume'; Target = '/cache'; Access = 'OwnerOnly' }) }) }) }"
        Set-Content $invalidOptionPath "@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @(@{ Name = 'Network'; Type = 'string'; Mappings = @(@{ Type = 'RuntimeOption'; Name = '-n' }) }) }) }"

        { Test-ContainerModuleSpecification $invalidVolumeTypePath } | Should -Throw -ExpectedMessage "*Volume*mapping*must use type 'string'*"
        { Test-ContainerModuleSpecification $invalidVolumeTargetPath } | Should -Throw -ExpectedMessage "*'Target'*absolute container path*"
        { Test-ContainerModuleSpecification $invalidVolumeAccessPath } | Should -Throw -ExpectedMessage "*'Access'*'ReadOnly' or 'ReadWrite'*"
        { Test-ContainerModuleSpecification $invalidOptionPath } | Should -Throw -ExpectedMessage "*'Name'*RuntimeOption*beginning with '--'*"
    }
}

Describe 'Device and GPU mappings' {
    It 'generates device passthrough and GPU options before the image' {
        $specificationPath = Join-Path $TestDrive 'AcceleratorMappings.psd1'
        $outputPath = Join-Path $TestDrive 'accelerator-output'
        $devicePath = Join-Path $TestDrive 'render-device'
        Set-Content -LiteralPath $devicePath -Value ''
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    ModuleName = 'AcceleratorExample'
    ContainerImage = 'example/accelerator-tool'
    Commands = @(@{ Name = 'Invoke-AcceleratorExample'; Parameters = @(
        @{ Name = 'Device'; Type = 'FileInfo'; Mappings = @(
            @{ Type = 'Device'; Target = '/dev/render'; Permissions = 'rw' }
        ) }
        @{ Name = 'SamePathDevice'; Type = 'FileInfo'; Mappings = @(
            @{ Type = 'Device'; Permissions = 'r' }
        ) }
        @{ Name = 'Gpu'; Type = 'string'; Mappings = @(
            @{ Type = 'Gpu' }
        ) }
    ) })
}
'@

        Build-ContainerModule -Specification $specificationPath -Output $outputPath | Out-Null
        $module = Import-Module (Join-Path $outputPath 'AcceleratorExample.psd1') -Force -PassThru
        $global:capturedDockerArguments = $null
        function global:docker { $global:capturedDockerArguments = @($args); $global:LASTEXITCODE = 0 }
        try {
            Invoke-AcceleratorExample -Device $devicePath -SamePathDevice $devicePath -Gpu 'device=0,1'

            $global:capturedDockerArguments | Should -Be @(
                'run', '--rm', '--device', ([System.IO.Path]::GetFullPath($devicePath) + ':/dev/render:rw'),
                '--device', ([System.IO.Path]::GetFullPath($devicePath) + ':' + [System.IO.Path]::GetFullPath($devicePath) + ':r'),
                '--gpus', 'device=0,1', 'example/accelerator-tool'
            )
        }
        finally {
            Remove-Item Function:\docker -Force
            Remove-Variable capturedDockerArguments -Scope Global -Force
            Remove-Module $module -Force
        }
    }

    It 'rejects an unsafe GPU selection before invoking Docker' {
        $specificationPath = Join-Path $TestDrive 'GpuValue.psd1'
        $outputPath = Join-Path $TestDrive 'gpu-value-output'
        Set-Content -LiteralPath $specificationPath -Value @'
@{ ModuleName = 'GpuValueExample'; Commands = @(@{ Name = 'Invoke-GpuValueExample'; Parameters = @(
    @{ Name = 'Gpu'; Type = 'string'; Mappings = @(@{ Type = 'Gpu' }) }
) }) }
'@

        Build-ContainerModule -Specification $specificationPath -Output $outputPath | Out-Null
        $module = Import-Module (Join-Path $outputPath 'GpuValueExample.psd1') -Force -PassThru
        $global:dockerWasInvoked = $false
        function global:docker { $global:dockerWasInvoked = $true }
        try {
            { Invoke-GpuValueExample -Gpu '--privileged' } | Should -Throw -ExceptionType ([System.ArgumentException])
            $global:dockerWasInvoked | Should -BeFalse
        }
        finally {
            Remove-Item Function:\docker -Force
            Remove-Variable dockerWasInvoked -Scope Global -Force
            Remove-Module $module -Force
        }
    }

    It 'rejects malformed device and GPU mapping definitions' {
        $invalidDeviceTypePath = Join-Path $TestDrive 'InvalidDeviceType.psd1'
        $invalidDeviceTargetPath = Join-Path $TestDrive 'InvalidDeviceTarget.psd1'
        $invalidPermissionsPath = Join-Path $TestDrive 'InvalidDevicePermissions.psd1'
        $invalidGpuTypePath = Join-Path $TestDrive 'InvalidGpuType.psd1'
        Set-Content $invalidDeviceTypePath "@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @(@{ Name = 'Device'; Type = 'int'; Mappings = @(@{ Type = 'Device' }) }) }) }"
        Set-Content $invalidDeviceTargetPath "@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @(@{ Name = 'Device'; Type = 'string'; Mappings = @(@{ Type = 'Device'; Target = 'dev/render' }) }) }) }"
        Set-Content $invalidPermissionsPath "@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @(@{ Name = 'Device'; Type = 'string'; Mappings = @(@{ Type = 'Device'; Permissions = 'wr' }) }) }) }"
        Set-Content $invalidGpuTypePath "@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @(@{ Name = 'Gpu'; Type = 'int'; Mappings = @(@{ Type = 'Gpu' }) }) }) }"

        { Test-ContainerModuleSpecification $invalidDeviceTypePath } | Should -Throw -ExpectedMessage "*Device*mapping*must use type 'string' or 'FileInfo'*"
        { Test-ContainerModuleSpecification $invalidDeviceTargetPath } | Should -Throw -ExpectedMessage "*'Target'*Device mapping*absolute container path*"
        { Test-ContainerModuleSpecification $invalidPermissionsPath } | Should -Throw -ExpectedMessage "*'Permissions'*ordered combination*"
        { Test-ContainerModuleSpecification $invalidGpuTypePath } | Should -Throw -ExpectedMessage "*Gpu*mapping*must use type 'string'*"
    }
}

Describe 'Resource limit and secret mappings' {
    It 'generates culture-invariant resource limits and read-only secret mounts' {
        $specificationPath = Join-Path $TestDrive 'Resources.psd1'
        $outputPath = Join-Path $TestDrive 'resource-output'
        $secretPath = Join-Path $TestDrive 'api-token.txt'
        Set-Content -LiteralPath $secretPath -Value 'secret-value'
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    ModuleName = 'ResourceExample'
    ContainerImage = 'example/resource-tool'
    Commands = @(@{ Name = 'Invoke-ResourceExample'; Parameters = @(
        @{ Name = 'Memory'; Type = 'string'; Mappings = @(
            @{ Type = 'ResourceLimit'; Resource = 'Memory' }
        ) }
        @{ Name = 'Cpus'; Type = 'double'; Mappings = @(
            @{ Type = 'ResourceLimit'; Resource = 'Cpus' }
        ) }
        @{ Name = 'Secret'; Type = 'FileInfo'; Mappings = @(
            @{ Type = 'Secret'; Name = 'api-token' }
        ) }
    ) })
}
'@

        Build-ContainerModule -Specification $specificationPath -Output $outputPath | Out-Null
        $module = Import-Module (Join-Path $outputPath 'ResourceExample.psd1') -Force -PassThru
        $global:capturedDockerArguments = $null
        function global:docker { $global:capturedDockerArguments = @($args); $global:LASTEXITCODE = 0 }
        $originalCulture = [System.Globalization.CultureInfo]::CurrentCulture
        try {
            [System.Globalization.CultureInfo]::CurrentCulture = [System.Globalization.CultureInfo]::GetCultureInfo('de-DE')
            Invoke-ResourceExample -Memory '512m' -Cpus 1.5 -Secret $secretPath

            $global:capturedDockerArguments | Should -Be @(
                'run', '--rm', '--memory', '512m', '--cpus', '1.5', '--mount',
                ('type=bind,source=' + [System.IO.Path]::GetFullPath($secretPath) + ',target=/run/secrets/api-token,readonly'),
                'example/resource-tool'
            )
        }
        finally {
            [System.Globalization.CultureInfo]::CurrentCulture = $originalCulture
            Remove-Item Function:\docker -Force
            Remove-Variable capturedDockerArguments -Scope Global -Force
            Remove-Module $module -Force
        }
    }

    It 'rejects invalid resource values and missing secret files before Docker' {
        $specificationPath = Join-Path $TestDrive 'ResourceValues.psd1'
        $outputPath = Join-Path $TestDrive 'resource-value-output'
        Set-Content -LiteralPath $specificationPath -Value @'
@{ ModuleName = 'ResourceValueExample'; Commands = @(@{ Name = 'Invoke-ResourceValueExample'; Parameters = @(
    @{ Name = 'Memory'; Type = 'string'; Mappings = @(@{ Type = 'ResourceLimit'; Resource = 'Memory' }) }
    @{ Name = 'Cpus'; Type = 'double'; Mappings = @(@{ Type = 'ResourceLimit'; Resource = 'Cpus' }) }
    @{ Name = 'Secret'; Type = 'FileInfo'; Mappings = @(@{ Type = 'Secret'; Name = 'token' }) }
) }) }
'@

        Build-ContainerModule -Specification $specificationPath -Output $outputPath | Out-Null
        $module = Import-Module (Join-Path $outputPath 'ResourceValueExample.psd1') -Force -PassThru
        $commaSecretPath = Join-Path $TestDrive 'unsafe,secret'
        Set-Content -LiteralPath $commaSecretPath -Value 'secret'
        $global:dockerWasInvoked = $false
        function global:docker { $global:dockerWasInvoked = $true }
        try {
            { Invoke-ResourceValueExample -Memory 'unlimited' } | Should -Throw -ExceptionType ([System.ArgumentException])
            { Invoke-ResourceValueExample -Cpus 0 } | Should -Throw -ExceptionType ([System.ArgumentOutOfRangeException])
            { Invoke-ResourceValueExample -Secret (Join-Path $TestDrive 'missing.secret') } | Should -Throw -ExceptionType ([System.IO.FileNotFoundException])
            { Invoke-ResourceValueExample -Secret $commaSecretPath } | Should -Throw -ExceptionType ([System.ArgumentException])
            $global:dockerWasInvoked | Should -BeFalse
        }
        finally {
            Remove-Item Function:\docker -Force
            Remove-Variable dockerWasInvoked -Scope Global -Force
            Remove-Module $module -Force
        }
    }

    It 'rejects malformed resource limit and secret definitions' {
        $invalidResourcePath = Join-Path $TestDrive 'InvalidResource.psd1'
        $invalidMemoryTypePath = Join-Path $TestDrive 'InvalidMemoryType.psd1'
        $invalidCpuTypePath = Join-Path $TestDrive 'InvalidCpuType.psd1'
        $invalidSecretTypePath = Join-Path $TestDrive 'InvalidSecretType.psd1'
        $invalidSecretNamePath = Join-Path $TestDrive 'InvalidSecretName.psd1'
        $invalidSecretTargetPath = Join-Path $TestDrive 'InvalidSecretTarget.psd1'
        Set-Content $invalidResourcePath "@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @(@{ Name = 'Limit'; Type = 'string'; Mappings = @(@{ Type = 'ResourceLimit'; Resource = 'Disk' }) }) }) }"
        Set-Content $invalidMemoryTypePath "@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @(@{ Name = 'Memory'; Type = 'int'; Mappings = @(@{ Type = 'ResourceLimit'; Resource = 'Memory' }) }) }) }"
        Set-Content $invalidCpuTypePath "@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @(@{ Name = 'Cpus'; Type = 'string'; Mappings = @(@{ Type = 'ResourceLimit'; Resource = 'Cpus' }) }) }) }"
        Set-Content $invalidSecretTypePath "@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @(@{ Name = 'Secret'; Type = 'int'; Mappings = @(@{ Type = 'Secret'; Name = 'token' }) }) }) }"
        Set-Content $invalidSecretNamePath "@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @(@{ Name = 'Secret'; Type = 'string'; Mappings = @(@{ Type = 'Secret'; Name = '../token' }) }) }) }"
        Set-Content $invalidSecretTargetPath "@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @(@{ Name = 'Secret'; Type = 'string'; Mappings = @(@{ Type = 'Secret'; Name = 'token'; Target = 'run/token' }) }) }) }"

        { Test-ContainerModuleSpecification $invalidResourcePath } | Should -Throw -ExpectedMessage "*'Resource'*'Memory' or 'Cpus'*"
        { Test-ContainerModuleSpecification $invalidMemoryTypePath } | Should -Throw -ExpectedMessage "*Memory ResourceLimit*must use type 'string'*"
        { Test-ContainerModuleSpecification $invalidCpuTypePath } | Should -Throw -ExpectedMessage "*Cpus ResourceLimit*numeric type*"
        { Test-ContainerModuleSpecification $invalidSecretTypePath } | Should -Throw -ExpectedMessage "*Secret*mapping*must use type 'string' or 'FileInfo'*"
        { Test-ContainerModuleSpecification $invalidSecretNamePath } | Should -Throw -ExpectedMessage "*'Name'*Secret mapping*safe non-empty file name*"
        { Test-ContainerModuleSpecification $invalidSecretTargetPath } | Should -Throw -ExpectedMessage "*'Target'*Secret mapping*absolute container path*"
    }
}

Describe 'Static argument completion' {
    It 'normalizes, persists, renders, and returns static completion values' {
        $specificationPath = Join-Path $TestDrive 'Completions.psd1'
        $outputPath = Join-Path $TestDrive 'completion-output'
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    ModuleName = 'CompletionExample'
    Commands = @(@{ Name = 'Invoke-CompletionExample'; Parameters = @(
        @{ Name = 'Mode'; Type = 'string'; Completions = @(
            @{ Type = 'Static'; Values = @('Build', 'Benchmark') }
            @{ Type = 'Static'; Values = @('Test') }
        ) }
    ) })
}
'@

        $model = Get-ContainerModuleModel -Specification $specificationPath
        Build-ContainerModule -Specification $specificationPath -Output $outputPath | Out-Null
        $source = Get-Content -LiteralPath (Join-Path $outputPath 'Public' 'Invoke-CompletionExample.ps1') -Raw
        $metadata = Get-Content -LiteralPath (Join-Path $outputPath 'Metadata/model.json') -Raw | ConvertFrom-Json
        $module = Import-Module (Join-Path $outputPath 'CompletionExample.psd1') -Force -PassThru
        try {
            $inputText = 'Invoke-CompletionExample -Mode B'
            $completionMatches = [System.Management.Automation.CommandCompletion]::CompleteInput(
                $inputText, $inputText.Length, $null
            ).CompletionMatches.CompletionText

            $model.Commands[0].Parameters[0].Completions.Count | Should -Be 2
            $model.Commands[0].Parameters[0].Completions[0].Values | Should -Be @('Build', 'Benchmark')
            $metadata.Commands[0].Parameters[0].Completions[1].Values | Should -Be @('Test')
            $source | Should -Match "\[ArgumentCompletions\('Build', 'Benchmark', 'Test'\)\]"
            $completionMatches | Should -Be @('Build', 'Benchmark')
        }
        finally {
            Remove-Module $module -Force
        }
    }

    It 'rejects malformed and duplicate static completion definitions' {
        $scalarPath = Join-Path $TestDrive 'ScalarCompletions.psd1'
        $unsupportedPath = Join-Path $TestDrive 'UnsupportedCompletion.psd1'
        $emptyValuesPath = Join-Path $TestDrive 'EmptyCompletionValues.psd1'
        $duplicatePath = Join-Path $TestDrive 'DuplicateCompletionValues.psd1'
        Set-Content $scalarPath "@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @(@{ Name = 'Value'; Type = 'string'; Completions = @{ Type = 'Static'; Values = @('One') } }) }) }"
        Set-Content $unsupportedPath "@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @(@{ Name = 'Value'; Type = 'string'; Completions = @(@{ Type = 'Script' }) }) }) }"
        Set-Content $emptyValuesPath "@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @(@{ Name = 'Value'; Type = 'string'; Completions = @(@{ Type = 'Static'; Values = @() }) }) }) }"
        Set-Content $duplicatePath "@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @(@{ Name = 'Value'; Type = 'string'; Completions = @(@{ Type = 'Static'; Values = @('One', 'one') }) }) }) }"

        { Test-ContainerModuleSpecification $scalarPath } | Should -Throw -ExpectedMessage "*'Completions'*must be an array*"
        { Test-ContainerModuleSpecification $unsupportedPath } | Should -Throw -ExpectedMessage "*Completion type 'Script'*not supported*"
        { Test-ContainerModuleSpecification $emptyValuesPath } | Should -Throw -ExpectedMessage "*Static completion*non-empty string array*"
        { Test-ContainerModuleSpecification $duplicatePath } | Should -Throw -ExpectedMessage "*Completion value 'one'*defined more than once*"
    }
}

Describe 'Parameter validation attributes' {
    It 'normalizes and renders supported native validation attributes' {
        $specificationPath = Join-Path $TestDrive 'Validations.psd1'
        $outputPath = Join-Path $TestDrive 'validation-output'
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    ModuleName = 'ValidationExample'
    Commands = @(@{ Name = 'Invoke-ValidationExample'; Parameters = @(
        @{ Name = 'Task'; Type = 'string'; Validations = @(
            @{ Type = 'ValidateSet'; Values = @('Build', 'Test') }
            @{ Type = 'ValidatePattern'; Pattern = '^[A-Z][a-z]+$' }
        ) }
        @{ Name = 'Count'; Type = 'int'; Validations = @(
            @{ Type = 'ValidateRange'; Minimum = 1; Maximum = 10 }
        ) }
    ) })
}
'@

        $model = Get-ContainerModuleModel -Specification $specificationPath
        Build-ContainerModule -Specification $specificationPath -Output $outputPath | Out-Null
        $source = Get-Content -LiteralPath (Join-Path $outputPath 'Public' 'Invoke-ValidationExample.ps1') -Raw
        $module = Import-Module (Join-Path $outputPath 'ValidationExample.psd1') -Force -PassThru
        try {
            $model.Commands[0].Parameters[0].Validations.Count | Should -Be 2
            $model.Commands[0].Parameters[0].Validations[0].Type | Should -Be 'ValidateSet'
            $source | Should -Match "\[ValidateSet\('Build', 'Test'\)\]"
            $source | Should -Match '\[ValidatePattern\(''\^\[A-Z\]\[a-z\]\+\$''\)\]'
            $source | Should -Match '\[ValidateRange\(1, 10\)\]'
            { Invoke-ValidationExample -Task Deploy -Count 5 } | Should -Throw -ExceptionType ([System.Management.Automation.ParameterBindingException])
            { Invoke-ValidationExample -Task Build -Count 11 } | Should -Throw -ExceptionType ([System.Management.Automation.ParameterBindingException])
        }
        finally {
            Remove-Module $module -Force
        }
    }

    It 'rejects malformed validation definitions' {
        $unsupportedPath = Join-Path $TestDrive 'UnsupportedValidation.psd1'
        $emptySetPath = Join-Path $TestDrive 'EmptySet.psd1'
        $reversedRangePath = Join-Path $TestDrive 'ReversedRange.psd1'
        $invalidPatternPath = Join-Path $TestDrive 'InvalidPattern.psd1'
        Set-Content -LiteralPath $unsupportedPath -Value "@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @(@{ Name = 'Value'; Type = 'string'; Validations = @(@{ Type = 'ValidateScript' }) }) }) }"
        Set-Content -LiteralPath $emptySetPath -Value "@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @(@{ Name = 'Value'; Type = 'string'; Validations = @(@{ Type = 'ValidateSet'; Values = @() }) }) }) }"
        Set-Content -LiteralPath $reversedRangePath -Value "@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @(@{ Name = 'Value'; Type = 'int'; Validations = @(@{ Type = 'ValidateRange'; Minimum = 10; Maximum = 1 }) }) }) }"
        Set-Content -LiteralPath $invalidPatternPath -Value "@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @(@{ Name = 'Value'; Type = 'string'; Validations = @(@{ Type = 'ValidatePattern'; Pattern = '[' }) }) }) }"

        { Test-ContainerModuleSpecification $unsupportedPath } | Should -Throw -ExpectedMessage '*not supported*'
        { Test-ContainerModuleSpecification $emptySetPath } | Should -Throw -ExpectedMessage '*non-empty string array*'
        { Test-ContainerModuleSpecification $reversedRangePath } | Should -Throw -ExpectedMessage '*ascending order*'
        { Test-ContainerModuleSpecification $invalidPatternPath } | Should -Throw -ExpectedMessage '*invalid regular expression*'
    }
}

Describe 'Container module object model' {
    It 'normalizes a specification without commands to an empty collection' {
        InModuleScope SubZeroDev.ContainerPSGenerator {
            $model = ConvertTo-ContainerModuleModel -Specification @{}

            $model.PSObject.TypeNames | Should -Contain 'SubZeroDev.ContainerPSGenerator.Model'
            $model.ModuleName | Should -Be 'PSModule'
            $model.ModuleVersion | Should -Be '0.1.0'
            $model.ContainerImage | Should -Be 'PSModule'
            [object]::ReferenceEquals($null, $model.Commands) | Should -BeFalse
            $model.Commands.Count | Should -Be 0
        }
    }

    It 'normalizes commands, parameters, and mappings' {
        InModuleScope SubZeroDev.ContainerPSGenerator {
            $definition = @{
                Commands = @(
                    @{
                        Id = 'command.example'
                        Name = 'Invoke-Example'
                        Description = 'Runs the example.'
                        Parameters = @(
                            @{
                                Id = 'parameter.repository'
                                Name = 'Repository'
                                Type = 'DirectoryInfo'
                                Mappings = @(
                                    @{ Type = 'Mount'; Target = '/repository'; Access = 'ReadOnly' }
                                )
                            }
                        )
                    }
                )
            }

            $model = ConvertTo-ContainerModuleModel -Specification $definition
            $command = $model.Commands[0]
            $parameter = $command.Parameters[0]
            $mapping = $parameter.Mappings[0]

            $command.PSObject.TypeNames | Should -Contain 'SubZeroDev.ContainerPSGenerator.Model.Command'
            $command.Id | Should -Be 'command.example'
            $command.Name | Should -Be 'Invoke-Example'
            $command.Description | Should -Be 'Runs the example.'
            $parameter.PSObject.TypeNames | Should -Contain 'SubZeroDev.ContainerPSGenerator.Model.Parameter'
            $parameter.Id | Should -Be 'parameter.repository'
            $parameter.Type | Should -Be 'DirectoryInfo'
            $parameter.Mandatory | Should -BeFalse
            $mapping.PSObject.TypeNames | Should -Contain 'SubZeroDev.ContainerPSGenerator.Model.Mapping'
            $mapping.Type | Should -Be 'Mount'
            $mapping.Definition.Target | Should -Be '/repository'
            [object]::ReferenceEquals($model.Definition, $definition) | Should -BeTrue
        }
    }
}

Describe 'Get-ContainerModuleModel' {
    It 'returns a validated normalized model' {
        $specificationPath = Join-Path $TestDrive 'Model.psd1'
        Set-Content -LiteralPath $specificationPath -Value @'
@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @() }) }
'@

        $model = Get-ContainerModuleModel -Specification $specificationPath

        $model.PSObject.TypeNames | Should -Contain 'SubZeroDev.ContainerPSGenerator.Model'
        $model.Commands[0].Name | Should -Be 'Invoke-Example'
    }
}

Describe 'Container module metadata generation' {
    It 'writes deterministic normalized JSON using UTF-8 without BOM' {
        $specificationPath = Join-Path $TestDrive 'Metadata.psd1'
        $outputPath = Join-Path $TestDrive 'metadata-output'
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    Commands = @(
        @{ Name = 'Invoke-Example'; Parameters = @(
            @{ Name = 'Message'; Type = 'string'; Mappings = @(
                @{ Type = 'Environment'; Name = 'EXAMPLE_MESSAGE' }
            ) }
        ) }
    )
}
'@

        $artifact = Build-ContainerModule -Specification $specificationPath -Output $outputPath
        $firstContent = [System.IO.File]::ReadAllText($artifact.FullName)
        $firstBytes = [System.IO.File]::ReadAllBytes($artifact.FullName)
        $metadata = $firstContent | ConvertFrom-Json

        $metadata.SchemaVersion | Should -Be 1
        $metadata.Commands[0].Parameters[0].Mappings[0].Name | Should -Be 'EXAMPLE_MESSAGE'
        $firstContent | Should -Not -Match "`r`n"
        $firstBytes[0] | Should -Not -Be 0xEF

        $null = Build-ContainerModule -Specification $specificationPath -Output $outputPath
        [System.IO.File]::ReadAllText($artifact.FullName) | Should -BeExactly $firstContent
    }
}

Describe 'Container module command source generation' {
    It 'writes parseable deterministic command source with declared parameters' {
        $specificationPath = Join-Path $TestDrive 'CommandSource.psd1'
        $outputPath = Join-Path $TestDrive 'command-output'
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    Commands = @(
        @{ Name = 'Invoke-Example'; Parameters = @(
            @{ Name = 'Repository'; Type = 'DirectoryInfo'; Mandatory = $true }
            @{ Name = 'Tags'; Type = 'string[]' }
        ) }
    )
}
'@

        $null = Build-ContainerModule -Specification $specificationPath -Output $outputPath
        $sourcePath = Join-Path $outputPath 'Public' 'Invoke-Example.ps1'
        $firstContent = [System.IO.File]::ReadAllText($sourcePath)
        $tokens = $null
        $parseErrors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile(
            $sourcePath,
            [ref] $tokens,
            [ref] $parseErrors
        )

        $parseErrors | Should -BeNullOrEmpty
        $firstContent | Should -Match 'function Invoke-Example'
        $firstContent | Should -Match '\[Parameter\(Mandatory = \$true\)\]'
        $firstContent | Should -Match '\[System\.IO\.DirectoryInfo\] \$Repository,'
        $firstContent | Should -Match '\[string\[\]\] \$Tags'
        $firstContent | Should -Not -Match "`r`n"

        $null = Build-ContainerModule -Specification $specificationPath -Output $outputPath
        [System.IO.File]::ReadAllText($sourcePath) | Should -BeExactly $firstContent
    }

    It 'normalizes SwitchParameter specifications into importable switch parameters' {
        $specificationPath = Join-Path $TestDrive 'SwitchParameter.psd1'
        $outputPath = Join-Path $TestDrive 'switch-parameter-output'
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    ModuleName = 'SwitchParameterExample'
    Commands = @(
        @{ Name = 'Invoke-SwitchExample'; Parameters = @(
            @{ Name = 'Force'; Type = 'SwitchParameter' }
            @{ Name = 'NoOpen'; Type = 'System.Management.Automation.SwitchParameter' }
        ) }
    )
}
'@

        $null = Build-ContainerModule -Specification $specificationPath -Output $outputPath
        $source = Get-Content -LiteralPath (
            Join-Path $outputPath 'Public' 'Invoke-SwitchExample.ps1'
        ) -Raw
        $module = Import-Module (
            Join-Path $outputPath 'SwitchParameterExample.psd1'
        ) -Force -PassThru
        try {
            $source | Should -Match '\[switch\] \$Force'
            $source | Should -Match '\[switch\] \$NoOpen'
            (Get-Command Invoke-SwitchExample).Parameters['Force'].ParameterType |
                Should -Be ([Management.Automation.SwitchParameter])
            (Get-Command Invoke-SwitchExample).Parameters['NoOpen'].ParameterType |
                Should -Be ([Management.Automation.SwitchParameter])
        }
        finally {
            Remove-Module $module -Force
        }
    }
}

Describe 'Container module loader generation' {
    It 'writes an importable loader that exports generated commands' {
        $specificationPath = Join-Path $TestDrive 'Loader.psd1'
        $outputPath = Join-Path $TestDrive 'loader-output'
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    ModuleName = 'ExampleContainer'
    ModuleVersion = '1.2.3'
    Commands = @(
        @{ Name = 'Invoke-Example'; Parameters = @() }
    )
}
'@

        $null = Build-ContainerModule -Specification $specificationPath -Output $outputPath
        $loaderPath = Join-Path $outputPath 'ExampleContainer.psm1'
        $module = Import-Module $loaderPath -Force -PassThru

        try {
            $module.Name | Should -Be 'ExampleContainer'
            Get-Command Invoke-Example -Module ExampleContainer | Should -Not -BeNullOrEmpty
        }
        finally {
            Remove-Module ExampleContainer -Force
        }
    }

    It 'imports without a Public directory when the module has no commands' {
        $specificationPath = Join-Path $TestDrive 'EmptyLoader.psd1'
        $outputPath = Join-Path $TestDrive 'empty-loader-output'
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    ModuleName = 'EmptyContainer'
    Commands = @()
}
'@

        $null = Build-ContainerModule -Specification $specificationPath -Output $outputPath

        Test-Path -LiteralPath (Join-Path $outputPath 'Public') | Should -BeFalse
        $module = Import-Module (
            Join-Path $outputPath 'EmptyContainer.psd1'
        ) -Force -PassThru -ErrorAction Stop
        try {
            @(Get-Command -Module $module.Name).Count | Should -Be 0
        }
        finally {
            Remove-Module $module -Force
        }
    }
}

Describe 'Container module manifest generation' {
    It 'writes a valid manifest that imports and exports generated commands' {
        $specificationPath = Join-Path $TestDrive 'Manifest.psd1'
        $outputPath = Join-Path $TestDrive 'manifest-output'
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    ModuleName = 'ManifestExample'
    ModuleVersion = '2.3.4'
    Commands = @(
        @{ Name = 'Invoke-ManifestExample'; Parameters = @() }
    )
}
'@

        Build-ContainerModule -Specification $specificationPath -Output $outputPath | Out-Null

        $generatedManifestPath = Join-Path $outputPath 'ManifestExample.psd1'
        $manifest = Test-ModuleManifest -Path $generatedManifestPath -ErrorAction Stop
        $module = Import-Module $generatedManifestPath -Force -PassThru
        try {
            $manifest.Version.ToString() | Should -Be '2.3.4'
            $manifest.PowerShellVersion.ToString() | Should -Be '7.4'
            $module.ExportedFunctions.Keys | Should -Contain 'Invoke-ManifestExample'
        }
        finally {
            Remove-Module ManifestExample -Force
        }
    }

    It 'writes deterministic manifest content' {
        $specificationPath = Join-Path $TestDrive 'DeterministicManifest.psd1'
        $outputPath = Join-Path $TestDrive 'deterministic-manifest-output'
        Set-Content -LiteralPath $specificationPath -Value @'
@{ ModuleName = 'StableExample'; Commands = @(@{ Name = 'Get-StableExample' }) }
'@

        Build-ContainerModule -Specification $specificationPath -Output $outputPath | Out-Null
        $first = [System.IO.File]::ReadAllBytes((Join-Path $outputPath 'StableExample.psd1'))
        Build-ContainerModule -Specification $specificationPath -Output $outputPath | Out-Null
        $second = [System.IO.File]::ReadAllBytes((Join-Path $outputPath 'StableExample.psd1'))

        [Convert]::ToHexString($second) | Should -Be ([Convert]::ToHexString($first))
    }
}

Describe 'Container module output reset' {
    It 'produces an identical complete package across repeated builds' {
        $repositoryPath = Join-Path $TestDrive 'deterministic-package-repository'
        $specificationDirectory = New-Item -Path (
            Join-Path $repositoryPath 'PSModule'
        ) -ItemType Directory -Force
        $scriptsDirectory = New-Item -Path (
            Join-Path $repositoryPath 'scripts'
        ) -ItemType Directory -Force
        $supportDirectory = New-Item -Path (
            Join-Path $scriptsDirectory 'support'
        ) -ItemType Directory -Force
        Set-Content -LiteralPath (Join-Path $scriptsDirectory 'Invoke-Local.ps1') -Value @'
param([string] $Name)
"Hello, $Name"
'@
        Set-Content -LiteralPath (
            Join-Path $supportDirectory 'settings.json'
        ) -Value '{ "enabled": true }'
        $specificationPath = Join-Path $specificationDirectory 'PSModule.psd1'
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    ModuleName = 'DeterministicPackage'
    ModuleVersion = '1.2.3'
    ContainerImage = 'example/deterministic:1.2.3'
    Commands = @(
        @{
            Name = 'Invoke-ContainerExample'
            Description = 'Runs the container example.'
            Parameters = @(
                @{ Name = 'Message'; Type = 'string'; Mappings = @(
                    @{ Type = 'Argument'; Name = '--message' }
                ) }
            )
        }
        @{
            Name = 'Invoke-Local'
            Description = 'Runs the packaged local script.'
            SourceKind = 'Script'
            SourcePath = 'scripts/Invoke-Local.ps1'
            Parameters = @(
                @{ Name = 'Name'; Type = 'string' }
            )
        }
    )
}
'@
        $outputPath = Join-Path $repositoryPath 'artifacts' 'PSModule'
        $getPackageSnapshot = {
            param ([string] $Path)

            @(
                Get-ChildItem -LiteralPath $Path -File -Recurse |
                    Sort-Object {
                        [IO.Path]::GetRelativePath($Path, $_.FullName)
                    } |
                    ForEach-Object {
                        $relativePath = [IO.Path]::GetRelativePath($Path, $_.FullName) -replace '\\', '/'
                        $hash = [Security.Cryptography.SHA256]::HashData(
                            [IO.File]::ReadAllBytes($_.FullName)
                        )
                        [ordered] @{
                            Path   = $relativePath
                            Length = $_.Length
                            SHA256 = [Convert]::ToHexString($hash)
                        }
                    }
            ) | ConvertTo-Json -Compress
        }

        Build-ContainerModule -Specification $specificationPath -Output $outputPath | Out-Null
        $firstSnapshot = & $getPackageSnapshot $outputPath
        $firstPaths = @(
            Get-ChildItem -LiteralPath $outputPath -File -Recurse |
                ForEach-Object {
                    [IO.Path]::GetRelativePath($outputPath, $_.FullName) -replace '\\', '/'
                }
        )

        Build-ContainerModule -Specification $specificationPath -Output $outputPath | Out-Null
        $secondSnapshot = & $getPackageSnapshot $outputPath

        $firstPaths | Should -Contain 'DeterministicPackage.psd1'
        $firstPaths | Should -Contain 'DeterministicPackage.psm1'
        $firstPaths | Should -Contain 'Metadata/model.json'
        $firstPaths | Should -Contain 'Public/Invoke-ContainerExample.ps1'
        $firstPaths | Should -Contain 'Public/Invoke-Local.ps1'
        $firstPaths | Should -Contain 'Documentation/Invoke-ContainerExample.md'
        $firstPaths | Should -Contain 'Documentation/Invoke-Local.md'
        $firstPaths | Should -Contain 'Scripts/Invoke-Local.ps1'
        $firstPaths | Should -Contain 'Scripts/support/settings.json'
        $secondSnapshot | Should -BeExactly $firstSnapshot
    }

    It 'removes stale artifacts before generating the current module' {
        $specificationPath = Join-Path $TestDrive 'Reset.psd1'
        $outputPath = Join-Path $TestDrive 'reset-output'
        New-Item -Path $outputPath -ItemType Directory -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $outputPath 'stale.txt') -Value 'old build'
        Set-Content -LiteralPath $specificationPath -Value '@{ Commands = @() }'

        Build-ContainerModule -Specification $specificationPath -Output $outputPath | Out-Null

        Test-Path -LiteralPath (Join-Path $outputPath 'stale.txt') | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $outputPath 'PSModule.psd1') | Should -BeTrue
    }

    It 'preserves existing output when validation fails' {
        $specificationPath = Join-Path $TestDrive 'InvalidReset.psd1'
        $outputPath = Join-Path $TestDrive 'preserved-output'
        New-Item -Path $outputPath -ItemType Directory -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $outputPath 'keep.txt') -Value 'keep me'
        Set-Content -LiteralPath $specificationPath -Value "@{ ModuleVersion = 'invalid' }"

        { Build-ContainerModule -Specification $specificationPath -Output $outputPath } | Should -Throw

        Test-Path -LiteralPath (Join-Path $outputPath 'keep.txt') | Should -BeTrue
    }
}

Describe 'Container runtime configuration' {
    It 'normalizes an explicit container image into the model and metadata' {
        $specificationPath = Join-Path $TestDrive 'Runtime.psd1'
        $outputPath = Join-Path $TestDrive 'runtime-output'
        Set-Content -LiteralPath $specificationPath -Value @'
@{ ContainerImage = 'ghcr.io/example/tool:1.2.3'; Commands = @() }
'@

        $model = Get-ContainerModuleModel -Specification $specificationPath
        $artifact = Build-ContainerModule -Specification $specificationPath -Output $outputPath
        $metadata = Get-Content -LiteralPath $artifact -Raw | ConvertFrom-Json

        $model.ContainerImage | Should -Be 'ghcr.io/example/tool:1.2.3'
        $metadata.ContainerImage | Should -Be 'ghcr.io/example/tool:1.2.3'
    }

    It 'rejects an unsafe container image reference' {
        $specificationPath = Join-Path $TestDrive 'UnsafeRuntime.psd1'
        Set-Content -LiteralPath $specificationPath -Value "@{ ContainerImage = 'bad image' }"

        { Test-ContainerModuleSpecification -Specification $specificationPath } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage "*'ContainerImage' property must be*"
    }
}

Describe 'Docker runtime command generation' {
    It 'maps bound environment and argument parameters in Docker order' {
        $specificationPath = Join-Path $TestDrive 'DockerCommand.psd1'
        $outputPath = Join-Path $TestDrive 'docker-command-output'
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    ModuleName = 'DockerExample'
    ContainerImage = 'ghcr.io/example/tool:latest'
    Commands = @(
        @{
            Name = 'Invoke-DockerExample'
            Parameters = @(
                @{ Name = 'Message'; Type = 'string'; Mappings = @(
                    @{ Type = 'Environment'; Name = 'TOOL_MESSAGE' }
                    @{ Type = 'Argument'; Name = '--message' }
                ) }
                @{ Name = 'VerboseOutput'; Type = 'switch'; Mappings = @(
                    @{ Type = 'Argument'; Name = '--verbose' }
                ) }
            )
        }
    )
}
'@

        Build-ContainerModule -Specification $specificationPath -Output $outputPath | Out-Null
        $module = Import-Module (Join-Path $outputPath 'DockerExample.psd1') -Force -PassThru
        $global:capturedDockerArguments = $null
        function global:docker { $global:capturedDockerArguments = @($args) }
        try {
            $verboseOutput = Invoke-DockerExample -Message 'hello world' -VerboseOutput -Verbose 4>&1

            $global:capturedDockerArguments | Should -Be @(
                'run', '--rm', '-e', 'TOOL_MESSAGE=hello world',
                'ghcr.io/example/tool:latest', '--message', 'hello world', '--verbose'
            )
            $verboseOutput -join "`n" | Should -Match 'Starting container command: docker run --rm'
            $verboseOutput -join "`n" | Should -Match 'Docker is attached to this session'
            $verboseOutput -join "`n" | Should -Match 'Container command finished after .* exit code 0'
        }
        finally {
            Remove-Item -Path Function:\docker -Force
            Remove-Variable -Name capturedDockerArguments -Scope Global -Force
            Remove-Module $module -Force
        }
    }

    It 'does not emit mappings for omitted optional parameters' {
        $specificationPath = Join-Path $TestDrive 'OptionalDockerCommand.psd1'
        $outputPath = Join-Path $TestDrive 'optional-docker-command-output'
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    ModuleName = 'OptionalDockerExample'
    ContainerImage = 'example/tool'
    Commands = @(@{ Name = 'Invoke-OptionalDockerExample'; Parameters = @(
        @{ Name = 'Message'; Type = 'string'; Mappings = @(
            @{ Type = 'Argument'; Name = '--message' }
        ) }
    ) })
}
'@

        Build-ContainerModule -Specification $specificationPath -Output $outputPath | Out-Null
        $module = Import-Module (Join-Path $outputPath 'OptionalDockerExample.psd1') -Force -PassThru
        $global:capturedDockerArguments = $null
        function global:docker { $global:capturedDockerArguments = @($args) }
        try {
            Invoke-OptionalDockerExample

            $global:capturedDockerArguments | Should -Be @('run', '--rm', 'example/tool')
        }
        finally {
            Remove-Item -Path Function:\docker -Force
            Remove-Variable -Name capturedDockerArguments -Scope Global -Force
            Remove-Module $module -Force
        }
    }
}

Describe 'Docker mount and error generation' {
    It 'maps read-only and read-write bind mounts before the image' {
        $specificationPath = Join-Path $TestDrive 'DockerMounts.psd1'
        $outputPath = Join-Path $TestDrive 'docker-mount-output'
        $readOnlyPath = Join-Path $TestDrive 'source-one'
        $readWritePath = Join-Path $TestDrive 'source-two'
        New-Item -Path $readOnlyPath -ItemType Directory -Force | Out-Null
        New-Item -Path $readWritePath -ItemType Directory -Force | Out-Null
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    ModuleName = 'MountExample'
    ContainerImage = 'example/mount-tool'
    Commands = @(@{ Name = 'Invoke-MountExample'; Parameters = @(
        @{ Name = 'InputPath'; Type = 'DirectoryInfo'; Mappings = @(
            @{ Type = 'Mount'; Target = '/input'; Access = 'ReadOnly' }
        ) }
        @{ Name = 'OutputPath'; Type = 'DirectoryInfo'; Mappings = @(
            @{ Type = 'Mount'; Target = '/output'; Access = 'ReadWrite' }
        ) }
    ) })
}
'@

        Build-ContainerModule -Specification $specificationPath -Output $outputPath | Out-Null
        $module = Import-Module (Join-Path $outputPath 'MountExample.psd1') -Force -PassThru
        $global:capturedDockerArguments = $null
        function global:docker { $global:capturedDockerArguments = @($args) }
        try {
            Invoke-MountExample -InputPath $readOnlyPath -OutputPath $readWritePath

            $global:capturedDockerArguments | Should -Be @(
                'run', '--rm',
                '--mount', "type=bind,source=$([System.IO.Path]::GetFullPath($readOnlyPath)),target=/input,readonly",
                '--mount', "type=bind,source=$([System.IO.Path]::GetFullPath($readWritePath)),target=/output",
                'example/mount-tool'
            )
        }
        finally {
            Remove-Item -Path Function:\docker -Force
            Remove-Variable -Name capturedDockerArguments -Scope Global -Force
            Remove-Module $module -Force
        }
    }

    It 'reports when Docker cannot be found' {
        $specificationPath = Join-Path $TestDrive 'MissingDocker.psd1'
        $outputPath = Join-Path $TestDrive 'missing-docker-output'
        Set-Content -LiteralPath $specificationPath -Value @'
@{ ModuleName = 'MissingDockerExample'; Commands = @(@{ Name = 'Invoke-MissingDockerExample' }) }
'@

        Build-ContainerModule -Specification $specificationPath -Output $outputPath | Out-Null
        $module = Import-Module (Join-Path $outputPath 'MissingDockerExample.psd1') -Force -PassThru
        $originalPath = $env:PATH
        try {
            $env:PATH = ''
            { Invoke-MissingDockerExample } |
                Should -Throw -ExceptionType ([System.InvalidOperationException]) -ExpectedMessage '*Docker is required*not found on PATH*'
        }
        finally {
            $env:PATH = $originalPath
            Remove-Module $module -Force
        }
    }

    It 'reports an unsuccessful Docker invocation' {
        $specificationPath = Join-Path $TestDrive 'FailedDocker.psd1'
        $outputPath = Join-Path $TestDrive 'failed-docker-output'
        Set-Content -LiteralPath $specificationPath -Value @'
@{ ModuleName = 'FailedDockerExample'; Commands = @(@{ Name = 'Invoke-FailedDockerExample' }) }
'@

        Build-ContainerModule -Specification $specificationPath -Output $outputPath | Out-Null
        $module = Import-Module (Join-Path $outputPath 'FailedDockerExample.psd1') -Force -PassThru
        function global:docker { $global:LASTEXITCODE = 23 }
        try {
            { Invoke-FailedDockerExample -ErrorAction SilentlyContinue } |
                Should -Throw -ExceptionType ([System.InvalidOperationException]) -ExpectedMessage '*Docker failed with exit code 23*'
        }
        finally {
            Remove-Item -Path Function:\docker -Force
            Remove-Module $module -Force
        }
    }
}

Describe 'Generated command help and preview' {
    It 'renders synopsis, description, notes, and structured examples' {
        $specificationPath = Join-Path $TestDrive 'RichHelp.psd1'
        $outputPath = Join-Path $TestDrive 'rich-help-output'
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    ModuleName = 'RichHelpExample'
    Commands = @(@{
        Name = 'Invoke-RichHelpExample'
        Synopsis = 'Runs the documented example.'
        Description = 'Provides a longer explanation of the operation.'
        Notes = 'Docker must be available on PATH.'
        Examples = @(@{
            Code = "Invoke-RichHelpExample -WhatIf"
            Description = 'Previews the container invocation.'
        })
    })
}
'@

        Build-ContainerModule -Specification $specificationPath -Output $outputPath | Out-Null
        $module = Import-Module (Join-Path $outputPath 'RichHelpExample.psd1') -Force -PassThru
        try {
            $help = Get-Help Invoke-RichHelpExample -Full

            $help.Synopsis | Should -Be 'Runs the documented example.'
            $help.Description.Text | Should -Be 'Provides a longer explanation of the operation.'
            $help.alertSet.alert.Text | Should -Be 'Docker must be available on PATH.'
            $help.Examples.Example[0].Code | Should -Be 'Invoke-RichHelpExample -WhatIf'
            @($help.Examples.Example[0].Remarks.Text).Where({ -not [string]::IsNullOrWhiteSpace($_) }) |
                Should -Be 'Previews the container invocation.'
        }
        finally {
            Remove-Module $module -Force
        }
    }

    It 'renders command and parameter descriptions as help' {
        $specificationPath = Join-Path $TestDrive 'Help.psd1'
        $outputPath = Join-Path $TestDrive 'help-output'
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    ModuleName = 'HelpExample'
    Commands = @(@{
        Name = 'Invoke-HelpExample'
        Description = 'Runs a documented container operation.'
        Parameters = @(@{
            Name = 'Message'
            Description = 'Message supplied to the container.'
            Type = 'string'
        })
    })
}
'@

        Build-ContainerModule -Specification $specificationPath -Output $outputPath | Out-Null
        $module = Import-Module (Join-Path $outputPath 'HelpExample.psd1') -Force -PassThru
        try {
            $help = Get-Help Invoke-HelpExample -Full

            $help.Synopsis | Should -Be 'Runs a documented container operation.'
            $help.Parameters.Parameter.Where({ $_.Name -eq 'Message' }).Description.Text |
                Should -Be 'Message supplied to the container.'
        }
        finally {
            Remove-Module $module -Force
        }
    }

    It 'previews the Docker invocation without discovering or running Docker' {
        $specificationPath = Join-Path $TestDrive 'Preview.psd1'
        $outputPath = Join-Path $TestDrive 'preview-output'
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    ModuleName = 'PreviewExample'
    ContainerImage = 'example/preview-tool'
    Commands = @(@{ Name = 'Invoke-PreviewExample'; Parameters = @(
        @{ Name = 'Message'; Type = 'string'; Mappings = @(
            @{ Type = 'Argument'; Name = '--message' }
        ) }
    ) })
}
'@

        Build-ContainerModule -Specification $specificationPath -Output $outputPath | Out-Null
        $module = Import-Module (Join-Path $outputPath 'PreviewExample.psd1') -Force -PassThru
        $global:dockerWasInvoked = $false
        function global:docker { $global:dockerWasInvoked = $true }
        try {
            $command = Get-Command Invoke-PreviewExample
            Invoke-PreviewExample -Message 'hello' -WhatIf

            $command.Parameters.Keys | Should -Contain 'WhatIf'
            $global:dockerWasInvoked | Should -BeFalse
        }
        finally {
            Remove-Item -Path Function:\docker -Force
            Remove-Variable -Name dockerWasInvoked -Scope Global -Force
            Remove-Module $module -Force
        }
    }

    It 'requires descriptions to be non-empty strings when provided' {
        $commandSpecificationPath = Join-Path $TestDrive 'InvalidCommandHelp.psd1'
        $parameterSpecificationPath = Join-Path $TestDrive 'InvalidParameterHelp.psd1'
        Set-Content -LiteralPath $commandSpecificationPath -Value @'
@{ Commands = @(@{ Name = 'Invoke-Example'; Description = ' ' }) }
'@
        Set-Content -LiteralPath $parameterSpecificationPath -Value @'
@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @(
    @{ Name = 'Message'; Type = 'string'; Description = 42 }
) }) }
'@

        { Test-ContainerModuleSpecification -Specification $commandSpecificationPath } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage "*'Description' property for command*"
        { Test-ContainerModuleSpecification -Specification $parameterSpecificationPath } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage "*'Description' property for parameter*"
    }

    It 'validates structured command help fields and examples' {
        $invalidSynopsisPath = Join-Path $TestDrive 'InvalidSynopsis.psd1'
        $scalarExamplesPath = Join-Path $TestDrive 'ScalarExamples.psd1'
        $invalidExamplePath = Join-Path $TestDrive 'InvalidExample.psd1'
        Set-Content -LiteralPath $invalidSynopsisPath -Value "@{ Commands = @(@{ Name = 'Invoke-Example'; Synopsis = ' ' }) }"
        Set-Content -LiteralPath $scalarExamplesPath -Value "@{ Commands = @(@{ Name = 'Invoke-Example'; Examples = @{ Code = 'Invoke-Example'; Description = 'Runs it.' } }) }"
        Set-Content -LiteralPath $invalidExamplePath -Value "@{ Commands = @(@{ Name = 'Invoke-Example'; Examples = @(@{ Code = ' '; Description = 'Runs it.' }) }) }"

        { Test-ContainerModuleSpecification -Specification $invalidSynopsisPath } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage "*'Synopsis' property for command*"
        { Test-ContainerModuleSpecification -Specification $scalarExamplesPath } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage "*'Examples' property for command*must be an array*"
        { Test-ContainerModuleSpecification -Specification $invalidExamplePath } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage "*'Code' property for example*must be a non-empty string*"
    }
}

Describe 'Generated Markdown command documentation' {
    It 'writes deterministic command references from the normalized help model' {
        $specificationPath = Join-Path $TestDrive 'MarkdownHelp.psd1'
        $outputPath = Join-Path $TestDrive 'markdown-help-output'
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    ModuleName = 'MarkdownHelpExample'
    Commands = @(@{
        Name = 'Invoke-MarkdownHelpExample'
        Synopsis = 'Runs the **documented** operation.'
        Description = 'A longer Markdown description.'
        Notes = 'Requires Docker.'
        Examples = @(@{
            Code = "Invoke-MarkdownHelpExample -Message 'hello'"
            Description = 'Runs with a message.'
        })
        Parameters = @(
            @{ Name = 'Message'; Type = 'string'; Mandatory = $true; Description = 'Message to send.' }
            @{ Name = 'Count'; Type = 'int'; Description = 'Optional repeat count.' }
        )
    })
}
'@

        Build-ContainerModule -Specification $specificationPath -Output $outputPath | Out-Null
        $documentationPath = Join-Path $outputPath 'Documentation' 'Invoke-MarkdownHelpExample.md'
        $firstBytes = [System.IO.File]::ReadAllBytes($documentationPath)
        $markdown = [System.Text.Encoding]::UTF8.GetString($firstBytes)

        $markdown | Should -Match '^# Invoke-MarkdownHelpExample\n'
        $markdown | Should -Match 'Runs the \*\*documented\*\* operation\.'
        $markdown | Should -Match 'Invoke-MarkdownHelpExample -Message <string> \[-Count <int>\] \[<CommonParameters>\]'
        $markdown | Should -Match '### `-Message`\n\nType: `string`  \nRequired: Yes'
        $markdown | Should -Match "    Invoke-MarkdownHelpExample -Message 'hello'"
        $markdown | Should -Match '## Notes\n\nRequires Docker\.'
        $firstBytes[0..2] | Should -Not -Be @(0xEF, 0xBB, 0xBF)

        Build-ContainerModule -Specification $specificationPath -Output $outputPath | Out-Null
        [System.IO.File]::ReadAllBytes($documentationPath) | Should -Be $firstBytes
    }

    It 'does not create a documentation directory when no commands exist' {
        $specificationPath = Join-Path $TestDrive 'NoDocumentation.psd1'
        $outputPath = Join-Path $TestDrive 'no-documentation-output'
        Set-Content -LiteralPath $specificationPath -Value '@{ ModuleName = ''NoDocumentationExample'' }'

        Build-ContainerModule -Specification $specificationPath -Output $outputPath | Out-Null

        Join-Path $outputPath 'Documentation' | Should -Not -Exist
    }
}

Describe 'Install-ContainerModule' {
    BeforeEach {
        $global:dockerCalls = [System.Collections.Generic.List[string]]::new()
        function global:Write-TestContainerModule {
            param ([string] $Path)
            Set-Content -LiteralPath (Join-Path $Path 'Example.psm1') -Value ''
            Set-Content -LiteralPath (Join-Path $Path 'Example.psd1') -Value @'
@{ RootModule = 'Example.psm1'; ModuleVersion = '1.0.0' }
'@
        }
    }

    AfterEach {
        if (Test-Path Function:\docker) {
            Remove-Item Function:\docker -Force
        }
        Remove-Variable -Name dockerCalls -Scope Global -Force -ErrorAction SilentlyContinue
        Remove-Item Function:\Write-TestContainerModule -Force -ErrorAction SilentlyContinue
    }

    It 'copies the embedded module and removes the temporary container' {
        $destination = Join-Path $TestDrive 'installed-module'
        function global:docker {
            $global:dockerCalls.Add(($args -join ' '))
            $global:LASTEXITCODE = 0
            if ($args[0] -eq 'create') { 'container-123' }
            if ($args[0] -eq 'cp') { Write-TestContainerModule -Path $args[2] }
        }

        $installedDirectory = Install-ContainerModule 'example/tool:1.0' -Destination $destination

        $installedDirectory.FullName | Should -Be ([System.IO.Path]::GetFullPath($destination))
        $global:dockerCalls[0] | Should -Be 'create example/tool:1.0'
        $global:dockerCalls[1] | Should -Match '^cp container-123:/PSModule/\. .+\.installed-module\.install-[a-f0-9]{32}$'
        $global:dockerCalls[2] | Should -Be 'rm --force container-123'
        Test-Path -LiteralPath (Join-Path $destination 'Example.psd1') | Should -BeTrue
    }

    It 'removes the temporary container when copying fails' {
        $destination = Join-Path $TestDrive 'failed-install'
        function global:docker {
            $global:dockerCalls.Add(($args -join ' '))
            if ($args[0] -eq 'create') {
                $global:LASTEXITCODE = 0
                'container-failed-copy'
            }
            elseif ($args[0] -eq 'cp') {
                $global:LASTEXITCODE = 17
            }
            else {
                $global:LASTEXITCODE = 0
            }
        }

        { Install-ContainerModule 'example/tool:1.0' -Destination $destination } |
            Should -Throw -ExceptionType ([System.InvalidOperationException]) -ExpectedMessage '*could not copy /PSModule*Exit code: 17*'

        $global:dockerCalls[-1] | Should -Be 'rm --force container-failed-copy'
    }

    It 'previews installation without calling Docker or creating the destination' {
        $destination = Join-Path $TestDrive 'preview-install'
        function global:docker {
            $global:dockerCalls.Add(($args -join ' '))
            $global:LASTEXITCODE = 0
        }

        Install-ContainerModule 'example/tool:1.0' -Destination $destination -WhatIf

        $global:dockerCalls | Should -BeNullOrEmpty
        Test-Path -LiteralPath $destination | Should -BeFalse
    }

    It 'requires Force before replacing an existing destination' {
        $destination = Join-Path $TestDrive 'existing-install'
        New-Item -Path $destination -ItemType Directory | Out-Null
        Set-Content -LiteralPath (Join-Path $destination 'existing.txt') -Value 'preserve'
        function global:docker { throw 'Docker should not be called.' }

        { Install-ContainerModule 'example/tool:1.0' -Destination $destination } |
            Should -Throw -ExceptionType ([System.IO.IOException]) -ExpectedMessage '*already exists*Use -Force*'

        Test-Path -LiteralPath (Join-Path $destination 'existing.txt') | Should -BeTrue
        $global:dockerCalls | Should -BeNullOrEmpty
    }

    It 'rejects a filesystem root as the destination' {
        $rootPath = [System.IO.Path]::GetPathRoot($TestDrive)
        function global:docker { throw 'Docker should not be called.' }

        { Install-ContainerModule 'example/tool:1.0' -Destination $rootPath -Force } |
            Should -Throw -ExceptionType ([System.ArgumentException]) -ExpectedMessage '*destination cannot be a filesystem root*'
    }

    It 'preserves an existing destination when staged manifest validation fails' {
        $destination = Join-Path $TestDrive 'preserved-install'
        New-Item -Path $destination -ItemType Directory | Out-Null
        Set-Content -LiteralPath (Join-Path $destination 'existing.txt') -Value 'preserve'
        function global:docker {
            $global:dockerCalls.Add(($args -join ' '))
            $global:LASTEXITCODE = 0
            if ($args[0] -eq 'create') { 'container-invalid-module' }
        }

        { Install-ContainerModule 'example/tool:1.0' -Destination $destination -Force } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage '*exactly one module manifest*Found 0*'

        Test-Path -LiteralPath (Join-Path $destination 'existing.txt') | Should -BeTrue
        $global:dockerCalls[-1] | Should -Be 'rm --force container-invalid-module'
        @(Get-ChildItem -LiteralPath $TestDrive -Directory -Filter '.preserved-install.install-*').Count | Should -Be 0
    }

    It 'replaces a validated existing destination with Force' {
        $destination = Join-Path $TestDrive 'replaced-install'
        New-Item -Path $destination -ItemType Directory | Out-Null
        Set-Content -LiteralPath (Join-Path $destination 'old.txt') -Value 'old'
        function global:docker {
            $global:dockerCalls.Add(($args -join ' '))
            $global:LASTEXITCODE = 0
            if ($args[0] -eq 'create') { 'container-replacement' }
            if ($args[0] -eq 'cp') { Write-TestContainerModule -Path $args[2] }
        }

        Install-ContainerModule 'example/tool:1.0' -Destination $destination -Force | Out-Null

        Test-Path -LiteralPath (Join-Path $destination 'old.txt') | Should -BeFalse
        Test-ModuleManifest -Path (Join-Path $destination 'Example.psd1') -ErrorAction Stop |
            Should -Not -BeNullOrEmpty
    }

    It 'reports when Docker is unavailable' {
        $destination = Join-Path $TestDrive 'missing-docker-install'
        Remove-Item Function:\docker -Force -ErrorAction SilentlyContinue
        $originalPath = $env:PATH
        try {
            $env:PATH = ''
            { Install-ContainerModule 'example/tool:1.0' -Destination $destination } |
                Should -Throw -ExceptionType ([System.InvalidOperationException]) -ExpectedMessage '*Docker is required*not found on PATH*'
        }
        finally {
            $env:PATH = $originalPath
        }
    }
}

Describe 'Test-LocalRepository script' {
    BeforeAll {
        $repositoryPath = Join-Path $TestDrive 'Repository'
        $specificationDirectory = Join-Path $repositoryPath 'PSModule'
        New-Item -Path $specificationDirectory -ItemType Directory -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $specificationDirectory 'PSModule.psd1') -Value @'
@{ Commands = @(@{ Name = 'Invoke-ExternalRepository'; Parameters = @() }) }
'@
        $scriptPath = Join-Path $PSScriptRoot '..' 'build' 'Test-LocalRepository.ps1'
    }

    It 'returns the target repository model and restores the caller location' {
        $originalLocation = Get-Location

        $model = & $scriptPath -Repository $repositoryPath

        $model.Commands[0].Name | Should -Be 'Invoke-ExternalRepository'
        (Get-Location).Path | Should -Be $originalLocation.Path
    }

    It 'generates repository metadata and restores the caller location' {
        $originalLocation = Get-Location

        $artifact = & $scriptPath -Repository $repositoryPath -Generate -Output './generated'

        $artifact.FullName | Should -Be (Join-Path $repositoryPath 'generated' 'Metadata' 'model.json')
        (Get-Location).Path | Should -Be $originalLocation.Path
    }

    It 'initializes a missing specification from repository PowerShell and documentation' {
        $originalLocation = Get-Location
        $repositoryPath = Join-Path $TestDrive 'InferredRepository'
        $scriptsPath = New-Item -Path (Join-Path $repositoryPath 'scripts') -ItemType Directory -Force
        $modulesPath = New-Item -Path (Join-Path $scriptsPath 'modules') -ItemType Directory -Force
        Set-Content -LiteralPath (Join-Path $repositoryPath 'README.md') -Value @'
# Inferred Repository
docker run --rm ghcr.io/example/inferred:latest
'@
        Set-Content -LiteralPath (Join-Path $repositoryPath 'container-tool.ps1') -Value @'
param([string] $Tag)
'@
        Set-Content -LiteralPath (Join-Path $scriptsPath 'install-tool.ps1') -Value @'
param(
    [Parameter(Mandatory)][string] $Name,
    [Parameter(Mandatory = $false)][string] $Optional,
    [switch] $Force
)
'@
        Set-Content -LiteralPath (Join-Path $modulesPath 'Tools.psm1') -Value @'
function Test-RepositoryTool { param([string] $Path) }
Export-ModuleMember -Function @('Test-RepositoryTool')
'@

        & $scriptPath -Repository ($repositoryPath + [IO.Path]::DirectorySeparatorChar) | Out-Null

        $specificationPath = Join-Path $repositoryPath 'PSModule' 'PSModule.psd1'
        $definition = Import-PowerShellDataFile $specificationPath
        $definition.GeneratedBy | Should -Be 'SubZeroDev.ContainerPSGenerator'
        $definition.ModuleName | Should -Be 'InferredRepository'
        $definition.ContainerImage | Should -Be 'ghcr.io/example/inferred:latest'
        $definition.Commands.Name | Should -Be @('Invoke-InstallTool', 'Test-RepositoryTool')
        $definition.Commands[0].SourceKind | Should -Be 'Script'
        $definition.Commands[0].Parameters.Name | Should -Be @('Name', 'Optional', 'Force')
        $definition.Commands[0].Parameters[0].Mandatory | Should -BeTrue
        $definition.Commands[0].Parameters[1].Mandatory | Should -BeFalse
        $definition.Commands[0].Parameters[2].Type | Should -Be 'switch'
        $definition.Commands[1].SourceKind | Should -Be 'ModuleFunction'
        Test-Path -LiteralPath (Join-Path $repositoryPath 'artifacts' 'PSModule' 'Public' 'Invoke-ContainerTool.ps1') |
            Should -BeFalse
        Test-Path -LiteralPath (Join-Path $repositoryPath 'artifacts' 'PSModule' 'Public' 'Invoke-InstallTool.ps1') |
            Should -BeTrue
        Test-Path -LiteralPath (Join-Path $repositoryPath 'artifacts' 'PSModule' 'Public' 'Test-RepositoryTool.ps1') |
            Should -BeTrue
        (Get-Location).Path | Should -Be $originalLocation.Path
    }

    It 'refreshes an empty specification but preserves authored commands' {
        $repositoryPath = Join-Path $TestDrive 'RefreshRepository'
        $specificationDirectory = New-Item -Path (Join-Path $repositoryPath 'PSModule') -ItemType Directory -Force
        $scriptsPath = New-Item -Path (Join-Path $repositoryPath 'scripts') -ItemType Directory -Force
        $specificationPath = Join-Path $specificationDirectory 'PSModule.psd1'
        Set-Content -LiteralPath $specificationPath -Value '@{ ModuleName = ''Old''; Commands = @() }'
        Set-Content -LiteralPath (Join-Path $scriptsPath 'run-tool.ps1') -Value 'param([string] $Value)'

        & $scriptPath -Repository $repositoryPath | Out-Null

        $refreshed = Import-PowerShellDataFile $specificationPath
        $refreshed.ModuleName | Should -Be 'RefreshRepository'
        $refreshed.Commands.Name | Should -Be 'Invoke-RunTool'
        Test-Path -LiteralPath (Join-Path $repositoryPath 'artifacts' 'PSModule' 'Public' 'Invoke-RunTool.ps1') |
            Should -BeTrue

        $authoredSource = "@{ ModuleName = 'Authored'; Commands = @(@{ Name = 'Invoke-Authored'; Parameters = @() }) }"
        Set-Content -LiteralPath $specificationPath -Value $authoredSource
        & $scriptPath -Repository $repositoryPath | Out-Null

        (Get-Content -LiteralPath $specificationPath -Raw).Trim() | Should -Be $authoredSource
    }

    It 'refreshes a legacy generated scaffold using only scripts-directory sources' {
        $repositoryPath = Join-Path $TestDrive 'LegacyGeneratedRepository'
        $specificationDirectory = New-Item -Path (Join-Path $repositoryPath 'PSModule') -ItemType Directory -Force
        $specificationPath = Join-Path $specificationDirectory 'PSModule.psd1'
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    ModuleName = 'LegacyGeneratedRepository'
    Commands = @(
        @{
            Name = 'Invoke-Existing'
            Description = 'Scaffolded from ''scripts/existing.ps1''. Review its container invocation mappings before publishing.'
            SourcePath = 'scripts/existing.ps1'
            SourceKind = 'Script'
            Parameters = @()
        }
    )
}
'@
        Set-Content -LiteralPath (Join-Path $repositoryPath 'setup.ps1') -Value 'param([switch] $Ignored)'
        $scriptsPath = New-Item -Path (Join-Path $repositoryPath 'scripts') -ItemType Directory -Force
        Set-Content -LiteralPath (Join-Path $scriptsPath 'setup.ps1') -Value 'param([switch] $Force)'

        $commands = @(& $scriptPath -Repository $repositoryPath -ListCommands)
        $definition = Import-PowerShellDataFile $specificationPath

        $definition.Commands.Name | Should -Be 'Invoke-Setup'
        $definition.Commands[0].Parameters.Name | Should -Be 'Force'
        $commands.Name | Should -Contain 'Invoke-Setup'
        Remove-Module LegacyGeneratedRepository -Force
    }

    It 'imports the generated module and lists commands for immediate testing' {
        $commands = @(& $scriptPath -Repository $repositoryPath -ListCommands -Output './listed')

        $commands.Name | Should -Contain 'Invoke-ExternalRepository'
        (Get-Command Invoke-ExternalRepository -ErrorAction Stop).ModuleName | Should -Be 'PSModule'

        Remove-Module PSModule -Force
    }

    It 'returns no commands when repository discovery produces an empty module' {
        $emptyRepositoryPath = Join-Path $TestDrive 'EmptyRepository'
        New-Item -Path $emptyRepositoryPath -ItemType Directory -Force | Out-Null

        $commands = @(& $scriptPath -Repository $emptyRepositoryPath -ListCommands)

        $commands.Count | Should -Be 0
        Test-Path -LiteralPath (
            Join-Path $emptyRepositoryPath 'artifacts' 'PSModule' 'Public'
        ) | Should -BeFalse
        Remove-Module EmptyRepository -Force -ErrorAction SilentlyContinue
    }
}

Describe 'Maintained repository integration fixtures' {
    BeforeAll {
        $fixtureRoot = Join-Path $PSScriptRoot 'fixtures' 'repositories'
        $localRepositoryScript = Join-Path $PSScriptRoot '..' 'build' 'Test-LocalRepository.ps1'
    }

    It 'initializes, packages, imports, and invokes the script-only fixture' {
        $repositoryPath = Join-Path $TestDrive 'ScriptOnlyRepository'
        Copy-Item -LiteralPath (Join-Path $fixtureRoot 'ScriptOnly') `
            -Destination $repositoryPath -Recurse

        $commands = @(& $localRepositoryScript -Repository $repositoryPath -ListCommands)
        $definition = Import-PowerShellDataFile (
            Join-Path $repositoryPath 'PSModule' 'PSModule.psd1'
        )

        try {
            $definition.GeneratedBy | Should -Be 'SubZeroDev.ContainerPSGenerator'
            $definition.ModuleName | Should -Be 'ScriptOnlyRepository'
            $definition.ContainerImage | Should -Be 'ghcr.io/example/script-fixture:latest'
            $definition.Commands.Name | Should -Be 'Invoke-WriteGreeting'
            $definition.Commands[0].SourceKind | Should -Be 'Script'
            $definition.Commands[0].Parameters.Name | Should -Be @('Name', 'Uppercase')
            $commands.Name | Should -Contain 'Invoke-WriteGreeting'
            Test-Path -LiteralPath (
                Join-Path $repositoryPath 'artifacts' 'PSModule' 'Scripts' 'support' 'settings.json'
            ) | Should -BeTrue

            Invoke-WriteGreeting -Name 'Codex' -Uppercase | Should -Be 'HELLO, CODEX!'
        }
        finally {
            Remove-Module ScriptOnlyRepository -Force -ErrorAction SilentlyContinue
        }
    }

    It 'inspects and generates the authored build-agent fixture' {
        $repositoryPath = Join-Path $TestDrive 'BuildAgentRepository'
        Copy-Item -LiteralPath (Join-Path $fixtureRoot 'BuildAgent') `
            -Destination $repositoryPath -Recurse
        $specificationPath = Join-Path $repositoryPath 'PSModule' 'PSModule.psd1'

        $inspection = Get-ContainerModuleInspection -Specification $specificationPath
        $commands = @(& $localRepositoryScript -Repository $repositoryPath -ListCommands)
        $generatedCommandPath = Join-Path $repositoryPath `
            'artifacts' 'PSModule' 'Public' 'Invoke-BuildAgent.ps1'
        $generatedCommand = Get-Content -LiteralPath $generatedCommandPath -Raw

        try {
            $inspection.Data.Dockerfiles[0].Stages[0].Image |
                Should -Be 'mcr.microsoft.com/dotnet/sdk:8.0'
            $inspection.Data.DotNetProjects[0].PackageReferences.Name |
                Should -Contain 'Microsoft.NET.Test.Sdk'
            $buildProject = $inspection.Data.DotNetProjects |
                Where-Object Path -eq 'src/Build/Build.csproj'
            $buildProject.IsExecutable | Should -BeTrue
            $buildProject.IsTestProject | Should -BeFalse
            $buildProject.ProjectReferences.Path | Should -Be 'src/Common/Common.csproj'
            ($inspection.Data.DotNetProjects |
                Where-Object Path -eq 'src/Build.Tests/Build.Tests.csproj').IsTestProject |
                Should -BeTrue
            $inspection.Data.GitHubActions[0].Name | Should -Be 'Build'
            $inspection.Data.GitHubActions[0].Jobs | Should -Be 'build'
            $inspection.Data.Nuke.IsConfigured | Should -BeTrue
            $inspection.Data.Nuke.ProjectPaths | Should -Be @(
                'src/Build/Build.csproj'
                'src/Common/Common.csproj'
            )
            $inspection.Data.Nuke.ConfiguredParameterNames | Should -Be 'Configuration'
            $inspection.Data.Nuke.ParameterNames | Should -Be @(
                'Configuration'
                'RegistryToken'
                'Target'
            )
            $inspection.Data.Nuke.Targets | Should -Be @('Build', 'Pack', 'Test')
            $commands.Name | Should -Contain 'Invoke-BuildAgent'
            (Get-Command Invoke-BuildAgent -ErrorAction Stop).ModuleName |
                Should -Be 'BuildAgentFixture'
            (Get-Help Invoke-BuildAgent).Synopsis |
                Should -Be 'Runs a target in the build-agent container.'
            $generatedCommand | Should -Match ([regex]::Escape('--target'))
            $generatedCommand | Should -Match ([regex]::Escape('CONFIGURATION'))
            $generatedCommand | Should -Match ([regex]::Escape('/workspace'))
            {
                Invoke-BuildAgent `
                    -Repository $repositoryPath `
                    -Target Test `
                    -Configuration Release `
                    -WhatIf
            } | Should -Not -Throw
        }
        finally {
            Remove-Module BuildAgentFixture -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Minimal runnable container example' {
    BeforeAll {
        $exampleRoot = Join-Path $PSScriptRoot '..' 'examples' 'Minimal'
        $specificationPath = Join-Path $exampleRoot 'PSModule' 'PSModule.psd1'
    }

    It 'contains parseable host and container entry-point scripts' {
        foreach ($scriptName in @('Run-Example.ps1', 'Invoke-ExampleContainer.ps1')) {
            $tokens = $null
            $parseErrors = $null
            $null = [Management.Automation.Language.Parser]::ParseFile(
                (Join-Path $exampleRoot $scriptName),
                [ref] $tokens,
                [ref] $parseErrors
            )

            $parseErrors | Should -BeNullOrEmpty
        }
    }

    It 'uses one image identity across generation, packaging, and the lifecycle runner' {
        $model = Get-ContainerModuleModel -Specification $specificationPath
        $dockerfile = Get-Content -LiteralPath (Join-Path $exampleRoot 'Dockerfile') -Raw
        $runnerTokens = $null
        $runnerErrors = $null
        $runnerAst = [Management.Automation.Language.Parser]::ParseFile(
            (Join-Path $exampleRoot 'Run-Example.ps1'),
            [ref] $runnerTokens,
            [ref] $runnerErrors
        )
        $runnerCommands = @($runnerAst.FindAll({
            param ($node)
            $node -is [Management.Automation.Language.CommandAst]
        }, $true).GetCommandName())

        $model.ContainerImage | Should -Be 'subzerodev-containerpsgenerator-minimal:local'
        $dockerfile | Should -Match 'COPY artifacts/PSModule /PSModule'
        $runnerCommands | Should -Contain 'Build-ContainerModule'
        $runnerCommands | Should -Contain 'Install-ContainerModule'
        $runnerCommands | Should -Contain 'Import-Module'
        $runnerCommands | Should -Contain 'Invoke-Example'
        $runnerCommands | Should -Contain 'Get-Help'
        $runnerCommands | Should -Contain 'Get-Content'
        $runnerCommands | Should -Contain 'Remove-Module'
        $runnerCommands | Should -Contain 'Remove-Item'
    }
}

Describe 'Discovered PowerShell source execution' {
    It 'invokes a discovered script with its bound parameters instead of Docker' {
        $repositoryPath = Join-Path $TestDrive 'source-repository'
        $specificationDirectory = New-Item -Path (Join-Path $repositoryPath 'PSModule') -ItemType Directory -Force
        $scriptsDirectory = New-Item -Path (Join-Path $repositoryPath 'scripts') -ItemType Directory -Force
        $sourcePath = Join-Path $scriptsDirectory 'run-source.ps1'
        $helperDirectory = New-Item -Path (Join-Path $scriptsDirectory 'modules') -ItemType Directory -Force
        Set-Content -LiteralPath (Join-Path $helperDirectory 'Common.ps1') -Value @'
function Write-SourceResult {
    param([string] $Path, [string] $Value)
    Set-Content -LiteralPath $Path -Value $Value
}
'@
        $supportDirectory = New-Item -Path (Join-Path $scriptsDirectory 'support') -ItemType Directory -Force
        Set-Content -LiteralPath (Join-Path $supportDirectory 'settings.json') -Value '{ "packaged": true }'
        $resultPath = Join-Path $repositoryPath 'result.txt'
        Set-Content -LiteralPath $sourcePath -Value @'
param([Parameter(Mandatory)][string] $Value, [Parameter(Mandatory)][string] $ResultPath)
. (Join-Path $PSScriptRoot 'modules/Common.ps1')
Write-SourceResult -Path $ResultPath -Value $Value
'@
        $specificationPath = Join-Path $specificationDirectory 'PSModule.psd1'
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    ModuleName = 'SourceExample'
    Commands = @(@{
        Name = 'Invoke-SourceExample'
        SourceKind = 'Script'
        SourcePath = 'scripts/run-source.ps1'
        Parameters = @(
            @{ Name = 'Value'; Type = 'string'; Mandatory = $true }
            @{ Name = 'ResultPath'; Type = 'string'; Mandatory = $true }
        )
    })
}
'@
        $outputPath = Join-Path $repositoryPath 'artifacts'

        Build-ContainerModule -Specification $specificationPath -Output $outputPath | Out-Null
        $module = Import-Module (Join-Path $outputPath 'SourceExample.psd1') -Force -PassThru
        $generatedCommandSource = Get-Content -LiteralPath (
            Join-Path $outputPath 'Public' 'Invoke-SourceExample.ps1'
        ) -Raw
        function global:docker { throw 'Docker must not be called for a discovered script.' }
        try {
            $verboseOutput = Invoke-SourceExample -Value 'executed' -ResultPath $resultPath -Verbose 4>&1

            Test-Path -LiteralPath (Join-Path $outputPath 'Scripts' 'run-source.ps1') |
                Should -BeTrue
            Test-Path -LiteralPath (
                Join-Path $outputPath 'Scripts' 'modules' 'Common.ps1'
            ) | Should -BeTrue
            Test-Path -LiteralPath (
                Join-Path $outputPath 'Scripts' 'support' 'settings.json'
            ) | Should -BeTrue
            $generatedCommandSource | Should -Match '\$moduleRoot = Split-Path \$PSScriptRoot -Parent'
            $expectedPackagedPath = Join-Path 'Scripts' 'run-source.ps1'
            $generatedCommandSource | Should -Match (
                [regex]::Escape("Join-Path `$moduleRoot '$expectedPackagedPath'")
            )
            $generatedCommandSource | Should -Not -Match [regex]::Escape($repositoryPath)
            Get-Content -LiteralPath $resultPath -Raw | Should -Match '^executed'
            $verboseOutput -join "`n" | Should -Match 'Invoking discovered PowerShell source'
            $verboseOutput -join "`n" | Should -Match 'PowerShell source finished after'
        }
        finally {
            Remove-Item Function:\docker -Force
            Remove-Module $module -Force
        }
    }

    It 'invokes a discovered exported module function module-qualified instead of Docker' {
        $repositoryPath = Join-Path $TestDrive 'module-source-repository'
        $specificationDirectory = New-Item -Path (Join-Path $repositoryPath 'PSModule') -ItemType Directory -Force
        $modulesDirectory = New-Item -Path (Join-Path $repositoryPath 'scripts' 'modules') -ItemType Directory -Force
        $sourcePath = Join-Path $modulesDirectory 'SourceTools.psm1'
        $resultPath = Join-Path $repositoryPath 'module-result.txt'
        Set-Content -LiteralPath $sourcePath -Value @'
function Invoke-SourceTool {
    param([Parameter(Mandatory)][string] $Value, [Parameter(Mandatory)][string] $ResultPath)
    Set-Content -LiteralPath $ResultPath -Value $Value
}
Export-ModuleMember -Function Invoke-SourceTool
'@
        $specificationPath = Join-Path $specificationDirectory 'PSModule.psd1'
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    ModuleName = 'ModuleSourceExample'
    Commands = @(@{
        Name = 'Invoke-SourceTool'
        SourceKind = 'ModuleFunction'
        SourcePath = 'scripts/modules/SourceTools.psm1'
        Parameters = @(
            @{ Name = 'Value'; Type = 'string'; Mandatory = $true }
            @{ Name = 'ResultPath'; Type = 'string'; Mandatory = $true }
        )
    })
}
'@
        $outputPath = Join-Path $repositoryPath 'artifacts'

        Build-ContainerModule -Specification $specificationPath -Output $outputPath | Out-Null
        $module = Import-Module (Join-Path $outputPath 'ModuleSourceExample.psd1') -Force -PassThru
        function global:docker { throw 'Docker must not be called for a discovered module function.' }
        try {
            Invoke-SourceTool -Value 'module-executed' -ResultPath $resultPath

            Test-Path -LiteralPath (
                Join-Path $outputPath 'Scripts' 'modules' 'SourceTools.psm1'
            ) | Should -BeTrue
            Test-Path -LiteralPath (Join-Path $outputPath 'Modules') | Should -BeFalse
            Get-Content -LiteralPath $resultPath -Raw | Should -Match '^module-executed'
        }
        finally {
            Remove-Item Function:\docker -Force
            Remove-Module $module -Force
            Remove-Module SourceTools -Force -ErrorAction SilentlyContinue
        }
    }

    It 'rejects an authored PowerShell source outside the scripts directory' {
        $repositoryPath = Join-Path $TestDrive 'outside-source-repository'
        $specificationDirectory = New-Item -Path (Join-Path $repositoryPath 'PSModule') -ItemType Directory -Force
        Set-Content -LiteralPath (Join-Path $repositoryPath 'outside.ps1') -Value 'param()'
        $specificationPath = Join-Path $specificationDirectory 'PSModule.psd1'
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    ModuleName = 'OutsideSource'
    Commands = @(@{
        Name = 'Invoke-Outside'
        SourceKind = 'Script'
        SourcePath = 'outside.ps1'
        Parameters = @()
    })
}
'@

        {
            Build-ContainerModule -Specification $specificationPath -Output (
                Join-Path $repositoryPath 'artifacts'
            )
        } | Should -Throw "*must be beneath the repository's 'scripts' directory*"
    }
}
