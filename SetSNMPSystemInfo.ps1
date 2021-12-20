function Set-CustomSystemInfo
{
	param (
		[string]$SNMP,
		[string]$Probe
	)
	
	
	# Set SNMP Settings
	if ($SNMP -eq 1)
	{		
		Get-WindowsFeature "*SNMP*" | Where-Object{ $_.InstallState -notmatch "Installed" } | Foreach-Object{
			Write-Host "Installing $($_.Name)"
			$_ | Install-WindowsFeature -IncludeAllSubFeature -IncludeManagementTools -Verbose
			
		}
		
		Set-Service -Name SNMP -StartupType Automatic
		
		#Contact information: 
		if ((Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\services\SNMP\Parameters\RFC1156Agent" -Name "sysContact" -ErrorAction SilentlyContinue) -eq $null)
		{
			if ((Test-Path "HKLM:\SYSTEM\CurrentControlSet\services\SNMP\Parameters\RFC1156Agent") -eq $false)
			{
				New-Item -Path "HKLM:\SYSTEM\CurrentControlSet\services\SNMP\Parameters\RFC1156Agent" -Force
			}
			New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\services\SNMP\Parameters\RFC1156Agent" -Name "sysContact" -Value "YOURCOMPANYNAME" -PropertyType string
		}
		
		Else
		{
			Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\services\SNMP\Parameters\RFC1156Agent" -Name "sysContact" -Value "YOURCOMPANYNAME"
		}
		
		if ((Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\services\SNMP\Parameters\RFC1156Agent" -Name "sysLocation" -ErrorAction SilentlyContinue) -eq $null)
		{
			if ((Test-Path "HKLM:\SYSTEM\CurrentControlSet\services\SNMP\Parameters\RFC1156Agent") -eq $false)
			{
				New-Item -Path "HKLM:\SYSTEM\CurrentControlSet\services\SNMP\Parameters\RFC1156Agent" -Force
			}
			New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\services\SNMP\Parameters\RFC1156Agent" -Name "sysLocation" -Value "YOURLOCATION" -PropertyType string
		}
		
		Else
		{
			Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\services\SNMP\Parameters\RFC1156Agent" -Name "sysLocation" -Value "YOURLOCATION"
		}

		#SNMP CompanyName services add to the SNMP service: 
		If ((Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\SNMP\Parameters\RFC1156Agent" -Name "sysServices" -ErrorAction SilentlyContinue) -eq $null)
		{
			If ((Test-Path "HKLM:\SYSTEM\CurrentControlSet\Services\SNMP\Parameters\RFC1156Agent") -eq $false)
			{
				New-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Services\SNMP\Parameters\RFC1156Agent" -Force
			}
			New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\SNMP\Parameters\RFC1156Agent" -Name "sysServices" -Value 79 -PropertyType DWord
		}
		
		Else
		{
			Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\SNMP\Parameters\RFC1156Agent" -Name "sysServices" -Value 79
		}


		#Add SNMP Communities to the SNMP service: 
		If ((Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\SNMP\Parameters\ValidCommunities" -Name "YOURSNMPCOMMUNITY" -ErrorAction SilentlyContinue) -eq $null)
		{
			If ((Test-Path "HKLM:\SYSTEM\CurrentControlSet\Services\SNMP\Parameters\ValidCommunities") -eq $false)
			{
				New-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Services\SNMP\Parameters\ValidCommunities" -Force
			}
			New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\SNMP\Parameters\ValidCommunities" -Name "YOURSNMPCOMMUNITY" -Value 4 -PropertyType DWord
		}
		
		Else
		{
			Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\SNMP\Parameters\ValidCommunities" -Name "YOURSNMPCOMMUNITY" -Value 4
		}
		
		#Allow SNMP queries from x.x.x.x:
		If ((Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\SNMP\Parameters\PermittedManagers" -Name "1" -ErrorAction SilentlyContinue) -eq $null)
		{
			If ((Test-Path "HKLM:\SYSTEM\CurrentControlSet\Services\SNMP\Parameters\PermittedManagers") -eq $false)
			{
				New-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Services\SNMP\Parameters\PermittedManagers" -Force
			}
			New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\SNMP\Parameters\PermittedManagers" -Name "1" -Value $Probe -PropertyType string
		}
		
		Else
		{
			Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\SNMP\Parameters\PermittedManagers" -Name "1" -Value $Probe
		}
		
		if ((Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\SNMP\Parameters\PermittedManagers" -Name "2" -ErrorAction SilentlyContinue) -eq $null)
		{
			If ((Test-Path "HKLM:\SYSTEM\CurrentControlSet\Services\SNMP\Parameters\PermittedManagers") -eq $false)
			{
				New-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Services\SNMP\Parameters\PermittedManagers" -Force
			}
			New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\SNMP\Parameters\PermittedManagers" -Name "2" -Value "localhost" -PropertyType string
		}
		
		Else
		{
			Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\SNMP\Parameters\PermittedManagers" -Name "2" -Value "localhost"
		}
		
		#Authtrap enable:
		if ((Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\services\SNMP\Parameters" -Name "EnableAuthenticationTraps" -ErrorAction SilentlyContinue) -eq $null)
		{
			If ((Test-Path "HKLM:\SYSTEM\CurrentControlSet\services\SNMP\Parameters") -eq $false)
			{
				New-Item -Path "HKLM:\SYSTEM\CurrentControlSet\services\SNMP\Parameters" -Force
			}
			New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\services\SNMP\Parameters" -Name "EnableAuthenticationTraps" -Value 1 -PropertyType DWord
		}
		
		Else
		{
			Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\services\SNMP\Parameters" -Name "EnableAuthenticationTraps" -Value 1
		}
		
		#Allowed Servers to send SNMP-Traps to:
		if ((Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\services\SNMP\Parameters\TrapConfiguration\YOURSNMPCOMMUNITY" -Name "1" -ErrorAction SilentlyContinue) -eq $null)
		{
			if ((Test-Path "HKLM:\SYSTEM\CurrentControlSet\services\SNMP\Parameters\TrapConfiguration\YOURSNMPCOMMUNITY") -eq $false)
			{
				New-Item -Path "HKLM:\SYSTEM\CurrentControlSet\services\SNMP\Parameters\TrapConfiguration\YOURSNMPCOMMUNITY" -Force
			}
			New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\services\SNMP\Parameters\TrapConfiguration\YOURSNMPCOMMUNITY" -Name "1" -Value $Probe -PropertyType string
		}
		
		else
		{
			Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\services\SNMP\Parameters\TrapConfiguration\YOURSNMPCOMMUNITY" -Name "1" -Value $Probe
		}
		
		if ((Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\services\SNMP\Parameters\TrapConfiguration\YOURSNMPCOMMUNITY" -Name "2" -ErrorAction SilentlyContinue) -eq $null)
		{
			If ((Test-Path "HKLM:\SYSTEM\CurrentControlSet\services\SNMP\Parameters\TrapConfiguration\YOURSNMPCOMMUNITY") -eq $false)
			{
				New-Item -Path "HKLM:\SYSTEM\CurrentControlSet\services\SNMP\Parameters\TrapConfiguration\YOURSNMPCOMMUNITY" -Force
			}
			New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\services\SNMP\Parameters\TrapConfiguration\YOURSNMPCOMMUNITY" -Name "2" -Value "localhost" -PropertyType string
		}
		
		Else
		{
			Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\services\SNMP\Parameters\TrapConfiguration\YOURSNMPCOMMUNITY" -Name "2" -Value "localhost"
		}
		
		Restart-Service SNMP -Force -Verbose
		
		Write-Host "Done setting up SNMP." -ForegroundColor Green
		
	}
	
	# Set System Information settings
	$MainPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation"
	$Model = (Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue).Model
	$Manufacturer = "YOURCOMPANYNAME"
	$SupportHours = "08:30 - 17:30 (8:30AM - 5:30PM CEST)"
	$SupportPhone = "YOURPHONENUMBER"
	$SupportURL = "https://YOURURL"
		
	# Setting System Information: 
	# Creating Main Path
	if ((Get-ItemProperty -Path $MainPath -Name "Manufacturer" -ErrorAction SilentlyContinue) -eq $null)
	{
		if ((Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation") -eq $false)
		{
			New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation" -Force
		}
		
		if ($Model -ne $null) { New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation" -Name "Model" -Value $Model -PropertyType string }
		New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation" -Name "Manufacturer" -Value $Manufacturer -PropertyType string
		New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation" -Name "SupportHours" -Value $SupportHours -PropertyType string
		New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation" -Name "SupportPhone" -Value $SupportPhone -PropertyType string
		New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation" -Name "SupportURL" -Value $SupportURL -PropertyType string
		
	}
	
	Else
	{
		if ($Model -ne $null) { Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation" -Name "Model" -Value $Model }
		Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation" -Name "Manufacturer" -Value $Manufacturer
		Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation" -Name "Model" -Value $Model
		Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation" -Name "SupportHours" -Value $SupportHours
		Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation" -Name "SupportPhone" -Value $SupportPhone
		Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation" -Name "SupportURL" -Value $SupportURL
	}
}

Set-CustomSystemInfo -SNMP:$args[0] -Probe:$args[1]