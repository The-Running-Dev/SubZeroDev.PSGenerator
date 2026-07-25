@{
    RootModule        = 'SubZeroDev.ContainerPSGenerator.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = 'a9ea0718-3a9b-4693-a647-b5472923f3f5'
    Author            = 'SubZeroDev'
    Description       = 'Generates repository-specific PowerShell modules for containerized applications.'
    PowerShellVersion = '7.4'

    FunctionsToExport = @(
        'Build-ContainerModule'
        'Get-ContainerModuleModel'
        'Get-ContainerModuleInspection'
        'Get-ContainerModuleDiagnostic'
        'Get-ContainerModulePlugin'
        'Install-ContainerModule'
        'Initialize-ContainerModuleSpecification'
        'Test-ContainerModuleSpecification'
    )

    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData = @{
        PSData = @{
            Tags       = @('PowerShell', 'Docker', 'Containers', 'CodeGeneration')
            ProjectUri = 'https://github.com/The-Running-Dev/SubZeroDev.ContainerPSGenerator'
            LicenseUri = 'https://github.com/The-Running-Dev/SubZeroDev.ContainerPSGenerator/blob/main/LICENSE'
        }
    }
}
