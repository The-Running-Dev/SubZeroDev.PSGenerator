@{
    Id = 'fixture.build-agent'
    ModuleName = 'BuildAgentFixture'
    ModuleVersion = '1.0.0'
    ContainerImage = 'ghcr.io/example/build-agent-fixture:latest'

    Commands = @(
        @{
            Id = 'fixture.command.invoke-build-agent'
            Name = 'Invoke-BuildAgent'
            Synopsis = 'Runs a target in the build-agent container.'
            Description = 'Mounts a repository and invokes a named NUKE target.'
            Examples = @(
                @{
                    Code = "Invoke-BuildAgent -Repository . -Target Test -WhatIf"
                    Description = 'Previews the Test target for the current repository.'
                }
            )
            Parameters = @(
                @{
                    Id = 'fixture.parameter.repository'
                    Name = 'Repository'
                    Type = 'DirectoryInfo'
                    Mandatory = $true
                    Description = 'Repository mounted at /workspace.'
                    Mappings = @(
                        @{
                            Type = 'Mount'
                            Target = '/workspace'
                            Access = 'ReadWrite'
                        }
                    )
                }
                @{
                    Id = 'fixture.parameter.target'
                    Name = 'Target'
                    Type = 'string'
                    Mandatory = $true
                    Description = 'NUKE target to execute.'
                    Completions = @(
                        @{ Type = 'Static'; Values = @('Compile', 'Test', 'Pack') }
                    )
                    Mappings = @(
                        @{ Type = 'Argument'; Name = '--target' }
                    )
                }
                @{
                    Id = 'fixture.parameter.configuration'
                    Name = 'Configuration'
                    Type = 'string'
                    Description = 'Build configuration.'
                    Validations = @(
                        @{ Type = 'ValidateSet'; Values = @('Debug', 'Release') }
                    )
                    Mappings = @(
                        @{ Type = 'Environment'; Name = 'CONFIGURATION' }
                    )
                }
            )
        }
    )
}
