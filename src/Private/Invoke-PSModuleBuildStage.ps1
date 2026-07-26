function Invoke-PSModuleBuildStage {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [psobject] $Context,

        [Parameter(Mandatory)]
        [string[]] $PluginPath,

        [Parameter(Mandatory)]
        [ValidateSet(
            'Inspectors',
            'Validators',
            'ObjectModelProcessors',
            'RuntimeAdapters',
            'CodeGenerators',
            'TemplateRenderers',
            'PackagingProviders'
        )]
        [string] $Stage
    )

    if ($Stage -eq 'CodeGenerators') {
        Reset-PSModuleOutput -Context $Context
    }

    $null = Invoke-PSModulePluginPipeline `
        -Context $Context `
        -Path $PluginPath `
        -Stage $Stage

    if ($Stage -eq 'ObjectModelProcessors' -and $null -eq $Context.Model) {
        throw [System.InvalidOperationException]::new(
            'The object-model processor stage did not produce a container module model.'
        )
    }

    if ($Stage -eq 'TemplateRenderers' -and -not $Context.Artifacts.Contains('Metadata')) {
        throw [System.InvalidOperationException]::new(
            'The template-renderer stage did not produce the metadata artifact.'
        )
    }
}
