Param (
    [Parameter(Mandatory = $True)]
    [string]$StorageAccountName = "",

    [Parameter(Mandatory = $True)]
    [string]$ShareName = "",

    [Parameter(Mandatory = $True)]
    [string]$LocalAdmin = ""
)

New-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "pku2u" -Force
New-Item -Path "HKLM:\Software\Policies\Microsoft" -Name "AzureADAccount" -Force

New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\Kerberos\Parameters" -Name CloudKerberosTicketRetrievalEnabled -Value 1 -PropertyType DWord -Force
New-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\AzureADAccount" -Name LoadCredKeyFromProfile -Value 1 -PropertyType DWord -Force
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\pku2u" -Name AllowOnlineID -Value 1 -PropertyType DWord -Force

New-ItemProperty -Path "HKLM:\SOFTWARE\FSLogix\Profiles" -Name Enabled -Value 1 -PropertyType DWord -Force
New-ItemProperty -Path "HKLM:\SOFTWARE\FSLogix\Profiles" -Name VHDLocations -Value "\\$($StorageAccountName).file.core.windows.net\$($ShareName)" -PropertyType String -Force
New-ItemProperty -Path "HKLM:\SOFTWARE\FSLogix\Profiles" -Name DeleteLocalProfileWhenVHDShouldApply -Value 1 -PropertyType DWord -Force
New-ItemProperty -Path "HKLM:\SOFTWARE\FSLogix\Profiles" -Name PreventLoginWithFailure -Value 1 -PropertyType DWord -Force
New-ItemProperty -Path "HKLM:\SOFTWARE\FSLogix\Profiles" -Name FlipFlopProfileDirectoryName -Value 1 -PropertyType DWord -Force
New-ItemProperty -Path "HKLM:\SOFTWARE\FSLogix\Profiles" -Name IsDynamic -Value 1 -PropertyType DWord -Force
New-ItemProperty -Path "HKLM:\SOFTWARE\FSLogix\Profiles" -Name LockedRetryCount -Value 3 -PropertyType DWord -Force
New-ItemProperty -Path "HKLM:\SOFTWARE\FSLogix\Profiles" -Name LockedRetryInterval -Value 15 -PropertyType DWord -Force
New-ItemProperty -Path "HKLM:\SOFTWARE\FSLogix\Profiles" -Name ReAttachIntervalSeconds -Value 15 -PropertyType DWord -Force
New-ItemProperty -Path "HKLM:\SOFTWARE\FSLogix\Profiles" -Name ReAttachRetryCount -Value 3 -PropertyType DWord -Force
New-ItemProperty -Path "HKLM:\SOFTWARE\FSLogix\Profiles" -Name VolumeType -Value "vhdx" -PropertyType String -Force
New-ItemProperty -Path "HKLM:\SOFTWARE\FSLogix\Profiles" -Name IgnoreNonWVD -Value 1 -PropertyType DWord -Force
New-ItemProperty -Path "HKLM:\SOFTWARE\FSLogix\Profiles" -Name LogFileKeepingPeriod -Value 7 -PropertyType DWord -Force

Remove-LocalGroupMember -Member "Everyone" -Group "FSLogix ODFC Include List"
Add-LocalGroupMember -Member "$($LocalAdmin)" -Group "FSLogix Profile Exclude List"