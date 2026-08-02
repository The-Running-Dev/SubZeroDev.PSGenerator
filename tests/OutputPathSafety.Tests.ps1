BeforeAll {
    $manifestPath = if (-not [string]::IsNullOrWhiteSpace($env:PSGENERATOR_MODULE_PATH)) {
        [IO.Path]::GetFullPath($env:PSGENERATOR_MODULE_PATH)
    }
    else {
        Join-Path $PSScriptRoot '..' 'src' 'SubZeroDev.PSGenerator.psd1'
    }
    Import-Module $manifestPath -Force

    function New-OutputSafetyFixture {
        param (
            [Parameter(Mandatory)] [string] $Root,
            [string] $ModuleName = 'OutputSafetyExample',
            [switch] $WithScripts
        )

        $directoryPath = Join-Path $Root 'repository'
        $specificationDirectory = Join-Path $directoryPath 'PSModule'
        New-Item -Path $specificationDirectory -ItemType Directory -Force | Out-Null
        $specificationPath = Join-Path $specificationDirectory 'PSModule.psd1'
        if ($WithScripts) {
            $scriptsPath = Join-Path $directoryPath 'scripts'
            $supportPath = Join-Path $scriptsPath 'support'
            New-Item -Path $supportPath -ItemType Directory -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $scriptsPath 'Invoke-SafeSource.ps1') -Value @'
param([string] $Name)
"Hello, $Name"
'@
            Set-Content -LiteralPath (Join-Path $supportPath 'settings.json') -Value '{}'
            Set-Content -LiteralPath $specificationPath -Value @"
@{
    ModuleName = '$ModuleName'
    Commands = @(
        @{
            Name = 'Invoke-SafeSource'
            SourceKind = 'Script'
            SourcePath = 'scripts/Invoke-SafeSource.ps1'
            Parameters = @(@{ Name = 'Name'; Type = 'string' })
        }
    )
}
"@
        }
        else {
            $scriptsPath = Join-Path $directoryPath 'scripts'
            Set-Content -LiteralPath $specificationPath -Value (
                "@{ ModuleName = '$ModuleName'; Commands = @() }"
            )
        }

        [pscustomobject] @{
            DirectoryPath     = $directoryPath
            SpecificationPath = $specificationPath
            ScriptsPath       = $scriptsPath
            OutputPath        = Join-Path $directoryPath 'artifacts' 'PSModule'
            ModuleName        = $ModuleName
        }
    }

    function Write-TestOutputMarker {
        param (
            [Parameter(Mandatory)] [string] $OutputPath,
            [string] $Content = @'
{
  "SchemaVersion": 1,
  "Generator": "SubZeroDev.PSGenerator",
  "ArtifactType": "GeneratedPowerShellModule"
}
'@
        )

        $metadataPath = Join-Path $OutputPath 'Metadata'
        New-Item -Path $metadataPath -ItemType Directory -Force | Out-Null
        [IO.File]::WriteAllText(
            (Join-Path $metadataPath 'output.json'),
            $Content.Replace("`r`n", "`n"),
            [Text.UTF8Encoding]::new($false)
        )
    }

    function New-LegacyOutput {
        param (
            [Parameter(Mandatory)] [string] $OutputPath,
            [string] $ModuleName = 'LegacyOutput',
            [switch] $WithOptionalDirectories
        )

        $metadataPath = Join-Path $OutputPath 'Metadata'
        New-Item -Path $metadataPath -ItemType Directory -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $metadataPath 'model.json') -Value (
            @{ SchemaVersion = 1; ModuleName = $ModuleName; Commands = @() } |
                ConvertTo-Json -Depth 5
        )
        Set-Content -LiteralPath (Join-Path $OutputPath "$ModuleName.psd1") -Value '@{}'
        Set-Content -LiteralPath (Join-Path $OutputPath "$ModuleName.psm1") -Value ''
        if ($WithOptionalDirectories) {
            foreach ($name in @('Public', 'Documentation', 'Scripts')) {
                New-Item -Path (Join-Path $OutputPath $name) -ItemType Directory -Force |
                    Out-Null
            }
        }
    }

    function New-OutputContext {
        param (
            [Parameter(Mandatory)] [psobject] $Fixture,
            [Parameter(Mandatory)] [string] $OutputPath,
            [switch] $Force
        )

        [pscustomobject] @{
            OutputPath        = $OutputPath
            SpecificationPath = $Fixture.SpecificationPath
            DirectoryPath     = $Fixture.DirectoryPath
            ForceOutputReset  = [bool] $Force
        }
    }
}

Describe 'Generated output public contract and context shape' {
    It 'declares Force and ForceOutput without changing public exports' {
        $buildCommand = Get-Command Build-PSModule -Module SubZeroDev.PSGenerator
        $initializeCommand = Get-Command Initialize-PSModuleDirectory -Module SubZeroDev.PSGenerator

        $buildCommand.Parameters.Force.ParameterType | Should -Be ([switch])
        $initializeCommand.Parameters.ForceOutput.ParameterType | Should -Be ([switch])
        (Get-Help Build-PSModule).Parameters.Parameter.Name | Should -Contain 'Force'
        (Get-Help Initialize-PSModuleDirectory).Parameters.Parameter.Name |
            Should -Contain 'ForceOutput'
        @(Get-Command -Module SubZeroDev.PSGenerator).Count | Should -Be 9
    }

    It 'adds a false ForceOutputReset value without creating output during context construction' {
        $fixture = New-OutputSafetyFixture -Root (Join-Path $TestDrive 'context-default')

        InModuleScope SubZeroDev.PSGenerator -Parameters @{ Fixture = $fixture } {
            param ($Fixture)

            $context = New-PSModuleBuildContext `
                -SpecificationPath $Fixture.SpecificationPath `
                -OutputPath $Fixture.OutputPath

            $context.ForceOutputReset | Should -BeFalse
            Test-Path -LiteralPath $Fixture.OutputPath | Should -BeFalse
        }
    }

    It 'CX-01 treats a context without ForceOutputReset as not forced' {
        $fixture = New-OutputSafetyFixture -Root (Join-Path $TestDrive 'context-no-force')
        $context = [pscustomobject] @{
            OutputPath        = $fixture.OutputPath
            SpecificationPath = $fixture.SpecificationPath
            DirectoryPath     = $fixture.DirectoryPath
        }

        InModuleScope SubZeroDev.PSGenerator -Parameters @{
            Context    = $context
            MarkerPath = (Join-Path $fixture.OutputPath 'Metadata' 'output.json')
        } {
            param ($Context, $MarkerPath)

            $null = Reset-PSModuleOutput -Context $Context
            Test-Path -LiteralPath $MarkerPath -PathType Leaf | Should -BeTrue
        }
    }

    It 'CX-02 fails closed when SpecificationPath is absent without mutating output' {
        $fixture = New-OutputSafetyFixture -Root (Join-Path $TestDrive 'context-no-spec')
        New-Item -Path $fixture.OutputPath -ItemType Directory -Force | Out-Null
        $sentinel = Join-Path $fixture.OutputPath 'keep.txt'
        Set-Content -LiteralPath $sentinel -Value 'keep'
        $context = [pscustomobject] @{
            OutputPath    = $fixture.OutputPath
            DirectoryPath = $fixture.DirectoryPath
        }

        InModuleScope SubZeroDev.PSGenerator -Parameters @{ Context = $context } {
            param ($Context)

            { Reset-PSModuleOutput -Context $Context } |
                Should -Throw -ExceptionType ([ArgumentException]) -ExpectedMessage '*SpecificationPath*'
        }
        Get-Content -LiteralPath $sentinel | Should -Be 'keep'
    }

    It 'CX-03 fails closed when DirectoryPath is absent without mutating output' {
        $fixture = New-OutputSafetyFixture -Root (Join-Path $TestDrive 'context-no-directory')
        New-Item -Path $fixture.OutputPath -ItemType Directory -Force | Out-Null
        $sentinel = Join-Path $fixture.OutputPath 'keep.txt'
        Set-Content -LiteralPath $sentinel -Value 'keep'
        $context = [pscustomobject] @{
            OutputPath        = $fixture.OutputPath
            SpecificationPath = $fixture.SpecificationPath
        }

        InModuleScope SubZeroDev.PSGenerator -Parameters @{ Context = $context } {
            param ($Context)

            { Reset-PSModuleOutput -Context $Context } |
                Should -Throw -ExceptionType ([ArgumentException]) -ExpectedMessage '*DirectoryPath*'
        }
        Get-Content -LiteralPath $sentinel | Should -Be 'keep'
    }

    It 'CX-04 fails closed on null source-boundary values' -ForEach @(
        @{ Property = 'SpecificationPath' }
        @{ Property = 'DirectoryPath' }
    ) {
        $fixture = New-OutputSafetyFixture -Root (Join-Path $TestDrive "context-null-$Property")
        New-Item -Path $fixture.OutputPath -ItemType Directory -Force | Out-Null
        $sentinel = Join-Path $fixture.OutputPath 'keep.txt'
        Set-Content -LiteralPath $sentinel -Value 'keep'
        $context = New-OutputContext -Fixture $fixture -OutputPath $fixture.OutputPath
        $context.$Property = $null

        InModuleScope SubZeroDev.PSGenerator -Parameters @{
            Context  = $context
            Property = $Property
        } {
            param ($Context, $Property)

            { Reset-PSModuleOutput -Context $Context } |
                Should -Throw -ExceptionType ([ArgumentException]) -ExpectedMessage "*$Property*"
        }
        Get-Content -LiteralPath $sentinel | Should -Be 'keep'
    }
}

Describe 'Generated output path relationships' {
    It 'recognizes ancestors without accepting equality or sibling prefixes' {
        $root = Join-Path $TestDrive 'relations'
        $child = Join-Path $root 'child'
        $siblingPrefix = $root + '-other'

        InModuleScope SubZeroDev.PSGenerator -Parameters @{
            Root          = $root
            Child         = $child
            SiblingPrefix = $siblingPrefix
        } {
            param ($Root, $Child, $SiblingPrefix)

            Test-PSModulePathAncestor -CandidateAncestor $Root -Path $Child |
                Should -BeTrue
            Test-PSModulePathAncestor -CandidateAncestor $Root -Path $Root |
                Should -BeFalse
            Test-PSModulePathAncestor -CandidateAncestor $Root -Path $SiblingPrefix |
                Should -BeFalse
        }
    }

    It 'does not re-normalize a trimmed volume root' {
        $root = [IO.Path]::GetPathRoot($TestDrive)
        $child = Join-Path $root 'output-safety-child'

        InModuleScope SubZeroDev.PSGenerator -Parameters @{ Root = $root; Child = $child } {
            param ($Root, $Child)

            Test-PSModulePathAncestor -CandidateAncestor $Root -Path $Child |
                Should -BeTrue
        }
    }
}

Describe 'Generated output ownership classification' {
    It 'OW-01 classifies a missing path as Missing' {
        $outputPath = Join-Path $TestDrive 'missing-output'

        InModuleScope SubZeroDev.PSGenerator -Parameters @{ OutputPath = $outputPath } {
            param ($OutputPath)
            (Test-PSModuleOutputOwnership -OutputPath $OutputPath).State | Should -Be 'Missing'
        }
    }

    It 'OW-02 classifies an empty directory as Empty' {
        $outputPath = New-Item -Path (Join-Path $TestDrive 'empty-output') -ItemType Directory

        InModuleScope SubZeroDev.PSGenerator -Parameters @{ OutputPath = $outputPath.FullName } {
            param ($OutputPath)
            (Test-PSModuleOutputOwnership -OutputPath $OutputPath).State | Should -Be 'Empty'
        }
    }

    It 'OW-03 counts a hidden entry as unowned content' {
        $outputPath = New-Item -Path (Join-Path $TestDrive 'hidden-output') -ItemType Directory
        $hiddenPath = Join-Path $outputPath '.hidden'
        Set-Content -LiteralPath $hiddenPath -Value 'content'
        if ($IsWindows) { (Get-Item -LiteralPath $hiddenPath).Attributes += 'Hidden' }

        InModuleScope SubZeroDev.PSGenerator -Parameters @{ OutputPath = $outputPath.FullName } {
            param ($OutputPath)
            (Test-PSModuleOutputOwnership -OutputPath $OutputPath).State | Should -Be 'Unowned'
        }
    }

    It 'OW-04 classifies the exact marker as Owned' {
        $outputPath = Join-Path $TestDrive 'owned-output'
        Write-TestOutputMarker -OutputPath $outputPath

        InModuleScope SubZeroDev.PSGenerator -Parameters @{ OutputPath = $outputPath } {
            param ($OutputPath)
            $ownership = Test-PSModuleOutputOwnership -OutputPath $OutputPath
            $ownership.PSObject.TypeNames | Should -Contain 'SubZeroDev.PSGenerator.OutputOwnership'
            $ownership.State | Should -Be 'Owned'
        }
    }

    It 'requires exact case-sensitive marker property names' {
        $outputPath = Join-Path $TestDrive 'marker-property-case'
        Write-TestOutputMarker -OutputPath $outputPath -Content (
            '{"schemaversion":1,"generator":"SubZeroDev.PSGenerator",' +
            '"artifacttype":"GeneratedPowerShellModule"}'
        )

        InModuleScope SubZeroDev.PSGenerator -Parameters @{ OutputPath = $outputPath } {
            param ($OutputPath)
            (Test-PSModuleOutputOwnership -OutputPath $OutputPath).State |
                Should -Be 'InvalidMarker'
        }
    }

    It 'OW-05 through OW-08 rejects malformed or mismatched marker content' -ForEach @(
        @{ Id = 'OW-05'; Content = '{not-json' }
        @{ Id = 'OW-06'; Content = '{"SchemaVersion":2,"Generator":"SubZeroDev.PSGenerator","ArtifactType":"GeneratedPowerShellModule"}' }
        @{ Id = 'OW-07'; Content = '{"SchemaVersion":1,"Generator":"Other","ArtifactType":"GeneratedPowerShellModule"}' }
        @{ Id = 'OW-08'; Content = '{"SchemaVersion":1,"Generator":"SubZeroDev.PSGenerator","ArtifactType":"Other"}' }
    ) {
        $outputPath = Join-Path $TestDrive "invalid-marker-$Id"
        Write-TestOutputMarker -OutputPath $outputPath -Content $Content

        InModuleScope SubZeroDev.PSGenerator -Parameters @{ OutputPath = $outputPath } {
            param ($OutputPath)
            (Test-PSModuleOutputOwnership -OutputPath $OutputPath).State |
                Should -Be 'InvalidMarker'
        }
    }

    It 'OW-09 rejects a marker that is not a regular file' {
        $outputPath = Join-Path $TestDrive 'marker-directory'
        New-Item -Path (Join-Path $outputPath 'Metadata' 'output.json') `
            -ItemType Directory -Force | Out-Null

        InModuleScope SubZeroDev.PSGenerator -Parameters @{ OutputPath = $outputPath } {
            param ($OutputPath)
            (Test-PSModuleOutputOwnership -OutputPath $OutputPath).State |
                Should -Be 'InvalidMarker'
        }
    }

    It 'OW-10 recognizes full and empty-module pre-marker packages as Legacy' -ForEach @(
        @{ Name = 'full'; OptionalDirectories = $true }
        @{ Name = 'empty'; OptionalDirectories = $false }
    ) {
        $outputPath = Join-Path $TestDrive "legacy-$Name"
        New-LegacyOutput `
            -OutputPath $outputPath `
            -ModuleName "Legacy$Name" `
            -WithOptionalDirectories:$OptionalDirectories

        InModuleScope SubZeroDev.PSGenerator -Parameters @{ OutputPath = $outputPath } {
            param ($OutputPath)
            (Test-PSModuleOutputOwnership -OutputPath $OutputPath).State | Should -Be 'Legacy'
        }
    }

    It 'rejects linked legacy root artifacts' -ForEach @(
        @{ Artifact = 'Manifest'; Extension = 'psd1' }
        @{ Artifact = 'Loader'; Extension = 'psm1' }
    ) {
        $outputPath = Join-Path $TestDrive "legacy-linked-$Artifact"
        $moduleName = "Linked$Artifact"
        New-LegacyOutput -OutputPath $outputPath -ModuleName $moduleName
        $artifactPath = Join-Path $outputPath "$moduleName.$Extension"
        $targetPath = Join-Path $TestDrive "external-$Artifact.$Extension"
        Set-Content -LiteralPath $targetPath -Value $(if ($Extension -eq 'psd1') { '@{}' } else { '' })
        Remove-Item -LiteralPath $artifactPath -Force
        try {
            New-Item -Path $artifactPath -ItemType SymbolicLink -Target $targetPath `
                -ErrorAction Stop | Out-Null
        }
        catch {
            Set-ItResult -Skipped -Because 'this host does not permit creating symbolic links'
            return
        }

        try {
            InModuleScope SubZeroDev.PSGenerator -Parameters @{ OutputPath = $outputPath } {
                param ($OutputPath)
                (Test-PSModuleOutputOwnership -OutputPath $OutputPath).State |
                    Should -Be 'Unowned'
            }
        }
        finally {
            Remove-Item -LiteralPath $artifactPath -Force -ErrorAction SilentlyContinue
        }
    }

    It 'OW-11 through OW-14 fails closed on incomplete legacy shapes' -ForEach @(
        @{ Id = 'OW-11'; Mutation = 'MalformedMetadata' }
        @{ Id = 'OW-12'; Mutation = 'UnsafeName' }
        @{ Id = 'OW-13'; Mutation = 'MissingManifest' }
        @{ Id = 'OW-14'; Mutation = 'MissingLoader' }
    ) {
        $outputPath = Join-Path $TestDrive "legacy-invalid-$Id"
        New-LegacyOutput -OutputPath $outputPath -ModuleName 'LegacyInvalid'
        switch ($Mutation) {
            'MalformedMetadata' {
                Set-Content -LiteralPath (Join-Path $outputPath 'Metadata' 'model.json') -Value '{'
            }
            'UnsafeName' {
                Set-Content -LiteralPath (Join-Path $outputPath 'Metadata' 'model.json') `
                    -Value '{"SchemaVersion":1,"ModuleName":"../Unsafe"}'
            }
            'MissingManifest' {
                Remove-Item -LiteralPath (Join-Path $outputPath 'LegacyInvalid.psd1') -Force
            }
            'MissingLoader' {
                Remove-Item -LiteralPath (Join-Path $outputPath 'LegacyInvalid.psm1') -Force
            }
        }

        InModuleScope SubZeroDev.PSGenerator -Parameters @{ OutputPath = $outputPath } {
            param ($OutputPath)
            (Test-PSModuleOutputOwnership -OutputPath $OutputPath).State | Should -Be 'Unowned'
        }
    }

    It 'OW-15 fails closed when directory enumeration is denied' {
        $outputPath = New-Item -Path (Join-Path $TestDrive 'denied-output') -ItemType Directory

        InModuleScope SubZeroDev.PSGenerator -Parameters @{ OutputPath = $outputPath.FullName } {
            param ($OutputPath)
            Mock Get-ChildItem { throw [UnauthorizedAccessException]::new('denied') }

            (Test-PSModuleOutputOwnership -OutputPath $OutputPath).State | Should -Be 'Unowned'
        }
    }
}

Describe 'Generated output hard denials' {
    BeforeEach {
        $fixture = New-OutputSafetyFixture -Root (Join-Path $TestDrive 'hard-denial')
        $sourceSentinel = Join-Path $fixture.DirectoryPath 'source.keep'
        Set-Content -LiteralPath $sourceSentinel -Value 'source'
    }

    It 'HD-01 rejects a lexical filesystem root before mutation' {
        $rootPath = [IO.Path]::GetPathRoot($TestDrive)
        $context = New-OutputContext -Fixture $fixture -OutputPath $rootPath

        InModuleScope SubZeroDev.PSGenerator -Parameters @{ Context = $context } {
            param ($Context)
            { Assert-PSModuleOutputPath -Context $Context } |
                Should -Throw -ExceptionType ([ArgumentException]) -ExpectedMessage '*filesystem root*'
        }
        Get-Content -LiteralPath $sourceSentinel | Should -Be 'source'
    }

    It 'HD-02 rejects a real path resolving to a root when links are available' {
        $rootPath = [IO.Path]::GetPathRoot($TestDrive)
        $linkPath = Join-Path $TestDrive 'root-output-link'
        try {
            New-Item -Path $linkPath -ItemType SymbolicLink -Target $rootPath -ErrorAction Stop |
                Out-Null
        }
        catch {
            Set-ItResult -Skipped -Because 'this host does not permit creating symbolic links'
            return
        }
        try {
            $context = New-OutputContext -Fixture $fixture -OutputPath $linkPath

            InModuleScope SubZeroDev.PSGenerator -Parameters @{ Context = $context } {
                param ($Context)
                { Assert-PSModuleOutputPath -Context $Context } |
                    Should -Throw -ExceptionType ([ArgumentException]) -ExpectedMessage '*filesystem root*'
            }
        }
        finally {
            Remove-Item -LiteralPath $linkPath -Force -ErrorAction SilentlyContinue
        }
    }

    It 'HD-03 through HD-07 reject source and specification containers without mutation' -ForEach @(
        @{ Id = 'HD-03'; Selector = 'Directory' }
        @{ Id = 'HD-04'; Selector = 'Parent' }
        @{ Id = 'HD-05'; Selector = 'Grandparent' }
        @{ Id = 'HD-06'; Selector = 'Specification' }
        @{ Id = 'HD-07'; Selector = 'SpecificationDirectory' }
    ) {
        $outputPath = switch ($Selector) {
            'Directory' { $fixture.DirectoryPath }
            'Parent' { Split-Path $fixture.DirectoryPath -Parent }
            'Grandparent' { Split-Path (Split-Path $fixture.DirectoryPath -Parent) -Parent }
            'Specification' { $fixture.SpecificationPath }
            'SpecificationDirectory' { Split-Path $fixture.SpecificationPath -Parent }
        }
        $context = New-OutputContext -Fixture $fixture -OutputPath $outputPath
        $specificationBytes = [IO.File]::ReadAllBytes($fixture.SpecificationPath)

        InModuleScope SubZeroDev.PSGenerator -Parameters @{ Context = $context } {
            param ($Context)
            { Assert-PSModuleOutputPath -Context $Context } |
                Should -Throw -ExceptionType ([ArgumentException])
        }

        Get-Content -LiteralPath $sourceSentinel | Should -Be 'source'
        [Convert]::ToHexString([IO.File]::ReadAllBytes($fixture.SpecificationPath)) |
            Should -Be ([Convert]::ToHexString($specificationBytes))
    }

    It 'HD-08 rejects an existing ordinary file without changing it' {
        $outputPath = Join-Path $TestDrive 'ordinary-output-file'
        Set-Content -LiteralPath $outputPath -Value 'keep'
        $context = New-OutputContext -Fixture $fixture -OutputPath $outputPath

        InModuleScope SubZeroDev.PSGenerator -Parameters @{ Context = $context } {
            param ($Context)
            { Assert-PSModuleOutputPath -Context $Context } |
                Should -Throw -ExceptionType ([ArgumentException]) -ExpectedMessage '*must be a directory*'
        }
        Get-Content -LiteralPath $outputPath | Should -Be 'keep'
    }

    It 'HD-09 rejects an existing symbolic-link directory without changing its target' {
        $targetPath = Join-Path $TestDrive 'linked-output-target'
        New-Item -Path $targetPath -ItemType Directory -Force | Out-Null
        $targetSentinel = Join-Path $targetPath 'keep.txt'
        Set-Content -LiteralPath $targetSentinel -Value 'keep'
        $linkPath = Join-Path $TestDrive 'linked-output'
        try {
            New-Item -Path $linkPath -ItemType SymbolicLink -Target $targetPath -ErrorAction Stop |
                Out-Null
        }
        catch {
            Set-ItResult -Skipped -Because 'this host does not permit creating symbolic links'
            return
        }
        $context = New-OutputContext -Fixture $fixture -OutputPath $linkPath

        InModuleScope SubZeroDev.PSGenerator -Parameters @{ Context = $context } {
            param ($Context)
            { Assert-PSModuleOutputPath -Context $Context } |
                Should -Throw -ExceptionType ([ArgumentException])
        }
        Get-Content -LiteralPath $targetSentinel | Should -Be 'keep'
    }

    It 'HD-10 rejects an existing Windows junction without changing its target' -Skip:(-not $IsWindows) {
        $targetPath = Join-Path $TestDrive 'junction-output-target'
        New-Item -Path $targetPath -ItemType Directory -Force | Out-Null
        $targetSentinel = Join-Path $targetPath 'keep.txt'
        Set-Content -LiteralPath $targetSentinel -Value 'keep'
        $junctionPath = Join-Path $TestDrive 'junction-output'
        try {
            New-Item -Path $junctionPath -ItemType Junction -Target $targetPath -ErrorAction Stop |
                Out-Null
        }
        catch {
            Set-ItResult -Skipped -Because 'this host does not permit creating junctions'
            return
        }
        try {
            $context = New-OutputContext -Fixture $fixture -OutputPath $junctionPath

            InModuleScope SubZeroDev.PSGenerator -Parameters @{ Context = $context } {
                param ($Context)
                { Assert-PSModuleOutputPath -Context $Context } |
                    Should -Throw -ExceptionType ([ArgumentException])
            }
            Get-Content -LiteralPath $targetSentinel | Should -Be 'keep'
        }
        finally {
            Remove-Item -LiteralPath $junctionPath -Force -ErrorAction SilentlyContinue
        }
    }

    It 'HD-11 rejects a linked ancestor that disguises a source relationship' {
        $linkPath = Join-Path $TestDrive 'source-parent-link'
        try {
            New-Item -Path $linkPath -ItemType SymbolicLink `
                -Target (Split-Path $fixture.DirectoryPath -Parent) -ErrorAction Stop | Out-Null
        }
        catch {
            Set-ItResult -Skipped -Because 'this host does not permit creating symbolic links'
            return
        }
        $disguisedOutput = Join-Path $linkPath (Split-Path $fixture.DirectoryPath -Leaf)
        $context = New-OutputContext -Fixture $fixture -OutputPath $disguisedOutput

        InModuleScope SubZeroDev.PSGenerator -Parameters @{ Context = $context } {
            param ($Context)
            { Assert-PSModuleOutputPath -Context $Context } |
                Should -Throw -ExceptionType ([ArgumentException])
        }
        Get-Content -LiteralPath $sourceSentinel | Should -Be 'source'
    }

    It 'HD-12 fails within the resolver hop bound for a cyclic link' {
        $linkPath = Join-Path $TestDrive 'output-cycle'
        try {
            New-Item -Path $linkPath -ItemType SymbolicLink -Target $linkPath -ErrorAction Stop |
                Out-Null
        }
        catch {
            Set-ItResult -Skipped -Because 'this host does not permit creating symbolic links'
            return
        }
        $context = New-OutputContext -Fixture $fixture -OutputPath $linkPath

        InModuleScope SubZeroDev.PSGenerator -Parameters @{ Context = $context } {
            param ($Context)
            $stopwatch = [Diagnostics.Stopwatch]::StartNew()
            { Assert-PSModuleOutputPath -Context $Context } |
                Should -Throw -ExceptionType ([IO.IOException]) -ExpectedMessage '*maximum depth*'
            $stopwatch.Stop()
            $stopwatch.Elapsed.TotalSeconds | Should -BeLessThan 5
        }
    }

    It 'HD-13 proves Force cannot bypass root or source denials' -ForEach @(
        @{ Selector = 'Root' }
        @{ Selector = 'Directory' }
        @{ Selector = 'Parent' }
        @{ Selector = 'SpecificationDirectory' }
        @{ Selector = 'Scripts' }
    ) {
        $outputPath = switch ($Selector) {
            'Root' { [IO.Path]::GetPathRoot($TestDrive) }
            'Directory' { $fixture.DirectoryPath }
            'Parent' { Split-Path $fixture.DirectoryPath -Parent }
            'SpecificationDirectory' { Split-Path $fixture.SpecificationPath -Parent }
            'Scripts' { Join-Path $fixture.DirectoryPath 'scripts' }
        }
        $context = New-OutputContext -Fixture $fixture -OutputPath $outputPath -Force

        InModuleScope SubZeroDev.PSGenerator -Parameters @{ Context = $context } {
            param ($Context)
            { Assert-PSModuleOutputPath -Context $Context -Force } |
                Should -Throw -ExceptionType ([ArgumentException])
        }
        Get-Content -LiteralPath $sourceSentinel | Should -Be 'source'
    }

    It 'HD-14 through HD-16 reject scripts-tree overlap with and without Force' -ForEach @(
        @{ Id = 'HD-14'; Relative = ''; Force = $false }
        @{ Id = 'HD-15'; Relative = 'nested-output'; Force = $false }
        @{ Id = 'HD-16'; Relative = ''; Force = $true }
        @{ Id = 'HD-16'; Relative = 'nested-output'; Force = $true }
    ) {
        New-Item -Path $fixture.ScriptsPath -ItemType Directory -Force | Out-Null
        $scriptSentinel = Join-Path $fixture.ScriptsPath 'keep.ps1'
        Set-Content -LiteralPath $scriptSentinel -Value '# keep'
        $outputPath = if ($Relative) { Join-Path $fixture.ScriptsPath $Relative }
            else { $fixture.ScriptsPath }
        $context = New-OutputContext -Fixture $fixture -OutputPath $outputPath -Force:$Force

        InModuleScope SubZeroDev.PSGenerator -Parameters @{
            Context = $context
            Force   = $Force
        } {
            param ($Context, $Force)
            { Assert-PSModuleOutputPath -Context $Context -Force:$Force } |
                Should -Throw -ExceptionType ([ArgumentException]) -ExpectedMessage '*scripts tree*'
        }
        Get-Content -LiteralPath $scriptSentinel | Should -Be '# keep'
    }

    It 'HD-17 rejects a linked output that resolves into the scripts tree' {
        New-Item -Path $fixture.ScriptsPath -ItemType Directory -Force | Out-Null
        $linkPath = Join-Path $TestDrive 'scripts-output-link'
        try {
            New-Item -Path $linkPath -ItemType SymbolicLink -Target $fixture.ScriptsPath `
                -ErrorAction Stop | Out-Null
        }
        catch {
            Set-ItResult -Skipped -Because 'this host does not permit creating symbolic links'
            return
        }
        $context = New-OutputContext -Fixture $fixture -OutputPath $linkPath

        InModuleScope SubZeroDev.PSGenerator -Parameters @{ Context = $context } {
            param ($Context)
            { Assert-PSModuleOutputPath -Context $Context } |
                Should -Throw -ExceptionType ([ArgumentException]) -ExpectedMessage '*scripts tree*'
        }
    }

    It 'HD-18 rejects a marker planted in the scripts tree before ownership is considered' {
        Write-TestOutputMarker -OutputPath $fixture.ScriptsPath

        { Build-PSModule `
            -Specification $fixture.SpecificationPath `
            -Output $fixture.ScriptsPath `
            -Force } | Should -Throw -ExceptionType ([ArgumentException]) -ExpectedMessage '*scripts tree*'

        Test-Path -LiteralPath (Join-Path $fixture.ScriptsPath 'Metadata' 'output.json') |
            Should -BeTrue
    }
}

Describe 'Generated output ownership and Force behavior' {
    It 'FO-01 rejects unowned output without Force and preserves its sentinel' {
        $fixture = New-OutputSafetyFixture -Root (Join-Path $TestDrive 'force-unowned')
        New-Item -Path $fixture.OutputPath -ItemType Directory -Force | Out-Null
        $sentinel = Join-Path $fixture.OutputPath 'keep.txt'
        Set-Content -LiteralPath $sentinel -Value 'keep'

        { Build-PSModule -Specification $fixture.SpecificationPath -Output $fixture.OutputPath } |
            Should -Throw -ExceptionType ([InvalidOperationException]) -ExpectedMessage '*-Force*'
        Get-Content -LiteralPath $sentinel | Should -Be 'keep'
    }

    It 'FO-02 replaces unowned output with Force and writes a marker' {
        $fixture = New-OutputSafetyFixture -Root (Join-Path $TestDrive 'force-replace')
        New-Item -Path $fixture.OutputPath -ItemType Directory -Force | Out-Null
        $sentinel = Join-Path $fixture.OutputPath 'stale.txt'
        Set-Content -LiteralPath $sentinel -Value 'stale'

        Build-PSModule `
            -Specification $fixture.SpecificationPath `
            -Output $fixture.OutputPath `
            -Force | Out-Null

        Test-Path -LiteralPath $sentinel | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $fixture.OutputPath 'Metadata' 'output.json') |
            Should -BeTrue
    }

    It 'FO-03 and FO-04 preserve an invalid marker unless Force is explicit' {
        $fixture = New-OutputSafetyFixture -Root (Join-Path $TestDrive 'force-invalid-marker')
        Write-TestOutputMarker -OutputPath $fixture.OutputPath -Content '{bad'
        $sentinel = Join-Path $fixture.OutputPath 'keep.txt'
        Set-Content -LiteralPath $sentinel -Value 'keep'

        { Build-PSModule -Specification $fixture.SpecificationPath -Output $fixture.OutputPath } |
            Should -Throw -ExceptionType ([InvalidOperationException])
        Get-Content -LiteralPath $sentinel | Should -Be 'keep'

        Build-PSModule `
            -Specification $fixture.SpecificationPath `
            -Output $fixture.OutputPath `
            -Force | Out-Null
        Test-Path -LiteralPath $sentinel | Should -BeFalse
        (Get-Content -LiteralPath (
            Join-Path $fixture.OutputPath 'Metadata' 'output.json'
        ) -Raw | ConvertFrom-Json).Generator | Should -Be 'SubZeroDev.PSGenerator'
    }

    It 'FO-05 replaces marker-owned output without Force' {
        $fixture = New-OutputSafetyFixture -Root (Join-Path $TestDrive 'owned-rebuild')
        Write-TestOutputMarker -OutputPath $fixture.OutputPath
        $sentinel = Join-Path $fixture.OutputPath 'stale.txt'
        Set-Content -LiteralPath $sentinel -Value 'stale'

        Build-PSModule -Specification $fixture.SpecificationPath -Output $fixture.OutputPath |
            Out-Null

        Test-Path -LiteralPath $sentinel | Should -BeFalse
    }

    It 'FO-06 replaces a legacy package without Force and migrates it to a marker' {
        $fixture = New-OutputSafetyFixture `
            -Root (Join-Path $TestDrive 'legacy-rebuild') `
            -ModuleName 'LegacyRebuild'
        New-LegacyOutput -OutputPath $fixture.OutputPath -ModuleName $fixture.ModuleName

        Build-PSModule -Specification $fixture.SpecificationPath -Output $fixture.OutputPath |
            Out-Null

        Test-Path -LiteralPath (Join-Path $fixture.OutputPath 'Metadata' 'output.json') |
            Should -BeTrue
    }

    It 'FO-07 does not force unowned output during directory initialization by default' {
        $fixture = New-OutputSafetyFixture -Root (Join-Path $TestDrive 'initialize-no-force')
        New-Item -Path $fixture.OutputPath -ItemType Directory -Force | Out-Null
        $sentinel = Join-Path $fixture.OutputPath 'keep.txt'
        Set-Content -LiteralPath $sentinel -Value 'keep'

        { Initialize-PSModuleDirectory `
            -Directory $fixture.DirectoryPath `
            -Specification 'PSModule/PSModule.psd1' `
            -Output $fixture.OutputPath `
            -Generate `
            -NoInitialize } | Should -Throw -ExceptionType ([InvalidOperationException])
        Get-Content -LiteralPath $sentinel | Should -Be 'keep'
    }

    It 'FO-08 forwards Force only when ForceOutput is selected' {
        $fixture = New-OutputSafetyFixture -Root (Join-Path $TestDrive 'initialize-force')
        New-Item -Path $fixture.OutputPath -ItemType Directory -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $fixture.OutputPath 'stale.txt') -Value 'stale'

        $artifact = Initialize-PSModuleDirectory `
            -Directory $fixture.DirectoryPath `
            -Specification 'PSModule/PSModule.psd1' `
            -Output $fixture.OutputPath `
            -Generate `
            -NoInitialize `
            -ForceOutput

        $artifact.FullName | Should -Be (
            Join-Path $fixture.OutputPath 'Metadata' 'model.json'
        )
    }
}

Describe 'Generated output marker and lifecycle' {
    It 'BL-01 and BL-09 produce complete marked packages for ordinary and empty modules' {
        $fixture = New-OutputSafetyFixture -Root (Join-Path $TestDrive 'first-build')

        Build-PSModule -Specification $fixture.SpecificationPath -Output $fixture.OutputPath |
            Out-Null

        Test-Path -LiteralPath (Join-Path $fixture.OutputPath 'Metadata' 'output.json') |
            Should -BeTrue
        Test-ModuleManifest (Join-Path $fixture.OutputPath "$($fixture.ModuleName).psd1") |
            Should -Not -BeNullOrEmpty
    }

    It 'BL-02 produces identical marker bytes on repeated builds' {
        $fixture = New-OutputSafetyFixture -Root (Join-Path $TestDrive 'repeat-build')
        $markerPath = Join-Path $fixture.OutputPath 'Metadata' 'output.json'

        Build-PSModule -Specification $fixture.SpecificationPath -Output $fixture.OutputPath |
            Out-Null
        $first = [IO.File]::ReadAllBytes($markerPath)
        Build-PSModule -Specification $fixture.SpecificationPath -Output $fixture.OutputPath |
            Out-Null
        $second = [IO.File]::ReadAllBytes($markerPath)

        [Convert]::ToHexString($second) | Should -Be ([Convert]::ToHexString($first))
    }

    It 'BL-03 preserves existing output when specification validation fails' {
        $fixture = New-OutputSafetyFixture -Root (Join-Path $TestDrive 'validation-failure')
        Write-TestOutputMarker -OutputPath $fixture.OutputPath
        $sentinel = Join-Path $fixture.OutputPath 'keep.txt'
        Set-Content -LiteralPath $sentinel -Value 'keep'
        Set-Content -LiteralPath $fixture.SpecificationPath -Value "@{ ModuleVersion = 'bad' }"

        { Build-PSModule -Specification $fixture.SpecificationPath -Output $fixture.OutputPath } |
            Should -Throw
        Get-Content -LiteralPath $sentinel | Should -Be 'keep'
    }

    It 'BL-04 preserves existing output when a runtime adapter fails before reset' {
        $fixture = New-OutputSafetyFixture -Root (Join-Path $TestDrive 'adapter-failure')
        Write-TestOutputMarker -OutputPath $fixture.OutputPath
        $sentinel = Join-Path $fixture.OutputPath 'keep.txt'
        Set-Content -LiteralPath $sentinel -Value 'keep'
        $pluginRoot = Join-Path $TestDrive 'adapter-plugins'
        $adapterPath = Join-Path $pluginRoot 'RuntimeAdapters' '99.Failure.ps1'
        New-Item -Path (Split-Path $adapterPath -Parent) -ItemType Directory -Force |
            Out-Null
        Set-Content -LiteralPath $adapterPath -Value @'
param([Parameter(Mandatory)] [psobject] $Context)
throw 'runtime adapter failure'
'@

        { Build-PSModule `
            -Specification $fixture.SpecificationPath `
            -Output $fixture.OutputPath `
            -PluginPath $pluginRoot } | Should -Throw -ExpectedMessage '*runtime adapter failure*'
        Get-Content -LiteralPath $sentinel | Should -Be 'keep'
    }

    It 'BL-05 and BL-06 leave failed render output marked and replace it on retry' {
        $fixture = New-OutputSafetyFixture -Root (Join-Path $TestDrive 'renderer-failure')
        $pluginRoot = Join-Path $TestDrive 'renderer-plugins'
        $rendererPath = Join-Path $pluginRoot 'TemplateRenderers' '99.Failure.ps1'
        New-Item -Path (Split-Path $rendererPath -Parent) -ItemType Directory -Force |
            Out-Null
        Set-Content -LiteralPath $rendererPath -Value @'
param([Parameter(Mandatory)] [psobject] $Context)
throw 'renderer failure'
'@

        { Build-PSModule `
            -Specification $fixture.SpecificationPath `
            -Output $fixture.OutputPath `
            -PluginPath $pluginRoot } | Should -Throw -ExpectedMessage '*renderer failure*'
        Test-Path -LiteralPath (Join-Path $fixture.OutputPath 'Metadata' 'output.json') |
            Should -BeTrue

        Build-PSModule -Specification $fixture.SpecificationPath -Output $fixture.OutputPath |
            Out-Null
        Test-ModuleManifest (Join-Path $fixture.OutputPath "$($fixture.ModuleName).psd1") |
            Should -Not -BeNullOrEmpty
    }

    It 'BL-07 and BL-08 rejects missing or malformed marker during package completion' -ForEach @(
        @{ Mode = 'Missing' }
        @{ Mode = 'Malformed' }
    ) {
        $fixture = New-OutputSafetyFixture -Root (Join-Path $TestDrive "completion-$Mode")
        $metadata = Build-PSModule `
            -Specification $fixture.SpecificationPath `
            -Output $fixture.OutputPath
        $model = Get-PSModuleModel -Specification $fixture.SpecificationPath
        $markerPath = Join-Path $fixture.OutputPath 'Metadata' 'output.json'
        if ($Mode -eq 'Missing') {
            Remove-Item -LiteralPath $markerPath -Force
        }
        else {
            Set-Content -LiteralPath $markerPath -Value '{bad'
        }
        $context = [pscustomobject] @{
            OutputPath = $fixture.OutputPath
            Model      = $model
            Artifacts  = [ordered] @{
                Manifest = Get-Item -LiteralPath (
                    Join-Path $fixture.OutputPath "$($fixture.ModuleName).psd1"
                )
                Metadata = $metadata
            }
        }

        InModuleScope SubZeroDev.PSGenerator -Parameters @{ Context = $context } {
            param ($Context)
            { Complete-PSModulePackage -Context $Context } |
                Should -Throw -ExceptionType ([IO.InvalidDataException])
        }
    }

    It 'does not mistake a marker-owned partial directory for a complete package' {
        $fixture = New-OutputSafetyFixture -Root (Join-Path $TestDrive 'partial-completion')
        New-Item -Path $fixture.OutputPath -ItemType Directory -Force | Out-Null
        InModuleScope SubZeroDev.PSGenerator -Parameters @{ OutputPath = $fixture.OutputPath } {
            param ($OutputPath)
            $null = Write-PSModuleOutputMarker -OutputPath $OutputPath
        }
        $context = [pscustomobject] @{
            OutputPath = $fixture.OutputPath
            Model      = [pscustomobject] @{ ModuleName = $fixture.ModuleName; Commands = @() }
            Artifacts  = [ordered] @{}
        }

        InModuleScope SubZeroDev.PSGenerator -Parameters @{ Context = $context } {
            param ($Context)
            { Complete-PSModulePackage -Context $Context } |
                Should -Throw -ExceptionType ([IO.InvalidDataException])
        }
    }

    It 'BL-10 and BL-12 copy scripts exactly once within an explicit timeout' {
        $fixture = New-OutputSafetyFixture `
            -Root (Join-Path $TestDrive 'bounded-normal-copy') `
            -WithScripts
        $sourceCount = @(Get-ChildItem -LiteralPath $fixture.ScriptsPath -File -Recurse).Count
        $job = Start-Job -ScriptBlock {
            param ($ManifestPath, $SpecificationPath, $OutputPath)
            Import-Module $ManifestPath -Force
            Build-PSModule -Specification $SpecificationPath -Output $OutputPath | Out-Null
        } -ArgumentList $manifestPath, $fixture.SpecificationPath, $fixture.OutputPath
        try {
            Wait-Job -Job $job -Timeout 15 | Should -Not -BeNullOrEmpty
            Receive-Job -Job $job -ErrorAction Stop
        }
        finally {
            Stop-Job -Job $job -ErrorAction SilentlyContinue
            Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
        }

        $packagedScripts = Join-Path $fixture.OutputPath 'Scripts'
        Test-Path -LiteralPath (Join-Path $packagedScripts 'Scripts') | Should -BeFalse
        @(Get-ChildItem -LiteralPath $packagedScripts -File -Recurse).Count |
            Should -Be $sourceCount
    }

    It 'BL-11 blocks a direct packager destination inside scripts within an explicit timeout' {
        $fixture = New-OutputSafetyFixture `
            -Root (Join-Path $TestDrive 'bounded-direct-copy') `
            -WithScripts
        $nestedOutput = Join-Path $fixture.ScriptsPath 'nested-output'
        $job = Start-Job -ScriptBlock {
            param ($ManifestPath, $DirectoryPath, $OutputPath)
            Import-Module $ManifestPath -Force
            $definition = @{
                SourceKind = 'Script'
                SourcePath = 'scripts/Invoke-SafeSource.ps1'
            }
            $context = [pscustomobject] @{
                DirectoryPath = $DirectoryPath
                OutputPath    = $OutputPath
                Model         = [pscustomobject] @{
                    ContainerImage = 'example/test:latest'
                    Commands       = @([pscustomobject] @{
                        Name       = 'Invoke-SafeSource'
                        Definition = $definition
                        Parameters = @()
                    })
                }
            }
            try {
                & (Get-Module SubZeroDev.PSGenerator) {
                    param ($Context)
                    Write-PSModuleCommandSource -Context $Context
                } $context
                'NO_ERROR'
            }
            catch {
                'ERROR:{0}:{1}' -f $_.Exception.GetType().FullName, $_.Exception.Message
            }
        } -ArgumentList $manifestPath, $fixture.DirectoryPath, $nestedOutput
        try {
            Wait-Job -Job $job -Timeout 15 | Should -Not -BeNullOrEmpty
            $result = @(Receive-Job -Job $job -ErrorAction Stop)
        }
        finally {
            Stop-Job -Job $job -ErrorAction SilentlyContinue
            Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
        }

        $result -join "`n" | Should -Match '^ERROR:System\.InvalidOperationException:'
        Test-Path -LiteralPath $nestedOutput | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $fixture.ScriptsPath 'Scripts') | Should -BeFalse
    }

    It 'MK-01 through MK-05 writes canonical deterministic and non-sensitive marker bytes' {
        $firstOutput = Join-Path $TestDrive 'marker-bytes-first'
        $secondOutput = Join-Path $TestDrive 'marker-bytes-second'

        InModuleScope SubZeroDev.PSGenerator -Parameters @{
            FirstOutput  = $firstOutput
            SecondOutput = $secondOutput
        } {
            param ($FirstOutput, $SecondOutput)
            $firstMarker = Write-PSModuleOutputMarker -OutputPath $FirstOutput
            $secondMarker = Write-PSModuleOutputMarker -OutputPath $SecondOutput
            $firstBytes = [IO.File]::ReadAllBytes($firstMarker.FullName)
            $secondBytes = [IO.File]::ReadAllBytes($secondMarker.FullName)
            $text = [Text.Encoding]::UTF8.GetString($firstBytes)

            [Convert]::ToHexString($firstBytes) |
                Should -Be ([Convert]::ToHexString($secondBytes))
            $firstBytes[0..2] | Should -Not -Be @(0xEF, 0xBB, 0xBF)
            $text | Should -Not -Match "`r"
            $text.EndsWith("`n") | Should -BeTrue
            $text.EndsWith("`n`n") | Should -BeFalse
            $text | Should -Match '(?s)"SchemaVersion".*"Generator".*"ArtifactType"'
            $text | Should -Not -Match '(?i)path|user|host|time|pid|secret'
        }
    }
}
