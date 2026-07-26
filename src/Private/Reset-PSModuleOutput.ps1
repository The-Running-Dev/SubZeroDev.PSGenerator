function Reset-PSModuleOutput {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [psobject] $Context
    )

    if (Test-Path -LiteralPath $Context.OutputPath) {
        Remove-Item -LiteralPath $Context.OutputPath -Recurse -Force
    }
}
