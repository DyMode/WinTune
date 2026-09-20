#requires -Version 5.1
# Module 09 - privacy & de-ads

Register-WTModule '09-privacy' '隐私与去广告' 'Privacy & De-ads' @(
    (New-WTOption -Id 'telemetry' -Zh '诊断数据(遥测)' -En 'Diagnostic data (telemetry)' -MinBuild 10240 `
        -States ([ordered]@{
            'required' = @{ Name = @{ zh = '必需(推荐,最小化)'; en = 'Required (recommended minimum)' }; Rec = $true; Apply = { WReg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry' 1 DWord } }
            'optional' = @{ Name = @{ zh = '可选(系统默认)'; en = 'Optional (default)' }; Rec = $false; Apply = { WReg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry' 3 DWord } }
        }) `
        -GetCurrent {
            $v = Get-WTRegVal 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry'
            if (-not $v.Exists) { 'optional' }
            elseif ($v.Value -le 1) { 'required' } else { 'optional' }
        } `
        -NoteZh '家庭版最低即为"必需"; 企业版可设 0(安全级)' -NoteEn 'Home edition minimum is Required; Enterprise can go to 0.'),
    (New-WTOption -Id 'ad-id' -Zh '广告 ID' -En 'Advertising ID' -MinBuild 10240 -Admin $false `
        -States ([ordered]@{
            'off' = @{ Name = @{ zh = '关闭(推荐)'; en = 'Off (recommended)' }; Rec = $true; Apply = { WReg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' 'Enabled' 0 DWord } }
            'on'  = @{ Name = @{ zh = '开启(默认)'; en = 'On (default)' }; Rec = $false; Apply = { WReg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' 'Enabled' 1 DWord } }
        }) `
        -GetCurrent {
            $v = Get-WTRegVal 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' 'Enabled'
            if ($v.Exists -and $v.Value -eq 0) { 'off' } else { 'on' }
        }),
    (New-WTOption -Id 'search-highlights' -Zh '搜索亮点/热门内容' -En 'Search highlights' -MinBuild 19041 -Admin $false `
        -States ([ordered]@{
            'off' = @{ Name = @{ zh = '关闭(推荐)'; en = 'Off (recommended)' }; Rec = $true; Apply = { WReg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings' 'IsDynamicSearchBoxEnabled' 0 DWord } }
            'on'  = @{ Name = @{ zh = '开启(默认)'; en = 'On (default)' }; Rec = $false; Apply = { WReg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings' 'IsDynamicSearchBoxEnabled' 1 DWord } }
        }) `
        -GetCurrent {
            $v = Get-WTRegVal 'HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings' 'IsDynamicSearchBoxEnabled'
            if ($v.Exists -and $v.Value -eq 0) { 'off' } else { 'on' }
        }),
    (New-WTOption -Id 'spotlight-ads' -Zh '锁屏聚焦广告/建议' -En 'Lock screen Spotlight ads' -MinBuild 10240 -Admin $false `
        -States ([ordered]@{
            'off' = @{ Name = @{ zh = '关闭(推荐)'; en = 'Off (recommended)' }; Rec = $true; Apply = {
                WReg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'RotatingLockScreenEnabled' 0 DWord
                WReg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SoftLandingEnabled' 0 DWord } }
            'on'  = @{ Name = @{ zh = '开启(默认)'; en = 'On (default)' }; Rec = $false; Apply = {
                WReg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'RotatingLockScreenEnabled' 1 DWord
                WReg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SoftLandingEnabled' 1 DWord } }
        }) `
        -GetCurrent {
            $v = Get-WTRegVal 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'RotatingLockScreenEnabled'
            if ($v.Exists -and $v.Value -eq 0) { 'off' } else { 'on' }
        }),
    (New-WTOption -Id 'widgets' -Zh '任务栏小部件(资讯)' -En 'Taskbar widgets / feeds' -MinBuild 10240 -Admin $false `
        -States ([ordered]@{
            'off' = @{ Name = @{ zh = '关闭(推荐)'; en = 'Off (recommended)' }; Rec = $true; Apply = {
                if ($script:WT.Env.Build -ge 22000) { WReg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarDa' 0 DWord }
                else { WReg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Feeds' 'ShellFeedsTaskbarViewMode' 2 DWord } } }
            'on'  = @{ Name = @{ zh = '开启(默认)'; en = 'On (default)' }; Rec = $false; Apply = {
                if ($script:WT.Env.Build -ge 22000) { WReg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarDa' 1 DWord }
                else { WReg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Feeds' 'ShellFeedsTaskbarViewMode' 0 DWord } } }
        }) `
        -GetCurrent {
            if ($script:WT.Env.Build -ge 22000) {
                $v = Get-WTRegVal 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarDa'
            } else {
                $v = Get-WTRegVal 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Feeds' 'ShellFeedsTaskbarViewMode'
                if ($v.Exists -and $v.Value -eq 2) { 'off' } elseif ($v.Exists) { 'on' } else { 'on' }
                return
            }
            if ($v.Exists -and $v.Value -eq 0) { 'off' } else { 'on' }
        }),
    (New-WTOption -Id 'activity-history' -Zh '活动历史记录' -En 'Activity history' -MinBuild 10240 `
        -States ([ordered]@{
            'off' = @{ Name = @{ zh = '关闭(推荐)'; en = 'Off (recommended)' }; Rec = $true; Apply = { WReg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'EnableActivityFeed' 0 DWord } }
            'on'  = @{ Name = @{ zh = '开启(默认)'; en = 'On (default)' }; Rec = $false; Apply = { WReg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'EnableActivityFeed' 1 DWord } }
        }) `
        -GetCurrent {
            $v = Get-WTRegVal 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'EnableActivityFeed'
            if ($v.Exists -and $v.Value -eq 0) { 'off' } else { 'on' }
        })
)
