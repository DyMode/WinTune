#requires -Version 5.1
# WinTune - environment detection (OS capability, device type, hardware)

function Get-WTVersionName([int]$build) {
    # Known builds; anything newer maps to the newest known branch (forward-compatible).
    $map = @{
        10240 = 'Windows 10 1507'; 10586 = 'Windows 10 1511'; 14393 = 'Windows 10 1607'
        15063 = 'Windows 10 1703'; 16299 = 'Windows 10 1709'; 17134 = 'Windows 10 1803'
        17763 = 'Windows 10 1809'; 18362 = 'Windows 10 1903'; 18363 = 'Windows 10 1909'
        19041 = 'Windows 10 2004'; 19042 = 'Windows 10 20H2'; 19043 = 'Windows 10 21H1'
        19044 = 'Windows 10 21H2'; 19045 = 'Windows 10 22H2 (EOL)'
        22000 = 'Windows 11 21H2'; 22621 = 'Windows 11 22H2'; 22631 = 'Windows 11 23H2'
        26100 = 'Windows 11 24H2'; 26200 = 'Windows 11 25H2'
        26300 = 'Windows 11 26H2'
    }
    if ($map.ContainsKey($build)) { return $map[$build] }
    if ($build -gt 26300) { return "Windows 11 26H2+ (Build $build)" }
    if ($build -gt 19045) { return "Windows 11 (Build $build)" }
    return "Windows 10 (Build $build)"
}

function Get-WTDeviceType {
    $laptopChassis = 8,9,10,11,12,14,18,21,30,31,32
    try {
        $chassis = (Get-CimInstance Win32_SystemEnclosure -ErrorAction Stop).ChassisTypes
        foreach ($c in $chassis) { if ($laptopChassis -contains $c) { return 'Laptop' } }
    } catch {}
    try {
        $bat = Get-CimInstance Win32_Battery -ErrorAction Stop
        if ($bat) { return 'Laptop' }
    } catch {}
    return 'Desktop'
}

function Get-WTEnvironment {
    $os = Get-CimInstance Win32_OperatingSystem
    $cs = Get-CimInstance Win32_ComputerSystem
    $gpus = @()
    try {
        $gpus = @(Get-CimInstance Win32_VideoController | ForEach-Object { $_.Name })
    } catch {}
    $basicAdapter = @($gpus | Where-Object { $_ -match 'Basic Display|基本显示' })
    # pwsh detection: process PATH first, then host version, then well-known install paths
    # (process PATH may predate a fresh per-user PATH entry until next logon)
    $pwshPath = $null
    $pwshCmd = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($pwshCmd) { $pwshPath = $pwshCmd.Source }
    if (-not $pwshPath -and $PSVersionTable.PSVersion.Major -ge 7) { $pwshPath = (Get-Process -Id $PID).Path }
    foreach ($cand in @("$env:LOCALAPPDATA\Programs\PowerShell\7\pwsh.exe", "$env:ProgramFiles\PowerShell\7\pwsh.exe")) {
        if (-not $pwshPath -and (Test-Path $cand)) { $pwshPath = $cand }
    }
    $env = [pscustomobject]@{
        Build       = [int]$os.BuildNumber
        VersionName = Get-WTVersionName ([int]$os.BuildNumber)
        Edition     = $os.Caption
        OsName      = $os.Caption
        Computer    = "$($cs.Manufacturer) $($cs.Model)"
        DeviceType  = Get-WTDeviceType
        IsAdmin     = Test-WTAdmin
        GPUs        = $gpus
        HasBasicAdapter = ($basicAdapter.Count -gt 0)
        PwshPath    = $pwshPath
    }
    $script:WT.Env = $env
    return $env
}
