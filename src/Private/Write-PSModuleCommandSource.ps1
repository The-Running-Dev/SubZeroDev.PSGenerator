function Write-PSModuleCommandSource {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [psobject] $Context
    )

    if ($Context.Model.Commands.Count -eq 0) {
        return
    }

    $sourceCommands = @($Context.Model.Commands | Where-Object {
        $_.Definition.ContainsKey('SourceKind') -and
        $_.Definition['SourceKind'] -in @('Script', 'ModuleFunction')
    })
    if ($sourceCommands.Count -gt 0) {
        $directoryScriptsPath = Join-Path $Context.DirectoryPath 'scripts'
        if (Test-Path -LiteralPath $directoryScriptsPath -PathType Container) {
            $scriptsDestinationPath = Join-Path $Context.OutputPath 'Scripts'
            $realScriptsPath = Resolve-PSModuleInspectionRealPath -Path $directoryScriptsPath
            $realDestinationPath = Resolve-PSModuleInspectionRealPath -Path $scriptsDestinationPath
            $comparison = if ($IsLinux) {
                [StringComparison]::Ordinal
            }
            else {
                [StringComparison]::OrdinalIgnoreCase
            }
            if ([string]::Equals($realScriptsPath, $realDestinationPath, $comparison) -or
                (Test-PSModulePathAncestor `
                    -CandidateAncestor $realScriptsPath `
                    -Path $realDestinationPath `
                    -Comparison $comparison)) {
                throw [InvalidOperationException]::new(
                    "Cannot package scripts from '$realScriptsPath' into '$realDestinationPath' " +
                    'because the destination is inside the source tree.'
                )
            }

            Copy-Item `
                -LiteralPath $directoryScriptsPath `
                -Destination $scriptsDestinationPath `
                -Recurse `
                -Force
        }
    }

    $publicDirectory = Join-Path $Context.OutputPath 'Public'
    $null = New-Item -Path $publicDirectory -ItemType Directory -Force

    foreach ($command in $Context.Model.Commands) {
        $sourcePath = Join-Path $publicDirectory "$($command.Name).ps1"
        $sourceKind = if ($command.Definition.ContainsKey('SourceKind')) {
            [string] $command.Definition['SourceKind']
        }
        else { $null }
        $packagedSourcePath = $null
        if ($sourceKind -in @('Script', 'ModuleFunction')) {
            $declaredSourcePath = [string] $command.Definition['SourcePath']
            if ([IO.Path]::IsPathRooted($declaredSourcePath)) {
                throw [System.IO.InvalidDataException]::new(
                    "SourcePath for command '$($command.Name)' must be relative to the directory."
                )
            }
            $resolvedSourcePath = [IO.Path]::GetFullPath((Join-Path $Context.DirectoryPath $declaredSourcePath))
            $directoryPrefix = $Context.DirectoryPath.TrimEnd(
                [IO.Path]::DirectorySeparatorChar,
                [IO.Path]::AltDirectorySeparatorChar
            ) + [IO.Path]::DirectorySeparatorChar
            if (-not $resolvedSourcePath.StartsWith($directoryPrefix, [StringComparison]::OrdinalIgnoreCase)) {
                throw [System.IO.InvalidDataException]::new(
                    "SourcePath for command '$($command.Name)' resolves outside the directory."
                )
            }
            $scriptsPrefix = (Join-Path $Context.DirectoryPath 'scripts').TrimEnd(
                [IO.Path]::DirectorySeparatorChar,
                [IO.Path]::AltDirectorySeparatorChar
            ) + [IO.Path]::DirectorySeparatorChar
            if (-not $resolvedSourcePath.StartsWith($scriptsPrefix, [StringComparison]::OrdinalIgnoreCase)) {
                throw [System.IO.InvalidDataException]::new(
                    "SourcePath for command '$($command.Name)' must be beneath the directory's 'scripts' directory."
                )
            }
            if (-not (Test-Path -LiteralPath $resolvedSourcePath -PathType Leaf)) {
                throw [System.IO.FileNotFoundException]::new(
                    "SourcePath for command '$($command.Name)' was not found.",
                    $resolvedSourcePath
                )
            }

            $scriptsRelativePath = [IO.Path]::GetRelativePath(
                (Join-Path $Context.DirectoryPath 'scripts'),
                $resolvedSourcePath
            )
            $packagedSourcePath = Join-Path 'Scripts' $scriptsRelativePath
        }
        $source = ConvertTo-PSModuleCommandSource `
            -Command $command `
            -ContainerImage $Context.Model.ContainerImage `
            -SourceKind $sourceKind `
            -PackagedSourcePath $packagedSourcePath
        [System.IO.File]::WriteAllText(
            $sourcePath,
            $source,
            [System.Text.UTF8Encoding]::new($false)
        )
    }
}
