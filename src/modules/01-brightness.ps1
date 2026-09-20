#requires -Version 5.1
# Module 01 - brightness control (laptop only)

$videoSub = 'SUB_VIDEO'
$adaptiveOff = { WReg 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\7516b95f-f776-4464-8c53-06167f40cc99\aded5e82-b909-4619-9949-f5d71dac0bcb' 'Attributes' 2 DWord }
# ADAPTBRIGHT lives in the active power scheme; use powercfg aliases for AC/DC
$applyAdaptive = {
    param($value)
    & powercfg.exe /SETACVALUEINDEX SCHEME_CURRENT SUB_VIDEO ADAPTBRIGHT $value | Out-Null
    & powercfg.exe /SETDCVALUEINDEX SCHEME_CURRENT SUB_VIDEO ADAPTBRIGHT $value | Out-Null
    & powercfg.exe /SETACTIVE SCHEME_CURRENT | Out-Null
}
function Get-WTAdaptiveCurrent {
    $out = & powercfg.exe /QUERY SCHEME_CURRENT SUB_VIDEO ADAPTBRIGHT 2>$null | Out-String
    if ($out -match '0x00000000') { return 'off' }
    if ($out -match '0x00000001') { return 'on' }
    return $null
}

Register-WTModule '01-brightness' '亮度控制' 'Brightness' @(
    (New-WTOption -Id 'adaptive' -Zh '自适应亮度(随光线自动调)' -En 'Adaptive brightness' -Device Laptop -MinBuild 10240 `
        -States ([ordered]@{
            'off' = @{ Name = @{ zh = '关闭(推荐)'; en = 'Off (recommended)' }; Rec = $true; Apply = { & powercfg.exe /SETACVALUEINDEX SCHEME_CURRENT SUB_VIDEO ADAPTBRIGHT 0 | Out-Null; & powercfg.exe /SETDCVALUEINDEX SCHEME_CURRENT SUB_VIDEO ADAPTBRIGHT 0 | Out-Null; & powercfg.exe /SETACTIVE SCHEME_CURRENT | Out-Null } }
            'on'  = @{ Name = @{ zh = '开启'; en = 'On' }; Rec = $false; Apply = { & powercfg.exe /SETACVALUEINDEX SCHEME_CURRENT SUB_VIDEO ADAPTBRIGHT 1 | Out-Null; & powercfg.exe /SETDCVALUEINDEX SCHEME_CURRENT SUB_VIDEO ADAPTBRIGHT 1 | Out-Null; & powercfg.exe /SETACTIVE SCHEME_CURRENT | Out-Null } }
        }) `
        -GetCurrent { Get-WTAdaptiveCurrent } `
        -NoteZh '关闭后屏幕不再忽明忽暗;另可在 设置>系统>显示 关闭 [当光线变化时自动更改亮度]' `
        -NoteEn 'Screen will no longer flicker in brightness.'),
    (New-WTOption -Id 'sensrsvc' -Zh '传感器监控服务 SensrSvc' -En 'Sensor Monitoring Service' -Device Laptop -MinBuild 17763 `
        -States ([ordered]@{
            'disabled' = @{ Name = @{ zh = '禁用(推荐,自动亮度的根源)'; en = 'Disabled (recommended)' }; Rec = $true; Apply = { WSvc SensrSvc Disabled } }
            'manual'   = @{ Name = @{ zh = '手动'; en = 'Manual' }; Rec = $false; Apply = { WSvc SensrSvc Manual } }
            'auto'     = @{ Name = @{ zh = '自动(系统默认)'; en = 'Automatic (default)' }; Rec = $false; Apply = { WSvc SensrSvc Automatic } }
        }) `
        -GetCurrent {
            $s = Get-Service SensrSvc -ErrorAction SilentlyContinue
            if (-not $s) { return $null }
            switch ($s.StartType.ToString()) { 'Disabled' { 'disabled' } 'Manual' { 'manual' } 'Automatic' { 'auto' } default { 'custom' } }
        } `
        -NoteZh '禁用后自动旋转等传感器功能也会失效' -NoteEn 'Auto-rotate and other sensor features will stop working.')
)
