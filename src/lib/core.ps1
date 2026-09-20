#requires -Version 5.1
# WinTune - core engine
# UTF-8 with BOM is REQUIRED for Windows PowerShell 5.1 (CI enforces this).

$script:WT = @{
    Version   = '0.0.1'
    Lang      = 'zh'
    Changes   = @()     # change records for the current session
    Modules   = @()     # registered modules
    Env       = $null   # environment info (Get-WTEnvironment)
    UndoDir   = (Join-Path $env:LOCALAPPDATA 'WinTune\undo')
    DataDir   = (Join-Path $env:LOCALAPPDATA 'WinTune')
    LogFile   = (Join-Path $env:LOCALAPPDATA 'WinTune\wintune.log')
    PendingUndo = @()
    UndoSeq   = 0
}

function T([string]$zh, [string]$en) {
    if ($script:WT.Lang -eq 'zh') { return $zh }
    return $en
}

function Write-WTLog([string]$msg, [string]$color = 'Gray') {
    $line = "[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $msg
    Add-Content -Path $script:WT.LogFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue
    Write-Host $line -ForegroundColor $color
}

function Add-WTChange([string]$moduleId, [string]$optionId, [string]$from, [string]$to, [string]$note) {
    $script:WT.Changes += [pscustomobject]@{
        Time     = Get-Date
        Module   = $moduleId
        Option   = $optionId
        From     = $from
        To       = $to
        Note     = $note
    }
}

# ---------------- elevation ----------------
function Test-WTAdmin {
    return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-WTElevate {
    # relaunch the current script elevated and exit this process
    $exe  = Join-Path $PSHOME 'powershell.exe'
    if ($PSVersionTable.PSVersion.Major -ge 7) { $exe = (Get-Process -Id $PID).Path }
    $args = @('-NoProfile','-ExecutionPolicy','Bypass','-File', "`"$PSCommandPath`"") + $script:WT.LaunchArgs
    Write-WTLog (T '正在请求管理员权限(UAC)...' 'Requesting administrator privileges (UAC)...') 'Yellow'
    Start-Process -FilePath $exe -Verb RunAs -ArgumentList $args -Wait
    exit
}

# ---------------- registry helpers (with undo snapshot) ----------------
function Get-WTRegVal([string]$path, [string]$name) {
    try {
        $item = Get-ItemProperty -Path $path -Name $name -ErrorAction Stop
        $prop = $item.PSObject.Properties[$name]
        return @{ Exists = $true; Value = $prop.Value; Type = $prop.TypeNameOfValue }
    } catch {
        return @{ Exists = $false; Value = $null; Type = $null }
    }
}

function Set-WTRegVal([string]$path, [string]$name, $value, [string]$type = 'DWord') {
    $cur = Get-WTRegVal $path $name
    if (-not $cur.Exists -or $cur.Value -ne $value -or $cur.Type -ne $type) {
        $script:WT.PendingUndo += @{ Kind = 'reg'; Path = $path; Name = $name
            Exists = $cur.Exists; Value = $cur.Value; Type = $cur.Type }
    }
    if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
    New-ItemProperty -Path $path -Name $name -PropertyType $type -Value $value -Force | Out-Null
}

function Remove-WTRegVal([string]$path, [string]$name) {
    $cur = Get-WTRegVal $path $name
    if ($cur.Exists) {
        $script:WT.PendingUndo += @{ Kind = 'reg'; Path = $path; Name = $name
            Exists = $true; Value = $cur.Value; Type = $cur.Type }
        Remove-ItemProperty -Path $path -Name $name -Force -ErrorAction SilentlyContinue
    }
}

function Set-WTService([string]$name, [string]$startType) {
    $svc = Get-Service -Name $name -ErrorAction SilentlyContinue
    if (-not $svc) { throw "service $name not found" }
    $cur = $svc.StartType.ToString()
    if ($cur -ne $startType) {
        $script:WT.PendingUndo += @{ Kind = 'service'; Name = $name; StartType = $cur }
        Set-Service -Name $name -StartupType $startType
        if ($startType -eq 'Disabled') { Stop-Service -Name $name -Force -ErrorAction SilentlyContinue }
    }
}

function Save-WTUndo([string]$moduleId, [string]$optionId, [string]$from, [string]$to) {
    if ($script:WT.PendingUndo.Count -eq 0) { return }
    if (-not (Test-Path $script:WT.UndoDir)) { New-Item -Path $script:WT.UndoDir -ItemType Directory -Force | Out-Null }
    $script:WT.UndoSeq++
    $file = Join-Path $script:WT.UndoDir ("{0:yyyyMMdd-HHmmss}-{1:D3}.json" -f (Get-Date), $script:WT.UndoSeq)
    @{
        Time     = (Get-Date).ToString('s')
        Module   = $moduleId
        Option   = $optionId
        From     = $from
        To       = $to
        Undo     = $script:WT.PendingUndo
    } | ConvertTo-Json -Depth 5 | Out-File -FilePath $file -Encoding UTF8
    $script:WT.PendingUndo = @()
}

function Restore-WTUndoFile([string]$file) {
    $data = Get-Content $file -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($u in ($data.Undo | Sort-Object -Descending @{ Expression = { [array]::IndexOf($data.Undo, $_) } })) {
        try {
            if ($u.Kind -eq 'reg') {
                if ($u.Exists) {
                    Set-WTRegVal $u.Path $u.Name $u.Value ($u.Type -replace 'System\.','' -replace 'Int32','DWord' -replace 'String','String')
                } else {
                    Remove-WTRegVal $u.Path $u.Name
                }
            } elseif ($u.Kind -eq 'service') {
                Set-Service -Name $u.Name -StartupType $u.StartType
            }
        } catch {
            Write-WTLog (T "回滚失败: $($u.Kind) $($u.Path)$($u.Name) $($_.Exception.Message)" "Rollback failed: $($_.Exception.Message)") 'Red'
        }
    }
    Add-WTChange $data.Module $data.Option ($data.To) ($data.From) (T '撤销改动' 'undo')
}

# convenience aliases used inside module definitions
New-Alias -Name WReg    -Value Set-WTRegVal    -Force
New-Alias -Name WDelReg -Value Remove-WTRegVal -Force
New-Alias -Name WSvc    -Value Set-WTService   -Force

# ---------------- option / module DSL ----------------
function New-WTOption {
    param(
        [Parameter(Mandatory)][string]$Id,
        [string]$Zh,
        [string]$En,
        [hashtable]$States,          # key -> @{Zh;En;Apply={};Rec=$bool}
        [scriptblock]$GetCurrent,     # returns a state key, 'custom', $null
        [int]$MinBuild = 0,
        [ValidateSet('Any','Laptop','Desktop')][string]$Device = 'Any',
        [bool]$Admin = $true,
        [scriptblock]$Action,         # for action-type options (no states)
        [scriptblock]$Available,      # extra runtime probe: return $true/$false
        [string]$NoteZh = '',
        [string]$NoteEn = ''
    )
    [pscustomobject]@{
        Id        = $Id
        Name      = @{ zh = $Zh; en = $En }
        States    = $States
        GetCurrent = $GetCurrent
        MinBuild  = $MinBuild
        Device    = $Device
        Admin     = $Admin
        Action    = $Action
        Available = $Available
        Note      = @{ zh = $NoteZh; en = $NoteEn }
    }
}

function Register-WTModule([string]$Id, [string]$Zh, [string]$En, [object[]]$Options) {
    $script:WT.Modules += [pscustomobject]@{ Id = $Id; Name = @{ zh = $Zh; en = $En }; Options = $Options }
}

function Get-WTOptionName($opt) { return $opt.Name[$script:WT.Lang] }
function Get-WTStateName($state) { return $state.Name[$script:WT.Lang] }

# returns @{Ok=$bool; Reason=''}  Reason key: build / device / admin / probe
function Test-WTOptionAvail($opt) {
    $env = $script:WT.Env
    if ($opt.MinBuild -gt $env.Build) { return @{ Ok = $false; Reason = 'build' } }
    if ($opt.Device -eq 'Laptop' -and $env.DeviceType -ne 'Laptop') { return @{ Ok = $false; Reason = 'device' } }
    if ($opt.Device -eq 'Desktop' -and $env.DeviceType -ne 'Desktop') { return @{ Ok = $false; Reason = 'device' } }
    if ($opt.Admin -and -not $env.IsAdmin) { return @{ Ok = $false; Reason = 'admin' } }
    if ($opt.Available) { if (-not (& $opt.Available)) { return @{ Ok = $false; Reason = 'probe' } } }
    return @{ Ok = $true; Reason = '' }
}

function Get-WTOptionCurrent($opt) {
    if (-not $opt.GetCurrent) { return $null }
    try {
        $r = & $opt.GetCurrent
        if ($r -is [array]) { $r = $r[-1] }   # defensive: scriptblocks must return a single key
        return $r
    } catch { return 'error' }
}

function Get-WTStateLabel($opt, $key) {
    if ($null -eq $key) { return (T '未知' 'unknown') }
    if ($key -eq 'custom') { return (T '自定义' 'custom') }
    if ($key -eq 'error') { return (T '检测失败' 'detect error') }
    if ($opt.States -and $opt.States.ContainsKey($key)) { return (Get-WTStateName $opt.States[$key]) }
    return $key
}

function Invoke-WTOptionApply($module, $opt, [string]$stateKey) {
    $from = Get-WTOptionCurrent $opt
    try {
        if ($stateKey) {
            $st = $opt.States[$stateKey]
            & $st.Apply
        } elseif ($opt.Action) {
            & $opt.Action
        }
        Save-WTUndo $module.Id $opt.Id $from $stateKey
        Add-WTChange $module.Id $opt.Id (Get-WTStateLabel $opt $from) (Get-WTStateLabel $opt $(if ($stateKey) { $stateKey } else { 'action' })) ''
        Write-WTLog ("{0} :: {1} -> {2}" -f (Get-WTOptionName $opt), (Get-WTStateLabel $opt $from), (Get-WTStateLabel $opt $(if($stateKey){$stateKey}else{'action'}))) 'Green'
        return $true
    } catch {
        $script:WT.PendingUndo = @()
        Add-WTChange $module.Id $opt.Id (Get-WTStateLabel $opt $from) (T '失败' 'FAILED') $_.Exception.Message
        Write-WTLog ("{0}: {1}" -f (Get-WTOptionName $opt), $_.Exception.Message) 'Red'
        return $false
    }
}
