# Download the MicrosoftTeams module version 2.5.2 and place in folder "C:\Users\UserName\Documents\WindowsPowerShell\Modules"
#Install-Module MicrosoftTeams 
Import-Module MicrosoftTeams
Connect-MicrosoftTeams

Get-Team | Sort-Object DisplayName |select * | ForEach-Object{
$DisplayName = $_.DisplayName
$GroupID = $_.GroupId
$Channels = $null
$ChannelUsers = $null
$ChannelName = $null


$CurrentTeamUser = Get-TeamUser -GroupId $GroupID | Where-Object {$_.Name -match "DisplayNameOfUserToScanFor"} | Select *
If(($CurrentTeamUser).Name.count -gt 0){
Write-Host "`nRole $($CurrentTeamUser.Role) on team '$($DisplayName)'" -ForegroundColor Green
$Channels = Get-TeamChannel -GroupId $GroupID
$Channels | Foreach-Object {
    $ChannelName = $_.DisplayName
    Write-Host "Checking '$($DisplayName)/$($ChannelName)'" -ForegroundColor Cyan
    $ChannelUsers = Get-TeamChannelUser -GroupId $GroupID -DisplayName $ChannelName | Where-Object {$_.Name -match "DisplayNameOfUserToScanFor"}
    If($Channelusers.Name.Count -gt 0){Write-Host "Role $($ChannelUsers.Role) within '$($DisplayName)/$($ChannelName)'" -ForegroundColor Yellow}
}



}
}

Disconnect-MicrosoftTeams