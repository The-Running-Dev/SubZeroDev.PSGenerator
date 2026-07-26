# Minimal runnable example

This example exercises the complete local lifecycle: generate a module, build an
image containing it at `/PSModule`, install and import it, invoke its generated
command, read its help, and clean up.

Docker must be running and PowerShell 7 must be available. From the directory,
run:

```powershell
./examples/Minimal/Run-Example.ps1
```

The script returns a structured result from `Invoke-Example`, verifies generated
PowerShell help and the installed Markdown command reference, removes the imported
module and local image, and deletes its generated files. Pass `-KeepArtifacts` to
retain `examples/Minimal/artifacts` for inspection.

The hosted container test also invokes this example with argument, environment,
bind-mount, port, working-directory, named-volume, generic runtime-option, memory,
CPU, and secret mappings. Device and GPU mappings remain capability-gated because
standard runners do not expose that hardware.

## Run each step manually

```powershell
Import-Module ./src/SubZeroDev.PSGenerator.psd1 -Force

Build-PSModule `
    -Specification ./examples/Minimal/PSModule/PSModule.psd1 `
    -Output ./examples/Minimal/artifacts/PSModule

docker build `
    --tag subzerodev-psgenerator-minimal:local `
    ./examples/Minimal

Install-PSModule `
    subzerodev-psgenerator-minimal:local `
    -Destination ./examples/Minimal/artifacts/Installed/ExampleContainer

Import-Module `
    ./examples/Minimal/artifacts/Installed/ExampleContainer/ExampleContainer.psd1 `
    -Force

Invoke-Example `
    -Directory ./examples/Minimal `
    -Message 'hello-from-minimal'

Get-Help Invoke-Example -Full
Get-Content `
    ./examples/Minimal/artifacts/Installed/ExampleContainer/Documentation/Invoke-Example.md
```

Clean up the imported module, image, and generated files:

```powershell
Remove-Module ExampleContainer -Force
docker image rm --force subzerodev-psgenerator-minimal:local
Remove-Item ./examples/Minimal/artifacts -Recurse -Force
```
