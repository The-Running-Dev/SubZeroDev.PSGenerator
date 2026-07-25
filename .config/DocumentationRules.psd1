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
    )

    # Path segments never scanned. Fixture repositories are test input rather
    # than documentation, and generated or vendored trees are not authored here.
    ExcludedSegments = @(
        '.git'
        'artifacts'
        'node_modules'
        'versioned_docs'
    )

    # Individual files excluded from scanning, relative to the repository root.
    # docs/docs/index.md is generated from README.md by docs.ps1 before every
    # image build, so it is validated at its source instead.
    ExcludedFiles = @(
        'docs/docs/index.md'
        'tests/fixtures'
    )
}
