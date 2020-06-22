@{
    RootModule = 'xTestClassDsc.psm1'
    ModuleVersion = '1.0.0'
    GUID = '883aa273-27b8-4b9f-a96d-6e4056f987b2'
    Author = ''
    CompanyName = ''
    Copyright = ''
    Description = 'Example DSC Resource'
    PowerShellVersion = '5.1'
    RequiredAssemblies = @("System.ServiceProcess")
    FunctionsToExport = '*'
    CmdletsToExport = '*'
    VariablesToExport = '*'
    AliasesToExport = '*'
    DscResourcesToExport = 'xTestClassDsc'
    PrivateData = @{
        PSData = @{
        }
    }
}
