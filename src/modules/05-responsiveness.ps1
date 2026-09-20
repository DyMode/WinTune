#requires -Version 5.1
# Module 05 - system responsiveness

Register-WTModule '05-responsiveness' '系统响应' 'Responsiveness' @(
    (New-WTOption -Id 'power-throttling' -Zh '电源节流 Power Throttling' -En 'Power Throttling' -MinBuild 16299 `
        -States ([ordered]@{
            'off' = @{ Name = @{ zh = '禁用(推荐,性能优先)'; en = 'Disabled (recommended)' }; Rec = $true; Apply = { WReg 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling' 'PowerThrottlingOff' 1 DWord } }
            'on'  = @{ Name = @{ zh = '启用(默认,省电)'; en = 'Enabled (default)' }; Rec = $false; Apply = { WReg 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling' 'PowerThrottlingOff' 0 DWord } }
        }) `
        -GetCurrent {
            $v = Get-WTRegVal 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling' 'PowerThrottlingOff'
            if ($v.Exists -and $v.Value -eq 1) { 'off' } else { 'on' }
        }),
    (New-WTOption -Id 'hags' -Zh '硬件加速 GPU 调度 HAGS' -En 'Hardware-accelerated GPU scheduling' -MinBuild 19041 `
        -States ([ordered]@{
            'on'  = @{ Name = @{ zh = '开启(推荐,重启生效)'; en = 'On (recommended, reboot required)' }; Rec = $true; Apply = { WReg 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode' 2 DWord } }
            'off' = @{ Name = @{ zh = '关闭(默认)'; en = 'Off (default)' }; Rec = $false; Apply = { WReg 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode' 1 DWord } }
        }) `
        -GetCurrent {
            $v = Get-WTRegVal 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode'
            if ($v.Exists -and $v.Value -eq 2) { 'on' } else { 'off' }
        } `
        -NoteZh '需 WDDM 2.7+ 显卡驱动; 过旧的驱动可能不生效' -NoteEn 'Requires a WDDM 2.7+ display driver.'),
    (New-WTOption -Id 'game-mode' -Zh '游戏模式' -En 'Game Mode' -MinBuild 15063 `
        -States ([ordered]@{
            'on'  = @{ Name = @{ zh = '开启(推荐)'; en = 'On (recommended)' }; Rec = $true; Apply = { WReg 'HKCU:\Software\Microsoft\GameBar' 'AllowAutoGameMode' 1 DWord; WReg 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled' 1 DWord } }
            'off' = @{ Name = @{ zh = '关闭(默认)'; en = 'Off (default)' }; Rec = $false; Apply = { WReg 'HKCU:\Software\Microsoft\GameBar' 'AllowAutoGameMode' 0 DWord } }
        }) `
        -GetCurrent {
            $v = Get-WTRegVal 'HKCU:\Software\Microsoft\GameBar' 'AllowAutoGameMode'
            if ($v.Exists -and $v.Value -eq 1) { 'on' } else { 'off' }
        }),
    (New-WTOption -Id 'gamedvr' -Zh 'GameDVR 后台录制' -En 'GameDVR background recording' -MinBuild 15063 `
        -States ([ordered]@{
            'off' = @{ Name = @{ zh = '关闭(推荐,去除录制开销)'; en = 'Off (recommended)' }; Rec = $true; Apply = { WReg 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled' 0 DWord; WReg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' 0 DWord } }
            'on'  = @{ Name = @{ zh = '开启(默认)'; en = 'On (default)' }; Rec = $false; Apply = { WReg 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled' 1 DWord; WReg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' 1 DWord } }
        }) `
        -GetCurrent {
            $v = Get-WTRegVal 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled'
            if ($v.Exists -and $v.Value -eq 0) { 'off' } else { 'on' }
        }),
    (New-WTOption -Id 'visual-effects' -Zh '视觉效果' -En 'Visual effects' -MinBuild 10240 -Admin $false `
        -States ([ordered]@{
            'best'    = @{ Name = @{ zh = '最佳外观(推荐)'; en = 'Best appearance (recommended)' }; Rec = $true; Apply = { WReg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' 'VisualFXSetting' 1 DWord } }
            'perf'    = @{ Name = @{ zh = '最佳性能'; en = 'Best performance' }; Rec = $false; Apply = { WReg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' 'VisualFXSetting' 2 DWord } }
            'custom'  = @{ Name = @{ zh = '自定义'; en = 'Custom' }; Rec = $false; Apply = { WReg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' 'VisualFXSetting' 3 DWord } }
            'default' = @{ Name = @{ zh = '系统默认(让Windows选择)'; en = 'Let Windows choose (default)' }; Rec = $false; Apply = { WDelReg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' 'VisualFXSetting' } }
        }) `
        -GetCurrent {
            $v = Get-WTRegVal 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' 'VisualFXSetting'
            if (-not $v.Exists) { 'default' }
            elseif ($v.Value -eq 1) { 'best' } elseif ($v.Value -eq 2) { 'perf' } elseif ($v.Value -eq 3) { 'custom' } else { 'custom' }
        } `
        -NoteZh '注销重登后生效; 最佳外观与性能差异极小,推荐保持美观' -NoteEn 'Takes effect after re-logon.')
)
