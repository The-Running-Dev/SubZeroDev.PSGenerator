function ConvertTo-DockerContainerModuleCommandSource {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [psobject] $Command,

        [Parameter(Mandatory)]
        [string] $ContainerImage,

        [Parameter()]
        [string] $SourceKind,

        [Parameter()]
        [string] $PackagedSourcePath
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("function $($Command.Name) {")
    $lines.Add('    <#')
    $lines.Add('    .SYNOPSIS')
    $commandSynopsis = if (-not [string]::IsNullOrWhiteSpace($Command.Synopsis)) {
        $Command.Synopsis
    }
    elseif (-not [string]::IsNullOrWhiteSpace($Command.Description)) {
        $Command.Description
    }
    else {
        "Runs the $($Command.Name) container command."
    }
    foreach ($descriptionLine in $commandSynopsis.Replace('#>', '# >') -split "`r?`n") {
        $lines.Add("    $descriptionLine")
    }
    if (-not [string]::IsNullOrWhiteSpace($Command.Description) -and $Command.Description -ne $commandSynopsis) {
        $lines.Add('')
        $lines.Add('    .DESCRIPTION')
        foreach ($descriptionLine in $Command.Description.Replace('#>', '# >') -split "`r?`n") {
            $lines.Add("    $descriptionLine")
        }
    }
    foreach ($parameter in $Command.Parameters | Where-Object { -not [string]::IsNullOrWhiteSpace($_.Description) }) {
        $lines.Add('')
        $lines.Add("    .PARAMETER $($parameter.Name)")
        foreach ($descriptionLine in $parameter.Description.Replace('#>', '# >') -split "`r?`n") {
            $lines.Add("    $descriptionLine")
        }
    }
    if (-not [string]::IsNullOrWhiteSpace($Command.Notes)) {
        $lines.Add('')
        $lines.Add('    .NOTES')
        foreach ($notesLine in $Command.Notes.Replace('#>', '# >') -split "`r?`n") {
            $lines.Add("    $notesLine")
        }
    }
    foreach ($example in $Command.Examples) {
        $lines.Add('')
        $lines.Add('    .EXAMPLE')
        foreach ($codeLine in $example.Code.Replace('#>', '# >') -split "`r?`n") {
            $lines.Add("    $codeLine")
        }
        $lines.Add('')
        foreach ($descriptionLine in $example.Description.Replace('#>', '# >') -split "`r?`n") {
            $lines.Add("    $descriptionLine")
        }
    }
    $lines.Add('    #>')
    $lines.Add("    [CmdletBinding(SupportsShouldProcess = `$true, ConfirmImpact = 'Low')]")

    if ($Command.Parameters.Count -eq 0) {
        $lines.Add('    param ()')
    }
    else {
        $lines.Add('    param (')
        for ($index = 0; $index -lt $Command.Parameters.Count; $index++) {
            $parameter = $Command.Parameters[$index]
            $mandatory = if ($parameter.Mandatory) { 'Mandatory = $true' } else { '' }
            $separator = if ($index -lt ($Command.Parameters.Count - 1)) { ',' } else { '' }
            $parameterType = switch -Regex ($parameter.Type) {
                '^(?:System\.Management\.Automation\.)?SwitchParameter$' { 'switch'; break }
                '^DirectoryInfo(\[\])?$' { $parameter.Type -replace '^DirectoryInfo', 'System.IO.DirectoryInfo'; break }
                '^FileInfo(\[\])?$' { $parameter.Type -replace '^FileInfo', 'System.IO.FileInfo'; break }
                default { $parameter.Type }
            }

            $lines.Add("        [Parameter($mandatory)]")
            $completionValues = @(
                foreach ($completion in $parameter.Completions | Where-Object Type -eq 'Static') {
                    foreach ($value in $completion.Values) { "'$($value.Replace("'", "''"))'" }
                }
            )
            if ($completionValues.Count -gt 0) {
                $lines.Add("        [ArgumentCompletions($($completionValues -join ', '))]")
            }
            foreach ($validation in $parameter.Validations) {
                switch ($validation.Type) {
                    'ValidateSet' {
                        $values = $validation.Definition['Values'] | ForEach-Object { "'$($_.Replace("'", "''"))'" }
                        $lines.Add("        [ValidateSet($($values -join ', '))]")
                    }
                    'ValidateRange' {
                        $minimum = [System.Convert]::ToString($validation.Definition['Minimum'], [System.Globalization.CultureInfo]::InvariantCulture)
                        $maximum = [System.Convert]::ToString($validation.Definition['Maximum'], [System.Globalization.CultureInfo]::InvariantCulture)
                        $lines.Add("        [ValidateRange($minimum, $maximum)]")
                    }
                    'ValidatePattern' {
                        $pattern = $validation.Definition['Pattern'].Replace("'", "''")
                        $lines.Add("        [ValidatePattern('$pattern')]")
                    }
                }
            }
            $lines.Add("        [$parameterType] `$$($parameter.Name)$separator")
        }
        $lines.Add('    )')
    }

    if ($SourceKind -in @('Script', 'ModuleFunction')) {
        $escapedSourcePath = $PackagedSourcePath.Replace("'", "''")
        $lines.Add('')
        $lines.Add('    $sourceParameters = @{}')
        foreach ($parameter in $Command.Parameters) {
            $lines.Add("    if (`$PSBoundParameters.ContainsKey('$($parameter.Name)')) {")
            $lines.Add("        `$sourceParameters['$($parameter.Name)'] = `$$($parameter.Name)")
            $lines.Add('    }')
        }
        $lines.Add('    $moduleRoot = Split-Path $PSScriptRoot -Parent')
        $lines.Add("    `$sourcePath = Join-Path `$moduleRoot '$escapedSourcePath'")
        $lines.Add("    if (-not (Test-Path -LiteralPath `$sourcePath -PathType Leaf)) {")
        $lines.Add("        throw [System.IO.FileNotFoundException]::new('Discovered PowerShell source was not found.', `$sourcePath)")
        $lines.Add('    }')
        $lines.Add('')
        $lines.Add("    if (-not `$PSCmdlet.ShouldProcess(`$sourcePath, 'Invoke discovered PowerShell $SourceKind')) {")
        $lines.Add('        return')
        $lines.Add('    }')
        $lines.Add('')
        $lines.Add("    Write-Verbose `"Invoking discovered PowerShell source: `$sourcePath`"")
        $lines.Add('    $sourceStopwatch = [System.Diagnostics.Stopwatch]::StartNew()')
        if ($SourceKind -eq 'Script') {
            $lines.Add('    & $sourcePath @sourceParameters')
        }
        else {
            $escapedCommandName = $Command.Name.Replace("'", "''")
            $lines.Add('    $sourceModule = Import-Module $sourcePath -Force -PassThru -ErrorAction Stop')
            $lines.Add("    `$sourceCommand = Get-Command -Module `$sourceModule.Name -Name '$escapedCommandName' -ErrorAction Stop")
            $lines.Add('    & $sourceCommand @sourceParameters')
        }
        $lines.Add('    $sourceStopwatch.Stop()')
        $lines.Add('    Write-Verbose ("PowerShell source finished after {0:N2}s." -f $sourceStopwatch.Elapsed.TotalSeconds)')
        $lines.Add('}')
        return ($lines -join "`n") + "`n"
    }

    $lines.Add('')
    $lines.Add('    $dockerArguments = [System.Collections.Generic.List[string]]::new()')
    $lines.Add("    `$dockerArguments.Add('run')")
    $lines.Add("    `$dockerArguments.Add('--rm')")

    foreach ($parameter in $Command.Parameters) {
        foreach ($mapping in $parameter.Mappings | Where-Object Type -eq 'Device') {
            $lines.Add("    if (`$PSBoundParameters.ContainsKey('$($parameter.Name)')) {")
            $lines.Add("        `$devicePath = [System.IO.Path]::GetFullPath([string] `$$($parameter.Name))")
            $lines.Add("        `$dockerArguments.Add('--device')")
            if ($mapping.Definition.Contains('Target')) {
                $target = $mapping.Definition['Target'].Replace("'", "''")
                $permissions = if ($mapping.Definition.Contains('Permissions')) { ':' + $mapping.Definition['Permissions'] } else { '' }
                $lines.Add("        `$dockerArguments.Add(`$devicePath + ':$target$permissions')")
            }
            elseif ($mapping.Definition.Contains('Permissions')) {
                $lines.Add("        `$dockerArguments.Add(`$devicePath + ':' + `$devicePath + ':$($mapping.Definition['Permissions'])')")
            }
            else {
                $lines.Add("        `$dockerArguments.Add(`$devicePath)")
            }
            $lines.Add('    }')
        }
    }

    foreach ($parameter in $Command.Parameters) {
        foreach ($mapping in $parameter.Mappings | Where-Object Type -eq 'Gpu') {
            $lines.Add("    if (`$PSBoundParameters.ContainsKey('$($parameter.Name)')) {")
            $lines.Add("        if (`$$($parameter.Name) -notmatch '^(all|[1-9][0-9]*|device=[A-Za-z0-9_.:-]+(?:,[A-Za-z0-9_.:-]+)*)`$') {")
            $lines.Add("            throw [System.ArgumentException]::new('GPU selection must be all, a positive count, or a device list.', '$($parameter.Name)')")
            $lines.Add('        }')
            $lines.Add("        `$dockerArguments.Add('--gpus')")
            $lines.Add("        `$dockerArguments.Add(`$$($parameter.Name))")
            $lines.Add('    }')
        }
    }

    foreach ($parameter in $Command.Parameters) {
        foreach ($mapping in $parameter.Mappings | Where-Object Type -eq 'ResourceLimit') {
            $resource = $mapping.Definition['Resource']
            $option = if ($resource -eq 'Memory') { '--memory' } else { '--cpus' }
            $lines.Add("    if (`$PSBoundParameters.ContainsKey('$($parameter.Name)')) {")
            if ($resource -eq 'Memory') {
                $lines.Add("        if (`$$($parameter.Name) -notmatch '^[1-9][0-9]*(?:[bBkKmMgG])?`$') {")
                $lines.Add("            throw [System.ArgumentException]::new('Memory limit must be a positive integer with an optional b, k, m, or g suffix.', '$($parameter.Name)')")
                $lines.Add('        }')
                $lines.Add("        `$resourceValue = `$$($parameter.Name)")
            }
            else {
                $lines.Add("        if (`$$($parameter.Name) -le 0) {")
                $lines.Add("            throw [System.ArgumentOutOfRangeException]::new('$($parameter.Name)', 'CPU limit must be greater than zero.')")
                $lines.Add('        }')
                $lines.Add("        `$resourceValue = [System.Convert]::ToString(`$$($parameter.Name), [System.Globalization.CultureInfo]::InvariantCulture)")
            }
            $lines.Add("        `$dockerArguments.Add('$option')")
            $lines.Add("        `$dockerArguments.Add(`$resourceValue)")
            $lines.Add('    }')
        }
    }

    foreach ($parameter in $Command.Parameters) {
        foreach ($mapping in $parameter.Mappings | Where-Object Type -eq 'Secret') {
            $target = if ($mapping.Definition.Contains('Target')) { $mapping.Definition['Target'] } else { '/run/secrets/' + $mapping.Definition['Name'] }
            $target = $target.Replace("'", "''")
            $lines.Add("    if (`$PSBoundParameters.ContainsKey('$($parameter.Name)')) {")
            $lines.Add("        `$secretPath = [System.IO.Path]::GetFullPath([string] `$$($parameter.Name))")
            $lines.Add("        if (`$secretPath.Contains(',')) {")
            $lines.Add("            throw [System.ArgumentException]::new('Secret file path cannot contain a comma.', '$($parameter.Name)')")
            $lines.Add('        }')
            $lines.Add("        if (-not [System.IO.File]::Exists(`$secretPath)) {")
            $lines.Add("            throw [System.IO.FileNotFoundException]::new('Secret file was not found.', `$secretPath)")
            $lines.Add('        }')
            $lines.Add("        `$dockerArguments.Add('--mount')")
            $lines.Add("        `$dockerArguments.Add('type=bind,source=' + `$secretPath + ',target=$target,readonly')")
            $lines.Add('    }')
        }
    }

    foreach ($parameter in $Command.Parameters) {
        foreach ($mapping in $parameter.Mappings | Where-Object Type -eq 'Mount') {
            $target = $mapping.Definition['Target'].Replace("'", "''")
            $readOnly = if ($mapping.Definition['Access'] -eq 'ReadOnly') { ',readonly' } else { '' }
            $lines.Add("    if (`$PSBoundParameters.ContainsKey('$($parameter.Name)')) {")
            $lines.Add("        `$dockerArguments.Add('--mount')")
            $lines.Add("        `$dockerArguments.Add('type=bind,source=' + [System.IO.Path]::GetFullPath([string] `$$($parameter.Name)) + ',target=$target$readOnly')")
            $lines.Add('    }')
        }
    }

    foreach ($parameter in $Command.Parameters) {
        foreach ($mapping in $parameter.Mappings | Where-Object Type -eq 'Volume') {
            $target = $mapping.Definition['Target'].Replace("'", "''")
            $readOnly = if ($mapping.Definition['Access'] -eq 'ReadOnly') { ',readonly' } else { '' }
            $lines.Add("    if (`$PSBoundParameters.ContainsKey('$($parameter.Name)')) {")
            $lines.Add("        if (`$$($parameter.Name) -notmatch '^[A-Za-z0-9][A-Za-z0-9_.-]*`$') {")
            $lines.Add("            throw [System.ArgumentException]::new('Docker volume name contains unsupported characters.', '$($parameter.Name)')")
            $lines.Add('        }')
            $lines.Add("        `$dockerArguments.Add('--mount')")
            $lines.Add("        `$dockerArguments.Add('type=volume,source=' + `$$($parameter.Name) + ',target=$target$readOnly')")
            $lines.Add('    }')
        }
    }

    foreach ($parameter in $Command.Parameters) {
        foreach ($mapping in $parameter.Mappings | Where-Object Type -eq 'Environment') {
            $mappingName = $mapping.Definition['Name'].Replace("'", "''")
            $lines.Add("    if (`$PSBoundParameters.ContainsKey('$($parameter.Name)')) {")
            $lines.Add("        `$dockerArguments.Add('-e')")
            $lines.Add("        `$dockerArguments.Add('$mappingName=' + [string] `$$($parameter.Name))")
            $lines.Add('    }')
        }
    }

    foreach ($parameter in $Command.Parameters) {
        foreach ($mapping in $parameter.Mappings | Where-Object Type -eq 'Port') {
            $containerPort = $mapping.Definition['ContainerPort']
            $protocol = if ($mapping.Definition.Contains('Protocol')) { $mapping.Definition['Protocol'].ToLowerInvariant() } else { 'tcp' }
            $lines.Add("    if (`$PSBoundParameters.ContainsKey('$($parameter.Name)')) {")
            $lines.Add("        if (`$$($parameter.Name) -lt 1 -or `$$($parameter.Name) -gt 65535) {")
            $lines.Add("            throw [System.ArgumentOutOfRangeException]::new('$($parameter.Name)', 'Host port must be from 1 through 65535.')")
            $lines.Add('        }')
            $lines.Add("        `$dockerArguments.Add('--publish')")
            $lines.Add("        `$dockerArguments.Add([string] `$$($parameter.Name) + ':$containerPort/$protocol')")
            $lines.Add('    }')
        }
    }

    foreach ($parameter in $Command.Parameters) {
        foreach ($mapping in $parameter.Mappings | Where-Object Type -eq 'WorkingDirectory') {
            $lines.Add("    if (`$PSBoundParameters.ContainsKey('$($parameter.Name)')) {")
            $lines.Add("        if ([string]::IsNullOrWhiteSpace(`$$($parameter.Name))) {")
            $lines.Add("            throw [System.ArgumentException]::new('Container working directory cannot be empty.', '$($parameter.Name)')")
            $lines.Add('        }')
            $lines.Add("        `$dockerArguments.Add('--workdir')")
            $lines.Add("        `$dockerArguments.Add(`$$($parameter.Name))")
            $lines.Add('    }')
        }
    }

    foreach ($parameter in $Command.Parameters) {
        foreach ($mapping in $parameter.Mappings | Where-Object Type -eq 'RuntimeOption') {
            $optionName = $mapping.Definition['Name']
            $lines.Add("    if (`$PSBoundParameters.ContainsKey('$($parameter.Name)')) {")
            if ($parameter.Type -eq 'switch') {
                $lines.Add("        `$dockerArguments.Add('$optionName')")
            }
            else {
                $lines.Add("        foreach (`$value in @(`$$($parameter.Name))) {")
                $lines.Add("            `$dockerArguments.Add('$optionName')")
                $lines.Add('            $dockerArguments.Add([string] $value)')
                $lines.Add('        }')
            }
            $lines.Add('    }')
        }
    }

    $lines.Add("    `$dockerArguments.Add('$($ContainerImage.Replace("'", "''"))')")

    foreach ($parameter in $Command.Parameters) {
        foreach ($mapping in $parameter.Mappings | Where-Object Type -eq 'Argument') {
            $mappingName = $mapping.Definition['Name'].Replace("'", "''")
            $lines.Add("    if (`$PSBoundParameters.ContainsKey('$($parameter.Name)')) {")
            if ($parameter.Type -eq 'switch') {
                $lines.Add("        `$dockerArguments.Add('$mappingName')")
            }
            else {
                $lines.Add("        foreach (`$value in @(`$$($parameter.Name))) {")
                $lines.Add("            `$dockerArguments.Add('$mappingName')")
                $lines.Add('            $dockerArguments.Add([string] $value)')
                $lines.Add('        }')
            }
            $lines.Add('    }')
        }
    }

    $lines.Add('')
    $lines.Add("    if (-not `$PSCmdlet.ShouldProcess('$($ContainerImage.Replace("'", "''"))', 'docker ' + (`$dockerArguments -join ' '))) {")
    $lines.Add('        return')
    $lines.Add('    }')
    $lines.Add('')
    $lines.Add("    if (`$null -eq (Get-Command -Name 'docker' -ErrorAction SilentlyContinue)) {")
    $lines.Add("        throw [System.InvalidOperationException]::new('Docker is required to run this command but was not found on PATH.')")
    $lines.Add('    }')
    $lines.Add('')
    $lines.Add("    `$dockerCommand = 'docker ' + (`$dockerArguments -join ' ')")
    $lines.Add("    Write-Verbose `"Starting container command: `$dockerCommand`"")
    $lines.Add("    Write-Verbose 'Docker is attached to this session. Press Ctrl+C to stop a command that does not return.'")
    $lines.Add('    $dockerStopwatch = [System.Diagnostics.Stopwatch]::StartNew()')
    $lines.Add('    $global:LASTEXITCODE = 0')
    $lines.Add('    & docker @dockerArguments')
    $lines.Add('    $dockerSucceeded = $?')
    $lines.Add('    $dockerExitCode = $global:LASTEXITCODE')
    $lines.Add('    $dockerStopwatch.Stop()')
    $lines.Add('    Write-Verbose ("Container command finished after {0:N2}s with exit code {1}." -f $dockerStopwatch.Elapsed.TotalSeconds, $dockerExitCode)')
    $lines.Add('    if (-not $dockerSucceeded -or $dockerExitCode -ne 0) {')
    $lines.Add('        throw [System.InvalidOperationException]::new("Docker failed with exit code $dockerExitCode. Command: $dockerCommand")')
    $lines.Add('    }')
    $lines.Add('}')

    return ($lines -join "`n") + "`n"
}
