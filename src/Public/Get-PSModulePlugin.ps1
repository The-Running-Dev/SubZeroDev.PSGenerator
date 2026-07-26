function Get-PSModulePlugin {
    <#
    .SYNOPSIS
    Discovers container module pipeline plugins.

    .DESCRIPTION
    Finds PowerShell plugin files in the supported pipeline stage directories and
    returns metadata in deterministic pipeline and lexical filename order. This
    command inspects plugins; it does not execute their code. Version 1 plugins use
    the generator's internal shared-context contract, are trusted unsandboxed
    PowerShell code, and do not constitute a stable public SDK.

    .PARAMETER Path
    One or more plugin roots containing the supported stage directories.

    .PARAMETER Stage
    Limits discovery to one or more pipeline stages.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string[]] $Path,

        [ValidateSet(
            'Inspectors',
            'Validators',
            'ObjectModelProcessors',
            'RuntimeAdapters',
            'CodeGenerators',
            'TemplateRenderers',
            'PackagingProviders'
        )]
        [string[]] $Stage
    )

    begin {
        $stageOrder = @(
            'Inspectors'
            'Validators'
            'ObjectModelProcessors'
            'RuntimeAdapters'
            'CodeGenerators'
            'TemplateRenderers'
            'PackagingProviders'
        )
        $requestedPaths = [System.Collections.Generic.List[string]]::new()
    }

    process {
        foreach ($pluginPath in $Path) {
            $requestedPaths.Add($pluginPath)
        }
    }

    end {
        $selectedStages = if ($Stage) {
            $stageOrder.Where({ $_ -in $Stage })
        }
        else {
            $stageOrder
        }

        $resolvedRoots = [System.Collections.Generic.List[string]]::new()
        foreach ($pluginPath in $requestedPaths) {
            if (-not (Test-Path -LiteralPath $pluginPath -PathType Container)) {
                throw [System.IO.DirectoryNotFoundException]::new(
                    "Plugin root '$pluginPath' was not found or is not a directory."
                )
            }

            $resolvedRoot = [System.IO.Path]::GetFullPath((Resolve-Path -LiteralPath $pluginPath).Path)
            if ($resolvedRoots.Contains($resolvedRoot)) {
                throw [System.IO.InvalidDataException]::new("Plugin root '$resolvedRoot' was specified more than once.")
            }

            $resolvedRoots.Add($resolvedRoot)
        }

        $executionOrder = 0
        foreach ($stageName in $selectedStages) {
            $plugins = foreach ($root in $resolvedRoots) {
                $stagePath = Join-Path $root $stageName
                if (Test-Path -LiteralPath $stagePath -PathType Container) {
                    Get-ChildItem -LiteralPath $stagePath -File -Filter '*.ps1'
                }
            }

            $plugins = @($plugins)
            [Array]::Sort(
                $plugins,
                [System.Collections.Generic.Comparer[object]]::Create({
                    param ($left, $right)

                    $comparison = [System.StringComparer]::Ordinal.Compare($left.Name, $right.Name)
                    if ($comparison -eq 0) {
                        return [System.StringComparer]::Ordinal.Compare($left.FullName, $right.FullName)
                    }

                    return $comparison
                })
            )
            foreach ($plugin in $plugins) {
                if ($plugin.Name -notmatch '^(?<Prefix>[0-9]+)\.(?<Name>.+)\.ps1$') {
                    throw [System.IO.InvalidDataException]::new(
                        "Plugin '$($plugin.FullName)' must use the '<numeric-prefix>.<name>.ps1' filename format."
                    )
                }

                [pscustomobject]@{
                    PSTypeName     = 'SubZeroDev.PSGenerator.PluginInfo'
                    Stage          = $stageName
                    ExecutionOrder = $executionOrder
                    Prefix         = [int] $Matches.Prefix
                    Name           = $Matches.Name
                    FileName       = $plugin.Name
                    Path           = $plugin.FullName
                }
                $executionOrder++
            }
        }
    }
}
