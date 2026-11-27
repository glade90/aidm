# AIDM-DES-037.1 — owner-admin installation of ONE-SHOT limited reader proof.
# This runs under an approved elevated administrator session on PEQUOD only.
# AIDM_Reader is never elevated; no SQL rights, source records, or passwords are changed.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$RepoRoot,
    [Parameter(Mandatory = $true)][string]$PythonExe,
    [Parameter(Mandatory = $true)][string]$Server,
    [ValidateSet('ODBC Driver 17 for SQL Server','ODBC Driver 18 for SQL Server')]
    [string]$Driver = 'ODBC Driver 17 for SQL Server'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$TaskName = 'AIDM-Reader-DES0371'
$ReaderAccount = "$env:COMPUTERNAME\AIDM_Reader"
$BaseDir = Join-Path $env:ProgramData 'AIDM\Reader0371'
$RuntimeDir = Join-Path $BaseDir 'Runtime'
$ReportDir = Join-Path $BaseDir 'Reports'
$TaskCreated = $false

function Fail([string]$code) { throw "BLOCKED: $code" }

function Set-OnlyReaderAcl([string]$Path, [string]$Rights) {
    # No permissions on the owner's home/profile or original source checkout.
    $readerGrant = "$($ReaderAccount):(OI)(CI)$Rights"
    & icacls.exe $Path '/inheritance:r' '/grant:r' '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' $readerGrant | Out-Null
    if ($LASTEXITCODE -ne 0) { Fail 'FAILED_TO_SET_PRIVATE_ACL' }
}

function Quote-TaskValue([string]$value) {
    if ($value.Contains('"') -or $value.Contains([char]13) -or $value.Contains([char]10)) {
        Fail 'INVALID_TASK_ARGUMENT'
    }
    return '"' + $value + '"'
}

try {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Fail 'OWNER_ADMIN_REQUIRED_FOR_SETUP_ONLY'
    }
    if (-not $env:ProgramData -or -not $env:COMPUTERNAME) { Fail 'WINDOWS_HOST_REQUIRED' }

    $reader = Get-LocalUser -Name 'AIDM_Reader' -ErrorAction Stop
    if (-not $reader.Enabled) { Fail 'LOCAL_READER_DISABLED' }
    $administrators = Get-LocalGroup -SID 'S-1-5-32-544'
    $adminMembers = @(Get-LocalGroupMember -Group $administrators.Name)
    if (@($adminMembers | Where-Object { $_.SID -eq $reader.SID }).Count -gt 0) {
        Fail 'READER_MUST_NOT_BE_ADMIN'
    }

    $RepoRoot = [IO.Path]::GetFullPath($RepoRoot)
    $PythonExe = [IO.Path]::GetFullPath($PythonExe)
    if (-not (Test-Path -LiteralPath $RepoRoot -PathType Container)) { Fail 'REPO_MISSING' }
    if (-not (Test-Path -LiteralPath $PythonExe -PathType Leaf)) { Fail 'SHARED_PYTHON_MISSING' }
    if ($PythonExe -notmatch '^[A-Za-z]:\\(Program Files( \(x86\))?|ProgramData)\\') {
        Fail 'PYTHON_MUST_BE_IN_SHARED_INSTALL_NOT_PERSONAL_PROFILE'
    }
    if ($Server -notmatch '^[A-Za-z0-9_.()\\-]{1,128}$') {
        Fail 'INVALID_LOCAL_SQL_SERVER'
    }
    $hostPart = $Server.Split('\')[0].ToLowerInvariant()
    if ($hostPart -notin @('.','(local)','localhost',$env:COMPUTERNAME.ToLowerInvariant())) {
        Fail 'SQL_MUST_BE_ON_PEQUOD'
    }

    $SourceFile = Join-Path $RepoRoot 'aidm\reader_probe.py'
    if (-not (Test-Path -LiteralPath $SourceFile -PathType Leaf)) {
        Fail 'SOURCE_SHA_MISSING_READER_PROBE'
    }
    $gitSha = (& git.exe -C $RepoRoot rev-parse HEAD 2>$null | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $gitSha -notmatch '^[0-9a-f]{40}$') { Fail 'SOURCE_REVISION_MISSING' }
    $dirty = & git.exe -C $RepoRoot status --porcelain
    if ($LASTEXITCODE -ne 0 -or $dirty) { Fail 'SOURCE_CHECKOUT_MUST_BE_CLEAN' }
    if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
        Fail 'PROBE_TASK_ALREADY_EXISTS_REVIEW_BEFORE_RETRY'
    }

    # A shared Python + site-installed pyodbc must work independently of owner.
    & $PythonExe -I -c 'import pyodbc' *> $null
    if ($LASTEXITCODE -ne 0) { Fail 'INSTALL_PYODBC_IN_SHARED_RUNTIME' }

    New-Item -ItemType Directory -Path $RuntimeDir -Force | Out-Null
    New-Item -ItemType Directory -Path $ReportDir -Force | Out-Null
    Set-OnlyReaderAcl -Path $BaseDir -Rights 'RX'
    Set-OnlyReaderAcl -Path $RuntimeDir -Rights 'RX'
    Set-OnlyReaderAcl -Path $ReportDir -Rights 'M'
    $ProbePath = Join-Path $RuntimeDir 'reader_probe.py'
    Copy-Item -LiteralPath $SourceFile -Destination $ProbePath -Force
    # Reader is not permitted to change the audited executable code.
    $readerFileGrant = "$($ReaderAccount):RX"
    & icacls.exe $ProbePath '/inheritance:r' '/grant:r' '*S-1-5-18:F' '*S-1-5-32-544:F' $readerFileGrant | Out-Null
    if ($LASTEXITCODE -ne 0) { Fail 'CODE_ACL_INVALID' }

    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
    $ReportFile = Join-Path $ReportDir "proof-$stamp.json"
    $arguments = @(
        '-I', (Quote-TaskValue $ProbePath),
        '--server', (Quote-TaskValue $Server),
        '--driver', (Quote-TaskValue $Driver),
        '--expected-account', (Quote-TaskValue $ReaderAccount),
        '--source-sha', (Quote-TaskValue $gitSha),
        '--report-file', (Quote-TaskValue $ReportFile)
    ) -join ' '
    $action = New-ScheduledTaskAction -Execute $PythonExe -Argument $arguments -WorkingDirectory $RuntimeDir
    $settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Seconds 60) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew

    # Register-ScheduledTask's User parameter set accepts a password and
    # explicit LIMITED RunLevel. Never pass the password on a shell command line.
    $secure = Read-Host "Dedicated reader account password (hidden)" -AsSecureString
    $bstr = [IntPtr]::Zero
    $plaintext = $null
    try {
        $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
        $plaintext = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
        Register-ScheduledTask -TaskName $TaskName -Action $action -Settings $settings -User $ReaderAccount -Password $plaintext -RunLevel Limited -Description 'One-shot AIDM read-only identity audit' -ErrorAction Stop | Out-Null
        $TaskCreated = $true
    } finally {
        $plaintext = $null
        if ($bstr -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
        $secure.Dispose()
    }

    $registered = Get-ScheduledTask -TaskName $TaskName
    if ($registered.Principal.UserId -ine $ReaderAccount -or
        $registered.Principal.RunLevel -ne 'Limited' -or
        $registered.Principal.LogonType -ne 'Password') {
        Fail 'SCHEDULED_TASK_PRINCIPAL_UNVERIFIED'
    }
    Start-ScheduledTask -TaskName $TaskName
    $lastResult = 267011  # 0x41303 means "has not run", NOT a Python error.
    for ($n = 0; $n -lt 30; $n++) {
        Start-Sleep -Seconds 1
        $taskInfo = Get-ScheduledTaskInfo -TaskName $TaskName
        $lastResult = [long]$taskInfo.LastTaskResult
        if ($lastResult -eq 0 -and (Test-Path -LiteralPath $ReportFile -PathType Leaf)) { break }
        if ($lastResult -notin @(0,267011,267009)) { break }
    }

    if (-not (Test-Path -LiteralPath $ReportFile -PathType Leaf)) {
        Write-Output ("BLOCKED: NO_PROCESS_REPORT; LastTaskResult=0x{0:X}" -f $lastResult)
        Write-Output 'Review Microsoft-Windows-TaskScheduler/Operational events; no reader runtime proved.'
        exit 3
    }
    $receipt = Get-Content -LiteralPath $ReportFile -Raw | ConvertFrom-Json
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $ProbePath).Hash.ToLowerInvariant()
    Write-Output ("AttestationPath: " + $ReportFile)
    Write-Output ("SourceSHA: " + $gitSha)
    Write-Output ("ReaderScriptSHA256: " + $hash)
    Write-Output ("TaskLastResult: " + $lastResult)
    Write-Output ("ProofStatus: " + $receipt.status)
    Write-Output ("ProofReason: " + $receipt.reason)
    if ($lastResult -ne 0 -or $receipt.status -ne 'PASS' -or
        $receipt.source_sha -ne $gitSha -or $receipt.script_sha256 -ne $hash -or
        $receipt.process_account -ine $ReaderAccount -or
        @($receipt.objects).Count -ne 3) {
        Fail 'READER_PROCESS_ATTESTATION_FAILED'
    }
    Write-Output 'PASS: Windows process, SQL login, three SELECT-only objects verified.'
    exit 0
}
catch {
    # Never dump credentials, ODBC errors or user-specific filesystem paths.
    Write-Output 'BLOCKED: setup, task execution or reader proof failed.'
    exit 3
}
finally {
    if ($TaskCreated) {
        try { Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction Stop }
        catch { Write-Output 'WARNING: MANUAL_TASK_CLEANUP_REQUIRED' }
    }
    # Deliberately do not delete legacy AIDM-Reader-Probe without owner review.
}
