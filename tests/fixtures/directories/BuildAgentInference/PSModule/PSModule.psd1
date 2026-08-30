# Intentionally empty. This fixture proves the current gap: build evidence from
# .nuke/, src/, and scripts/powershell-module/ is inspected but does not yet
# materialize into inferred commands. See
# design/planning/build-agent-evidence-design.md.
#
# Commands is explicit rather than omitted: an empty PSD1 hashtable with no
# Commands key at all currently crashes Initialize-PSModuleDirectory under
# strict mode (Initialize-PSModuleDirectory.ps1 unconditionally reads
# $existingDefinition.Commands) - a latent, unrelated bug this fixture is not
# the place to fix or pin as expected behavior.
@{
    Commands = @()
}
