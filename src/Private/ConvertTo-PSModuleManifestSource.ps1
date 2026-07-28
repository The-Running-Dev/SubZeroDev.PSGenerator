function ConvertTo-PSModuleManifestSource {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [psobject] $Model
    )

    $functionsToExport = if ($Model.Commands.Count -eq 0) {
        '@()'
    }
    else {
        $entries = $Model.Commands | ForEach-Object { "        '$($_.Name.Replace("'", "''"))'" }
        "@(`n$($entries -join "`n")`n    )"
    }
    $specificationId = ([string] $Model.Id).Replace("'", "''")

    @"
@{
    RootModule        = '$($Model.ModuleName).psm1'
    ModuleVersion     = '$($Model.ModuleVersion)'
    PowerShellVersion = '7.4'
    FunctionsToExport = $functionsToExport
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSGenerator = @{
            GeneratedBy     = 'SubZeroDev.PSGenerator'
            SpecificationId = '$specificationId'
        }
    }
}
"@.Replace("`r`n", "`n")
}
