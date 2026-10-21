# Stops the agent and removes its Task Scheduler task.
# Usage: powershell -ExecutionPolicy Bypass -File scripts\uninstall-autostart.ps1

$ErrorActionPreference = "Stop"

$TaskName = "PC Remote Agent"

$Task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($null -eq $Task) {
    Write-Host "Task '$TaskName' is not installed."
    exit 0
}

Stop-ScheduledTask -TaskName $TaskName
Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
Write-Host "Task '$TaskName' stopped and removed."
