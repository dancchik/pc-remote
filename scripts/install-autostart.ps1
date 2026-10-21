# Registers a Task Scheduler task that starts the agent (hidden, no console) when the current user logs on.
# Usage: powershell -ExecutionPolicy Bypass -File scripts\install-autostart.ps1

$ErrorActionPreference = "Stop"

$TaskName = "PC Remote Agent"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$Pythonw = Join-Path $ProjectRoot ".venv\Scripts\pythonw.exe"
$Server = Join-Path $ProjectRoot "agent\server.py"

if (-not (Test-Path $Pythonw)) { throw "Not found: $Pythonw. Create the virtual environment first." }
if (-not (Test-Path (Join-Path $ProjectRoot ".env"))) { throw "Not found: .env. Copy .env.example to .env and set AGENT_TOKEN." }

$User = "$env:USERDOMAIN\$env:USERNAME"

$Action = New-ScheduledTaskAction -Execute $Pythonw -Argument "`"$Server`"" -WorkingDirectory $ProjectRoot
$Trigger = New-ScheduledTaskTrigger -AtLogOn -User $User
# Interactive: runs in the user's desktop session, so screenshots and lock work.
$Principal = New-ScheduledTaskPrincipal -UserId $User -LogonType Interactive -RunLevel Limited
$Settings = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit ([TimeSpan]::Zero) `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -MultipleInstances IgnoreNew

# Replace the task if it already exists (e.g. when re-installing).
Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings `
    -Description "Remote control agent for the PC Remote phone app." | Out-Null

Write-Host "Task '$TaskName' registered. Starting it now..."
Start-ScheduledTask -TaskName $TaskName
Write-Host "Done. Log file: $(Join-Path $ProjectRoot 'logs\agent.log')"
