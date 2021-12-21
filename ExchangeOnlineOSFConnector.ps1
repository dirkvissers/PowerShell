<# Title: Create Inbound Connecter for Oxillion's Mail-Scanner (Hosted Spam-Filter)
   Note: This script gets all your connected customers from the Partner Portal and creates an InboundConnector for Exchange Online.
         It enables Enhanced Filtering for Connectors for the IP's from your 3rd Party Hosted Spam Filter.
         Be sure to change the $OSFArrayv4 to all possible IP's that your hosted Spam Filter might use.
         Refer to the knowledgebase of your product or contact support.

         Please use this as inspiration to create inbound connectors for Exchange Online or On-Premise, the cmdlets really look a like.
#>

[array]$OSFArrayv4 = "46.19.217.0/24","213.206.97.206","213.206.97.207","93.186.178.91","93.186.178.92","93.186.178.93"
#[array]$OSFArrayv6 = "2a00:d10:1141:3::16","2a00:d10:1141:3::14","fe80::250:56ff:fe01:848","2001:898:2000:1000::7","fe80::250:56ff:fe01:90e","fe80::250:56ff:fe8a:42f3","2a00:d10:1141:3::12","2a00:d10:1141:3::10","fe80::250:56ff:fe01:84a","2a00:d10:1141:3::18","fe80::250:56ff:fe01:1cb7"


If((Get-ExecutionPolicy) -ne "Bypass"){Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser -Force;write-host "Setting ExecutionPolicy for CurrentUser..."}
Else{Write-Host "ExecutionPolicy already Bypass for CurrentUser"}

Write-Host "Installing modules..." -ForegroundColor Yellow -BackgroundColor Black
Install-Module -Name ExchangeOnlineManagement -AllowClobber -Force -Scope AllUsers
Install-Module -Name PartnerCenter -AllowClobber -Force -Scope AllUsers

Write-Host "Importing modules..." -ForegroundColor Yellow -BackgroundColor Black
Import-Module -Name ExchangeOnlineManagement -Force
Import-Module -Name PartnerCenter -Force


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

Write-Host -NoNewline "Connecting to Exchange Online..." -ForegroundColor Yellow
Connect-ExchangeOnline -DelegatedOrganization $($ConnectTo.Domain)  | Out-Null;Write-Host " OK" -ForegroundColor Green

[string]$SetInbound = "no"
Write-Host "Create a new inbound connector for Online Spam Filter ? [yes][no] `n " -ForegroundColor Yellow
$SetInbound = Read-Host -Prompt " "

If($SetInbound -eq "yes"){
New-InboundConnector -Name "Online Spam Filter - Inbound Connector" -SenderIPAddresses $OSFArrayv4 -ConnectorType "Partner" -Enabled $False -RestrictDomainsToIPAddresses $false -RestrictDomainsToCertificate $false -CloudServicesMailEnabled $false -TreatMessagesAsInternal $false -ScanAndDropRecipients $false -EFSkipLastIP $false -EFSkipIPs $OSFArrayv4 -SenderDomains "smtp:*;1" | Out-Null
If((Get-InboundConnector "Online Spam Filter - Inbound Connector") -ne $false){Get-InboundConnector "Online Spam Filter - Inbound Connector" | Select *
Write-Host "Inbound Connector succesfully created using the following Best Practices:
https://docs.microsoft.com/en-us/exchange/mail-flow-best-practices/use-connectors-to-configure-mail-flow/enhanced-filtering-for-connectors
" -ForegroundColor Yellow
Write-Host "EFSkipIPs-list is activated for the following IP's (Office 365 should skip the checking of these IP's):" -ForegroundColor Magenta
Write-Host "46.19.217.0/24
213.206.97.206
213.206.97.207
93.186.178.91
93.186.178.92
93.186.178.93
" -ForegroundColor Green
Write-Host "List from:" -ForegroundColor Magenta
Write-Host "https://kb.oxilion.nl/support/solutions/articles/77000482982-anti-spam-gebruik-voor-beheerders-eigen-mail-servers" -ForegroundColor Green}
}