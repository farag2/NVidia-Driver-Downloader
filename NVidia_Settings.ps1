# Turn off services
Get-Service -ServiceName NvTelemetryContainer | Stop-Service | Set-Service -StartupType Manual

# Remove diagnostics tracking scheduled tasks
Unregister-ScheduledTask -TaskName NvProfile*, NvTmMon*, NvTmRep* -Confirm:$false

# Delete telemetry recovery batch files
Remove-Item -Path $env:SystemRoot\NvContainerRecovery.bat, $env:SystemRoot\NvTelemetryContainerRecovery.bat -Force -ErrorAction Ignore

# Turn off Nvidia control panel
Get-Service -ServiceName NVDisplay.ContainerLocalSystem | Stop-Service | Set-Service -StartupType Manual
Stop-Process -Name NVDisplay.Container -Force

# Turn off Ansel
Start-Process -FilePath "$env:ProgramFiles\NVIDIA Corporation\Ansel\Tools\NvCameraEnable.exe" -ArgumentList off

# Delete telemetry logs
Remove-Item -Path "$env:ProgramData\NVIDIA Corporation\NvTelemetry", $env:ProgramData\NVIDIA\NvTelemetryContainer.log* -Recurse -Force -ErrorAction Ignore
