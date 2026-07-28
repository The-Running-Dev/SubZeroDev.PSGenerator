function Get-PSModuleCommandCollision {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]] $Command,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $ModuleName,

        [Parameter()]
        [AllowEmptyString()]
        [string] $SpecificationId = ''
    )

    if ($Command.Count -eq 0) {
        return
    }

    function GetGeneratedIdentity {
        param ([AllowNull()] [object] $PrivateData)

        $identity = [ordered] @{
            GeneratedBy     = ''
            SpecificationId = ''
        }
        if ($PrivateData -isnot [System.Collections.IDictionary]) {
            return $identity
        }

        $generatorData = $PrivateData['PSGenerator']
        if ($generatorData -isnot [System.Collections.IDictionary]) {
            return $identity
        }

        $identity.GeneratedBy = [string] $generatorData['GeneratedBy']
        $identity.SpecificationId = [string] $generatorData['SpecificationId']
        return $identity
    }

    function NewCommandIdentity {
        param (
            [Parameter(Mandatory)] [string] $Name,
            [Parameter(Mandatory)] [string] $CommandType,
            [AllowEmptyString()] [string] $ModuleName,
            [AllowEmptyString()] [string] $Source,
            [AllowNull()] [object] $PrivateData
        )

        $generatedIdentity = GetGeneratedIdentity -PrivateData $PrivateData
        [pscustomobject] @{
            Name              = $Name
            CommandType       = $CommandType
            ModuleName        = $ModuleName
            Source            = $Source
            GeneratedBy       = $generatedIdentity.GeneratedBy
            SpecificationId   = $generatedIdentity.SpecificationId
        }
    }

    # Locating the manifests is cheap; parsing them is not. The inventory therefore
    # runs on every call and the parsed index is cached against the state of the
    # files it was built from, so installing, removing, or editing a module beneath
    # an unchanged PSModulePath root cannot leave the diagnostics stale.
    $moduleRoots = @(
        foreach ($moduleRoot in (
            $env:PSModulePath -split [IO.Path]::PathSeparator |
                Where-Object { $_ } |
                Sort-Object -Unique
        )) {
            try {
                if (Test-Path `
                    -LiteralPath $moduleRoot `
                    -PathType Container `
                    -ErrorAction Stop) {
                    $moduleRoot
                }
            }
            catch [System.UnauthorizedAccessException] {
                continue
            }
            catch [System.IO.IOException] {
                continue
            }
        }
    )
    $manifestFiles = @(
        foreach ($moduleRoot in $moduleRoots) {
            foreach ($moduleDirectory in @(
                Get-ChildItem `
                    -LiteralPath $moduleRoot `
                    -Directory `
                    -ErrorAction SilentlyContinue
            )) {
                $directManifest = Join-Path `
                    $moduleDirectory.FullName `
                    "$($moduleDirectory.Name).psd1"
                if (Test-Path -LiteralPath $directManifest -PathType Leaf) {
                    Get-Item -LiteralPath $directManifest
                }

                foreach ($versionDirectory in @(
                    Get-ChildItem `
                        -LiteralPath $moduleDirectory.FullName `
                        -Directory `
                        -ErrorAction SilentlyContinue
                )) {
                    $versionManifest = Join-Path `
                        $versionDirectory.FullName `
                        "$($moduleDirectory.Name).psd1"
                    if (Test-Path -LiteralPath $versionManifest -PathType Leaf) {
                        Get-Item -LiteralPath $versionManifest
                    }
                }
            }
        }
    )
    $orderedManifests = @($manifestFiles | Sort-Object FullName -Unique)

    # Full path, length, and write time together detect an added, removed,
    # replaced, or edited manifest. PSModulePath needs no separate key: changing
    # it changes the discovered file set.
    $cacheKey = (
        $orderedManifests | ForEach-Object {
            '{0}|{1}|{2:o}' -f $_.FullName, $_.Length, $_.LastWriteTimeUtc
        }
    ) -join "`n"
    $cacheVariable = Get-Variable `
        -Name 'PSModuleAvailableCommandCache' `
        -Scope Script `
        -ErrorAction SilentlyContinue
    if ($null -eq $cacheVariable -or $cacheVariable.Value.Key -cne $cacheKey) {
        $availableCommandIndex =
            [System.Collections.Generic.Dictionary[string, object]]::new(
                [System.StringComparer]::OrdinalIgnoreCase
            )

        foreach ($manifestFile in $orderedManifests) {
            try {
                $manifest = Import-PowerShellDataFile `
                    -LiteralPath $manifestFile.FullName `
                    -ErrorAction Stop
            }
            catch {
                continue
            }

            $exportTypes = [ordered] @{
                FunctionsToExport = 'Function'
                CmdletsToExport   = 'Cmdlet'
                AliasesToExport   = 'Alias'
            }
            foreach ($exportType in $exportTypes.GetEnumerator()) {
                if (-not $manifest.ContainsKey($exportType.Key)) {
                    continue
                }

                foreach ($exportedName in @($manifest[$exportType.Key])) {
                    if ($exportedName -isnot [string] -or
                        [string]::IsNullOrWhiteSpace($exportedName) -or
                        [WildcardPattern]::ContainsWildcardCharacters($exportedName)) {
                        continue
                    }
                    if (-not $availableCommandIndex.ContainsKey($exportedName)) {
                        $availableCommandIndex[$exportedName] =
                            [System.Collections.Generic.List[object]]::new()
                    }

                    $privateData = if ($manifest.ContainsKey('PrivateData')) {
                        $manifest['PrivateData']
                    }
                    else {
                        $null
                    }
                    $availableCommandIndex[$exportedName].Add((
                        NewCommandIdentity `
                            -Name $exportedName `
                            -CommandType $exportType.Value `
                            -ModuleName $manifestFile.BaseName `
                            -Source $manifestFile.FullName `
                            -PrivateData $privateData
                    ))
                }
            }
        }

        $script:PSModuleAvailableCommandCache = [pscustomobject] @{
            Key   = $cacheKey
            Index = $availableCommandIndex
        }
    }
    else {
        $availableCommandIndex = $cacheVariable.Value.Index
    }

    $localPreference = Get-Variable `
        -Name 'PSModuleAutoLoadingPreference' `
        -Scope Local `
        -ErrorAction SilentlyContinue
    $originalModulePath = $env:PSModulePath
    try {
        $PSModuleAutoLoadingPreference = 'None'
        $env:PSModulePath = ''

        foreach ($candidate in @($Command | Sort-Object Name, SourcePath)) {
            $identities = [System.Collections.Generic.List[object]]::new()
            foreach ($resolvedCommand in @(
                Get-Command `
                    -Name $candidate.Name `
                    -All `
                    -ErrorAction SilentlyContinue
            )) {
                $source = if ($null -ne $resolvedCommand.Module) {
                    [string] $resolvedCommand.Module.Path
                }
                else {
                    [string] $resolvedCommand.Source
                }
                $privateData = if ($null -ne $resolvedCommand.Module) {
                    $resolvedCommand.Module.PrivateData
                }
                else {
                    $null
                }
                $identities.Add((
                    NewCommandIdentity `
                        -Name ([string] $resolvedCommand.Name) `
                        -CommandType ([string] $resolvedCommand.CommandType) `
                        -ModuleName ([string] $resolvedCommand.ModuleName) `
                        -Source $source `
                        -PrivateData $privateData
                ))
            }

            if ($availableCommandIndex.ContainsKey($candidate.Name)) {
                foreach ($availableCommand in $availableCommandIndex[$candidate.Name]) {
                    $identities.Add($availableCommand)
                }
            }

            $seenIdentities = [System.Collections.Generic.HashSet[string]]::new(
                [System.StringComparer]::OrdinalIgnoreCase
            )
            $existingCommands = @(
                $identities |
                    Where-Object {
                        -not (
                            $SpecificationId -and
                            $_.ModuleName -eq $ModuleName -and
                            $_.GeneratedBy -eq 'SubZeroDev.PSGenerator' -and
                            $_.SpecificationId -eq $SpecificationId
                        )
                    } |
                    Sort-Object CommandType, ModuleName, Name, Source |
                    Where-Object {
                        $identityKey = if ($_.ModuleName) {
                            "$($_.CommandType)|$($_.ModuleName)|$($_.Name)"
                        }
                        else {
                            "$($_.CommandType)|$($_.Source)|$($_.Name)"
                        }
                        $seenIdentities.Add($identityKey)
                    }
            )
            if ($existingCommands.Count -eq 0) {
                continue
            }

            [pscustomobject] @{
                PSTypeName       = 'SubZeroDev.PSGenerator.CommandCollision'
                Name             = [string] $candidate.Name
                SourcePath       = [string] $candidate.SourcePath
                ExistingCommands = $existingCommands
            }
        }
    }
    finally {
        $env:PSModulePath = $originalModulePath
        if ($null -eq $localPreference) {
            Remove-Variable `
                -Name 'PSModuleAutoLoadingPreference' `
                -Scope Local `
                -ErrorAction SilentlyContinue
        }
        else {
            Set-Variable `
                -Name 'PSModuleAutoLoadingPreference' `
                -Value $localPreference.Value `
                -Scope Local
        }
    }
}
