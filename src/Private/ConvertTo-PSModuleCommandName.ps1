function ConvertTo-PSModuleCommandName {
    <#
    .SYNOPSIS
    Derives a generated command name from a script file name.

    .DESCRIPTION
    A file already named Verb-Noun keeps that name when the verb is one
    PowerShell approves, so Test-Documentation.ps1 becomes Test-Documentation
    rather than Invoke-TestDocumentation. The verb is returned in the casing
    Get-Verb reports, which keeps a compound verb such as ConvertTo correct even
    when the file name is lowercase.

    Anything else becomes Invoke- followed by the file name in Pascal case,
    because a name the author did not write as a command has no verb to
    preserve.

    The verb lookup is resolved per call rather than cached in a script
    variable: inspector plugins run as external scripts in their own session
    state, where a module script variable is not reachable.

    .PARAMETER FileBaseName
    File name without its extension.

    .EXAMPLE
    ConvertTo-PSModuleCommandName -FileBaseName 'Test-Documentation'

    Returns Test-Documentation.

    .EXAMPLE
    ConvertTo-PSModuleCommandName -FileBaseName 'container-tool'

    Returns Invoke-ContainerTool, because container is not an approved verb.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $FileBaseName
    )

    $parts = $FileBaseName -split '-'

    # Both sides must be plain words before the name can be treated as
    # Verb-Noun. Constraining the verb to letters also keeps a file name
    # containing wildcard characters out of the Get-Verb match below.
    if ($parts.Count -eq 2 -and
        $parts[0] -match '^[A-Za-z]+$' -and
        $parts[1] -match '^[A-Za-z][A-Za-z0-9]*$') {
        $approvedVerb = @(Get-Verb -Verb $parts[0] -ErrorAction SilentlyContinue) |
            Select-Object -First 1
        if ($approvedVerb) {
            $noun = [char]::ToUpperInvariant($parts[1][0]) + $parts[1].Substring(1)
            return "$($approvedVerb.Verb)-$noun"
        }
    }

    $words = [regex]::Matches($FileBaseName, '[A-Za-z0-9]+') | ForEach-Object {
        [char]::ToUpperInvariant($_.Value[0]) + $_.Value.Substring(1)
    }

    return "Invoke-$($words -join '')"
}
