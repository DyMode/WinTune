#requires -Version 5.1
# Module 02 - RDP client (this machine controls others)

$rdpClientKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\Client'

Register-WTModule '02-rdp-client' 'RDP 客户端(控制别人)' 'RDP Client' @(
    (New-WTOption -Id 'udp' -Zh 'RDP UDP 传输' -En 'RDP UDP transport' -MinBuild 10240 `
        -States ([ordered]@{
            'on'      = @{ Name = @{ zh = '启用(推荐,降低延迟)'; en = 'Enabled (recommended)' }; Rec = $true; Apply = { WReg $rdpClientKey 'fClientDisableUDP' 0 DWord } }
            'off'     = @{ Name = @{ zh = '禁用'; en = 'Disabled' }; Rec = $false; Apply = { WReg $rdpClientKey 'fClientDisableUDP' 1 DWord } }
            'default' = @{ Name = @{ zh = '系统默认(删除策略键)'; en = 'OS default (remove policy)' }; Rec = $false; Apply = { WDelReg $rdpClientKey 'fClientDisableUDP' } }
        }) `
        -GetCurrent {
            $v = Get-WTRegVal $rdpClientKey 'fClientDisableUDP'
            if (-not $v.Exists) { return 'default' }
            if ($v.Value -eq 0) { return 'on' }
            return 'off'
        }),
    (New-WTOption -Id 'rdp-template' -Zh '生成最佳体验 .rdp 模板到桌面' -En 'Generate best-experience .rdp template on Desktop' -MinBuild 10240 -Admin $false `
        -Action {
            $rdp = @(
                'screen mode id:i:2','use multimon:i:0','session bpp:i:32','connection type:i:7'
                'networkautodetect:i:1','bandwidthautodetect:i:1','compression:i:1'
                'disable wallpaper:i:0','allow font smoothing:i:1','allow desktop composition:i:1'
                'disable full window drag:i:0','disable menu anims:i:0','disable themes:i:0'
                'bitmapcachepersistenable:i:1','audiomode:i:0','videoplaybackmode:i:1'
                'redirectclipboard:i:1','redirectprinters:i:0','redirectdrives:i:0'
                'promptcredentialonce:i:1','authentication level:i:2','enablecredsspsupport:i:1'
            ) -join "`r`n"
            $path = Join-Path ([Environment]::GetFolderPath('Desktop')) 'WinTune-Best-RDP.rdp'
            [System.IO.File]::WriteAllText($path, $rdp, (New-Object System.Text.UTF8Encoding $false))
            Write-WTLog (T "模板已生成: $path" "Template written: $path") 'Green'
        })
)
