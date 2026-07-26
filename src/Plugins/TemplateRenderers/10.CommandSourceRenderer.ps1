param ([Parameter(Mandatory)] [psobject] $Context)

if ($Context.RenderRequests.Contains('CommandSource')) {
    Write-PSModuleCommandSource -Context $Context
}
