***WIN LINEINFILE Expectations***

This folder contains expected files as the tests in this playbook executes on the
files in 'files'. 

To get the checksum as would win_stat in the tests, go to this folder in powershell and
execute

```powershell
Get-ChildItem | ForEach-Object {
    $fp = [System.IO.File]::Open("$pwd/$($_.Name)", [System.IO.Filemode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    Write-Output $_.Name
    try {
        [System.BitConverter]::ToString($sp.ComputeHash($fp)).Replace("-", "").ToLower()
    } finally {
        $fp.Dispose()
    }
    Write-Output ""
}
```

There is one exception right now: 30_linebreaks_checksum_bad.txt which requires mixed line endings that 
git cannot handle without turning the file binary. The file should read

```
c:\return\newCRLF
c:CR
eturnLF
ew
```
where CR and LF denote carriage return (\r) and line feed (\n) respectively, to get the correct checksum.

Also, the .gitattributes files is important as it assures that the EOL characters
for the files are correct, regardless of environment. The files may be checked out on
linux but the resulting files will be created using windows EOL, and the comparison must
match.