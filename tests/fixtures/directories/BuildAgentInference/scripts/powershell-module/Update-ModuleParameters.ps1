<#
.SYNOPSIS
    Regenerates parameters.json from the C# build parameter classes.
.DESCRIPTION
    Reference behavior only. Scans the *Params classes referenced by this
    repository's NUKE build project, extracts property name, type, and XML
    summary, strips the trailing "Params" suffix into a build configuration
    name, resolves recursive inheritance with cycle detection, and writes
    parameters.json. This fixture script is a test oracle for a future C#
    source inspector; PSGenerator discovery must never execute it.
.FUNCTIONALITY
    Maintenance
#>
[CmdletBinding()]
param ()

throw 'Reference fixture script. Not intended to run - discovery must not invoke it.'
