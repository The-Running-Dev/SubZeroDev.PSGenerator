param ([Parameter(Mandatory)] [psobject] $Context)

if ($Context.RenderRequests.Contains('CommandDocumentation')) {
    Write-PSModuleCommandDocumentation -Context $Context
}
