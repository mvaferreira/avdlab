$ProgressPreference = 'SilentlyContinue'
Invoke-WebRequest -Uri "https://github.com/The-Virtual-Desktop-Team/Virtual-Desktop-Optimization-Tool/archive/refs/tags/2.2.2009.1.zip" -OutFile .\VDOT-2.2.2009.1.zip
Expand-Archive -Path .\VDOT-2.2.2009.1.zip -DestinationPath .\VDOT-2.2.2009.1
& .\VDOT-2.2.2009.1\Virtual-Desktop-Optimization-Tool-2.2.2009.1\Windows_VDOT.ps1 -Optimizations All -AdvancedOptimizations All -AcceptEULA -Verbose

New-Item -ItemType Directory -Path C:\Temp -Force

$Script = {
    $Arguments = @(
        "/Delete"
        "/TN"
        "\SYSPREP"
        "/F"
    )

    Start-Process "C:\windows\system32\schtasks.exe" -ArgumentList $Arguments -PassThru -Wait

    $Arguments = @(
        "/generalize"
        "/oobe"
        "/shutdown"
        "/mode:vm"
    )

    Start-Process "C:\windows\system32\sysprep\sysprep.exe" -ArgumentList $Arguments -PassThru

    Remove-Item -Path "C:\Temp\sysprep.ps1" -Force
}

New-Item -ItemType File -Path C:\Temp -Name sysprep.ps1 -Value $Script -Force
$Action = New-ScheduledTaskAction -Execute 'Powershell.exe' -Argument '-NoProfile -WindowStyle Hidden -Command "C:\Temp\sysprep.ps1"'
$Trigger =  New-ScheduledTaskTrigger -AtStartup 
$Principal = New-ScheduledTaskPrincipal -RunLevel Highest -UserId "SYSTEM"
Register-ScheduledTask -Action $Action -Trigger $Trigger -TaskName "SYSPREP" -Principal $Principal

Restart-Computer -Force