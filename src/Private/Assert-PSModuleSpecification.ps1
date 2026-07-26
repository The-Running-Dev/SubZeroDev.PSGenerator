function Assert-PSModuleSpecification {
    [CmdletBinding()]
param (
        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Specification
    )

    Assert-PSModuleIdentity -Specification $Specification
    Assert-PSModuleRuntime -Specification $Specification
    Assert-PSModuleCommands -Specification $Specification
    Assert-PSModuleParameters -Specification $Specification
    Assert-PSModuleObjectIdentities -Specification $Specification
    Assert-PSModuleParameterCompletions -Specification $Specification
    Assert-PSModuleParameterValidations -Specification $Specification
    Assert-PSModuleMappings -Specification $Specification
    Assert-PSModuleNamedMappings -Specification $Specification
    Assert-PSModuleMountMappings -Specification $Specification
    Assert-PSModuleRuntimeMappings -Specification $Specification
}
