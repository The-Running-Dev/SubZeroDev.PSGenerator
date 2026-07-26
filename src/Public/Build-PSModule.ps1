function Build-PSModule {
    <#
    .SYNOPSIS
    Generates a repository-specific PowerShell module.

    .DESCRIPTION
    Runs the ordered Version 1 build pipeline and writes a deterministic,
    self-contained PowerShell module from a repository specification. The package
    includes metadata, an importable manifest and loader, generated public commands,
    and one Markdown reference page per command.

    Built-in plugins always run. Trusted repository plugins are discovered from a
    sibling Plugins directory unless explicit roots are supplied. The command returns
    the generated Metadata/model.json file; the complete package is written to Output.

    .PARAMETER Specification
    Path to the repository's PowerShell data file.

    .PARAMETER Output
    Directory where the complete generated module package will be written. Existing
    output is replaced only after specification and model validation succeed.

    .PARAMETER PluginPath
    One or more trusted plugin roots used in addition to the built-in plugins. When
    omitted, the Plugins directory beside the resolved specification is used when it
    exists. Repository plugins execute as unsandboxed PowerShell code.
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [string] $Specification = 'PSModule/PSModule.psd1',

        [Parameter()]
        [string] $Output = 'artifacts/PSModule',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]] $PluginPath
    )

    $context = New-PSModuleBuildContext -SpecificationPath $Specification -OutputPath $Output
    [string[]] $pluginRoots = @((Join-Path $PSScriptRoot '..' 'Plugins'))
    if ($PSBoundParameters.ContainsKey('PluginPath')) {
        $pluginRoots += @($PluginPath)
    }
    else {
        $conventionalPluginPath = Join-Path (Split-Path $context.SpecificationPath -Parent) 'Plugins'
        if (Test-Path -LiteralPath $conventionalPluginPath -PathType Container) {
            $pluginRoots += @($conventionalPluginPath)
        }
    }

    foreach ($stage in @(
        'Inspectors'
        'Validators'
        'ObjectModelProcessors'
        'RuntimeAdapters'
        'CodeGenerators'
        'TemplateRenderers'
        'PackagingProviders'
    )) {
        Invoke-PSModuleBuildStage `
            -Context $context `
            -PluginPath $pluginRoots `
            -Stage $stage
    }

    return $context.Artifacts['Metadata']
}
