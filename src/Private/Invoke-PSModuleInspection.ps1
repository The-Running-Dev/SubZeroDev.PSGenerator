function Invoke-PSModuleInspection {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string] $Specification,

        [string[]] $PluginPath,

        [switch] $PluginPathSpecified
    )

    $specificationPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Specification)
    $specificationDirectory = Split-Path $specificationPath -Parent
    $inspectionOutput = Join-Path $specificationDirectory '.container-module-inspection'
    $context = New-PSModuleBuildContext -SpecificationPath $specificationPath -OutputPath $inspectionOutput

    [string[]] $pluginRoots = @((Join-Path $PSScriptRoot '..' 'Plugins'))
    if ($PluginPathSpecified) {
        $pluginRoots += @($PluginPath)
    }
    else {
        $conventionalPluginPath = Join-Path $specificationDirectory 'Plugins'
        if (Test-Path -LiteralPath $conventionalPluginPath -PathType Container) {
            $pluginRoots += $conventionalPluginPath
        }
    }

    $null = Invoke-PSModulePluginPipeline -Context $context -Path $pluginRoots -Stage Inspectors

    # Redaction runs once, after every inspector has finished and before any
    # caller (Get-PSModuleInspection or otherwise) can observe Context.Inspection,
    # per design/planning/build-agent-evidence-design.md's evidence model.
    Protect-PSModuleCommandEvidenceSecret -Context $context

    return $context
}
