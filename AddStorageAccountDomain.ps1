Param (
    [Parameter(Mandatory = $True)]
    [string]$DomainName = "",

    [Parameter(Mandatory = $True)]
    [string]$StorageAccountName = "",

    [Parameter(Mandatory = $True)]
    [string]$ShareName = "",    

    [Parameter(Mandatory = $True)]
    [string]$StorageAccountNameAAD = "",

    [Parameter(Mandatory = $True)]
    [string]$SubscriptionId = "",

    [Parameter(Mandatory = $True)]
    [string]$TenantId = "",

    [Parameter(Mandatory = $True)]
    [string]$ResourceGroupName = "",

    [Parameter(Mandatory = $True)]
    [string]$ResourceGroupSecName = "",

    [Parameter(Mandatory = $True)]
    [string]$LocalUsername = "",
    
    [Parameter(Mandatory = $True)]
    [string]$LocalPasswd = "",

    [Parameter(Mandatory = $True)]
    [string]$DCName = ""    
)

$SecurePassword = ConvertTo-SecureString $LocalPasswd -AsPlainText -Force
$Cred = New-Object System.Management.Automation.PSCredential ("$($DomainName)\$($LocalUsername)", $SecurePassword)

Write-Output "[$(Get-Date)]Installing Az module..."
$ProgressPreference = 'SilentlyContinue'
Invoke-WebRequest -Uri https://github.com/Azure/azure-powershell/releases/download/v10.2.0-August2023/Az-Cmdlets-10.2.0.37547-x64.msi -OutFile .\Az.msi

$MSIArguments = @(
    "/i"
    ('"{0}"' -f "Az.msi")
    "/qn"
    "/norestart"
    "/L*v"
    ".\Az.log"
)

Start-Process "msiexec.exe" -ArgumentList $MSIArguments -PassThru -Wait

Write-Output "[$(Get-Date)]Installing Powershell module..."
Add-WindowsCapability -Online -Name "Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0"

Write-Output "[$(Get-Date)]Connecting Az with MSI..."
Connect-AzAccount -Identity

Write-Output "[$(Get-Date)]Selecting subscription $($SubscriptionId)..."
Select-AzSubscription -Subscription $SubscriptionId

#Storage Account ADDS
Write-Output "[$(Get-Date)]Configuring Storage Account..."
$OUPath = "OU=Computers,OU=Lab,DC=$($DomainName.ToString().Split(".")[0]),DC=$($DomainName.ToString().Split(".")[1])"
New-AzStorageAccountKey -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -KeyName "kerb1"
$Passwd = (Get-AzStorageAccountKey -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -ListKerbKey | where-object { $_.Keyname -contains "kerb1" }).Value

Invoke-Command -Credential $Cred -ComputerName $DCName -ScriptBlock {
    param($StorageAccountName, $OUPath, $Passwd)
    New-ADComputer -Enabled $True -DisplayName $StorageAccountName -Name $StorageAccountName
    Get-ADComputer -Identity $StorageAccountName | Move-ADObject -TargetPath (Get-ADOrganizationalUnit -Identity $OUPath)
    Set-ADComputer -Identity $StorageAccountName -KerberosEncryptionType "AES256"
    setspn -S cifs/$($StorageAccountName).file.core.windows.net $StorageAccountName 
    Get-ADComputer -Identity $StorageAccountName | Set-ADAccountPassword -Reset -NewPassword (ConvertTo-SecureString -AsPlainText $Passwd -Force)   
} -ArgumentList $StorageAccountName, $OUPath, $Passwd

Write-Output "[$(Get-Date)]Joining Storage Account $($StorageAccountName) to Domain..."
Set-AzStorageAccount `
    -ResourceGroupName $ResourceGroupName `
    -Name $StorageAccountName `
    -EnableActiveDirectoryDomainServicesForFile $true `
    -ActiveDirectoryDomainName (Get-ADDomain).DNSRoot `
    -ActiveDirectoryNetBiosDomainName (Get-ADDomain).DNSRoot `
    -ActiveDirectoryForestName (Get-ADDomain).Forest `
    -ActiveDirectoryDomainGuid (Get-ADDomain).ObjectGUID.Guid `
    -ActiveDirectoryDomainsid (Get-ADDomain).DomainSID.Value `
    -ActiveDirectoryAzureStorageSid (Get-ADComputer -Identity $StorageAccountName).SID.Value `
    -ActiveDirectorySamAccountName $StorageAccountName `
    -ActiveDirectoryAccountType "Computer"

New-AzStorageAccountKey -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -KeyName "kerb2"    
$Passwd2 = (Get-AzStorageAccountKey -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -ListKerbKey | where-object { $_.Keyname -contains "kerb2" }).Value
Invoke-Command -Credential $Cred -ComputerName $DCName -ScriptBlock {
    param($StorageAccountName, $Passwd2)
    Get-ADComputer -Identity $StorageAccountName | Set-ADAccountPassword -Reset -NewPassword (ConvertTo-SecureString -AsPlainText $Passwd2 -Force)   
} -ArgumentList $StorageAccountName, $Passwd2

Write-Output "[$(Get-Date)]Configuring NTFS permissions for $($StorageAccountName)..."
$StorageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $ResourceGroupName -Name $StorageAccountName | where-object { $_.Keyname -contains "key1" }).Value

cmd.exe /C "cmdkey /add:`"$($StorageAccountName).file.core.windows.net`" /user:`"localhost\$($StorageAccountName)`" /pass:`"$($StorageAccountKey)`""
cmd.exe /C "icacls \\$($StorageAccountName).file.core.windows.net\$($ShareName) /grant `"$($DomainName)\Domain Admins`":(OI)(CI)(F)"
cmd.exe /C "icacls \\$($StorageAccountName).file.core.windows.net\$($ShareName) /grant `"$($DomainName)\AVDAdmins`":(OI)(CI)(F)"
cmd.exe /C "icacls \\$($StorageAccountName).file.core.windows.net\$($ShareName) /grant `"$($DomainName)\AVDUsers`":(OI)(CI)(M)"
cmd.exe /C "icacls \\$($StorageAccountName).file.core.windows.net\$($ShareName) /grant `"CREATOR OWNER`":(OI)(CI)(IO)(M)"
cmd.exe /C "icacls \\$($StorageAccountName).file.core.windows.net\$($ShareName) /remove `"Authenticated Users`""
cmd.exe /C "icacls \\$($StorageAccountName).file.core.windows.net\$($ShareName) /remove `"Builtin\Users`""
cmd.exe /C "cmdkey /delete:`"$($StorageAccountName).file.core.windows.net`""

#Storage Account AAD
Set-AzStorageAccount -ResourceGroupName $ResourceGroupSecName -StorageAccountName $StorageAccountNameAAD -EnableAzureActiveDirectoryKerberosForFile $true -ActiveDirectoryDomainName $DomainName -ActiveDirectoryDomainGuid (Get-ADDomain).ObjectGUID.Guid

$ProgressPreference = 'SilentlyContinue'
Invoke-WebRequest -Uri https://psg-prod-eastus.azureedge.net/packages/microsoft.graph.authentication.2.3.0.nupkg -OutFile microsoft.graph.authentication.zip
Invoke-WebRequest -Uri https://psg-prod-eastus.azureedge.net/packages/microsoft.graph.identity.signins.2.3.0.nupkg -OutFile .\microsoft.graph.identity.signins.zip
Invoke-WebRequest -Uri https://psg-prod-eastus.azureedge.net/packages/microsoft.graph.applications.2.3.0.nupkg -OutFile .\microsoft.graph.applications.zip
Expand-Archive -Path .\microsoft.graph.identity.signins.zip -DestinationPath .\microsoft.graph.identity.signins -Force
Expand-Archive -Path .\microsoft.graph.authentication.zip -DestinationPath .\microsoft.graph.authentication -Force
Expand-Archive -Path .\microsoft.graph.applications.zip -DestinationPath .\microsoft.graph.applications -Force
Import-Module .\microsoft.graph.authentication
Import-Module .\microsoft.graph.identity.signins
Import-Module .\microsoft.graph.applications

Write-Output "[$(Get-Date)]Joining Storage Account $($StorageAccountNameAAD) to Domain..."
Connect-MgGraph -Identity
$ClientSP = Get-MgServicePrincipal -Filter "DisplayName eq '[Storage Account] $StorageAccountNameAAD.file.core.windows.net'"
$Permissions = @("openid", "profile", "User.Read")
$ScopeToGrant = $Permissions -join " "
$ResourceSp = Get-MgServicePrincipal -Filter "DisplayName eq 'Microsoft Graph'"

$params = @{
	clientId = $ClientSP.Id
	consentType = "AllPrincipals"
    resourceId = $ResourceSp.Id
	scope = $ScopeToGrant
}

New-MgOauth2PermissionGrant -BodyParameter $params

Write-Output "[$(Get-Date)]Configuring NTFS permissions for $($StorageAccountNameAAD)..."
$StorageAccountKeyAAD = (Get-AzStorageAccountKey -ResourceGroupName $ResourceGroupSecName -Name $StorageAccountNameAAD | where-object { $_.Keyname -contains "key1" }).Value

cmd.exe /C "cmdkey /add:`"$($StorageAccountNameAAD).file.core.windows.net`" /user:`"localhost\$($StorageAccountNameAAD)`" /pass:`"$($StorageAccountKeyAAD)`""
cmd.exe /C "icacls \\$($StorageAccountNameAAD).file.core.windows.net\$($ShareName) /grant `"$($DomainName)\Domain Admins`":(OI)(CI)(F)"
cmd.exe /C "icacls \\$($StorageAccountNameAAD).file.core.windows.net\$($ShareName) /grant `"$($DomainName)\AVDAdmins`":(OI)(CI)(F)"
cmd.exe /C "icacls \\$($StorageAccountNameAAD).file.core.windows.net\$($ShareName) /grant `"$($DomainName)\AVDUsers`":(OI)(CI)(M)"
cmd.exe /C "icacls \\$($StorageAccountNameAAD).file.core.windows.net\$($ShareName) /grant `"CREATOR OWNER`":(OI)(CI)(IO)(M)"
cmd.exe /C "icacls \\$($StorageAccountNameAAD).file.core.windows.net\$($ShareName) /remove `"Authenticated Users`""
cmd.exe /C "icacls \\$($StorageAccountNameAAD).file.core.windows.net\$($ShareName) /remove `"Builtin\Users`""
cmd.exe /C "cmdkey /delete:`"$($StorageAccountNameAAD).file.core.windows.net`""