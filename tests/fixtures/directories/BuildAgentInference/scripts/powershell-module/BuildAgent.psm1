function Invoke-DockerBuild {
    <#
    .SYNOPSIS
        Runs the Docker build type.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [ValidateSet('Debug', 'Release')]
        [string] $Configuration = 'Release',

        [string] $ImageTag = 'latest'
    )
    if ($PSCmdlet.ShouldProcess('Docker build', "Configuration=$Configuration ImageTag=$ImageTag")) {
        throw 'Reference fixture module. Not intended to run.'
    }
}

function Invoke-ForgeBuild {
    <#
    .SYNOPSIS
        Runs the Forge build type.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [ValidateSet('Debug', 'Release')]
        [string] $Configuration = 'Release',

        [string] $OutputDirectory = 'out'
    )
    if ($PSCmdlet.ShouldProcess('Forge build', "Configuration=$Configuration OutputDirectory=$OutputDirectory")) {
        throw 'Reference fixture module. Not intended to run.'
    }
}

function Invoke-BuildDispatch {
    <#
    .SYNOPSIS
        Dispatches to a build type by literal ValidateSet.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [ValidateSet('Docker', 'Forge')]
        [string] $BuildType
    )
    switch ($BuildType) {
        'Docker' { Invoke-DockerBuild @PSBoundParameters }
        'Forge' { Invoke-ForgeBuild @PSBoundParameters }
    }
}

Export-ModuleMember -Function Invoke-DockerBuild, Invoke-ForgeBuild, Invoke-BuildDispatch
