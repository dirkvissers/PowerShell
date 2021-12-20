If(((Get-Tpm).TpmPresent -eq $true)-and((Get-Tpm).TpmEnabled) -eq $true){Write-Host "TPM present and enabled."}
If(((Get-Tpm).TpmPresent -eq $true)-and((Get-Tpm).TpmEnabled) -eq $false){Write-Host "TPM present, but disabled."}
If(((Get-Tpm).TpmPresent -eq $true)-and((Get-Tpm).TpmEnabled) -eq $null){Write-Host "TPM present, but Enabled property missing."}
If(((Get-Tpm).TpmPresent -eq $false)-or((Get-Tpm).TpmPresent -eq $null)){Write-Host "TPM Missing."}

if (Test-Path $env:windir\Panther\setupact.log) {(Select-String 'Detected boot environment' -Path "$env:windir\Panther\setupact.log"  -AllMatches).line -replace '.*:\s+'} else {if (Test-Path HKLM:\System\CurrentControlSet\control\SecureBoot\State) {"Installed in UEFI mode."} else {"Installed in Legacy mode."}}

# Create new folder "C:\Temp"
If( (Test-Path C:\Temp) -eq $True){
$Path = Get-ChildItem C:\ -Hidden | Where-Object {$_.Name -eq "Temp"}
}

Else{
$Path = New-Item -Path "C:\" -Name "Temp" -ItemType "Directory"
}

If((Test-Path C:\temp\testmsinfo32.nfo) -eq $false){msinfo32 /nfo C:\temp\testmsinfo32.nfo}

[bool]$Run=$true
While($Run -eq $true){
if((Test-Path C:\temp\testmsinfo32.nfo) -eq $true ){
    sleep 450
    $Values = Get-Content C:\temp\testmsinfo32.nfo
    $Values | Select-String "BIOS-modus" -Context 0,1
    $Values | Select-String "Status beveiligd opstarten"
    $Values | Select-String "BIOS mode" -Context 0,1
    $Values | Select-String "Secure Boot State" -Context 0,1
    [bool]$Run=$false
    Remove-Item C:\temp\testmsinfo32.nfo -Force}
}