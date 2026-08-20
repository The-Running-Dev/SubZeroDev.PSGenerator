function Reset-PSModuleOutput {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [psobject] $Context
    )

    $force = [bool] (
        $Context.PSObject.Properties['ForceOutputReset'] -and
        $Context.ForceOutputReset
    )
    $validation = Assert-PSModuleOutputPath -Context $Context -Force:$force

    $existsNow = Test-Path -LiteralPath $validation.OutputPath
    if ($validation.Existed -ne $existsNow) {
        throw [IO.IOException]::new(
            "The output path changed while reset safety was being validated: '$($validation.OutputPath)'."
        )
    }
    if ($existsNow) {
        if (-not (Test-Path -LiteralPath $validation.OutputPath -PathType Container)) {
            throw [IO.IOException]::new(
                "The output path changed from a directory before reset: '$($validation.OutputPath)'."
            )
        }

        $outputItem = Get-Item -LiteralPath $validation.OutputPath -Force -ErrorAction Stop
        $linkTarget = if ($outputItem.Attributes.HasFlag([IO.FileAttributes]::ReparsePoint)) {
            [IO.Directory]::ResolveLinkTarget($outputItem.FullName, $false)
        }
        else {
            $null
        }
        $realPathNow = Resolve-PSModuleInspectionRealPath -Path $validation.OutputPath
        $comparison = if ($IsLinux) {
            [StringComparison]::Ordinal
        }
        else {
            [StringComparison]::OrdinalIgnoreCase
        }
        if ($linkTarget -or -not [string]::Equals(
            $realPathNow,
            $validation.RealPath,
            $comparison
        )) {
            throw [IO.IOException]::new(
                "The output path identity changed before reset: '$($validation.OutputPath)'."
            )
        }

        Remove-Item -LiteralPath $validation.OutputPath -Recurse -Force
    }

    $null = New-Item -Path $validation.OutputPath -ItemType Directory -Force
    $null = Write-PSModuleOutputMarker -OutputPath $validation.OutputPath
}
