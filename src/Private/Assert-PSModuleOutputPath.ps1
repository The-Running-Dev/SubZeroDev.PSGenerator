function Assert-PSModuleOutputPath {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [psobject] $Context,

        [Parameter()]
        [switch] $Force
    )

    foreach ($name in @('OutputPath', 'SpecificationPath', 'DirectoryPath')) {
        if (-not $Context.PSObject.Properties[$name] -or
            [string]::IsNullOrWhiteSpace([string] $Context.$name)) {
            throw [ArgumentException]::new(
                "The build context does not define $name, so output cannot be reset safely."
            )
        }
    }

    $comparison = if ($IsLinux) {
        [StringComparison]::Ordinal
    }
    else {
        [StringComparison]::OrdinalIgnoreCase
    }
    $separators = [char[]] @(
        [IO.Path]::DirectorySeparatorChar,
        [IO.Path]::AltDirectorySeparatorChar
    )
    $equalsPath = {
        param ([string] $Left, [string] $Right)

        # Normalize once, then keep the trimmed values inside this comparison.
        $leftPath = [IO.Path]::GetFullPath($Left).TrimEnd($separators)
        $rightPath = [IO.Path]::GetFullPath($Right).TrimEnd($separators)
        return [string]::Equals($leftPath, $rightPath, $comparison)
    }
    $isRoot = {
        param ([string] $Path)

        $fullPath = [IO.Path]::GetFullPath($Path)
        $rootPath = [IO.Path]::GetPathRoot($fullPath)
        return & $equalsPath $fullPath $rootPath
    }
    $hasActualLinkTarget = {
        param ([System.IO.FileSystemInfo] $Item)

        if (-not $Item.Attributes.HasFlag([IO.FileAttributes]::ReparsePoint)) {
            return $false
        }
        $target = if ($Item.PSIsContainer) {
            [IO.Directory]::ResolveLinkTarget($Item.FullName, $false)
        }
        else {
            [IO.File]::ResolveLinkTarget($Item.FullName, $false)
        }
        return $null -ne $target
    }

    $outputPath = [IO.Path]::GetFullPath([string] $Context.OutputPath)
    $specificationPath = [IO.Path]::GetFullPath([string] $Context.SpecificationPath)
    $directoryPath = [IO.Path]::GetFullPath([string] $Context.DirectoryPath)
    $realOutputPath = Resolve-PSModuleInspectionRealPath -Path $outputPath
    $realSpecificationPath = Resolve-PSModuleInspectionRealPath -Path $specificationPath
    $realDirectoryPath = Resolve-PSModuleInspectionRealPath -Path $directoryPath

    foreach ($candidate in @($outputPath, $realOutputPath)) {
        if (& $isRoot $candidate) {
            throw [ArgumentException]::new(
                "PSGenerator output path is unsafe because it is a filesystem root: '$candidate'.",
                'Output'
            )
        }
    }

    foreach ($relationship in @(
        @{ Output = $outputPath; Source = $directoryPath; Description = 'inspected source directory' }
        @{ Output = $realOutputPath; Source = $realDirectoryPath; Description = 'inspected source directory' }
        @{ Output = $outputPath; Source = $specificationPath; Description = 'specification' }
        @{ Output = $realOutputPath; Source = $realSpecificationPath; Description = 'specification' }
    )) {
        if ((& $equalsPath $relationship.Output $relationship.Source) -or
            (Test-PSModulePathAncestor `
                -CandidateAncestor $relationship.Output `
                -Path $relationship.Source `
                -Comparison $comparison)) {
            throw [ArgumentException]::new(
                "PSGenerator output path is unsafe because it contains the $($relationship.Description): '$outputPath'.",
                'Output'
            )
        }
    }

    # This literal mirrors Write-PSModuleCommandSource. Keep the derived copy guard
    # there as well so a future packaged source does not silently bypass this policy.
    $scriptsPath = Join-Path $directoryPath 'scripts'
    $realScriptsPath = Resolve-PSModuleInspectionRealPath -Path $scriptsPath
    foreach ($relationship in @(
        @{ Output = $outputPath; Scripts = $scriptsPath }
        @{ Output = $realOutputPath; Scripts = $realScriptsPath }
    )) {
        if ((& $equalsPath $relationship.Output $relationship.Scripts) -or
            (Test-PSModulePathAncestor `
                -CandidateAncestor $relationship.Scripts `
                -Path $relationship.Output `
                -Comparison $comparison)) {
            throw [ArgumentException]::new(
                "PSGenerator output path is unsafe because it overlaps the packaged scripts tree: '$outputPath'.",
                'Output'
            )
        }
    }

    $existed = Test-Path -LiteralPath $outputPath
    if ($existed -and -not (Test-Path -LiteralPath $outputPath -PathType Container)) {
        throw [ArgumentException]::new(
            "PSGenerator output path must be a directory: '$outputPath'.",
            'Output'
        )
    }

    if ($existed) {
        $outputItem = Get-Item -LiteralPath $outputPath -Force -ErrorAction Stop
        if (& $hasActualLinkTarget $outputItem) {
            throw [ArgumentException]::new(
                "PSGenerator cannot reset a linked output directory: '$outputPath'.",
                'Output'
            )
        }
    }

    $ownership = Test-PSModuleOutputOwnership -OutputPath $outputPath
    if ($ownership.State -in @('Unowned', 'InvalidMarker') -and -not $Force) {
        throw [InvalidOperationException]::new(
            "Output directory '$outputPath' is not recognized as PSGenerator-owned and is not empty. " +
            'Review the directory, choose another output, or rerun Build-PSModule with -Force to replace it.'
        )
    }

    [pscustomobject] @{
        PSTypeName = 'SubZeroDev.PSGenerator.OutputPathValidation'
        OutputPath = $outputPath
        RealPath   = $realOutputPath
        Existed    = $existed
        Ownership = $ownership
    }
}
