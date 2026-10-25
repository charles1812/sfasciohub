# Registra (o aggiorna) l'attività pianificata di Windows che esegue tool/backup.sh ogni giorno alle 13:00.
# Se il PC era spento a quell'ora, parte appena si accende. Per toglierla:
#   Unregister-ScheduledTask -TaskName "SfascioHub backup" -Confirm:$false
$bash = "C:\Program Files\Git\bin\bash.exe"
$script = (Resolve-Path "$PSScriptRoot\backup.sh").Path -replace '\', '/'
$action = New-ScheduledTaskAction -Execute $bash -Argument "-lc `"'$script' >> ~/SfascioHub-Backup/schedule.log 2>&1`""
$trigger = New-ScheduledTaskTrigger -Daily -At 13:00
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -RunOnlyIfNetworkAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 30)
Register-ScheduledTask -TaskName "SfascioHub backup" -Action $action -Trigger $trigger -Settings $settings `
  -Description "Copia di sicurezza di database e foto di SfascioHub" -Force | Out-Null
Write-Host "Attività 'SfascioHub backup' registrata: ogni giorno alle 13:00."
