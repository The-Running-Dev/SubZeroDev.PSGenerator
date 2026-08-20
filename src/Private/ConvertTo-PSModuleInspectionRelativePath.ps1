function ConvertTo-PSModuleInspectionRelativePath {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [psobject] $Context,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Path
    )

    [IO.Path]::GetRelativePath($Context.DirectoryPath, $Path).Replace('\', '/')
}
