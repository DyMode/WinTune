#requires -Version 5.1
# WinTune - main menu

param(
    [switch]$Auto,
    [switch]$Elevated,
    [ValidateSet('zh','en')][string]$Lang,
    [string]$Repo = 'DyMode/WinTune',
    [string]$Branch = 'main',
    [string]$Jump
)

$ErrorActionPreference = 'Continue'

$root = if ($MyInvocation.MyCommand.Path) { Split-Path (Split-Path $MyInvocation.MyCommand.Path -Parent) -Parent } else { (Get-Location).Path }
. (Join-Path $root 'src\lib\core.ps1')
if (-not $MyInvocation.MyCommand.Path) { $root = (Get-Location).Path; . (Join-Path $root 'src\lib\core.ps1') }

# build relaunch args (needs $script:WT from core.ps1)
$script:WT.LaunchArgs = @()
foreach ($k in $PSBoundParameters.Keys) {
    if ($k -in 'Repo','Branch','Lang') { $script:WT.LaunchArgs += "-$k `"$($PSBoundParameters[$k])`"" }
    elseif ($PSBoundParameters[$k] -is [switch] -and $k -ne 'Elevated') { $script:WT.LaunchArgs += "-$k" }
}
if (-not $Elevated.IsPresent -and ($MyInvocation.MyCommand.Path)) { $script:WT.ScriptPath = $MyInvocation.MyCommand.Path }

. (Join-Path $root 'src\lib\detect.ps1')
. (Join-Path $root 'src\lib\net.ps1')
. (Join-Path $root 'src\lib\report.ps1')
Get-ChildItem (Join-Path $root 'src\modules\*.ps1') | Sort-Object Name | ForEach-Object { . $_.FullName }

if ($Lang) { $script:WT.Lang = $Lang }
$envInfo = Get-WTEnvironment

# ---- elevation strategy: stay unelevated; admin actions relaunch on demand ----
$script:menuPath = $MyInvocation.MyCommand.Path

function Request-WTElevation([string]$JumpTo) {
    if ($script:WT.Env.IsAdmin) { return $true }
    Write-Host (T '需要管理员权限,正在请求 UAC 提权(提权窗口为系统安全机制,属正常现象)...' 'Administrator rights required, requesting UAC (the elevation prompt is a Windows security mechanism)...') -ForegroundColor Yellow
    Start-Sleep -Milliseconds 800
    $psArgs = @('-NoProfile','-ExecutionPolicy','Bypass','-File', "`"$script:menuPath`"", '-Elevated','-Jump', "`"$JumpTo`"") + $script:WT.LaunchArgs
    $shellExe = (Get-Process -Id $PID).Path
    if (-not $shellExe -or $shellExe -notmatch '\.(exe|com)$') { $shellExe = Join-Path $PSHOME 'powershell.exe' }
    $wt = Get-Command wt.exe -ErrorAction SilentlyContinue
    try {
        if (-not [string]::IsNullOrEmpty($env:WT_SESSION) -and $wt) {
            # open the elevated session as a Windows Terminal window
            $line = 'new-tab --title WinTune -- "{0}" {1}' -f $shellExe, ($psArgs -join ' ')
            Start-Process -FilePath $wt.Source -Verb RunAs -ArgumentList $line -Wait
        } else {
            Start-Process -FilePath $shellExe -Verb RunAs -ArgumentList $psArgs -Wait
        }
    } catch {
        Write-Host (T '提权被取消或失败。' 'Elevation was cancelled or failed.') -ForegroundColor Red
    }
    return $false
}

# -Auto must run elevated: request once up front
if ($Auto.IsPresent -and -not $envInfo.IsAdmin -and -not $Elevated.IsPresent -and $script:menuPath) {
    Request-WTElevation 'auto' | Out-Null
    exit
}

# ---------------- UI helpers ----------------
function Show-WTHeader {
    $env = $script:WT.Env
    Write-Host ''
    Write-Host "  WinTune v$($script:WT.Version)" -ForegroundColor Cyan
    Write-Host ("  {0}  |  {1}  |  {2}: {3}" -f $env.VersionName, "$($env.Computer) ($($env.DeviceType))",
        (T '权限' 'Admin'), $(if ($env.IsAdmin) { (T '管理员' 'Administrator') } else { (T '普通' 'Standard') })) -ForegroundColor DarkGray
    if ($env.HasBasicAdapter) { Write-Host ("  ! " + (T '检测到基本显示适配器,建议运行 [06] 驱动医生' 'Basic display adapter detected - run module [06] Driver Doctor')) -ForegroundColor Yellow }
    if ($env.Build -le 19045) { Write-Host ("  ! " + (T 'Windows 10 已停止支持,建议升级; 本工具按兼容模式运行' 'Windows 10 is end-of-life; running in compatibility mode.')) -ForegroundColor Yellow }
    Write-Host ''
}

function Clear-WTScreen { Clear-Host; Show-WTHeader }

function Show-WTSeparator([string]$title) {
    Write-Host ''
    Write-Host "  $title" -ForegroundColor White
    Write-Host ("  " + ('─' * 56)) -ForegroundColor DarkGray
}

function Read-WTChoice([string]$prompt) {
    return Read-Host "`n  $prompt"
}

# ---------------- module menu ----------------
function Show-WTModuleMenu($module) {
    while ($true) {
        Clear-WTScreen
        Show-WTSeparator ("{0}  [{1}]" -f $module.Name[$script:WT.Lang], $module.Id)
        $rows = @()
        $i = 0
        foreach ($opt in $module.Options) {
            $i++
            $avail = Test-WTOptionAvail $opt
            $cur = Get-WTOptionCurrent $opt
            $label = Get-WTStateLabel $opt $cur
            if ($opt.Action) { $label = if ($cur -eq 'ok') { (T '无需处理' 'OK') } else { (T '可执行' 'Run') } }
            Write-Host ''
            if ($avail.Ok) {
                Write-Host ("  [$i] {0}" -f (Get-WTOptionName $opt)) -ForegroundColor White
                Write-Host ("      " + (T '当前' 'Current') + ": $label") -ForegroundColor Green
            } else {
                Write-Host ("  [$i] {0}" -f (Get-WTOptionName $opt)) -ForegroundColor DarkGray
                $reason = switch ($avail.Reason) {
                    'build'  { (T "不适用: 需要 Build $($opt.MinBuild)+" "N/A: requires Build $($opt.MinBuild)+") }
                    'device' { (T '不适用: 此设备类型' 'N/A: device type') }
                    'admin'  { (T '不适用: 需要管理员权限' 'N/A: admin required') }
                    'probe'  { (T '不适用: 当前环境无需/不支持' 'N/A: not needed or unsupported here') }
                    default  { (T '不适用' 'N/A') }
                }
                Write-Host ("      $reason") -ForegroundColor DarkGray
            }
            if ($opt.Note[$script:WT.Lang]) { Write-Host ("      " + $opt.Note[$script:WT.Lang]) -ForegroundColor DarkGray }
            $rows += @{ Opt = $opt; Avail = $avail }
        }
        Write-Host ''
        Write-Host ("  [B] " + (T '返回上一级' 'Back')) -ForegroundColor DarkGray
        $ans = Read-WTChoice (T '选择编号' 'Pick a number')
        if ($ans -match '^(b|B)$') { return }
        $n = 0
        if (-not [int]::TryParse($ans, [ref]$n) -or $n -lt 1 -or $n -gt $rows.Count) { continue }
        $row = $rows[$n - 1]
        if (-not $row.Avail.Ok) { continue }
        $opt = $row.Opt

        if ($opt.Action) {
            Clear-WTScreen
            Show-WTSeparator (Get-WTOptionName $opt)
            if ($opt.Note[$script:WT.Lang]) { Write-Host ("  " + $opt.Note[$script:WT.Lang]) -ForegroundColor DarkGray }
            $c = Read-WTChoice (T '确认执行? (y/n)' 'Run now? (y/n)')
            if ($c -eq 'y') { Invoke-WTOptionApply $module $opt $null | Out-Null; Read-WTChoice (T '按回车继续' 'Press Enter') | Out-Null }
            continue
        }

        # ---- state picker (fresh screen) ----
        Clear-WTScreen
        Show-WTSeparator (Get-WTOptionName $opt)
        $cur = Get-WTOptionCurrent $opt
        Write-Host ("  " + (T '当前状态' 'Current') + ": " + (Get-WTStateLabel $opt $cur)) -ForegroundColor Green
        if ($opt.Note[$script:WT.Lang]) { Write-Host ("  " + $opt.Note[$script:WT.Lang]) -ForegroundColor DarkGray }
        Write-Host ''
        Write-Host ("  " + (T '可选状态:' 'Target states:')) -ForegroundColor White
        $keys = @($opt.States.Keys)
        for ($s = 0; $s -lt $keys.Count; $s++) {
            $mark = if ($opt.States[$keys[$s]].Rec) { ' *' } else { '' }
            Write-Host ("    [{0}] {1}{2}" -f ($s + 1), (Get-WTStateName $opt.States[$keys[$s]]), $mark)
        }
        Write-Host (T '    (*) = 一键优化推荐值' '    (*) = recommended') -ForegroundColor DarkGray
        $sa = Read-WTChoice (T '选择目标状态(回车取消)' 'Pick target state (Enter to cancel)')
        $sn = 0
        if (-not [int]::TryParse($sa, [ref]$sn) -or $sn -lt 1 -or $sn -gt $keys.Count) { continue }
        $targetKey = $keys[$sn - 1]
        Write-Host ''
        Write-Host ("  " + (T '变更预览' 'Preview') + ": " + (Get-WTStateLabel $opt $cur) + "  ->  " + (Get-WTStateLabel $opt $targetKey)) -ForegroundColor Yellow
        $conf = Read-WTChoice (T '确认执行? (y/n)' 'Confirm? (y/n)')
        if ($conf -eq 'y') {
            Invoke-WTOptionApply $module $opt $targetKey | Out-Null
            Read-WTChoice (T '按回车继续' 'Press Enter') | Out-Null
        }
    }
}

# ---------------- one-click tune ----------------
function Invoke-WTOneClickTune {
    Clear-WTScreen
    Show-WTSeparator (T '一键优化(全部推荐值 *)' 'One-click tune (all recommended *)')
    Write-Host ("  " + (T '将把每个可用选项设置为推荐值; 已是推荐值的项自动跳过。' 'Every available option will be set to its recommended state; already-recommended items are skipped.')) -ForegroundColor Gray
    $c = Read-WTChoice (T '继续? (y/n)' 'Continue? (y/n)')
    if ($c -ne 'y') { return }
    foreach ($module in $script:WT.Modules) {
        foreach ($opt in $module.Options) {
            if ($opt.Action) { continue }
            $avail = Test-WTOptionAvail $opt
            if (-not $avail.Ok) { continue }
            $rec = $null
            foreach ($k in $opt.States.Keys) { if ($opt.States[$k].Rec) { $rec = $k; break } }
            if (-not $rec) { continue }
            $cur = Get-WTOptionCurrent $opt
            if ($cur -eq $rec) { continue }
            Invoke-WTOptionApply $module $opt $rec | Out-Null
        }
    }
    Write-Host ''
    Write-Host ("  " + (T '一键优化完成。' 'One-click tune finished.')) -ForegroundColor Green
    Read-WTChoice (T '按回车继续' 'Press Enter') | Out-Null
}

# ---------------- status report ----------------
function Show-WTStatusReport {
    Clear-WTScreen
    Show-WTSeparator (T '当前状态一览(只读)' 'Current status (read-only)')
    foreach ($module in $script:WT.Modules) {
        Write-Host ''
        Write-Host ("  [{0}] {1}" -f $module.Id, $module.Name[$script:WT.Lang]) -ForegroundColor Cyan
        foreach ($opt in $module.Options) {
            $avail = Test-WTOptionAvail $opt
            $label = if ($avail.Ok) { Get-WTStateLabel $opt (Get-WTOptionCurrent $opt) } else { (T '不适用' 'N/A') }
            Write-Host ("    - {0}: {1}" -f (Get-WTOptionName $opt), $label)
        }
    }
    Read-WTChoice (T '按回车返回' 'Press Enter to go back') | Out-Null
}

# ---------------- restore ----------------
function Show-WTRestoreMenu {
    while ($true) {
        Clear-WTScreen
        Show-WTSeparator (T '还原 / 撤销' 'Restore / Undo')
        $files = @()
        if (Test-Path $script:WT.UndoDir) { $files = @(Get-ChildItem $script:WT.UndoDir -Filter '*.json' | Sort-Object Name -Descending) }
        if ($files.Count -eq 0) { Write-Host ("  " + (T '没有可撤销的改动记录。' 'No undo records.')) -ForegroundColor Gray }
        $i = 0
        foreach ($f in $files) {
            $i++
            $d = Get-Content $f.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
            Write-Host ("  [$i] {0}  {1} :: {2}  ({3} -> {4})" -f $d.Time, $d.Module, $d.Option, $d.From, $d.To)
        }
        Write-Host ''
        Write-Host ("  [A] " + (T '全部撤销(从新到旧)' 'Undo all (newest first)')) -ForegroundColor DarkGray
        Write-Host ("  [B] " + (T '返回' 'Back')) -ForegroundColor DarkGray
        $ans = Read-WTChoice (T '选择' 'Pick')
        if ($ans -match '^(b|B)$') { return }
        if ($ans -match '^(a|A)$') {
            foreach ($f in $files) { Restore-WTUndoFile $f.FullName }
            Write-Host ("  " + (T '已全部撤销。' 'All undone.')) -ForegroundColor Green
            Read-WTChoice (T '按回车继续' 'Press Enter') | Out-Null
            continue
        }
        $n = 0
        if ([int]::TryParse($ans, [ref]$n) -and $n -ge 1 -and $n -le $files.Count) {
            Restore-WTUndoFile $files[$n - 1].FullName
            Write-Host ("  " + (T '已撤销。' 'Undone.')) -ForegroundColor Green
            Read-WTChoice (T '按回车继续' 'Press Enter') | Out-Null
        }
    }
}

function Offer-WTReport {
    $c = Read-WTChoice (T '生成报告到桌面? (y/n)' 'Generate a report on the Desktop? (y/n)')
    if ($c -ne 'y') { return }
    $r = Export-WTReport
    Write-Host ("  " + (T "报告已生成: $($r.Html)") ) -ForegroundColor Green
}

# ---------------- module browser ----------------
function Show-WTModuleBrowser {
    while ($true) {
        Clear-WTScreen
        Show-WTSeparator (T '模块列表' 'Modules')
        Write-Host ''
        for ($m = 0; $m -lt $script:WT.Modules.Count; $m++) {
            $mod = $script:WT.Modules[$m]
            Write-Host ("  [{0}]  {1}" -f ($m + 1), $mod.Name[$script:WT.Lang]) -ForegroundColor White
        }
        Write-Host ''
        Write-Host ("  [B]  " + (T '返回主菜单' 'Back to main menu')) -ForegroundColor DarkGray
        $ma = Read-WTChoice (T '选择模块' 'Pick a module')
        if ($ma -match '^(b|B)$') { return }
        $mn = 0
        if ([int]::TryParse($ma, [ref]$mn) -and $mn -ge 1 -and $mn -le $script:WT.Modules.Count) {
            Show-WTModuleMenu $script:WT.Modules[$mn - 1]
        }
    }
}

# ---------------- entry ----------------
Show-WTHeader

# elevated one-shot child (launched by Request-WTElevation)
if ($Jump -and ($Elevated.IsPresent -or $envInfo.IsAdmin)) {
    switch ($Jump) {
        'optimize' {
            Invoke-WTOneClickTune
            Offer-WTReport
        }
        'modules' {
            Show-WTModuleBrowser
            if ($script:WT.Changes.Count -gt 0) { Clear-WTScreen; Show-WTSeparator (T '完成' 'Done'); Offer-WTReport }
        }
        'restore' { Show-WTRestoreMenu }
        'auto'    { $Auto = [switch]$true }
    }
    if ($Jump -ne 'auto') { return }
}

if ($Auto.IsPresent) {
    $script:WT.Changes = @()
    foreach ($module in $script:WT.Modules) {
        foreach ($opt in $module.Options) {
            if ($opt.Action) { continue }
            $avail = Test-WTOptionAvail $opt
            if (-not $avail.Ok) { continue }
            $rec = $null
            foreach ($k in $opt.States.Keys) { if ($opt.States[$k].Rec) { $rec = $k; break } }
            if (-not $rec) { continue }
            $cur = Get-WTOptionCurrent $opt
            if ($cur -eq $rec) { continue }
            Invoke-WTOptionApply $module $opt $rec | Out-Null
        }
    }
    $r = Export-WTReport
    Write-Host (T "完成。报告: $($r.Html)" "Done. Report: $($r.Html)") -ForegroundColor Green
    exit
}

while ($true) {
    Clear-WTScreen
    Show-WTSeparator (T '主菜单' 'Main menu')
    Write-Host ''
        $mainItems = @(
            @('1', (T '一键优化' 'Tune all'),      (T '全部推荐值,适合新装机' 'Apply every recommended state')),
            @('2', (T '模块自选' 'Pick modules'),  (T '按模块逐项查看/切换' 'Browse and set item by item')),
            @('3', (T '状态一览' 'Status'),         (T '只读检测,不做任何改动' 'Read-only inspection')),
            @('4', (T '还原' 'Restore'),            (T '撤销某次改动或全部撤销' 'Undo changes (selective or all)')),
            @('R', (T '生成报告' 'Report'),         (T 'HTML + Markdown 输出到桌面' 'HTML + Markdown on Desktop')),
            @('L', (T '语言' 'Language'),           (T '切换 中文 / English' 'Switch ZH / EN')),
            @('0', (T '退出' 'Exit'),               (T '退出前可生成报告' 'Optionally export a report'))
        )
        foreach ($mi in $mainItems) {
            Write-Host ("  [{0}]  {1}" -f $mi[0], $mi[1]) -ForegroundColor White
            Write-Host ("       {0}" -f $mi[2]) -ForegroundColor DarkGray
        }    $ans = Read-WTChoice (T '请选择' 'Select')
    switch -Regex ($ans) {
        '^1' { if (Request-WTElevation 'optimize') { Invoke-WTOneClickTune } }
        '^2' { if (Request-WTElevation 'modules') { Show-WTModuleBrowser } }
        '^3' { Show-WTStatusReport }
        '^4' { if (Request-WTElevation 'restore') { Show-WTRestoreMenu } }
        '^[rR]' { Clear-WTScreen; Show-WTSeparator (T '生成报告' 'Report'); Offer-WTReport }
        '^[lL]' { $script:WT.Lang = if ($script:WT.Lang -eq 'zh') { 'en' } else { 'zh' } }
        '^0' {
            Clear-WTScreen
            Show-WTSeparator (T '退出' 'Exit')
            if ($script:WT.Changes.Count -gt 0) { Offer-WTReport }
            Write-Host ''
            Write-Host ("  " + (T '建议重启系统以使所有改动完全生效。' 'Restart the system to fully apply all changes.')) -ForegroundColor Yellow
            Write-Host ''
            return
        }
    }
}
