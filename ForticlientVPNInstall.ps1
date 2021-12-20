<#

https://links.fortinet.com/forticlient/win/vpnagent

#>


$LogoDest = "C:\Temp\FortiClientVPNOnlineInstaller.exe" 
$LogoDestPath = "C:\Temp"
	
# Create new folder "C:\Temp" for logo placement
If ((Test-Path $LogoDest) -ne $True)
	{
		If ((Test-Path $LogoDestPath) -ne $True) { $Path = New-Item -Path "C:\" -Name "Temp" -ItemType "Directory" }
		Invoke-WebRequest -Uri "https://links.fortinet.com/forticlient/win/vpnagent" -OutFile $LogoDest
	}

Start-Process -FilePath "C:\Temp\FortiClientVPNOnlineInstaller.exe /quiet /norestart" -ArgumentList "/quiet","/norestart"


"C:\Temp\FortiClientVPNOnlineInstaller.exe" FortiClientVPN.exe /quiet /norestart

Start-Process Msiexec.exe -Wait -ArgumentList '/i C:\temp\FortiClientVPN.msi REBOOT=ReallySuppress /qn'