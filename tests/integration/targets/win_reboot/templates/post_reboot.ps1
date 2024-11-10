if (Test-Path -LiteralPath '{{remote_tmp_dir}}\win_reboot_test') {
    New-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' `
        -Name PendingFileRenameOperations `
        -Value @("\??\{{remote_tmp_dir}}\win_reboot_test`0") `
        -PropertyType MultiString
    Restart-Computer -Force
    exit 1
}
