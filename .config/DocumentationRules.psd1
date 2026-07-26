@{
    # Product and technology names whose casing must stay consistent across
    # authored documentation. Each Required spelling lists the incorrect
    # variants to reject. Matching is case-sensitive and whole-word, and runs
    # only over prose: fenced code, inline code, link targets, and bare URLs
    # are masked before these rules are applied, so `pwsh -File script.ps1`,
    # ```powershell fences, and github.com URLs are never flagged.
    Terminology = @(
        @{ Required = 'PowerShell'; Variants = @('Powershell', 'PowerShell7', 'Power Shell') }
        @{ Required = 'GitHub'; Variants = @('Github', 'GitHUB', 'Git Hub') }
        @{ Required = 'NuGet'; Variants = @('Nuget', 'NUGET') }
        @{ Required = 'Docusaurus'; Variants = @('DocuSaurus', 'docusaurus') }
        @{ Required = 'Dockerfile'; Variants = @('DockerFile', 'docker file', 'Docker file') }
        @{ Required = 'Docker Compose'; Variants = @('docker compose', 'Docker-Compose') }
        @{ Required = 'Pester'; Variants = @('pester', 'PESTER') }
        @{ Required = 'PSScriptAnalyzer'; Variants = @('PsScriptAnalyzer', 'PSScriptanalyzer') }
        @{ Required = 'macOS'; Variants = @('MacOS', 'Mac OS', 'macos', 'OSX') }
        @{ Required = 'JSON Schema'; Variants = @('Json Schema', 'json schema') }
        @{ Required = 'OpenAPI'; Variants = @('OpenApi', 'Open API', 'openapi') }
        @{ Required = 'NUKE'; Variants = @('Nuke build', 'nuke') }

        # Guards against the v1 rename regressing. The product is PSGenerator
        # and its commands are *-PSModule; the old names must not reappear.
        @{ Required = 'PSGenerator'; Variants = @('ContainerPSGenerator') }
        @{ Required = 'PSModule'; Variants = @('ContainerModule') }
    )

    # Path segments never scanned. Fixture directories are test input rather
    # than documentation, and generated or vendored trees are not authored here.
    ExcludedSegments = @(
        '.git'
        'artifacts'
        'node_modules'
    )

    # Files generated from another file, checked for drift rather than scanned.
    # Each entry names the generated file, its source, and the script that
    # produces the expected content, all relative to the repository root. The
    # generator and this check share that script so they cannot disagree.
    GeneratedFiles = @(
        @{
            Path = 'docs/docs/index.md'
            Source = 'README.md'
            Generator = 'build/ConvertTo-DocumentationHomepage.ps1'
            SourceParameter = 'ReadmePath'
        }
    )

    # Individual files excluded from scanning, relative to the repository root.
    # docs/docs/index.md is generated from README.md by docs.ps1 before every
    # image build, so it is validated at its source instead.
    ExcludedFiles = @(
        'docs/docs/index.md'
        'tests/fixtures'
    )
}
