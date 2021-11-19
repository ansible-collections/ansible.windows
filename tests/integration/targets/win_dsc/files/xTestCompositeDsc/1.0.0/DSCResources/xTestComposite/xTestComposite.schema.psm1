Configuration xTestComposite {
    param
    (
        [string]$TestValue = 'test'
    )

    Import-DSCResource -ModuleName 'PSDesiredStateConfiguration'

    Registry "first setting" {
        Key = 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon'
        ValueData = $TestValue
        ValueName = 'DoesntMatter'
        ValueType = 'String'
    }

    Registry "second setting" {
        Key = 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon'
        ValueData = $TestValue
        ValueName = 'AlsoDoesntMatter'
        ValueType = 'String'
    }
}
