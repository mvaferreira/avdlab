Param (
    [Parameter(Mandatory = $True)]
    [string]$DomainName = "",

    [Parameter(Mandatory = $True)]
    [string]$DCName = "",

    [Parameter(Mandatory = $True)]
    [string]$StorageAccountName = "",

    [Parameter(Mandatory = $True)]
    [string]$ShareName = "",

    [Parameter(Mandatory = $True)]
    [string]$DscStorageAccountName = "",

    [Parameter(Mandatory = $True)]
    [string]$LocalUsername = "",
    
    [Parameter(Mandatory = $True)]
    [string]$LocalPasswd = "",

    [Parameter(Mandatory = $True)]
    [string]$TenantName = "",
    
    [Parameter(Mandatory = $True)]
    [string]$CloudAdmin = "",
    
    [Parameter(Mandatory = $True)]
    [string]$CloudAdminPasswd = ""
)

$SecurePassword = ConvertTo-SecureString $LocalPasswd -AsPlainText -Force
$DomainAdminCreds = New-Object System.Management.Automation.PSCredential ("$($DomainName)\$($LocalUsername)", $SecurePassword)

#
# Create and link GPOs to domain
#

$ComputersOUPath = "OU=Computers,OU=Lab,DC=$($DomainName.ToString().Split(".")[0]),DC=$($DomainName.ToString().Split(".")[1])"
$HybridOUPath = "OU=Hybrid,OU=Computers,OU=Lab,DC=$($DomainName.ToString().Split(".")[0]),DC=$($DomainName.ToString().Split(".")[1])"
$RootOUPath = "DC=$($DomainName.ToString().Split(".")[0]),DC=$($DomainName.ToString().Split(".")[1])"
$UsersOUPath = "OU=Users,OU=Lab,DC=$($DomainName.ToString().Split(".")[0]),DC=$($DomainName.ToString().Split(".")[1])"

$FirewallParam = @{
    DisplayName = 'Windows Remote Management (HTTP-In) AllSubnets'
    Direction   = 'Inbound'
    LocalPort   = 5985
    Protocol    = 'TCP'
    Action      = 'Allow'
    Program     = 'System'
}
New-NetFirewallRule @FirewallParam | Out-Null

New-GPO -Name "Disable UDP"
Set-GPRegistryValue -Name "Disable UDP" -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" -ValueName "SelectTransport" -Value 1 -Type DWord

New-GPO -Name "Enable Hybrid VMs"
Set-GPRegistryValue -Name "Enable Hybrid VMs" -Key "HKLM\Software\Policies\Microsoft\Windows\WorkplaceJoin" -ValueName "autoWorkplaceJoin" -Value 1 -Type DWord
Set-GPRegistryValue -Name "Enable Hybrid VMs" -Key "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System\Kerberos\domain_realm" -ValueName $DomainName -Value "$($StorageAccountName).file.core.windows.net" -Type String

New-GPO -Name "Enable RDP Shortpath Managed"
Set-GPRegistryValue -Name "Enable RDP Shortpath Managed" -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" -ValueName "fUseUdpPortRedirector" -Value 1 -Type DWord
Set-GPRegistryValue -Name "Enable RDP Shortpath Managed" -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" -ValueName "UdpRedirectorPort" -Value "3390" -Type String

Invoke-Command -Credential $DomainAdminCreds -ComputerName $DCName -ScriptBlock {
    param($DomainName, $DCName, $ComputersOUPath, $UsersOUPath)
    cmd.exe /C "redircmp $($ComputersOUPath)"
    cmd.exe /C "redirusr $($UsersOUPath)"
    $GPOSession = Open-NetGPO -PolicyStore "$DomainName\Enable RDP Shortpath Managed" -DomainController $DCName
    New-NetFirewallRule -DisplayName 'Remote Desktop - RDP Shortpath (UDP-In)' -Action Allow -Description 'Inbound rule for the Remote Desktop service to allow RDP Shortpath traffic. [UDP 3390]' -Group '@FirewallAPI.dll,-28752' -Name 'RemoteDesktop-UserMode-In-RDPShortpath-UDP' -Profile Domain, Private, Public -Service TermService -Protocol UDP -LocalPort 3390 -Program '%SystemRoot%\system32\svchost.exe' -Enabled:True -GPOSession $GPOSession
    Save-NetGPO -GPOSession $GPOSession
} -ArgumentList $DomainName, $DCName, $ComputersOUPath, $UsersOUPath

New-GPO -Name "Enable screen protection"
Set-GPRegistryValue -Name "Enable screen protection" -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" -ValueName "fEnableScreenCaptureProtection" -Value 1 -Type DWord
Set-GPRegistryValue -Name "Enable screen protection" -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" -ValueName "fEnableScreenCaptureProtect" -Value 2 -Type DWord

New-GPO -Name "Enable Watermarking"
Set-GPRegistryValue -Name "Enable Watermarking" -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" -ValueName "fEnableWatermarking" -Value 1 -Type DWord
Set-GPRegistryValue -Name "Enable Watermarking" -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" -ValueName "WatermarkingQrScale" -Value 4 -Type DWord
Set-GPRegistryValue -Name "Enable Watermarking" -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" -ValueName "WatermarkingOpacity" -Value 2000 -Type DWord
Set-GPRegistryValue -Name "Enable Watermarking" -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" -ValueName "WatermarkingWidthFactor" -Value 320 -Type DWord
Set-GPRegistryValue -Name "Enable Watermarking" -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" -ValueName "WatermarkingHeightFactor" -Value 180 -Type DWord

New-GPO -Name "Enable Timezone Redirection"
Set-GPRegistryValue -Name "Enable Timezone Redirection" -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" -ValueName "fEnableTimeZoneRedirection" -Value 1 -Type DWord

New-GPO -Name "FSLogix Settings"
Set-GPRegistryValue -Name "FSLogix Settings" -Key "HKLM\SOFTWARE\FSLogix\Profiles" -ValueName "Enabled" -Value 1 -Type DWord
Set-GPRegistryValue -Name "FSLogix Settings" -Key "HKLM\SOFTWARE\FSLogix\Profiles" -ValueName "VHDLocations" -Value "\\$($StorageAccountName).file.core.windows.net\$($ShareName)" -Type String
Set-GPRegistryValue -Name "FSLogix Settings" -Key "HKLM\SOFTWARE\FSLogix\Profiles" -ValueName "DeleteLocalProfileWhenVHDShouldApply" -Value 1 -Type DWord
Set-GPRegistryValue -Name "FSLogix Settings" -Key "HKLM\SOFTWARE\FSLogix\Profiles" -ValueName "PreventLoginWithFailure" -Value 1 -Type DWord
Set-GPRegistryValue -Name "FSLogix Settings" -Key "HKLM\SOFTWARE\FSLogix\Profiles" -ValueName "FlipFlopProfileDirectoryName" -Value 1 -Type DWord
Set-GPRegistryValue -Name "FSLogix Settings" -Key "HKLM\SOFTWARE\FSLogix\Profiles" -ValueName "IsDynamic" -Value 1 -Type DWord
Set-GPRegistryValue -Name "FSLogix Settings" -Key "HKLM\SOFTWARE\FSLogix\Profiles" -ValueName "LockedRetryCount" -Value 3 -Type DWord
Set-GPRegistryValue -Name "FSLogix Settings" -Key "HKLM\SOFTWARE\FSLogix\Profiles" -ValueName "LockedRetryInterval" -Value 15 -Type DWord
Set-GPRegistryValue -Name "FSLogix Settings" -Key "HKLM\SOFTWARE\FSLogix\Profiles" -ValueName "ReAttachRetryCount" -Value 3 -Type DWord
Set-GPRegistryValue -Name "FSLogix Settings" -Key "HKLM\SOFTWARE\FSLogix\Profiles" -ValueName "ReAttachIntervalSeconds" -Value 15 -Type DWord
Set-GPRegistryValue -Name "FSLogix Settings" -Key "HKLM\SOFTWARE\FSLogix\Profiles" -ValueName "VolumeType" -Value "vhdx" -Type String
Set-GPRegistryValue -Name "FSLogix Settings" -Key "HKLM\SOFTWARE\FSLogix\Profiles" -ValueName "IgnoreNonWVD" -Value 1 -Type DWord
Set-GPRegistryValue -Name "FSLogix Settings" -Key "HKLM\SOFTWARE\FSLogix\Profiles" -ValueName "LogFileKeepingPeriod" -Value 7 -Type DWord

New-GPO -Name "Enable Powershell Transcript"
Set-GPRegistryValue -Name "Enable Powershell Transcript" -Key "HKLM\Software\Policies\Microsoft\Windows\PowerShell\Transcription" -ValueName "EnableTranscripting" -Value 1 -Type DWord
Set-GPRegistryValue -Name "Enable Powershell Transcript" -Key "HKLM\Software\Policies\Microsoft\Windows\PowerShell\Transcription" -ValueName "EnableInvocationHeader" -Value 1 -Type DWord
Set-GPRegistryValue -Name "Enable Powershell Transcript" -Key "HKLM\Software\Policies\Microsoft\Windows\PowerShell\Transcription" -ValueName "OutputDirectory" -Value "C:\Transcripts" -Type String

New-GpLink -Name "FSLogix Settings" -Target $ComputersOUPath -LinkEnabled 'Yes'
New-GpLink -Name "Enable RDP Shortpath Managed" -Target $ComputersOUPath -LinkEnabled 'Yes'
New-GpLink -Name "Enable Timezone Redirection" -Target $ComputersOUPath -LinkEnabled 'Yes'
#New-GpLink -Name "Enable Powershell Transcript" -Target $RootOUPath -LinkEnabled 'Yes'
New-GpLink -Name "Enable Hybrid VMs" -Target $HybridOUPath -LinkEnabled 'Yes'

#
# Install Azure AD Connect Cloud Sync
# Work in progress.
#
Write-Output "[$(Get-Date)]Configuring AAD Connect Cloud Sync..."
Set-ADUser -Identity avduser -UserPrincipalName "avduser@$($TenantName)"
Set-ADUser -Identity avdadmin -UserPrincipalName "avdadmin@$($TenantName)"

$ProgressPreference = 'SilentlyContinue'
Invoke-WebRequest -Uri "https://$($DscStorageAccountName).blob.core.windows.net/scripts/AADConnectProvisioningAgentSetup.exe" -OutFile .\AADConnectProvisioningAgentSetup.exe
Invoke-WebRequest -Uri "https://$($DscStorageAccountName).blob.core.windows.net/scripts/Newtonsoft.Json.dll" -OutFile .\Newtonsoft.Json.dll

$EXEArguments = @(
    "/quiet"
    "-NoNewWindow"
    "-PassThru"
)

Start-Process ".\AADConnectProvisioningAgentSetup.exe" -ArgumentList $EXEArguments -PassThru -Wait

Import-Module "C:\Program Files\Microsoft Azure AD Connect Provisioning Agent\Microsoft.CloudSync.PowerShell.dll"
$CloudAdminPassword = ConvertTo-SecureString $CloudAdminPasswd -AsPlainText -Force
$HybridAdminCreds = New-Object System.Management.Automation.PSCredential -ArgumentList ("$($CloudAdmin)@$($TenantName)", $CloudAdminPassword) 

Connect-AADCloudSyncAzureAD -Credential $HybridAdminCreds
Add-AADCloudSyncGMSA -Credential $DomainAdminCreds

Rename-Item -Path "C:\Program Files\Microsoft Azure AD Connect Provisioning Agent\Newtonsoft.Json.dll" -NewName "C:\Program Files\Microsoft Azure AD Connect Provisioning Agent\Newtonsoft.Json.dll_bak" -Force
Copy-Item .\Newtonsoft.Json.dll "C:\Program Files\Microsoft Azure AD Connect Provisioning Agent\Newtonsoft.Json.dll" -Force

Add-AADCloudSyncADDomain -DomainName $DomainName -Credential $DomainAdminCreds

Remove-Item -Path "C:\Program Files\Microsoft Azure AD Connect Provisioning Agent\Newtonsoft.Json.dll" -Force
Rename-Item -Path "C:\Program Files\Microsoft Azure AD Connect Provisioning Agent\Newtonsoft.Json.dll_bak" -NewName "C:\Program Files\Microsoft Azure AD Connect Provisioning Agent\Newtonsoft.Json.dll" -Force
Restart-Service -Name AADConnectProvisioningAgent