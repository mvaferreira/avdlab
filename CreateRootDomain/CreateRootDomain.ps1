Configuration CreateRootDomain
{
    Param(
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$Admincreds,

        [Parameter(Mandatory)]
        [Array]$DomainParameters
    )

    $DomainName = $DomainParameters[0].DomainName
    $AADDomainName = $DomainParameters[0].AADDomainName
    
    Import-DscResource -ModuleName PSDesiredStateConfiguration, xActiveDirectory, xNetworking, ComputerManagementDSC, xComputerManagement, xDnsServer, NetworkingDsc
    [System.Management.Automation.PSCredential]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($Admincreds.UserName)", $Admincreds.Password)
    $Interface = Get-NetAdapter | Where-Object Name -Like "Ethernet*" | Select-Object -First 1
    $MyIP = ($Interface | Get-NetIPAddress -AddressFamily IPv4 | Select-Object -First 1).IPAddress
    $InterfaceAlias = $($Interface.Name)

    Node localhost
    {
        LocalConfigurationManager {
            RebootNodeIfNeeded = $true
            ConfigurationMode  = "ApplyOnly"
        }
                
        WindowsFeature DNS {
            Ensure = "Present"
            Name   = "DNS"
        }

        WindowsFeature AD-Domain-Services {
            Ensure    = "Present"
            Name      = "AD-Domain-Services"
            DependsOn = "[WindowsFeature]DNS"
        }      

        WindowsFeature DnsTools {
            Ensure    = "Present"
            Name      = "RSAT-DNS-Server"
            DependsOn = "[WindowsFeature]DNS"
        }        

        WindowsFeature GPOTools {
            Ensure    = "Present"
            Name      = "GPMC"
            DependsOn = "[WindowsFeature]DNS"
        }

        WindowsFeature DFSTools {
            Ensure    = "Present"
            Name      = "RSAT-DFS-Mgmt-Con"
            DependsOn = "[WindowsFeature]DNS"
        }        

        WindowsFeature RSAT-AD-Tools {
            Ensure               = "Present"
            Name                 = "RSAT-AD-Tools"
            DependsOn            = "[WindowsFeature]AD-Domain-Services"
            IncludeAllSubFeature = $True
        }

        Firewall EnableSMBFwRule
        {
            Name    = "FPS-SMB-In-TCP"
            Enabled = $True
            Ensure  = "Present"
        }
        
        xDnsServerAddress DnsServerAddress
        {
            Address        = $MyIP
            InterfaceAlias = $InterfaceAlias
            AddressFamily  = 'IPv4'
            DependsOn      = "[WindowsFeature]DNS"
        }

        xADDomain RootDomain
        {
            DomainName                    = $DomainName
            DomainAdministratorCredential = $DomainCreds
            SafemodeAdministratorPassword = $DomainCreds
            DatabasePath                  = "$Env:windir\NTDS"
            LogPath                       = "$Env:windir\NTDS"
            SysvolPath                    = "$Env:windir\SYSVOL"
            DependsOn                     = @("[WindowsFeature]AD-Domain-Services", "[xDnsServerAddress]DnsServerAddress")
        }

        xADOrganizationalUnit Lab
        {
            Ensure    = 'Present'
            Name      = 'Lab'
            Path      = ('DC={0},DC={1}' -f ($DomainName -split '\.')[0], ($DomainName -split '\.')[1])
            DependsOn = '[xADDomain]RootDomain'
        }

        xADOrganizationalUnit Users
        {
            Ensure    = 'Present'
            Name      = 'Users'
            Path      = ('OU=Lab,DC={0},DC={1}' -f ($DomainName -split '\.')[0], ($DomainName -split '\.')[1])
            DependsOn = '[xADOrganizationalUnit]Lab'
        }

        xADOrganizationalUnit Computers
        {
            Ensure    = 'Present'
            Name      = 'Computers'
            Path      = ('OU=Lab,DC={0},DC={1}' -f ($DomainName -split '\.')[0], ($DomainName -split '\.')[1])
            DependsOn = '[xADOrganizationalUnit]Lab'
        }

        xADOrganizationalUnit Hybrid
        {
            Ensure    = 'Present'
            Name      = 'Hybrid'
            Path      = ('OU=Computers,OU=Lab,DC={0},DC={1}' -f ($DomainName -split '\.')[0], ($DomainName -split '\.')[1])
            DependsOn = '[xADOrganizationalUnit]Computers'
        }        
        
        xADOrganizationalUnit Groups
        {
            Ensure    = 'Present'
            Name      = 'Groups'
            Path      = ('OU=Lab,DC={0},DC={1}' -f ($DomainName -split '\.')[0], ($DomainName -split '\.')[1])
            DependsOn = '[xADOrganizationalUnit]Lab'
        }       

        xADGroup AVDComputers
        {
            Ensure    = 'Present'
            GroupName = 'AVDComputers'
            Path      = ('OU=Groups,OU=Lab,DC={0},DC={1}' -f ($DomainName -split '\.')[0], ($DomainName -split '\.')[1])
            DependsOn = '[xADOrganizationalUnit]Groups'
        }
        
        xADUser AVDUser
        {
            Ensure            = 'Present'
            DomainName        = $DomainName
            GivenName         = 'AVD'
            SurName           = 'User'
            UserName          = 'avduser'
            UserPrincipalName = 'avduser@{0}' -f $AADDomainName
            Path              = ("OU=Users,OU=Lab,DC={0},DC={1}" -f ($DomainName -split '\.')[0], ($DomainName -split '\.')[1])
            Password          = $DomainCreds
            Enabled           = $True
            DependsOn         = '[xADOrganizationalUnit]Users'
        }

        xADUser AVDAdmin
        {
            Ensure            = 'Present'
            DomainName        = $DomainName
            GivenName         = 'AVD'
            SurName           = 'User'
            UserName          = 'avdadmin'
            UserPrincipalName = 'avdadmin@{0}' -f $AADDomainName
            Path              = ("OU=Users,OU=Lab,DC={0},DC={1}" -f ($DomainName -split '\.')[0], ($DomainName -split '\.')[1])
            Password          = $DomainCreds
            Enabled           = $True
            DependsOn         = '[xADOrganizationalUnit]Users'
        }
        
        xADGroup AVDUsers
        {
            Ensure    = 'Present'
            GroupName = 'AVDUsers'
            Path      = ('OU=Groups,OU=Lab,DC={0},DC={1}' -f ($DomainName -split '\.')[0], ($DomainName -split '\.')[1])
            Members   = 'AVDUser', 'AVDAdmin'
            DependsOn = '[xADOrganizationalUnit]Groups'
        }

        xADGroup AVDAdmins
        {
            Ensure    = 'Present'
            GroupName = 'AVDAdmins'
            Path      = ('OU=Groups,OU=Lab,DC={0},DC={1}' -f ($DomainName -split '\.')[0], ($DomainName -split '\.')[1])
            Members   = 'AVDAdmin'
            DependsOn = '[xADOrganizationalUnit]Groups'
        }
        
        xADGroup AddToDomainAdmins
        {
            Ensure           = 'Present'
            GroupName        = 'Domain Admins'
            MembersToInclude = 'AVDAdmin'
            DependsOn        = '[xADGroup]AVDAdmins'
        }

        xDnsServerForwarder SetForwarders
        {
            IsSingleInstance = 'Yes'
            IPAddresses      = @('168.63.129.16')
            UseRootHint      = $false
            DependsOn        = @("[WindowsFeature]DNS", "[xADDomain]RootDomain")
        }

        PendingReboot RebootAfterInstallingAD
        {
            Name      = 'RebootAfterInstallingAD'
            DependsOn = @("[xADDomain]RootDomain", "[xDnsServerForwarder]SetForwarders")
        }
    }
}