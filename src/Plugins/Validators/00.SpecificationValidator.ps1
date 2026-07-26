param (
    [Parameter(Mandatory)]
    [psobject] $Context
)

Invoke-PSModuleSpecificationValidation `
    -Specification $Context.Specification `
    -SpecificationPath $Context.SpecificationPath
