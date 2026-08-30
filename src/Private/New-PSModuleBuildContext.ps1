function New-PSModuleBuildContext {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string] $SpecificationPath,

        [Parameter(Mandatory)]
        [string] $OutputPath
    )

    $resolvedSpecificationPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(
        $SpecificationPath
    )
    $resolvedOutputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(
        $OutputPath
    )
    $specification = Import-PSModuleSpecification -Path $resolvedSpecificationPath
    $specificationDirectory = Split-Path $resolvedSpecificationPath -Parent
    $directoryPath = if ((Split-Path $specificationDirectory -Leaf) -eq 'PSModule') {
        Split-Path $specificationDirectory -Parent
    }
    else {
        $specificationDirectory
    }

    [pscustomobject] @{
        PSTypeName        = 'SubZeroDev.PSGenerator.BuildContext'
        SpecificationPath = $resolvedSpecificationPath
        OutputPath        = $resolvedOutputPath
        DirectoryPath    = $directoryPath
        ForceOutputReset = $false
        Specification     = $specification
        Inspection        = [ordered] @{
            CommandEvidence = [System.Collections.Generic.List[object]]::new()
        }
        Model             = $null
        Artifacts         = [ordered] @{}
        RenderRequests    = [System.Collections.Generic.List[string]]::new()
        PluginExecutions  = [System.Collections.Generic.List[object]]::new()
        InspectionIssues  = [System.Collections.Generic.List[object]]::new()
    }
}
