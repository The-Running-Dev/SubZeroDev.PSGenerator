param ([Parameter(Mandatory)] [psobject] $Context)

if ($Context.RenderRequests.Contains('Manifest')) {
    $Context.Artifacts['Manifest'] = Write-PSModuleManifest -Context $Context
}
