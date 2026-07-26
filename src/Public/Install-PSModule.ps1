function Install-PSModule {
    <#
    .SYNOPSIS
    Installs a generated PowerShell module from a container image.

    .DESCRIPTION
    Creates a temporary container without starting it, stages its /PSModule contents,
    validates the single module manifest, and installs the complete package including
    generated Markdown documentation. The temporary container is always removed.
    Existing destinations require Force, and WhatIf previews the operation without
    calling Docker or modifying the destination.

    .PARAMETER Image
    Container image containing a generated module at /PSModule.

    .PARAMETER Destination
    Local directory that receives the module files. Defaults to ~/PSModule.

    .PARAMETER Force
    Replaces an existing destination after the extracted module passes validation.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param (
        [Parameter(Mandatory, Position = 0)]
        [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._/:@-]*$')]
        [string] $Image,

        [Parameter()]
        [string] $Destination = (Join-Path ([System.Environment]::GetFolderPath('UserProfile')) 'PSModule'),

        [Parameter()]
        [switch] $Force
    )

    $destinationPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Destination)
    $destinationRoot = [System.IO.Path]::GetPathRoot($destinationPath)
    if ([string]::Equals($destinationPath, $destinationRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw [System.ArgumentException]::new('The installation destination cannot be a filesystem root.')
    }
    if (-not $PSCmdlet.ShouldProcess($destinationPath, "Install /PSModule from '$Image'")) {
        return
    }

    if ((Test-Path -LiteralPath $destinationPath) -and -not $Force) {
        throw [System.IO.IOException]::new(
            "The destination '$destinationPath' already exists. Use -Force to replace it."
        )
    }

    if ($null -eq (Get-Command -Name 'docker' -ErrorAction SilentlyContinue)) {
        throw [System.InvalidOperationException]::new(
            'Docker is required to install a container module but was not found on PATH.'
        )
    }

    $destinationParent = Split-Path -Path $destinationPath -Parent
    $destinationName = Split-Path -Path $destinationPath -Leaf
    $stagingPath = Join-Path $destinationParent ".$destinationName.install-$([guid]::NewGuid().ToString('N'))"
    $containerId = $null
    try {
        $null = New-Item -Path $destinationParent -ItemType Directory -Force
        $null = New-Item -Path $stagingPath -ItemType Directory

        $global:LASTEXITCODE = 0
        $containerId = (& docker create $Image | Out-String).Trim()
        if ($global:LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($containerId)) {
            throw [System.InvalidOperationException]::new(
                "Docker could not create a temporary container from '$Image'. Exit code: $global:LASTEXITCODE."
            )
        }

        $global:LASTEXITCODE = 0
        & docker cp "${containerId}:/PSModule/." $stagingPath
        if ($global:LASTEXITCODE -ne 0) {
            throw [System.InvalidOperationException]::new(
                "Docker could not copy /PSModule from '$Image'. Exit code: $global:LASTEXITCODE."
            )
        }

        $manifests = @(Get-ChildItem -LiteralPath $stagingPath -Filter '*.psd1' -File)
        if ($manifests.Count -ne 1) {
            throw [System.IO.InvalidDataException]::new(
                "The image '$Image' must contain exactly one module manifest at /PSModule. Found $($manifests.Count)."
            )
        }
        $null = Test-ModuleManifest -Path $manifests[0].FullName -ErrorAction Stop

        if (Test-Path -LiteralPath $destinationPath) {
            Remove-Item -LiteralPath $destinationPath -Recurse -Force
        }
        Move-Item -LiteralPath $stagingPath -Destination $destinationPath
        $stagingPath = $null
    }
    finally {
        if ($null -ne $stagingPath -and (Test-Path -LiteralPath $stagingPath)) {
            Remove-Item -LiteralPath $stagingPath -Recurse -Force
        }
        if (-not [string]::IsNullOrWhiteSpace($containerId)) {
            $global:LASTEXITCODE = 0
            & docker rm --force $containerId | Out-Null
            if ($global:LASTEXITCODE -ne 0) {
                Write-Warning "Docker could not remove temporary container '$containerId'."
            }
        }
    }

    Get-Item -LiteralPath $destinationPath
}
