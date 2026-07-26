param ([Parameter(Mandatory)] [psobject] $Context)

if ($Context.RenderRequests.Contains('Loader')) {
    Write-PSModuleLoader -Context $Context
}
