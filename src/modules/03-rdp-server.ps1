#requires -Version 5.1
# Module 03 - RDP server (this machine is controlled)

$rdpSrvKey   = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services'
$rdpTcpKey   = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp'
$rdpBaseKey  = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server'
$winStations = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations'

# Resolve the HEVC policy value name from the local ADMX when possible (never hard-guess).
function Get-WTHevcValueName {
    $admx = Join-Path $env:windir 'PolicyDefinitions\terminalserver.admx'
    $fallback = 'HEVCHardwareEncodePreferred'
    if (-not (Test-Path $admx)) { return $fallback }
    try {
        $raw = Get-Content $admx -Raw -Encoding UTF8
        $m = [regex]::Match($raw, '(?s)<policy name="[^"]*HEVC[^"]*".*?</policy>')
        if (-not $m.Success) { return $fallback }
        $vm = [regex]::Match($m.Value, 'valueName\s*=\s*"([^"]+)"')
        if ($vm.Success) { return $vm.Groups[1].Value }
    } catch {}
    return $fallback
}
function Get-WTRegKeyState($path, $name, $matchValue, $onKey, $offKey) {
    $v = Get-WTRegVal $path $name
    if (-not $v.Exists) { return 'default' }
    if ($v.Value -eq $matchValue) { return $onKey }
    return $offKey
}

Register-WTModule '03-rdp-server' 'RDP 服务端(被控制)' 'RDP Server' @(
    (New-WTOption -Id 'rdp-enabled' -Zh '允许远程桌面连接' -En 'Allow remote connections' -MinBuild 10240 `
        -States ([ordered]@{
            'on'  = @{ Name = @{ zh = '开启'; en = 'Enabled' }; Rec = $false; Apply = { WReg $rdpBaseKey 'fDenyTSConnections' 0 DWord } }
            'off' = @{ Name = @{ zh = '关闭(默认)'; en = 'Disabled (default)' }; Rec = $false; Apply = { WReg $rdpBaseKey 'fDenyTSConnections' 1 DWord } }
        }) `
        -GetCurrent { $v = Get-WTRegVal $rdpBaseKey 'fDenyTSConnections'; if ($v.Exists -and $v.Value -eq 0) { 'on' } else { 'off' } } `
        -NoteZh '开启后 3389 端口对外暴露: 请使用强密码/微软账号登录, 建议仅在内网使用, 必要时改端口' `
        -NoteEn 'Opening 3389 exposes this machine: use a strong password, LAN only, consider changing the port.'),
    (New-WTOption -Id 'firewall' -Zh '防火墙放行远程桌面' -En 'Firewall rules for Remote Desktop' -MinBuild 10240 `
        -States ([ordered]@{
            'on'  = @{ Name = @{ zh = '放行 TCP+UDP(推荐,UDP需配合开启)'; en = 'Allow TCP+UDP (recommended)' }; Rec = $true; Apply = { Enable-NetFirewallRule -DisplayGroup (T '远程桌面' 'Remote Desktop') -ErrorAction SilentlyContinue; Enable-NetFirewallRule -Name 'RemoteDesktop-UserMode-In-TCP','RemoteDesktop-UserMode-In-UDP' -ErrorAction SilentlyContinue } }
            'off' = @{ Name = @{ zh = '关闭'; en = 'Block' }; Rec = $false; Apply = { Disable-NetFirewallRule -DisplayGroup (T '远程桌面' 'Remote Desktop') -ErrorAction SilentlyContinue } }
        }) `
        -GetCurrent {
            $r = Get-NetFirewallRule -Name 'RemoteDesktop-UserMode-In-TCP' -ErrorAction SilentlyContinue
            if ($r -and $r.Enabled -eq 'True') { 'on' } else { 'off' }
        }),
    (New-WTOption -Id 'nla' -Zh '网络级别验证 NLA' -En 'Network Level Authentication' -MinBuild 10240 `
        -States ([ordered]@{
            'on'  = @{ Name = @{ zh = '开启(推荐,更安全)'; en = 'On (recommended, safer)' }; Rec = $true; Apply = { WReg $rdpTcpKey 'UserAuthentication' 1 DWord } }
            'off' = @{ Name = @{ zh = '关闭(兼容老客户端)'; en = 'Off (legacy clients)' }; Rec = $false; Apply = { WReg $rdpTcpKey 'UserAuthentication' 0 DWord } }
        }) `
        -GetCurrent { Get-WTRegKeyState $rdpTcpKey 'UserAuthentication' 1 'on' 'off' }),
    (New-WTOption -Id 'framerate' -Zh '远程会话帧率上限' -En 'Remote session frame rate' -MinBuild 10240 `
        -States ([ordered]@{
            '60' = @{ Name = @{ zh = '60 fps(推荐)'; en = '60 fps (recommended)' }; Rec = $true; Apply = { WReg $winStations 'DisplayRefreshRate' 60 DWord } }
            '30' = @{ Name = @{ zh = '30 fps(系统默认)'; en = '30 fps (OS default)' }; Rec = $false; Apply = { WReg $winStations 'DisplayRefreshRate' 30 DWord } }
        }) `
        -GetCurrent { $v = Get-WTRegVal $winStations 'DisplayRefreshRate'; if (-not $v.Exists) { return '30' }; if ([int]$v.Value -ge 60) { return '60' }; return '30' }),
    (New-WTOption -Id 'gpu-render' -Zh 'GPU 渲染远程会话' -En 'GPU-accelerated session rendering' -MinBuild 10240 `
        -States ([ordered]@{
            'on'  = @{ Name = @{ zh = '开启(推荐,有独显/核显时)'; en = 'On (recommended)' }; Rec = $true; Apply = { WReg $rdpSrvKey 'bEnumerateHWBeforeSW' 1 DWord; WReg $rdpSrvKey 'fEnableWddmDriver' 1 DWord } }
            'off' = @{ Name = @{ zh = '关闭(默认)'; en = 'Off (default)' }; Rec = $false; Apply = { WReg $rdpSrvKey 'bEnumerateHWBeforeSW' 0 DWord } }
        }) `
        -GetCurrent { Get-WTRegKeyState $rdpSrvKey 'bEnumerateHWBeforeSW' 1 'on' 'off' }),
    (New-WTOption -Id 'avc-hw' -Zh 'H.264/AVC 硬件编码' -En 'H.264/AVC hardware encoding' -MinBuild 10240 `
        -States ([ordered]@{
            'on'  = @{ Name = @{ zh = '开启(推荐,GPU编码省CPU)'; en = 'On (recommended)' }; Rec = $true; Apply = { WReg $rdpSrvKey 'AVCHardwareEncodePreferred' 1 DWord } }
            'off' = @{ Name = @{ zh = '关闭(默认,纯软件编码)'; en = 'Off (default)' }; Rec = $false; Apply = { WReg $rdpSrvKey 'AVCHardwareEncodePreferred' 0 DWord } }
        }) `
        -GetCurrent { Get-WTRegKeyState $rdpSrvKey 'AVCHardwareEncodePreferred' 1 'on' 'off' }),
    (New-WTOption -Id 'avc444' -Zh 'AVC 444 模式(文字更清晰)' -En 'AVC 444 mode (sharper text)' -MinBuild 10240 `
        -States ([ordered]@{
            'on'  = @{ Name = @{ zh = '开启(带宽占用更高)'; en = 'On (higher bandwidth)' }; Rec = $false; Apply = { WReg $rdpSrvKey 'AVC444ModePreferred' 1 DWord } }
            'off' = @{ Name = @{ zh = '关闭(默认)'; en = 'Off (default)' }; Rec = $false; Apply = { WReg $rdpSrvKey 'AVC444ModePreferred' 0 DWord } }
        }) `
        -GetCurrent { Get-WTRegKeyState $rdpSrvKey 'AVC444ModePreferred' 1 'on' 'off' } `
        -NoteZh '需要主控端 mstsc 为 Win10+; 文字/色阶锐利但吃带宽' -NoteEn 'Requires a Win10+ client; sharper text at higher bandwidth.'),
    (New-WTOption -Id 'hevc' -Zh 'H.265/HEVC 硬件编码(省带宽)' -En 'H.265/HEVC hardware encoding' -MinBuild 26100 `
        -Available { $script:WT.Env.Build -ge 26100 } `
        -States ([ordered]@{
            'on'  = @{ Name = @{ zh = '开启(24H2+,需GPU支持HEVC编码)'; en = 'On (24H2+, needs HEVC encoder)' }; Rec = $false; Apply = { WReg $rdpSrvKey (Get-WTHevcValueName) 1 DWord } }
            'off' = @{ Name = @{ zh = '关闭(默认)'; en = 'Off (default)' }; Rec = $false; Apply = { WReg $rdpSrvKey (Get-WTHevcValueName) 0 DWord } }
        }) `
        -GetCurrent { Get-WTRegKeyState $rdpSrvKey (Get-WTHevcValueName) 1 'on' 'off' } `
        -NoteZh '主控端需 Win11 22H2+ (自带HEVC解码扩展); 同画质省25-50%带宽' -NoteEn 'Client needs Win11 22H2+ (HEVC codec bundled); 25-50% bandwidth saving.'),
    (New-WTOption -Id 'img-quality' -Zh '图像质量(RemoteFX遗留项)' -En 'Image quality (legacy RemoteFX)' -MinBuild 10240 `
        -States ([ordered]@{
            'high' = @{ Name = @{ zh = '高'; en = 'High' }; Rec = $false; Apply = { WReg $rdpSrvKey 'ImageQuality' 2 DWord } }
            'mid'  = @{ Name = @{ zh = '中(默认)'; en = 'Medium (default)' }; Rec = $false; Apply = { WReg $rdpSrvKey 'ImageQuality' 1 DWord } }
        }) `
        -GetCurrent { $v = Get-WTRegVal $rdpSrvKey 'ImageQuality'; if (-not $v.Exists) { return 'mid' }; if ([int]$v.Value -eq 2) { return 'high' }; return 'mid' }),
    (New-WTOption -Id 'net-detect-fix' -Zh '24H2 连接检测修复' -En '24H2 network-detection fix' -MinBuild 26100 `
        -States ([ordered]@{
            'on'  = @{ Name = @{ zh = '开启(修复24H2偶发断连)'; en = 'On (fixes 24H2 drops)' }; Rec = $false; Apply = { WReg $rdpSrvKey 'fTurnOffNetworkDetect' 1 DWord } }
            'off' = @{ Name = @{ zh = '关闭(默认)'; en = 'Off (default)' }; Rec = $false; Apply = { WDelReg $rdpSrvKey 'fTurnOffNetworkDetect' } }
        }) `
        -GetCurrent { Get-WTRegKeyState $rdpSrvKey 'fTurnOffNetworkDetect' 1 'on' 'off' } `
        -NoteZh '对应组策略 [选择服务器上的网络检测]; 25H2/26H2 同分支可开' -NoteEn 'Maps to "Select network detection on the server"; same branch as 24H2.')
)
