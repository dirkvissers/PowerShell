<#
Product name          : Synology Active Backup for Microsoft 365 AppGenerator
Version information   : 2.0
Update time           : 2021/30/9
Author                : Version 2 iteration by Dirk Vissers
#>

[CmdletBinding()]
param()

Function Prerequisite() {
    # Check PS and Windows versions
    if ([System.Environment]::OSVersion.Version.Major -lt 10) {
        Write-Host "This PowerShell script file can only run on PowerShell in Windows 10 and Windows Server 2016 or later. Please upgrade your Windows version." -ForegroundColor Red -BackgroundColor white
        Exit
    }

    # Set SecurityProtocol to be compatible with W2016 server
    [Net.ServicePointManager]::SecurityProtocol = 'Ssl3, Tls, Tls11, Tls12'

    if ((Get-Module -ListAvailable -Name "AzureAD") -eq $null) {
        Install-Module "AzureAD" -Scope CurrentUser
    }
    Import-Module AzureAD
}

<#
 This script creates the Azure AD applications needed for this sample and updates the configuration files
 for the visual Studio projects from the data in the Azure AD applications.

 Before running this script you need to install the AzureAD cmdlets as an administrator. 
 For this:
 1) Run Powershell as an administrator
 2) in the PowerShell window, type: Install-Module AzureAD
#>

# Adds the requiredAccesses (expressed as a pipe separated string) to the requiredAccess structure
# The exposed permissions are in the $exposedPermissions collection, and the type of permission (Scope | Role) is 
# described in $permissionType
Function AddResourcePermission($requiredAccess, `
        $exposedPermissions, [string]$requiredAccesses, [string]$permissionType) {
    foreach ($permission in $requiredAccesses.Trim().Split("|")) {
        foreach ($exposedPermission in $exposedPermissions) {
            if ($exposedPermission.Value -eq $permission) {
                $resourceAccess = New-Object Microsoft.Open.AzureAD.Model.ResourceAccess
                $resourceAccess.Type = $permissionType # Scope = Delegated permissions | Role = Application permissions
                $resourceAccess.Id = $exposedPermission.Id # Read directory data
                $requiredAccess.ResourceAccess.Add($resourceAccess)
            }
        }
    }
}

#
# Exemple: GetRequiredPermissions "Microsoft Graph"  "Graph.Read|User.Read"
# See also: http://stackoverflow.com/questions/42164581/how-to-configure-a-new-azure-ad-application-through-powershell
Function GetRequiredPermissions([string] $applicationDisplayName, [string] $requiredDelegatedPermissions, [string]$requiredApplicationPermissions, $servicePrincipal) {
    # If we are passed the service principal we use it directly, otherwise we find it from the display name (which might not be unique)
    if ($servicePrincipal) {
        $sp = $servicePrincipal
    }
    else {
        $sp = Get-AzureADServicePrincipal -Filter "DisplayName eq '$applicationDisplayName'"
    }
    $appid = $sp.AppId
    $requiredAccess = New-Object Microsoft.Open.AzureAD.Model.RequiredResourceAccess
    $requiredAccess.ResourceAppId = $appid 
    $requiredAccess.ResourceAccess = New-Object System.Collections.Generic.List[Microsoft.Open.AzureAD.Model.ResourceAccess]

    # $sp.Oauth2Permissions | Select Id,AdminConsentDisplayName,Value: To see the list of all the Delegated permissions for the application:
    if ($requiredDelegatedPermissions) {
        AddResourcePermission $requiredAccess -exposedPermissions $sp.Oauth2Permissions -requiredAccesses $requiredDelegatedPermissions -permissionType "Scope"
    }
    
    # $sp.AppRoles | Select Id,AdminConsentDisplayName,Value: To see the list of all the Application permissions for the application
    if ($requiredApplicationPermissions) {
        AddResourcePermission $requiredAccess -exposedPermissions $sp.AppRoles -requiredAccesses $requiredApplicationPermissions -permissionType "Role"
    }
    return $requiredAccess
}

Function GetUnusedFileName([string] $desiredName, [string] $desiredExtension) {
    $location = Get-Location
    $path = "$($location)\$($desiredName).$($desiredExtension)"
    $count = 1

    while(Test-Path $path -PathType Leaf)
    {
        $path = "$($location)\$($desiredName) ($($count)).$($desiredExtension)"
        $count += 1
    }
    return $path
}

Function Get-RandomCharacters($length, $characters) { 
    $random = 1..$length | ForEach-Object { Get-Random -Maximum $characters.length } 
    $private:ofs="" 
    return [String]$characters[$random]
}

Function ConfigureApplications {

    if ($securePasswd.Length -eq 0) {
        Write-Host "[ERROR] Please enter PassWord." -ForegroundColor Red -BackgroundColor white
        Exit
    }

    # Get credential
    $creds = Connect-AzureAD
    if (!$creds) {
        Write-Host "[ERROR] Fail to get creds." -ForegroundColor Red -BackgroundColor white
        Exit
    }
    $tenantId = $creds.Tenant.Id
    $tenantDomain = $creds.TenantDomain

    # Prepare app name
    $appName = "Microsoft 365 Backup"

    # Get the user running the script
    $user = Get-AzureADUser -ObjectId $creds.Account.Id

    # Create the client AAD application
    Write-Host "[INFO] Creating the client application ($appName)"
    $clientAadApplication = New-AzureADApplication -DisplayName $appName

    # Generate a certificate
    $certificate = New-SelfSignedCertificate -Subject CN=$appName `
        -CertStoreLocation "Cert:\CurrentUser\My" `
        -KeyExportPolicy Exportable `
        -NotAfter (Get-Date).AddYears(100) `
        -KeySpec Signature
    $certBase64Value = [System.Convert]::ToBase64String($certificate.GetRawCertData())
    $certBase64Thumbprint = [System.Convert]::ToBase64String($certificate.GetCertHash())
    $pfxLocation = Get-Location

    #export pfx
    $pfxOut = GetUnusedFileName -desiredName "Certificate" -desiredExtension "pfx"
    Export-PfxCertificate -Cert $certificate -FilePath $pfxOut -Password $securePasswd > $null

    # Add a Azure Key Credentials from the certificate for the daemon application
    $clientKeyCredentials = New-AzureADApplicationKeyCredential -ObjectId $clientAadApplication.ObjectId `
        -CustomKeyIdentifier $certBase64Thumbprint `
        -Type AsymmetricX509Cert `
        -Usage Verify `
        -Value $certBase64Value `
        -StartDate $certificate.NotBefore `
        -EndDate $certificate.NotAfter

    $owner = Get-AzureADApplicationOwner -ObjectId $clientAadApplication.ObjectId
    if ($owner -eq $null) {
        Add-AzureADApplicationOwner -ObjectId $clientAadApplication.ObjectId -RefObjectId $user.ObjectId
        Write-Host "[INFO] '$($user.UserPrincipalName)' added as an application owner to app '$($appName)'"
    }

    Write-Host "[INFO] Done creating the client application ($appName)"
    # URL of the AAD application in the Azure portal
    $clientPortalUrl = "https://portal.azure.com/#blade/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/CallAnAPI/appId/" + $clientAadApplication.AppId + "/objectId/" + $clientAadApplication.ObjectId + "/isMSAApp/"

    $requiredResourcesAccess = New-Object System.Collections.Generic.List[Microsoft.Open.AzureAD.Model.RequiredResourceAccess]

    # Add Required Resources Access
    Write-Host "[INFO] Getting API permissions for Microsoft Graph, Microsoft 365 Exchange Online, Microsoft 365 SharePoint Online"
    $requiredPermissions = GetRequiredPermissions -applicationDisplayName "Microsoft Graph" `
        -requiredApplicationPermissions "Mail.ReadWrite|User.ReadWrite.All|Group.ReadWrite.All|Directory.ReadWrite.All|Contacts.ReadWrite|Files.ReadWrite.All|Calendars.ReadWrite|Sites.FullControl.All";
    $requiredResourcesAccess.Add($requiredPermissions)

    $requiredPermissions = GetRequiredPermissions -applicationDisplayName "Office 365 Exchange Online" `
        -requiredApplicationPermissions "full_access_as_app";
    $requiredResourcesAccess.Add($requiredPermissions)

    $requiredPermissions = GetRequiredPermissions -applicationDisplayName "Office 365 SharePoint Online" `
        -requiredApplicationPermissions "Sites.FullControl.All";
    $requiredResourcesAccess.Add($requiredPermissions)

    Write-Host "[INFO] Granting permissions..."
    Set-AzureADApplication -ObjectId $clientAadApplication.ObjectId -RequiredResourceAccess $requiredResourcesAccess

    $txtFile = $pfxLocation.Path + "\Microsoft365Backup.txt"

    $compress = @{
    Path = $txtFile, $pfxOut
    CompressionLevel = "Fastest"
    DestinationPath = ($pfxLocation.Path + "\AppCert-Data-Archive.zip")
    }
    
    Write-Host "==================================================================================="
    Write-Host "|                                                                                 |"
    Write-Host "|   Congratulations! Your Azure AD application has been successfully generated.   |"
    Write-Host "|                                                                                 |"
    Write-Host "==================================================================================="
    Write-Host "Tenant Domain:"
    Write-Host "$($tenantDomain)" -ForegroundColor Green
    Write-Host "Tenant ID:"
    Write-Host "$($tenantId)" -ForegroundColor Green
    Write-Host "Application ID:"
    Write-Host "$($clientAadApplication.AppId)" -ForegroundColor Green
    Write-Host "Certificate file:"
    Write-Host "$($pfxOut)" -ForegroundColor Green
    Write-Host "Certificate password:"
    Write-Host "$($securePassPlain)" -ForegroundColor Green
    Write-Host ""
    Write-Host "Make sure to upload " -NoNewline -ForegroundColor Yellow
    Write-Host $($compress.DestinationPath) -ForegroundColor Red -NoNewline
    Write-Host " to LastPass!" -ForegroundColor Yellow
    Write-Host ""
    Write-Host ""
    Write-Host "Copy the URL displayed below and open it in your browser:"
    Write-Host "$clientPortalUrl" -ForegroundColor Yellow
    Write-Host ""
    
    $Value = "
    Tenant Domain:
    $($tenantDomain)
    Tenant ID:
    $($tenantId)
    Application ID:
    $($clientAadApplication.AppId)
    Certificate file:
    $($pfxOut)
    Certificate password:
    $($securePassPlain)

    URL:
    $($clientPortalUrl)
    "

    Set-Content -Path $txtFile -Value $Value

    Compress-Archive @compress

}

# Pre-requisites
Prerequisite

$securePassPlain = Get-RandomCharacters -length 32 -characters "abcdefghiklmnoprstuvwxyzABCDEFGHKLMNOPRSTUVWXYZ1234567890!§$%&/()=?}][{@#*+"
$securePasswd = $securePassPlain|ConvertTo-SecureString -Force -AsPlainText
ConfigureApplications -passWord $securePasswd

# SIG # Begin signature block
# MIIf5AYJKoZIhvcNAQcCoIIf1TCCH9ECAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAE7lx5Ankxp6KB
# jBCQ1IUdI0AeicyVy4GuiaEfkJgZgaCCDUQwggaAMIIFaKADAgECAhAMAVGmQ5J6
# zRldtiGe54EjMA0GCSqGSIb3DQEBCwUAMGwxCzAJBgNVBAYTAlVTMRUwEwYDVQQK
# EwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xKzApBgNV
# BAMTIkRpZ2lDZXJ0IEVWIENvZGUgU2lnbmluZyBDQSAoU0hBMikwHhcNMTkwNzEy
# MDAwMDAwWhcNMjIwNzExMTIwMDAwWjCBnjETMBEGCysGAQQBgjc8AgEDEwJUVzEd
# MBsGA1UEDwwUUHJpdmF0ZSBPcmdhbml6YXRpb24xETAPBgNVBAUTCDcwNTM4NDMz
# MQswCQYDVQQGEwJUVzEYMBYGA1UEBxMPTmV3IFRhaXBlaSBDaXR5MRYwFAYDVQQK
# Ew1TeW5vbG9neSBJbmMuMRYwFAYDVQQDEw1TeW5vbG9neSBJbmMuMIICIjANBgkq
# hkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAw/MneMq4FG2vrRzaEasws7cc/0HTt9dK
# FD/TBbxiHTmXgUKRGW5uE6OzlS4VYF4RFenLInFiaMYy4tFzeUZKs0x6f3LmYFLP
# 9itZ/vTfKyqSoaPQRXr4ByP1IhSEGgU4OjwqyK9c0kRt4N3HmOCixSfM2Cu0A6ec
# +Jq+mfLKYqPhUzCNXStjActjAE79Nt/F3aSplFHtr+LfnHGu8mCXwgS03ZNQ21XX
# 6FsrsmAR525KH0u7qPcRZLW61ZaEf9osuhJ1YdJZGyc62yuU9TmyS3izkxfet0mx
# kk02EUqlt2PgGrRDH3GcSzofccVwSk99NTwRYRAlOGNM+FjL5IyhDsn1eXBQLbPO
# BxUtEVvQIMY3ePsQZYgVkatSLf99E1qADbQs+nY0dGn/4UVwKeB3FIxX0NfOMgBc
# FXkfEdPwW79TAGm+tsgWhUqIoe68mn9GmIAM0Wf4JtZnVlDswXjQQ2F1dlUH0ADL
# FbstMdBtKn0Wg1pkql6XrsAA3Crv+07FRWqeJVZULISEnOnO8nZSssMb/JBPKOkV
# PkGmC3/R7ssEfvdDtcDdyr/TyFEMckpgjvcXhMngSjDB/Y8bfpbO6DFZwtkT3bbu
# CFSqiiY/u32VCl5d8vaKq0o40g/8kpzZ/qHimloWgP6/q+QAupVQdb0NMdjXvKY5
# 3CdkdW3BHQcCAwEAAaOCAekwggHlMB8GA1UdIwQYMBaAFI/ofvBtMmoABSPHcJdq
# OpD/a+rUMB0GA1UdDgQWBBRWWvIyprXR0NcDxss6cegXRAbySzAmBgNVHREEHzAd
# oBsGCCsGAQUFBwgDoA8wDQwLVFctNzA1Mzg0MzMwDgYDVR0PAQH/BAQDAgeAMBMG
# A1UdJQQMMAoGCCsGAQUFBwMDMHsGA1UdHwR0MHIwN6A1oDOGMWh0dHA6Ly9jcmwz
# LmRpZ2ljZXJ0LmNvbS9FVkNvZGVTaWduaW5nU0hBMi1nMS5jcmwwN6A1oDOGMWh0
# dHA6Ly9jcmw0LmRpZ2ljZXJ0LmNvbS9FVkNvZGVTaWduaW5nU0hBMi1nMS5jcmww
# SwYDVR0gBEQwQjA3BglghkgBhv1sAwIwKjAoBggrBgEFBQcCARYcaHR0cHM6Ly93
# d3cuZGlnaWNlcnQuY29tL0NQUzAHBgVngQwBAzB+BggrBgEFBQcBAQRyMHAwJAYI
# KwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBIBggrBgEFBQcwAoY8
# aHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0RVZDb2RlU2lnbmlu
# Z0NBLVNIQTIuY3J0MAwGA1UdEwEB/wQCMAAwDQYJKoZIhvcNAQELBQADggEBAKOr
# SoFfeU8wM2B9xFsILfwSC8lanzxnmuopBNI21KnE78PUw6g0KMz0iH1xAQMZh0AK
# PBZCtlVm3IIJjZYrCRz130jdHn03hyvXI2z2GMqEOVGp/5ImS1PAvuuUaCk+yesf
# eae8jjqfmOG2/+Sk5SKuBZqRcnEK281vdDabGjva918pagCDpg/Fk+DPkzumEfNi
# ejC88UZbFPHwXQnPvCJEHPh7RkIhlNzgpDynR144lVccLhmzrB+MB1cuEXaPkB7T
# q+nvqHkjofITVSPhnkIaWFl1TqCnS1Zp78kKUE0/EPxLIFUzL+qD6a0MuBemTnwt
# y7OyGkW6Tjfw+10yjPQwgga8MIIFpKADAgECAhAD8bThXzqC8RSWeLPX2EdcMA0G
# CSqGSIb3DQEBCwUAMGwxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJ
# bmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xKzApBgNVBAMTIkRpZ2lDZXJ0
# IEhpZ2ggQXNzdXJhbmNlIEVWIFJvb3QgQ0EwHhcNMTIwNDE4MTIwMDAwWhcNMjcw
# NDE4MTIwMDAwWjBsMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5j
# MRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSswKQYDVQQDEyJEaWdpQ2VydCBF
# ViBDb2RlIFNpZ25pbmcgQ0EgKFNIQTIpMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8A
# MIIBCgKCAQEAp1P6D7K1E/Fkz4SA/K6ANdG218ejLKwaLKzxhKw6NRI6kpG6V+TE
# yfMvqEg8t9Zu3JciulF5Ya9DLw23m7RJMa5EWD6koZanh08jfsNsZSSQVT6hyiN8
# xULpxHpiRZt93mN0y55jJfiEmpqtRU+ufR/IE8t1m8nh4Yr4CwyY9Mo+0EWqeh6l
# WJM2NL4rLisxWGa0MhCfnfBSoe/oPtN28kBa3PpqPRtLrXawjFzuNrqD6jCoTN7x
# CypYQYiuAImrA9EWgiAiduteVDgSYuHScCTb7R9w0mQJgC3itp3OH/K7IfNs29iz
# GXuKUJ/v7DYKXJq3StMIoDl5/d2/PToJJQIDAQABo4IDWDCCA1QwEgYDVR0TAQH/
# BAgwBgEB/wIBADAOBgNVHQ8BAf8EBAMCAYYwEwYDVR0lBAwwCgYIKwYBBQUHAwMw
# fwYIKwYBBQUHAQEEczBxMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2Vy
# dC5jb20wSQYIKwYBBQUHMAKGPWh0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9E
# aWdpQ2VydEhpZ2hBc3N1cmFuY2VFVlJvb3RDQS5jcnQwgY8GA1UdHwSBhzCBhDBA
# oD6gPIY6aHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0SGlnaEFzc3Vy
# YW5jZUVWUm9vdENBLmNybDBAoD6gPIY6aHR0cDovL2NybDQuZGlnaWNlcnQuY29t
# L0RpZ2lDZXJ0SGlnaEFzc3VyYW5jZUVWUm9vdENBLmNybDCCAcQGA1UdIASCAbsw
# ggG3MIIBswYJYIZIAYb9bAMCMIIBpDA6BggrBgEFBQcCARYuaHR0cDovL3d3dy5k
# aWdpY2VydC5jb20vc3NsLWNwcy1yZXBvc2l0b3J5Lmh0bTCCAWQGCCsGAQUFBwIC
# MIIBVh6CAVIAQQBuAHkAIAB1AHMAZQAgAG8AZgAgAHQAaABpAHMAIABDAGUAcgB0
# AGkAZgBpAGMAYQB0AGUAIABjAG8AbgBzAHQAaQB0AHUAdABlAHMAIABhAGMAYwBl
# AHAAdABhAG4AYwBlACAAbwBmACAAdABoAGUAIABEAGkAZwBpAEMAZQByAHQAIABD
# AFAALwBDAFAAUwAgAGEAbgBkACAAdABoAGUAIABSAGUAbAB5AGkAbgBnACAAUABh
# AHIAdAB5ACAAQQBnAHIAZQBlAG0AZQBuAHQAIAB3AGgAaQBjAGgAIABsAGkAbQBp
# AHQAIABsAGkAYQBiAGkAbABpAHQAeQAgAGEAbgBkACAAYQByAGUAIABpAG4AYwBv
# AHIAcABvAHIAYQB0AGUAZAAgAGgAZQByAGUAaQBuACAAYgB5ACAAcgBlAGYAZQBy
# AGUAbgBjAGUALjAdBgNVHQ4EFgQUj+h+8G0yagAFI8dwl2o6kP9r6tQwHwYDVR0j
# BBgwFoAUsT7DaQP4v0cB1JgmGggC72NkK8MwDQYJKoZIhvcNAQELBQADggEBABkz
# SgyBMzfbrTbJ5Mk6u7UbLnqi4vRDQheev06hTeGx2+mB3Z8B8uSI1en+Cf0hwexd
# gNLw1sFDwv53K9v515EzzmzVshk75i7WyZNPiECOzeH1fvEPxllWcujrakG9HNVG
# 1XxJymY4FcG/4JFwd4fcyY0xyQwpojPtjeKHzYmNPxv/1eAal4t82m37qMayOmZr
# ewGzzdimNOwSAauVWKXEU1eoYObnAhKguSNkok27fIElZCG+z+5CGEOXu6U3Bq9N
# /yalTWFL7EZBuGXOuHmeCJYLgYyKO4/HmYyjKm6YbV5hxpa3irlhLZO46w4EQ9f1
# /qbwYtSZaqXBwfBklIAxghH2MIIR8gIBATCBgDBsMQswCQYDVQQGEwJVUzEVMBMG
# A1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSsw
# KQYDVQQDEyJEaWdpQ2VydCBFViBDb2RlIFNpZ25pbmcgQ0EgKFNIQTIpAhAMAVGm
# Q5J6zRldtiGe54EjMA0GCWCGSAFlAwQCAQUAoHwwEAYKKwYBBAGCNwIBDDECMAAw
# GQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisG
# AQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIIUSnGjaxF1DQDk4kuRafipwj4PJl+I+
# kBEqWOQdB/tRMA0GCSqGSIb3DQEBAQUABIICAEj9fve3ad4pY7PIOrLy5pcNKMAa
# iq+uCeu6GTIswJo0+t204/7ls1YO3PFD3tmzje6rkstsGYIwdiYnXWBn+3AzGwe3
# 5SsjD3LsDeSln+1RsOgwnAVBXW9w9qiFfSlkk3f7fN6CaoL8JaM6q7dJSHJkTiAp
# K6368BL4H72hHr6EXdfgnp7wrPhQp5wbwR6IwWvYp38VOwDD9oeVuOYusB3Uu5dT
# WPsWkTq20MEXKoBTv0BvOlsSguO7Mf3wTXOqb64kK/yeHxjPsekbfgkztEjd/0Lc
# RZBD9U4RF7SudbdRmEx1dH95L8c94LI3bS7PNxmef7abD2YOqiMVOaZWQR6HRHc0
# Dnbc8dBBz6igvvQRh9bnZixLhZXm1XNukJYME4RF+yjkUTV1nfnzZYmxURSYD0Rm
# pmIkX1lqbNJa9k+434kP+AVULtIQeEiUqZ4DZrqEVZb41hYRGADvvKeHdW7DLtUo
# 3dFXZctgHBzxI/2/4x3Qx7aP0QTRKsfaP8RW/IsjAZsw7a0gY1DRGX06J/30iXBq
# z/pUhkve0X5BGXw4jO4ozNtEflTY5DOMdqsK0/MvMLEZYIgLO3bA4TAvc8M7uXy7
# 9tnXIbdaAmmMuEvYA8wc6oK2pIOo0n4qKLGad4aW8lxseiwzdqQe/d40s9hllRVN
# XrKSRk3lrLzreHEfoYIOyDCCDsQGCisGAQQBgjcDAwExgg60MIIOsAYJKoZIhvcN
# AQcCoIIOoTCCDp0CAQMxDzANBglghkgBZQMEAgEFADB3BgsqhkiG9w0BCRABBKBo
# BGYwZAIBAQYJYIZIAYb9bAcBMDEwDQYJYIZIAWUDBAIBBQAEIM14seKk16saoMtQ
# iDnJjxMwhvBzbgpurY1eEdnQPXCdAhBEBGJzNqrxvayDOSqtGklhGA8yMDIwMDkw
# ODA2NDkzNlqgggu7MIIGgjCCBWqgAwIBAgIQBM0/hWiudsYbsP5xYMynbTANBgkq
# hkiG9w0BAQsFADByMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5j
# MRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMTEwLwYDVQQDEyhEaWdpQ2VydCBT
# SEEyIEFzc3VyZWQgSUQgVGltZXN0YW1waW5nIENBMB4XDTE5MTAwMTAwMDAwMFoX
# DTMwMTAxNzAwMDAwMFowTDELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0
# LCBJbmMuMSQwIgYDVQQDExtUSU1FU1RBTVAtU0hBMjU2LTIwMTktMTAtMTUwggEi
# MA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDpZDWc+qmYZWQb5BfcuCk2zGcJ
# WIVNMODJ/+U7PBEoUK8HMeJdCRjC9omMaQgEI+B3LZ0V5bjooWqO/9Su0noW7/hB
# tR05dcHPL6esRX6UbawDAZk8Yj5+ev1FlzG0+rfZQj6nVZvfWk9YAqgyaSITvouC
# LcaYq2ubtMnyZREMdA2y8AiWdMToskiioRSl+PrhiXBEO43v+6T0w7m9FCzrDCgn
# JYCrEEsWEmALaSKMTs3G1bJlWSHgfCwSjXAOj4rK4NPXszl3UNBCLC56zpxnejh3
# VED/T5UEINTryM6HFAj+HYDd0OcreOq/H3DG7kIWUzZFm1MZSWKdegKblRSjAgMB
# AAGjggM4MIIDNDAOBgNVHQ8BAf8EBAMCB4AwDAYDVR0TAQH/BAIwADAWBgNVHSUB
# Af8EDDAKBggrBgEFBQcDCDCCAb8GA1UdIASCAbYwggGyMIIBoQYJYIZIAYb9bAcB
# MIIBkjAoBggrBgEFBQcCARYcaHR0cHM6Ly93d3cuZGlnaWNlcnQuY29tL0NQUzCC
# AWQGCCsGAQUFBwICMIIBVh6CAVIAQQBuAHkAIAB1AHMAZQAgAG8AZgAgAHQAaABp
# AHMAIABDAGUAcgB0AGkAZgBpAGMAYQB0AGUAIABjAG8AbgBzAHQAaQB0AHUAdABl
# AHMAIABhAGMAYwBlAHAAdABhAG4AYwBlACAAbwBmACAAdABoAGUAIABEAGkAZwBp
# AEMAZQByAHQAIABDAFAALwBDAFAAUwAgAGEAbgBkACAAdABoAGUAIABSAGUAbAB5
# AGkAbgBnACAAUABhAHIAdAB5ACAAQQBnAHIAZQBlAG0AZQBuAHQAIAB3AGgAaQBj
# AGgAIABsAGkAbQBpAHQAIABsAGkAYQBiAGkAbABpAHQAeQAgAGEAbgBkACAAYQBy
# AGUAIABpAG4AYwBvAHIAcABvAHIAYQB0AGUAZAAgAGgAZQByAGUAaQBuACAAYgB5
# ACAAcgBlAGYAZQByAGUAbgBjAGUALjALBglghkgBhv1sAxUwHwYDVR0jBBgwFoAU
# 9LbhIB3+Ka7S5GGlsqIlssgXNW4wHQYDVR0OBBYEFFZTD8HGB6dN19huV3KAUEzk
# 7J7BMHEGA1UdHwRqMGgwMqAwoC6GLGh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9z
# aGEyLWFzc3VyZWQtdHMuY3JsMDKgMKAuhixodHRwOi8vY3JsNC5kaWdpY2VydC5j
# b20vc2hhMi1hc3N1cmVkLXRzLmNybDCBhQYIKwYBBQUHAQEEeTB3MCQGCCsGAQUF
# BzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20wTwYIKwYBBQUHMAKGQ2h0dHA6
# Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFNIQTJBc3N1cmVkSURUaW1l
# c3RhbXBpbmdDQS5jcnQwDQYJKoZIhvcNAQELBQADggEBAC6DoUQFSgTjuTJS+tmB
# 8Bq7+AmNI7k92JKh5kYcSi9uejxjbjcXoxq/WCOyQ5yUg045CbAs6Mfh4szty3lr
# zt4jAUftlVSB4IB7ErGvAoapOnNq/vifwY3RIYzkKYLDigtgAAKdH0fEn7QKaFN/
# WhCm+CLm+FOSMV/YgoMtbRNCroPBEE6kJPRHnN4PInJ3XH9P6TmYK1eSRNfvbpPZ
# Q8cEM2NRN1aeRwQRw6NYVCHY4o5W10k/V/wKnyNee/SUjd2dGrvfeiqm0kWmVQyP
# 9kyK8pbPiUbcMbKRkKNfMzBgVfX8azCsoe3kR04znmdqKLVNwu1bl4L4y6kIbFMJ
# tPcwggUxMIIEGaADAgECAhAKoSXW1jIbfkHkBdo2l8IVMA0GCSqGSIb3DQEBCwUA
# MGUxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsT
# EHd3dy5kaWdpY2VydC5jb20xJDAiBgNVBAMTG0RpZ2lDZXJ0IEFzc3VyZWQgSUQg
# Um9vdCBDQTAeFw0xNjAxMDcxMjAwMDBaFw0zMTAxMDcxMjAwMDBaMHIxCzAJBgNV
# BAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdp
# Y2VydC5jb20xMTAvBgNVBAMTKERpZ2lDZXJ0IFNIQTIgQXNzdXJlZCBJRCBUaW1l
# c3RhbXBpbmcgQ0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQC90DLu
# S82Pf92puoKZxTlUKFe2I0rEDgdFM1EQfdD5fU1ofue2oPSNs4jkl79jIZCYvxO8
# V9PD4X4I1moUADj3Lh477sym9jJZ/l9lP+Cb6+NGRwYaVX4LJ37AovWg4N4iPw7/
# fpX786O6Ij4YrBHk8JkDbTuFfAnT7l3ImgtU46gJcWvgzyIQD3XPcXJOCq3fQDpc
# t1HhoXkUxk0kIzBdvOw8YGqsLwfM/fDqR9mIUF79Zm5WYScpiYRR5oLnRlD9lCos
# p+R1PrqYD4R/nzEU1q3V8mTLex4F0IQZchfxFwbvPc3WTe8GQv2iUypPhR3EHTyv
# z9qsEPXdrKzpVv+TAgMBAAGjggHOMIIByjAdBgNVHQ4EFgQU9LbhIB3+Ka7S5GGl
# sqIlssgXNW4wHwYDVR0jBBgwFoAUReuir/SSy4IxLVGLp6chnfNtyA8wEgYDVR0T
# AQH/BAgwBgEB/wIBADAOBgNVHQ8BAf8EBAMCAYYwEwYDVR0lBAwwCgYIKwYBBQUH
# AwgweQYIKwYBBQUHAQEEbTBrMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdp
# Y2VydC5jb20wQwYIKwYBBQUHMAKGN2h0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNv
# bS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcnQwgYEGA1UdHwR6MHgwOqA4oDaG
# NGh0dHA6Ly9jcmw0LmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RD
# QS5jcmwwOqA4oDaGNGh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFz
# c3VyZWRJRFJvb3RDQS5jcmwwUAYDVR0gBEkwRzA4BgpghkgBhv1sAAIEMCowKAYI
# KwYBBQUHAgEWHGh0dHBzOi8vd3d3LmRpZ2ljZXJ0LmNvbS9DUFMwCwYJYIZIAYb9
# bAcBMA0GCSqGSIb3DQEBCwUAA4IBAQBxlRLpUYdWac3v3dp8qmN6s3jPBjdAhO9L
# hL/KzwMC/cWnww4gQiyvd/MrHwwhWiq3BTQdaq6Z+CeiZr8JqmDfdqQ6kw/4stHY
# fBli6F6CJR7Euhx7LCHi1lssFDVDBGiy23UC4HLHmNY8ZOUfSBAYX4k4YU1iRiSH
# Y4yRUiyvKYnleB/WCxSlgNcSR3CzddWThZN+tpJn+1Nhiaj1a5bA9FhpDXzIAbG5
# KHW3mWOFIoxhynmUfln8jA/jb7UBJrZspe6HUSHkWGCbugwtK22ixH67xCUrRwII
# fEmuE7bhfEJCKMYYVs9BNLZmXbZ0e/VWMyIvIjayS6JKldj1po5SMYICTTCCAkkC
# AQEwgYYwcjELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcG
# A1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTExMC8GA1UEAxMoRGlnaUNlcnQgU0hBMiBB
# c3N1cmVkIElEIFRpbWVzdGFtcGluZyBDQQIQBM0/hWiudsYbsP5xYMynbTANBglg
# hkgBZQMEAgEFAKCBmDAaBgkqhkiG9w0BCQMxDQYLKoZIhvcNAQkQAQQwHAYJKoZI
# hvcNAQkFMQ8XDTIwMDkwODA2NDkzNlowKwYLKoZIhvcNAQkQAgwxHDAaMBgwFgQU
# AyW9UF7aljAtwi9PoB5MKL4oNMUwLwYJKoZIhvcNAQkEMSIEIEWCeKINRppPvf6V
# i/MQPOwFMDbwCoso2USQrxm2iczsMA0GCSqGSIb3DQEBAQUABIIBADKsM1BQ9qaa
# atiwE3cAzj7QbR6ydXKNt27V/OOAe0nXznMvEKBPhTapPDYN8Y3PvRlsJ814Qic6
# gHNCKDSg5KCnw6qERrQjK0oKxm/rE2V3EG/ILs5SHB8+3uem21TQ5JcQvFOFz8tl
# h+P8K/3F1rwZ2vtkdQWpFOqR6v4wkRUjuEonWmlu6qnopolfVFhbAF8CcJ7KYwkA
# hgjwWiS4QaRfOBYH8E7Ow9i9MVcoucYcycpvg1/oP5an8q/jlzRRxQscHBEfC6RH
# 9ECR0o8pdn3PS1GDxtGOo3nkeKHd+ESMazG1MfK34g3oK1BhQQcYHr4nc6Xajw2Q
# K2wEDASq/nA=
# SIG # End signature block
