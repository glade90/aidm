# AIDM-DES-037.1 — targeted Scheduled Task cleanup with operator confirmation.
# Does NOT remove local user, SQL login/grants, Python or preserved proof artifacts.
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('AIDM-Reader-Probe','AIDM-Reader-DES0371')]
    [string]$TaskName
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if (-not $task) {
    Write-Output "NOT_REGISTERED: $TaskName"
    return
}
if ($task.State -eq 'Running') {
    throw 'BLOCKED: task still running; inspect and stop it deliberately before cleanup'
}
if ($PSCmdlet.ShouldProcess($TaskName,'Unregister temporary reader probe')) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction Stop
    Write-Output "CLEANED: $TaskName"
}
