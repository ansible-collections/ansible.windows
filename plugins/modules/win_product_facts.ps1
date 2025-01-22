#!powershell

# Copyright: (c) 2017, Dag Wieers (@dagwieers) <dag@wieers.com>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic

# This modules does not accept any options
$spec = @{
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

# First try to find the product key from ACPI
try {
    $product_key = (Get-CimInstance -Class SoftwareLicensingService).OA3xOriginalProductKey
}
catch {
    $product_key = $null
}

if (-not $product_key) {
    # Else try to get it from the registry instead
    try {
        $data = Get-ItemPropertyValue -LiteralPath "HKLM:\Software\Microsoft\Windows NT\CurrentVersion" -Name DigitalProductId
    }
    catch {
        $data = $null
    }

    # And for Windows 2008 R2
    if (-not $data) {
        try {
            $data = Get-ItemPropertyValue -LiteralPath "HKLM:\Software\Microsoft\Windows NT\CurrentVersion" -Name DigitalProductId4
        }
        catch {
            $data = $null
        }
    }

    if ($data) {
        $product_key = $null
        $isWin8 = [int]($data[66] / 6) -band 1
        $HF7 = 0xF7
        $data[66] = ($data[66] -band $HF7) -bOr (($isWin8 -band 2) * 4)
        $hexdata = $data[52..66]
        $chardata = "B", "C", "D", "F", "G", "H", "J", "K", "M", "P", "Q", "R", "T", "V", "W", "X", "Y", "2", "3", "4", "6", "7", "8", "9"

        # Decode base24 binary data
        for ($i = 24; $i -ge 0; $i--) {
            $k = 0
            for ($j = 14; $j -ge 0; $j--) {
                $k = $k * 256 -bxor $hexdata[$j]
                $hexdata[$j] = [math]::truncate($k / 24)
                $k = $k % 24
            }
            $product_key_output = $chardata[$k] + $product_key_output
            $last = $k
        }

        $product_key_tmp1 = $product_key_output.SubString(1, $last)
        $product_key_tmp2 = $product_key_output.SubString(1, $product_key_output.Length - 1)
        if ($last -eq 0) {
            $product_key_output = "N" + $product_key_tmp2
        }
        else {
            $product_key_output = $product_key_tmp2.Insert($product_key_tmp2.IndexOf($product_key_tmp1) + $product_key_tmp1.Length, "N")
        }
        $num = 0
        $product_key_split = @()
        for ($i = 0; $i -le 4; $i++) {
            $product_key_split += $product_key_output.SubString($num, 5)
            $num += 5
        }
        $product_key = $product_key_split -join "-"
    }
}

# Retrieve license information
$license_info = Get-CimInstance SoftwareLicensingProduct | Where-Object {
    $product_key -match $_.PartialProductKey -and $_.Name -match "Windows"
}
$winlicense_status = switch ($license_info.LicenseStatus) {
    0 { "Unlicensed" }
    1 { "Licensed" }
    2 { "OOBGrace" }
    3 { "OOTGrace" }
    4 { "NonGenuineGrace" }
    5 { "Notification" }
    6 { "ExtendedGrace" }
    default { $null }
}

$winlicense_edition = $license_info.Name
$winlicense_channel = $license_info.ProductKeyChannel

$module.Result.ansible_facts = @{
    ansible_os_product_id = (Get-CimInstance Win32_OperatingSystem).SerialNumber
    ansible_os_product_key = $product_key
    ansible_os_license_edition = $winlicense_edition
    ansible_os_license_channel = $winlicense_channel
    ansible_os_license_status = $winlicense_status
}

$module.ExitJson()
