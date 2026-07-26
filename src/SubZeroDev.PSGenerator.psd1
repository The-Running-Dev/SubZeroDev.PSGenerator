@{
    RootModule        = 'SubZeroDev.PSGenerator.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'a9ea0718-3a9b-4693-a647-b5472923f3f5'
    Author            = 'SubZeroDev'
    Description       = 'Generates PowerShell modules for containerized applications.'
    PowerShellVersion = '7.4'

    FunctionsToExport = @(
        'Build-PSModule'
        'Get-PSModuleModel'
        'Get-PSModuleInspection'
        'Get-PSModuleDiagnostic'
        'Get-PSModulePlugin'
        'Install-PSModule'
        'Initialize-PSModuleDirectory'
        'Initialize-PSModuleSpecification'
        'Test-PSModuleSpecification'
    )

    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData = @{
        PSData = @{
            Tags       = @('PowerShell', 'Docker', 'Containers', 'CodeGeneration')
            ProjectUri = 'https://github.com/The-Running-Dev/SubZeroDev.PSGenerator'
            LicenseUri = 'https://github.com/The-Running-Dev/SubZeroDev.PSGenerator/blob/main/LICENSE'
        }
    }
}
