# AIDM-DES-037.1 — read-only Task Scheduler triage, safe for remote admin.
# No password, task registration, permissions, or SQL connection is changed.
[CmdletBinding()]
param(
    [ValidateSet('AIDM-Reader-Probe','AIDM-Reader-DES0371')]
    [string]$TaskName = 'AIDM-Reader-Probe',
    [int]$Minutes = 60
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ($Minutes -lt 1 -or $Minutes -gt 1440) { throw 'Minutes must be 1..1440' }
$task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if (-not $task) {
    Write-Output "NOT_REGISTERED: $TaskName"
    exit 3
}
$info = Get-ScheduledTaskInfo -TaskName $TaskName
$last = [long]$info.LastTaskResult
$status = switch ($last) {
    267011 { 'NOT_YET_RUN_0x41303' }
    267009 { 'STILL_RUNNING_0x41301' }
    0 { 'LAST_TASK_EXIT_ZERO_NOT_SUFFICIENT_ALONE' }
    default { 'NONZERO_OR_UNKNOWN_RESULT' }
}
# Never print task action arguments: they could contain past sensitive data.
[PSCustomObject]@{
    Task = $TaskName
    TaskState = [string]$task.State
    Principal = [string]$task.Principal.UserId
    LogonType = [string]$task.Principal.LogonType
    RunLevel = [string]$task.Principal.RunLevel
    LastResultHex = ('0x{0:X8}' -f ($last -band 0xffffffffL))
    ResultInterpretation = $status
    LastRunTime = $info.LastRunTime
} | Format-List
try {
    $events = @(Get-WinEvent -FilterHashtable @{
        LogName = 'Microsoft-Windows-TaskScheduler/Operational'
        StartTime = (Get-Date).AddMinutes(-$Minutes)
    } -ErrorAction Stop | Where-Object {
        @($_.Properties | ForEach-Object { [string]$_.Value }) -match [regex]::Escape($TaskName)
    } | Select-Object -Last 20)
    # Only nonsecret event identifiers, time and level; not event messages.
    foreach ($evt in $events) {
        [PSCustomObject]@{
            EventUtc = $evt.TimeCreated.ToUniversalTime().ToString('o')
            EventId = $evt.Id
            EventLevel = $evt.LevelDisplayName
        }
    }
    if ($events.Count -eq 0) { Write-Output 'NO_TASK_EVENTS_IN_WINDOW' }
} catch {
    Write-Output 'TASK_OPERATIONAL_LOG_NOT_AVAILABLE; enable/inspect locally with approval'
}
