@{
    Id = 'example.container-module'
    ModuleName = 'ExampleContainer'
    ModuleVersion = '0.1.0'
    ContainerImage = 'subzerodev-psgenerator-minimal:local'

    Commands = @(
        @{
            Id          = 'command.invoke-example'
            Name        = 'Invoke-Example'
            Synopsis    = 'Runs the example container.'
            Description = 'Runs the example container command.'
            Notes       = 'Docker must be available on PATH unless using -WhatIf.'

            Examples = @(
                @{
                    Code = "Invoke-Example -Directory . -Message 'hello'"
                    Description = 'Runs the example container for the current directory.'
                }
            )

            Parameters = @(
                @{
                    Id        = 'parameter.directory'
                    Name      = 'Directory'
                    Description = 'Directory mounted read-only at /workspace.'
                    Type      = 'DirectoryInfo'
                    Mandatory = $true

                    Mappings = @(
                        @{
                            Type   = 'Mount'
                            Target = '/workspace'
                            Access = 'ReadOnly'
                        }
                    )
                }
                @{
                    Name      = 'Message'
                    Description = 'Message passed to the example container.'
                    Type      = 'string'
                    Mandatory = $true

                    Validations = @(
                        @{ Type = 'ValidatePattern'; Pattern = '^.{1,100}$' }
                    )

                    Mappings = @(
                        @{
                            Type = 'Environment'
                            Name = 'EXAMPLE_MESSAGE'
                        }
                        @{
                            Type = 'Argument'
                            Name = '--message'
                        }
                    )
                }
                @{
                    Name = 'HostPort'
                    Description = 'Optional host port published to container port 8080.'
                    Type = 'int'
                    Mappings = @(
                        @{ Type = 'Port'; ContainerPort = 8080; Protocol = 'tcp' }
                    )
                }
                @{
                    Name = 'WorkingDirectory'
                    Description = 'Optional working directory inside the container.'
                    Type = 'string'
                    Mappings = @(
                        @{ Type = 'WorkingDirectory' }
                    )
                }
                @{
                    Name = 'CacheVolume'
                    Description = 'Optional Docker volume mounted read-write at /cache.'
                    Type = 'string'
                    Mappings = @(
                        @{ Type = 'Volume'; Target = '/cache'; Access = 'ReadWrite' }
                    )
                }
                @{
                    Name = 'Network'
                    Description = 'Optional Docker network name.'
                    Type = 'string'
                    Completions = @(
                        @{ Type = 'Static'; Values = @('bridge', 'host', 'none') }
                    )
                    Mappings = @(
                        @{ Type = 'RuntimeOption'; Name = '--network' }
                    )
                }
                @{
                    Name = 'Hostname'
                    Description = 'Optional hostname assigned through a generic Docker runtime option.'
                    Type = 'string'
                    Mappings = @(
                        @{ Type = 'RuntimeOption'; Name = '--hostname' }
                    )
                }
                @{
                    Name = 'Device'
                    Description = 'Optional host device exposed read-write inside the container.'
                    Type = 'FileInfo'
                    Mappings = @(
                        @{ Type = 'Device'; Permissions = 'rw' }
                    )
                }
                @{
                    Name = 'Gpu'
                    Description = 'Optional GPU selection such as all, 1, or device=0.'
                    Type = 'string'
                    Mappings = @(
                        @{ Type = 'Gpu' }
                    )
                }
                @{
                    Name = 'Memory'
                    Description = 'Optional container memory limit such as 512m.'
                    Type = 'string'
                    Mappings = @(
                        @{ Type = 'ResourceLimit'; Resource = 'Memory' }
                    )
                }
                @{
                    Name = 'Cpus'
                    Description = 'Optional container CPU limit.'
                    Type = 'double'
                    Mappings = @(
                        @{ Type = 'ResourceLimit'; Resource = 'Cpus' }
                    )
                }
                @{
                    Name = 'SecretFile'
                    Description = 'Optional host secret mounted read-only at /run/secrets/api-token.'
                    Type = 'FileInfo'
                    Mappings = @(
                        @{ Type = 'Secret'; Name = 'api-token' }
                    )
                }
            )
        }
    )
}
