<#
Dirk Vissers:
Use this script to get every tenant linked to you Reseller / Partner Portal and connect to MSOnline,
ExchangeOnlineManagement and AzureAD using properties coming from the complete Partners list.

This is used to connect to a single Tenant and might come in handy if you have a setting to push
to every tenant under your administration.

Please understand you are connecting to this tenant using your Partner credentials.
Office 365 Protection, Compliance and other features are not allowed for Partners to modify.
You will need explicit Global Admin credentials to modify settings here.
#>

If((Get-ExecutionPolicy) -ne "Bypass"){Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser -Force;write-host "Setting ExecutionPolicy for CurrentUser..."}
Else{Write-Host "ExecutionPolicy already Bypass for CurrentUser"}

Write-Host "Installing modules..." -ForegroundColor Yellow -BackgroundColor Black
If(((Get-Module -Name ExchangeOnlineManagement) -eq $null) -eq $true){
Install-Module -Name ExchangeOnlineManagement -AllowClobber -Force -Scope AllUsers}

If(((Get-Module -Name MSOnline) -eq $null) -eq $true){
Install-Module -Name MSOnline -AllowClobber -Force -Scope AllUsers}

If(((Get-Module -Name PartnerCenter) -eq $null) -eq $true){
Install-Module -Name PartnerCenter -AllowClobber -Force -Scope AllUsers}

If(((Get-Module -Name AzureAD) -eq $null) -eq $true){
Install-Module -Name AzureAD -AllowClobber -Force -Scope AllUsers}

Write-Host "Importing modules..." -ForegroundColor Yellow -BackgroundColor Black
Import-Module -Name ExchangeOnlineManagement -Force
Import-Module -Name PartnerCenter -Force
Import-Module -Name MSOnline -Force
Import-Module -Name AzureAD -Force

$ClipBoardEmail = Read-Host "`nEnter your email address: "
Set-Clipboard -Value $ClipBoardEmail
Write-Host "CLIPBOARD SET WITH : $ClipBoardEmail" -ForegroundColor Yellow -BackgroundColor Black

# Get all partner Tenant-ID's

Write-Host "`nConnecting to Microsoft Partner Center services...`n" -ForegroundColor Green -BackgroundColor Black
Connect-PartnerCenter | Out-Null;Write-Host " DONE" -ForegroundColor Green
$AllPartners = Get-PartnerCustomer | select Name, Domain, CustomerId, RelationshipToPartner
If($AllPartners.Count -eq 0){
Write-Host -NoNewline "`nNo Customer Tenants found!" -ForegroundColor Red -BackgroundColor Black;Write-Host "Press a key to exit..." -ForegroundColor Yellow -BackgroundColor Black;Read-Host;break
}

Clear-Host
$AllPartners.Name | sort
Write-Host -NoNewline "`nTo which customer do you wish to connect to?" -ForegroundColor Yellow;[string]$CustomerString = Read-Host -Prompt " ";
$ConnectTo = $AllPartners | Where-Object {$_.Name -match $CustomerString}
[string]$MaxNumber = 0
[int]$RowNumber = 0
[int]$MaxNumber = ($($ConnectTo).count) - 1
$StopScript=$false

While((($ConnectTo).Domain).Count -ne 1){
   
    If( ($ConnectTo).Count -eq 0){$StopScript=$True
    Write-Host "`nNo tenants found to connect to." -ForegroundColor Red -BackgroundColor Black;break
    }

    Elseif(($ConnectTo).Count -gt 1){Write-Host "More than 1 tenant found: " -ForegroundColor Red;$ConnectTo | Format-Table
    Write-Host -NoNewline "Select which row we need to connect to, starting from 0 to $($ConnectTo.count - 1): " -ForegroundColor Yellow;$RowNumber = Read-Host
    
        While((0..($MaxNumber) -notcontains $RowNumber)){
        Clear-Host;
        Write-Host "`nWrong input, input was $($RowNumber), try again" -ForegroundColor Red -BackgroundColor Black;$ConnectTo | Format-Table
        Write-Host -NoNewline "Select which row we need to connect to, starting from 0 to $($ConnectTo.count - 1): " -ForegroundColor Yellow;$RowNumber = Read-Host
        }

    $ConnectTo = $ConnectTo | Where-Object {$_.Domain -eq $($ConnectTo.Domain)[$($RowNumber)]};
    }

}

If($StopScript -eq $True){Write-Host "Press a key to exit..." -ForegroundColor Yellow -BackgroundColor Black;Read-Host;break}
If((($ConnectTo).Domain).Count -eq 1 ){Write-Host -NoNewline "Connecting to customer tenant: " -ForegroundColor Yellow;Write-Host $($ConnectTo).Domain -ForegroundColor Green}

Set-Clipboard -Value $ClipBoardEmail
Write-Host -NoNewline "Connecting to Microsoft Online services..." -ForegroundColor Yellow
Connect-MsolService  | Out-Null;Write-Host " OK" -ForegroundColor Green

Write-Host -NoNewline "Connecting to Exchange Online..." -ForegroundColor Yellow
Connect-ExchangeOnline -DelegatedOrganization $($ConnectTo.Domain)  | Out-Null;Write-Host " OK" -ForegroundColor Green

Write-Host -NoNewline "Connecting to AzureAD Tenant..." -ForegroundColor Yellow
Connect-AzureAD -TenantId $($ConnectTo.CustomerId)  | Out-Null;Write-Host " OK" -ForegroundColor Green

Write-Host -NoNewline "Your current PSSession has logged into: " -ForegroundColor Green;Write-Host "$(($ConnectTo).Domain)" -ForegroundColor Magenta
Write-Host -NoNewline "Be sure to disconnect any sessions when finished by using: " -ForegroundColor Green
Write-Host "
Get-PSSession | Disconnect-PSSession
Disconnect-ExchangeOnline
Disconnect-AzureAD
Disconnect-PartnerCenter`n" -ForegroundColor Magenta

Write-Host "For more information check out the following links:

Exchange Online:
https://aka.msc/exops-docs

Microsoft Online (MSOL):
https://docs.microsoft.com/nl-nl/powershell/module/msonline/?view=azureadps-1.0#msonline

AzureAD:
https://docs.microsoft.com/en-us/powershell/module/azuread/?view=azureadps-2.0#users

Microsoft PartnerCenter:
https://docs.microsoft.com/en-us/powershell/module/partnercenter/?view=partnercenterps-3.0
" -ForegroundColor Yellow

$ConnectTo | Format-List *

Write-Host -NoNewline "Press ENTER to exit script and continue the session..." -ForegroundColor Green;Read-Host;Break