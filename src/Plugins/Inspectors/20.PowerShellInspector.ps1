param ([Parameter(Mandatory)] [psobject] $Context)

$scriptsPath = Join-Path $Context.DirectoryPath 'scripts'
$items = @(
    if (Test-Path -LiteralPath $scriptsPath -PathType Container) {
        Get-ChildItem -LiteralPath $scriptsPath -Recurse -File | Where-Object {
            $_.Extension -in @('.ps1', '.psm1', '.psd1') -and
            (Test-PSModuleInspectionPath -Context $Context -Path $_.FullName)
        }
    }
)
[Array]::Sort($items, [Collections.Generic.Comparer[object]]::Create({ param($a, $b) [StringComparer]::Ordinal.Compare($a.FullName, $b.FullName) }))

$files = foreach ($item in $items) {
    $tokens = $null
    $errors = $null
    $source = Get-Content -LiteralPath $item.FullName -Raw -ErrorAction Stop
    $ast = [Management.Automation.Language.Parser]::ParseInput(
        $source,
        $item.FullName,
        [ref]$tokens,
        [ref]$errors
    )
    $relativePath = [IO.Path]::GetRelativePath($Context.DirectoryPath, $item.FullName).Replace('\', '/')
    $isCommandCandidate = $item.Extension -eq '.ps1'
    $suggestedCommandName = $null
    if ($isCommandCandidate) {
        $suggestedCommandName = ConvertTo-PSModuleCommandName -FileBaseName $item.BaseName
    }
    $parameters = @(
        if ($isCommandCandidate -and $ast.ParamBlock) {
            foreach ($parameter in $ast.ParamBlock.Parameters) {
                $type = if ($parameter.StaticType -eq [Management.Automation.SwitchParameter]) {
                    'switch'
                }
                elseif ($parameter.StaticType -and $parameter.StaticType -ne [object]) {
                    $parameter.StaticType.Name
                }
                else { 'string' }
                [ordered]@{
                    Name      = $parameter.Name.VariablePath.UserPath
                    Type      = $type
                    Mandatory = [bool]($parameter.Attributes |
                        Where-Object { $_.TypeName.Name -eq 'Parameter' } |
                        ForEach-Object {
                            $_.NamedArguments | Where-Object {
                                $_.ArgumentName -eq 'Mandatory' -and
                                ($_.ExpressionOmitted -or $_.Argument.SafeGetValue())
                            }
                        })
                }
            }
        }
    )
    [ordered]@{
        Path                 = $relativePath
        Type                 = $item.Extension.TrimStart('.').ToUpperInvariant()
        IsCommandCandidate   = $isCommandCandidate
        SuggestedCommandName = $suggestedCommandName
        Parameters           = $parameters
        Functions            = @($ast.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] }, $true) | ForEach-Object Name)
        Classes              = @($ast.FindAll({ param($node) $node -is [Management.Automation.Language.TypeDefinitionAst] -and $node.IsClass }, $true) | ForEach-Object Name)
        ParseErrors          = @($errors | ForEach-Object Message)
    }
}
$Context.Inspection['PowerShellFiles'] = @($files)
