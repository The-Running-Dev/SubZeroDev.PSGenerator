function Write-PSModuleCommandDocumentation {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [psobject] $Context
    )

    if ($Context.Model.Commands.Count -eq 0) { return }

    $documentationDirectory = Join-Path $Context.OutputPath 'Documentation'
    $null = New-Item -Path $documentationDirectory -ItemType Directory -Force
    foreach ($command in $Context.Model.Commands) {
        $documentationPath = Join-Path $documentationDirectory "$($command.Name).md"
        $markdown = ConvertTo-PSModuleCommandMarkdown -Command $command
        [System.IO.File]::WriteAllText(
            $documentationPath,
            $markdown,
            [System.Text.UTF8Encoding]::new($false)
        )
    }
}
