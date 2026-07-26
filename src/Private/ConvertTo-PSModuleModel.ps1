function ConvertTo-PSModuleModel {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Specification
    )

    $commands = @(
        if ($Specification.Contains('Commands')) {
            foreach ($command in $Specification['Commands']) {
                $parameters = @(
                    if ($command.Contains('Parameters')) {
                        foreach ($parameter in $command['Parameters']) {
                            $completions = @(
                                if ($parameter.Contains('Completions')) {
                                    foreach ($completion in $parameter['Completions']) {
                                        [pscustomobject] @{
                                            PSTypeName = 'SubZeroDev.PSGenerator.Model.Completion'
                                            Type       = $completion['Type']
                                            Values     = @($completion['Values'])
                                            Definition = $completion
                                        }
                                    }
                                }
                            )
                            $validations = @(
                                if ($parameter.Contains('Validations')) {
                                    foreach ($validation in $parameter['Validations']) {
                                        [pscustomobject] @{
                                            PSTypeName = 'SubZeroDev.PSGenerator.Model.Validation'
                                            Type       = $validation['Type']
                                            Definition = $validation
                                        }
                                    }
                                }
                            )
                            $mappings = @(
                                if ($parameter.Contains('Mappings')) {
                                    foreach ($mapping in $parameter['Mappings']) {
                                        [pscustomobject] @{
                                            PSTypeName = 'SubZeroDev.PSGenerator.Model.Mapping'
                                            Type       = $mapping['Type']
                                            Definition = $mapping
                                        }
                                    }
                                }
                            )

                            [pscustomobject] @{
                                PSTypeName = 'SubZeroDev.PSGenerator.Model.Parameter'
                                Id         = $parameter['Id']
                                Name       = $parameter['Name']
                                Description = $parameter['Description']
                                Type       = if ($parameter['Type'] -in @(
                                    'SwitchParameter',
                                    'System.Management.Automation.SwitchParameter'
                                )) { 'switch' } else { $parameter['Type'] }
                                Mandatory  = if ($parameter.Contains('Mandatory')) { $parameter['Mandatory'] } else { $false }
                                Completions = $completions
                                Validations = $validations
                                Mappings   = $mappings
                                Definition = $parameter
                            }
                        }
                    }
                )

                [pscustomobject] @{
                    PSTypeName  = 'SubZeroDev.PSGenerator.Model.Command'
                    Id          = $command['Id']
                    Name        = $command['Name']
                    Synopsis    = $command['Synopsis']
                    Description = $command['Description']
                    Notes       = $command['Notes']
                    Examples    = @(
                        if ($command.Contains('Examples')) {
                            foreach ($example in $command['Examples']) {
                                [pscustomobject] @{
                                    PSTypeName  = 'SubZeroDev.PSGenerator.Model.Example'
                                    Code        = $example['Code']
                                    Description = $example['Description']
                                    Definition  = $example
                                }
                            }
                        }
                    )
                    Parameters  = $parameters
                    Definition  = $command
                }
            }
        }
    )

    [pscustomobject] @{
        PSTypeName    = 'SubZeroDev.PSGenerator.Model'
        Id            = $Specification['Id']
        ModuleName    = if ($Specification.Contains('ModuleName')) { $Specification['ModuleName'] } else { 'PSModule' }
        ModuleVersion = if ($Specification.Contains('ModuleVersion')) { $Specification['ModuleVersion'] } else { '0.1.0' }
        ContainerImage = if ($Specification.Contains('ContainerImage')) { $Specification['ContainerImage'] } else { if ($Specification.Contains('ModuleName')) { $Specification['ModuleName'] } else { 'PSModule' } }
        Commands      = $commands
        Definition    = $Specification
    }
}
