#requires -Version 5.1
# Module 11 - explorer preferences

$psHereKey = 'HKLM:\SOFTWARE\Classes\Directory\Background\shell\PowerShellHere'

Register-WTModule '11-explorer' '资源管理器偏好' 'Explorer Preferences' @(
    (New-WTOption -Id 'file-ext' -Zh '显示文件扩展名' -En 'Show file extensions' -MinBuild 10240 -Admin $false `
        -States ([ordered]@{
            'show' = @{ Name = @{ zh = '显示(推荐)'; en = 'Show (recommended)' }; Rec = $true; Apply = { WReg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'HideFileExt' 0 DWord } }
            'hide' = @{ Name = @{ zh = '隐藏(默认)'; en = 'Hide (default)' }; Rec = $false; Apply = { WReg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'HideFileExt' 1 DWord } }
        }) `
        -GetCurrent {
            $v = Get-WTRegVal 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'HideFileExt'
            if ($v.Exists -and $v.Value -eq 0) { 'show' } else { 'hide' }
        } `
        -NoteZh '需重启资源管理器生效(注销或重启explorer)' -NoteEn 'Restart Explorer to apply.'),
    (New-WTOption -Id 'hidden-files' -Zh '显示隐藏文件' -En 'Show hidden files' -MinBuild 10240 -Admin $false `
        -States ([ordered]@{
            'show' = @{ Name = @{ zh = '显示'; en = 'Show' }; Rec = $false; Apply = { WReg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'Hidden' 1 DWord } }
            'hide' = @{ Name = @{ zh = '隐藏(默认)'; en = 'Hide (default)' }; Rec = $false; Apply = { WReg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'Hidden' 2 DWord } }
        }) `
        -GetCurrent {
            $v = Get-WTRegVal 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'Hidden'
            if ($v.Exists -and $v.Value -eq 1) { 'show' } else { 'hide' }
        }),
    (New-WTOption -Id 'ps-here' -Zh '右键菜单 [在此处打开 PowerShell]' -En 'Right-click: Open PowerShell here' -MinBuild 10240 `
        -States ([ordered]@{
            'on'  = @{ Name = @{ zh = '添加(经典菜单)'; en = 'Add (classic menu)' }; Rec = $false; Apply = {
                New-Item -Path $psHereKey -Force | Out-Null
                New-ItemProperty -Path $psHereKey -Name '(Default)' -PropertyType String -Value (T '在此处打开 PowerShell' 'Open PowerShell here') -Force | Out-Null
                New-ItemProperty -Path $psHereKey -Name 'Icon' -PropertyType String -Value 'powershell.exe,0' -Force | Out-Null
                $cmdKey = Join-Path $psHereKey 'command'
                New-Item -Path $cmdKey -Force | Out-Null
                New-ItemProperty -Path $cmdKey -Name '(Default)' -PropertyType String -Value 'powershell.exe -NoExit -Command Set-Location -LiteralPath "%V"' -Force | Out-Null } }
            'off' = @{ Name = @{ zh = '移除(默认)'; en = 'Remove (default)' }; Rec = $false; Apply = { Remove-Item -Path $psHereKey -Recurse -Force -ErrorAction SilentlyContinue } }
        }) `
        -GetCurrent { if (Test-Path $psHereKey) { 'on' } else { 'off' } })
)
