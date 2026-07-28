function Invoke-PSModulePluginPipeline {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [psobject] $Context,

        [Parameter(Mandatory)]
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

    if (-not $Context.PSObject.Properties['PluginExecutions']) {
        $Context | Add-Member -MemberType NoteProperty -Name PluginExecutions -Value (
            [System.Collections.Generic.List[object]]::new()
        )
    }
    elseif ($Context.PluginExecutions -isnot [System.Collections.IList]) {
        throw [System.IO.InvalidDataException]::new(
            "The pipeline context 'PluginExecutions' property must implement IList."
        )
    }

    $discoveryParameters = @{ Path = $Path }
    if ($Stage) {
        $discoveryParameters.Stage = $Stage
    }

    foreach ($plugin in Get-PSModulePlugin @discoveryParameters) {
        $command = Get-Command -Name $plugin.Path -CommandType ExternalScript -ErrorAction Stop
        if (-not $command.Parameters.ContainsKey('Context')) {
            throw [System.IO.InvalidDataException]::new(
                "Plugin '$($plugin.Path)' must declare a 'Context' parameter."
            )
        }

        $startedAt = [DateTimeOffset]::UtcNow
        $execution = [pscustomobject]@{
            PSTypeName = 'SubZeroDev.PSGenerator.PluginExecution'
            Stage      = $plugin.Stage
            ExecutionOrder = $plugin.ExecutionOrder
            Plugin     = $plugin.Name
            Path       = $plugin.Path
            StartedAt  = $startedAt
            Duration   = [TimeSpan]::Zero
            Succeeded  = $false
            Error      = $null
        }

        try {
            & $plugin.Path -Context $Context | Out-Null
            $execution.Succeeded = $true
        }
        catch {
            $execution.Error = $_.Exception.Message
            if ($_.Exception.Data['PSModule.PreserveType']) {
                $_.Exception.Data['PSModule.InspectionIssues'] = @(
                    Get-PSModuleInspectionIssue -Context $Context
                )
                throw
            }
            $wrappedException = [System.InvalidOperationException]::new(
                "Plugin '$($plugin.Name)' in stage '$($plugin.Stage)' failed: $($_.Exception.Message)",
                $_.Exception
            )
            $wrappedException.Data['PSModule.InspectionIssues'] = @(
                Get-PSModuleInspectionIssue -Context $Context
            )
            throw $wrappedException
        }
        finally {
            $execution.Duration = [DateTimeOffset]::UtcNow - $startedAt
            $Context.PluginExecutions.Add($execution)
        }
    }

    return $Context
}
