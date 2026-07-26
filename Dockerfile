# PSGenerator as a ready-to-use PowerShell environment: the module installed on
# the all-users module path, with pwsh as the entry point.
#
# Alpine keeps the image small. PowerShell is installed from Microsoft's musl
# tarball rather than an official image tag so the version is pinned exactly and
# verified by checksum; the module manifest requires PowerShell 7.4, and this
# guarantees that baseline instead of tracking a floating tag.
FROM alpine:3.21

ARG POWERSHELL_VERSION=7.4.6
ARG POWERSHELL_SHA256=d5f63653c1cc73a8903d0181bd8616952b4b0e435758d98ee19a617c203c48a8

# The apk list is PowerShell's own native runtime dependencies on musl. curl is
# needed only to fetch the tarball and is removed afterwards.
RUN apk add --no-cache \
        ca-certificates \
        icu-libs \
        krb5-libs \
        less \
        libgcc \
        libintl \
        libssl3 \
        libstdc++ \
        ncurses-terminfo-base \
        tzdata \
        userspace-rcu \
        zlib \
    && apk add --no-cache --virtual .powershell-build curl \
    && curl -fSL "https://github.com/PowerShell/PowerShell/releases/download/v${POWERSHELL_VERSION}/powershell-${POWERSHELL_VERSION}-linux-musl-x64.tar.gz" \
        -o /tmp/powershell.tar.gz \
    && echo "${POWERSHELL_SHA256}  /tmp/powershell.tar.gz" | sha256sum -c - \
    && mkdir -p /opt/microsoft/powershell/7 \
    && tar zxf /tmp/powershell.tar.gz -C /opt/microsoft/powershell/7 \
    && chmod +x /opt/microsoft/powershell/7/pwsh \
    && ln -s /opt/microsoft/powershell/7/pwsh /usr/bin/pwsh \
    && rm -f /tmp/powershell.tar.gz \
    && apk del .powershell-build

# Telemetry is opt-out only through this variable, and an image should not phone
# home on the user's behalf.
ENV POWERSHELL_TELEMETRY_OPTOUT=1
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1

# Run the remaining build steps in pwsh so a failure inside them stops the build.
SHELL ["pwsh", "-NoLogo", "-NoProfile", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

# Install onto the all-users module path so the module resolves by name for any
# user, and command discovery imports it automatically. Copying src/ mirrors what
# build/New-GeneratorModulePackage.ps1 stages.
COPY src/ /usr/local/share/powershell/Modules/SubZeroDev.PSGenerator/

# Fail the build rather than ship an image whose module does not load. This also
# proves the manifest, loader, and every public command survived the copy.
RUN $manifest = Test-ModuleManifest /usr/local/share/powershell/Modules/SubZeroDev.PSGenerator/SubZeroDev.PSGenerator.psd1; \
    Import-Module SubZeroDev.PSGenerator -ErrorAction Stop; \
    $expected = $manifest.ExportedFunctions.Keys | Sort-Object; \
    $actual = (Get-Command -Module SubZeroDev.PSGenerator).Name | Sort-Object; \
    if (Compare-Object $expected $actual) { throw 'Exported commands do not match the manifest.' }; \
    Write-Host "Installed SubZeroDev.PSGenerator $($manifest.Version) with $($actual.Count) commands."

WORKDIR /workspace

LABEL org.opencontainers.image.source="https://github.com/The-Running-Dev/SubZeroDev.PSGenerator"
LABEL org.opencontainers.image.description="PSGenerator: generate PowerShell modules for containerized applications"
LABEL org.opencontainers.image.licenses="MIT"

# pwsh is the default shell. Mount the directory to inspect at /workspace.
ENTRYPOINT ["pwsh"]
