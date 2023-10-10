# Azure Virtual Desktop Lab
Azure Virtual Desktop built with Terraform and Powershell

Use at your own risk!

This Sample Code is provided for the purpose of illustration only and is not intended to be used in a production environment.
THIS SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED, 
INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
We grant You a nonexclusive, royalty-free right to use and modify the Sample Code and to reproduce and distribute the object code form of the Sample Code, provided that You agree:

(i) to not use Our name, logo, or trademarks to market Your software product in which the Sample Code is embedded;
(ii) to include a valid copyright notice on Your software product in which the Sample Code is embedded;
and (iii) to indemnify, hold harmless, and defend Us and Our suppliers from and against any claims or lawsuits, including attorneys’ fees,
that arise or result from the use or distribution of the Sample Code.

# Lab only

This is just a lab for deploying and learning Azure Virtual Desktop.
Do not use it for production. This is intended to save deployment costs.<br>
This is not following guidelines for performance and best practices. Be aware!

If you need to deploy a production environment for AVD, please start here <br>
https://learn.microsoft.com/en-us/azure/architecture/guide/virtual-desktop/start-here

# Features

```
Active Directory domain deployment through Powershell DSC
Group Policies pre-created for AVD deployments
Microsoft Entra ID (AAD) + Active Directory hybrid identities (ADDS)
Storage Account - Active Directory joined
Storage Account - Azure AD (Microsoft Entra ID) Kerberos joined
Azure File Share configured with NTFS permissions configured
Azure Virtual Desktop (AVD) Private Link
AVD Personal Desktops Host Pool
AVD Pooled Desktops Host Pool
AVD Workspaces
AVD Scaling Plan for Pooled
AVD Start VM on Connect
AVD Scheduled Agent Updates
FSLogix configured for both ADDS and AAD
RBAC configured
```