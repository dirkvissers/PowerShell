<#
Dirk Vissers:
We need a complete list of all current AzureADUser-ObjectID's and put it inside an array.
Get-LocalGroupMember is a very nice cmdlet, but doesn't work consistently across different Windows installations.
So I've build a secondary failsave to get the same results.

I have found a nice function by Oliver Kieselbach to convert AzureADUser-ObjectID's to local Windows SID's.

In the secondary options we scan the registry for any of these generated Windows SID's to be present:
Microsoft.PowerShell.Core\Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\

Example to generate an AzureAD export: 

Connect-AzureAD
Write-Host "Creating C:\Scripts\AzureADExport directory"
New-Item -Path C:\Scripts\AzureADExport -Type directory -Force | Out-Null
Write-Host "Generating CSV of all ObjectID's"
Get-AzureADUser -All:$true | Select ObjectID |Export-Csv -Path "C:\Scripts\AzureADExport\UserExport.csv" -Delimiter ";" -NoTypeInformation
Write-Host "Importing CSV into variable"
$CSVImport = Import-Csv -Path "C:\Scripts\AzureADExport\UserExport.csv" -Delimiter ";"
Write-Host 'Joining every ObjectID with "," '
[string]$ObjectIDs = '"' + (($CSVImport.ObjectId) -join '","') + '"'
Write-Host "Outputting the Array(ed) ObjectID's to a textfile so that they are copyable"
$ObjectIDs > C:\Scripts\AzureADExport\objectids.txt # use this to paste for variable $ArrayObjectIDs

#>

[array]$ArrayObjectIDs = "All","of","your","Azure","AD","Object ID's","in","one","long","array"
[bool]$CmdletWorking = $true


function Convert-AzureAdSidToObjectId {
<#
.SYNOPSIS
Convert a Azure AD SID to Object ID
 
.DESCRIPTION
Converts an Azure AD SID to Object ID.
Author: Oliver Kieselbach (oliverkieselbach.com)
The script is provided "AS IS" with no warranties.
 
.PARAMETER ObjectID
The SID to convert
#>

    param([String] $Sid)

    $text = $sid.Replace('S-1-12-1-', '')
    $array = [UInt32[]]$text.Split('-')

    $bytes = New-Object 'Byte[]' 16
    [Buffer]::BlockCopy($array, 0, $bytes, 0, 16)
    [Guid]$guid = $bytes

    return $guid
}


try
{
    Get-LocalGroupMember Administrators -ErrorAction stop
}

catch
{
    Write-Host "Get-LocalGroupMember cmdlet not usable. Results might be inconsistent." -ForegroundColor red
    $CMDletWorking = $false
}


if($CmdletWorking -eq $true){
Get-LocalGroupMember Administrators | Where-Object {$_.name -match "AzureAD"} | ForEach-Object{
Write-Host "Removing $($_.Name) from local Administrators."
$_ | Remove-LocalGroupMember -Group Administrators
}

}

Else{
# Generate a table with usernames and SID's starting with S-1-12 ##### GENERAL USAGE
$CurrentHash = @{}
[array]$DontWantThese = @("systemprofile", "LocalService", "NetworkService")
[array]$AllUserNames = @()
Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList" | ForEach {
    $UserSID = $null
    $UserSID = ($_.Name).Split("\\")
    $UserSID = $UserSID[($UserSID.count - 1)]
    if ($UserSID -match "S-1-12") {
        # This path could contain old profiles that are no longer active
        $FunctionPath = "Microsoft.PowerShell.Core\Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\" + $UserSID
        $UserName = $null
        $UserName = (Get-ItemProperty $FunctionPath | Select-Object -ExpandProperty ProfileImagePath).Split("\\")
        $UserName = $UserName[($UserName.count - 1)]

        If ($UserName -notin $DontWantThese) {
            $CurrentHash.Add($UserName, $UserSID)
        }


    }
}

$CurrentHash.Keys | Foreach-Object{
$UserSIDRemove = $null
$SIDtoCalc = $CurrentHash.$_
$SIDtoCompare = Convert-AzureAdSidToObjectId -Sid $SIDtoCalc

Write-Host "Checking account $($_)"

if($SIDtoCompare -in $ArrayObjectIDs){
        $UserSIDRemove = $SIDtoCalc
        Try{Write-Host "Removing $($_) from Local Administrators group." -ForegroundColor Green
        Remove-LocalGroupMember -Group Administrators -Member $UserSIDRemove -ErrorAction stop}
        Catch{Write-Host  $($_)}
}
}


}
sleep 10
net localgroup administrators