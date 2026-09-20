#requires -Version 5.1
# Module 07 - font rendering (FontSmoothing must be REG_SZ - enforced here)

Register-WTModule '07-fonts' '字体渲染' 'Font Rendering' @(
    (New-WTOption -Id 'font-smoothing' -Zh '字体平滑(ClearType)' -En 'Font smoothing (ClearType)' -MinBuild 10240 -Admin $false `
        -States ([ordered]@{
            'on'  = @{ Name = @{ zh = '开启(默认,REG_SZ正确类型)'; en = 'On (default, correct REG_SZ)' }; Rec = $true; Apply = {
                WReg 'HKCU:\Control Panel\Desktop' 'FontSmoothing' '2' String
                WReg 'HKCU:\Control Panel\Desktop' 'FontSmoothingType' 2 DWord } }
            'off' = @{ Name = @{ zh = '关闭(不推荐)'; en = 'Off (not recommended)' }; Rec = $false; Apply = {
                WReg 'HKCU:\Control Panel\Desktop' 'FontSmoothing' '0' String } }
        }) `
        -GetCurrent {
            $v = Get-WTRegVal 'HKCU:\Control Panel\Desktop' 'FontSmoothing'
            if (-not $v.Exists) { return 'on' }
            if ("$($v.Value)" -eq '2') { 'on' } else { 'off' }
        } `
        -NoteZh '注销重登后生效; 本工具强制使用字符串类型写入(常见错误是写成DWORD导致锯齿)' `
        -NoteEn 'Takes effect after re-logon; this tool always writes REG_SZ (a common DWORD mistake causes jagged fonts).'),
    (New-WTOption -Id 'cleartype-tuner' -Zh '打开 ClearType 文本调谐器' -En 'Launch ClearType Text Tuner' -MinBuild 10240 -Admin $false `
        -Action { Start-Process 'cttune.exe' })
)
