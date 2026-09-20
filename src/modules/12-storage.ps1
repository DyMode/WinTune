#requires -Version 5.1
# Module 12 - disk & maintenance

Register-WTModule '12-storage' '磁盘与维护' 'Disk & Maintenance' @(
    (New-WTOption -Id 'storage-sense' -Zh '存储感知(自动清垃圾)' -En 'Storage Sense' -MinBuild 15063 -Admin $false `
        -States ([ordered]@{
            'on'  = @{ Name = @{ zh = '开启(推荐)'; en = 'On (recommended)' }; Rec = $true; Apply = { WReg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy' '01' 1 DWord } }
            'off' = @{ Name = @{ zh = '关闭(默认)'; en = 'Off (default)' }; Rec = $false; Apply = { WReg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy' '01' 0 DWord } }
        }) `
        -GetCurrent {
            $v = Get-WTRegVal 'HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy' '01'
            if ($v.Exists -and $v.Value -eq 1) { 'on' } else { 'off' }
        }),
    (New-WTOption -Id 'hibernate' -Zh '休眠文件 hiberfil.sys' -En 'Hibernation file' -MinBuild 10240 `
        -States ([ordered]@{
            'off' = @{ Name = @{ zh = '关闭休眠(省 3-8GB,推荐台式机)'; en = 'Disable (frees 3-8GB)' }; Rec = $false; Apply = { & powercfg.exe /hibernate off | Out-Null } }
            'on'  = @{ Name = @{ zh = '保留(默认,笔记本合盖续航)'; en = 'Keep (default)' }; Rec = $false; Apply = { & powercfg.exe /hibernate on | Out-Null } }
        }) `
        -GetCurrent {
            $on = Test-Path "$env:SystemDrive\hiberfil.sys"
            if ($on) { 'on' } else { 'off' }
        }),
    (New-WTOption -Id 'sysmain' -Zh 'SysMain(Superfetch)' -En 'SysMain (Superfetch)' -MinBuild 10240 `
        -States ([ordered]@{
            'disabled' = @{ Name = @{ zh = '禁用(SSD 推荐)'; en = 'Disable (recommended for SSD)' }; Rec = $false; Apply = { WSvc SysMain Disabled } }
            'auto'     = @{ Name = @{ zh = '自动(默认)'; en = 'Automatic (default)' }; Rec = $false; Apply = { WSvc SysMain Automatic; Set-Service SysMain -StartupType Automatic; Start-Service SysMain -ErrorAction SilentlyContinue } }
        }) `
        -GetCurrent {
            $s = Get-Service SysMain -ErrorAction SilentlyContinue
            if (-not $s) { return $null }
            if ($s.StartType -eq 'Disabled') { 'disabled' } else { 'auto' }
        } `
        -NoteZh '机械硬盘建议保持默认; SSD 上收益为负' -NoteEn 'Keep default on HDD; SSD gains are negative.'),
    (New-WTOption -Id 'trim-check' -Zh 'TRIM 状态检测(只读)' -En 'TRIM status check (read-only)' -MinBuild 10240 -Admin $false `
        -Action {
            $out = & fsutil.exe behavior query DisableDeleteNotify 2>$null | Out-String
            if ($out -match '0x00000000') { Write-WTLog (T 'TRIM 已启用 (0)' 'TRIM enabled (0)') 'Green' }
            elseif ($out -match '0x00000001') { Write-WTLog (T 'TRIM 已禁用 (1),建议执行: fsutil behavior set DisableDeleteNotify 0' 'TRIM disabled (1)') 'Yellow' }
            else { Write-WTLog (T "无法解析: $out" "Cannot parse: $out") 'Gray' }
        })
)
