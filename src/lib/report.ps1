#requires -Version 5.1
# WinTune - HTML / Markdown report: full status snapshot + changes, modern card design

function Convert-WTHtmlEncode([string]$s) {
    if ($null -eq $s) { return '' }
    return [System.Web.HttpUtility]::HtmlEncode($s)
}

function Get-WTStatusSnapshot {
    # read-only pass over every option: current state, recommended state, classification
    $rows = @()
    foreach ($module in $script:WT.Modules) {
        foreach ($opt in $module.Options) {
            $avail = Test-WTOptionAvail $opt
            $recKey = $null
            if ($opt.States) { foreach ($k in $opt.States.Keys) { if ($opt.States[$k].Rec) { $recKey = $k; break } } }
            $recLabel = if ($recKey) { Get-WTStateLabel $opt $recKey } else { $null }
            if (-not $avail.Ok) {
                $rows += [pscustomobject]@{ Module = $module.Id; ModuleName = $module.Name[$script:WT.Lang]
                    Option = (Get-WTOptionName $opt); Current = (T '不适用' 'N/A'); Recommended = $recLabel
                    Class = 'na'; Note = $opt.Note[$script:WT.Lang] }
                continue
            }
            $cur = Get-WTOptionCurrent $opt
            $curLabel = if ($opt.Action) { (T '动作项' 'Action') } else { Get-WTStateLabel $opt $cur }
            $class = 'info'
            if ($opt.Action) { $class = 'action' }
            elseif ($cur -eq 'custom') { $class = 'custom' }
            elseif ($recKey -and $cur -eq $recKey) { $class = 'ok' }
            elseif ($recKey) { $class = 'diff' }
            $rows += [pscustomobject]@{ Module = $module.Id; ModuleName = $module.Name[$script:WT.Lang]
                Option = (Get-WTOptionName $opt); Current = $curLabel; Recommended = $recLabel
                Class = $class; Note = $opt.Note[$script:WT.Lang] }
        }
    }
    return $rows
}

function Export-WTReport {
    param(
        [string]$Dir = ([Environment]::GetFolderPath('Desktop')),
        [string]$Title = 'WinTune Report'
    )
    Add-Type -AssemblyName System.Web -ErrorAction SilentlyContinue
    $ts = Get-Date -Format 'yyyyMMdd-HHmmss'
    # html + md go into one folder per run
    $outDir = Join-Path $Dir "WinTune-Report-$ts"
    New-Item -Path $outDir -ItemType Directory -Force | Out-Null
    $htmlPath = Join-Path $outDir "WinTune-Report-$ts.html"
    $mdPath   = Join-Path $outDir "WinTune-Report-$ts.md"
    $env = $script:WT.Env
    $lang = $script:WT.Lang
    $zh = ($lang -eq 'zh')
    $statuses = Get-WTStatusSnapshot

    $classText = @{
        'ok'     = @{ zh = '已达标'; en = 'Aligned';     color = '#16a34a' }
        'diff'   = @{ zh = '可优化'; en = 'Improvable';  color = '#d97706' }
        'custom' = @{ zh = '自定义'; en = 'Custom';      color = '#2563eb' }
        'na'     = @{ zh = '不适用'; en = 'N/A';         color = '#9ca3af' }
        'action' = @{ zh = '动作项'; en = 'Action';      color = '#7c3aed' }
        'info'   = @{ zh = '信息';   en = 'Info';        color = '#6b7280' }
    }

    # ---------- markdown ----------
    $md = New-Object System.Collections.Generic.List[string]
    $md.Add("# $Title")
    $md.Add("")
    $md.Add("- **$(if($zh){'时间'}else{'Time'})**: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    $md.Add("- **OS**: $($env.OsName) (Build $($env.Build) - $($env.VersionName))")
    $md.Add("- **$(if($zh){'设备'}else{'Device'})**: $($env.Computer) ($($env.DeviceType))")
    $md.Add("- **Admin**: $($env.IsAdmin)")
    $md.Add("- **GPU**: $($env.GPUs -join ' | ')")
    $md.Add("")
    $md.Add("## $(if($zh){'配置状态总览'}else{'Configuration status'})")
    $md.Add("")
    $md.Add("| Module | Option | $(if($zh){'当前'}else{'Current'}) | $(if($zh){'推荐'}else{'Recommended'}) | Status |")
    $md.Add("|---|---|---|---|---|")
    foreach ($s in $statuses) {
        $ct = $classText[$s.Class]
        $md.Add("| $($s.Module) | $($s.Option) | $($s.Current) | $($s.Recommended) | $($ct[$lang]) |")
    }
    $md.Add("")
    $md.Add("## $(if($zh){'本次改动'}else{'Changes this run'})")
    $md.Add("")
    $md.Add("| Time | Module | Option | $(if($zh){'改动前'}else{'From'}) | $(if($zh){'改动后'}else{'To'}) | Note |")
    $md.Add("|---|---|---|---|---|---|")
    foreach ($c in $script:WT.Changes) {
        $md.Add("| $($c.Time.ToString('HH:mm:ss')) | $($c.Module) | $($c.Option) | $($c.From) | $($c.To) | $($c.Note) |")
    }
    if ($script:WT.Changes.Count -eq 0) { $md.Add("| - | - | - | - | - | - |") }
    $md.Add("")
    $md.Add("## $(if($zh){'建议'}else{'Suggestions'})")
    $md.Add("")
    $md.Add("- " + (T '重启系统以使所有改动完全生效。' 'Restart the system to fully apply all changes.'))
    if ($env.HasBasicAdapter) { $md.Add("- " + (T '检测到基本显示适配器,建议运行驱动医生。' 'Basic display adapter detected - run Driver Doctor.')) }
    $md -join "`r`n" | Out-File -FilePath $mdPath -Encoding UTF8

    # ---------- html ----------
    $modGroups = foreach ($module in $script:WT.Modules) {
        $modRows = @( $statuses | Where-Object { $_.Module -eq $module.Id } )
        if ($modRows.Count -eq 0) { continue }
        $body = foreach ($s in $modRows) {
            $ct = $classText[$s.Class]
            $badge = "<span class='badge' style='background:$($ct.color)'>$([System.Web.HttpUtility]::HtmlEncode($ct[$lang]))</span>"
            $rec = if ($s.Recommended) { [System.Web.HttpUtility]::HtmlEncode($s.Recommended) } else { "<span class='dim'>-</span>" }
            $note = if ($s.Note) { "<div class='note'>$([System.Web.HttpUtility]::HtmlEncode($s.Note))</div>" } else { '' }
            "<tr><td class='opt'>$([System.Web.HttpUtility]::HtmlEncode($s.Option))$note</td><td>$([System.Web.HttpUtility]::HtmlEncode($s.Current))</td><td>$rec</td><td>$badge</td></tr>"
        }
        "<div class='card'><div class='card-title'>$([System.Web.HttpUtility]::HtmlEncode($module.Name[$lang])) <span class='dim'>[$($module.Id)]</span></div><table><thead><tr><th>$(if($zh){'配置项'}else{'Option'})</th><th>$(if($zh){'当前状态'}else{'Current'})</th><th>$(if($zh){'推荐值'}else{'Recommended'})</th><th>Status</th></tr></thead><tbody>$($body -join "`n")</tbody></table></div>"
    }
    $changeRows = foreach ($c in $script:WT.Changes) {
        $cls = if ($c.To -match 'FAIL|失败') { 'row-fail' } else { 'row-ok' }
        "<tr class='$cls'><td>$($c.Time.ToString('HH:mm:ss'))</td><td>$([System.Web.HttpUtility]::HtmlEncode($c.Module))</td><td>$([System.Web.HttpUtility]::HtmlEncode($c.Option))</td><td>$([System.Web.HttpUtility]::HtmlEncode($c.From))</td><td>$([System.Web.HttpUtility]::HtmlEncode($c.To))</td><td>$([System.Web.HttpUtility]::HtmlEncode($c.Note))</td></tr>"
    }
    if (-not $changeRows) { $changeRows = "<tr><td colspan='6' class='dim'>-</td></tr>" }
    $warn = if ($env.HasBasicAdapter) { "<div class='alert warn'>$([System.Web.HttpUtility]::HtmlEncode((T '检测到基本显示适配器,建议运行驱动医生修复显卡驱动。' 'Basic display adapter detected - run Driver Doctor.')))</div>" } else { '' }
    $eolWarn = if ($env.Build -le 19045) { "<div class='alert warn'>$([System.Web.HttpUtility]::HtmlEncode((T 'Windows 10 已停止支持,建议升级系统。' 'Windows 10 is end-of-life; consider upgrading.')))</div>" } else { '' }

    $html = @"
<!DOCTYPE html>
<html lang="$lang"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>$Title</title>
<style>
:root{--bg:#f3f5f9;--card:#ffffff;--ink:#1f2733;--dim:#8a94a6;--line:#e6eaf1;--accent:#4f6ef7}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);font-family:system-ui,-apple-system,'Segoe UI','Microsoft YaHei',sans-serif;line-height:1.55}
.wrap{max-width:1080px;margin:0 auto;padding:32px 20px 64px}
.hero{background:linear-gradient(135deg,#4f6ef7,#7c3aed);color:#fff;border-radius:16px;padding:26px 30px;margin-bottom:24px;box-shadow:0 8px 24px rgba(79,110,247,.25)}
.hero h1{margin:0 0 4px;font-size:26px}
.hero .sub{opacity:.85;font-size:14px}
.stats{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:14px;margin-bottom:24px}
.stat{background:var(--card);border:1px solid var(--line);border-radius:12px;padding:14px 16px}
.stat .k{font-size:12px;color:var(--dim);text-transform:uppercase;letter-spacing:.04em}
.stat .v{font-size:15px;font-weight:600;margin-top:2px;overflow-wrap:break-word;word-break:keep-all}
h2.sec{font-size:18px;margin:30px 0 14px;display:flex;align-items:center;gap:10px}
h2.sec::before{content:'';width:4px;height:18px;background:var(--accent);border-radius:2px}
.card{background:var(--card);border:1px solid var(--line);border-radius:12px;padding:6px 18px 14px;margin-bottom:16px;box-shadow:0 1px 3px rgba(20,30,60,.05)}
.card-title{font-weight:600;padding:12px 0 4px;font-size:15px}
table{width:100%;border-collapse:collapse;font-size:14px}
th,td{text-align:left;padding:9px 10px;border-bottom:1px solid var(--line);vertical-align:top}
th{color:var(--dim);font-weight:600;font-size:12.5px;text-transform:uppercase;letter-spacing:.03em}
tr:last-child td{border-bottom:none}
.badge{display:inline-block;color:#fff;font-size:12px;font-weight:600;padding:2px 10px;border-radius:999px;white-space:nowrap}
.dim{color:var(--dim)}
.note{font-size:12px;color:var(--dim);margin-top:2px}
.alert{border-radius:10px;padding:12px 16px;margin:14px 0;font-size:14px}
.alert.warn{background:#fff7e6;border:1px solid #ffe1a8;color:#8a5a00}
.row-ok td{background:#f6fdf8}
.row-fail td{background:#fdf4f4}
footer{margin-top:36px;text-align:center;color:var(--dim);font-size:12.5px}
</style></head><body><div class="wrap">
<div class="hero"><h1>$Title</h1><div class="sub">WinTune $($script:WT.Version) · $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</div></div>
<div class="stats">
<div class="stat"><div class="k">OS</div><div class="v">$([System.Web.HttpUtility]::HtmlEncode("$($env.OsName)"))<div class="dim">Build $($env.Build) · $($env.VersionName)</div></div></div>
<div class="stat"><div class="k">$(if($zh){'设备'}else{'Device'})</div><div class="v">$([System.Web.HttpUtility]::HtmlEncode($env.Computer))<div class="dim">$($env.DeviceType)</div></div></div>
<div class="stat"><div class="k">Admin</div><div class="v">$($env.IsAdmin)</div></div>
<div class="stat"><div class="k">GPU</div><div class="v">$([System.Web.HttpUtility]::HtmlEncode(($env.GPUs -join ' | ')))</div></div>
</div>
$warn
$eolWarn
<h2 class="sec">$(if($zh){'配置状态总览'}else{'Configuration status'})</h2>
$($modGroups -join "`n")
<h2 class="sec">$(if($zh){'本次改动'}else{'Changes this run'})</h2>
<div class="card"><table><thead><tr><th>Time</th><th>Module</th><th>Option</th><th>$(if($zh){'改动前'}else{'From'})</th><th>$(if($zh){'改动后'}else{'To'})</th><th>Note</th></tr></thead><tbody>$changeRows</tbody></table></div>
<div class="alert warn">$([System.Web.HttpUtility]::HtmlEncode((T '⚠ 建议重启系统,使所有改动完全生效。' '⚠ Restart the system to fully apply all changes.')))</div>
<footer>Generated by WinTune $($script:WT.Version)</footer>
</div></body></html>
"@
    [System.IO.File]::WriteAllText($htmlPath, $html, (New-Object System.Text.UTF8Encoding $true))
    return @{ Html = $htmlPath; Md = $mdPath; Dir = $outDir }
}
