param (
    [Parameter(Mandatory)]
    [psobject] $Context
)

$Context.Artifacts['Package'] = Complete-PSModulePackage -Context $Context
