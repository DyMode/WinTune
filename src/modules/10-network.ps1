#requires -Version 5.1
# Module 10 - network basics (China-friendly defaults available)

Register-WTModule '10-network' '网络基础' 'Network' @(
    (New-WTOption -Id 'bbr2' -Zh 'TCP 拥塞算法' -En 'TCP congestion provider' -MinBuild 22000 `
        -States ([ordered]@{
            'bbr2'  = @{ Name = @{ zh = 'BBR2(推荐,抗丢包)'; en = 'BBR2 (recommended)' }; Rec = $true; Apply = { & netsh.exe int tcp set supplemental template=internet congestionprovider=bbr2 | Out-Null } }
            'cubic' = @{ Name = @{ zh = 'CUBIC(默认)'; en = 'CUBIC (default)' }; Rec = $false; Apply = { & netsh.exe int tcp set supplemental template=internet congestionprovider=cubic | Out-Null } }
        }) `
        -GetCurrent {
            $out = & netsh.exe int tcp show supplemental 2>$null | Out-String
            if ($out -match 'bbr2') { 'bbr2' } elseif ($out -match 'cubic') { 'cubic' } else { $null }
        } `
        -NoteZh '仅 Win11 支持 BBR2; 应用后即时生效' -NoteEn 'BBR2 is Windows 11 only; effective immediately.'),
    (New-WTOption -Id 'ntp' -Zh 'NTP 时间同步源' -En 'NTP time source' -MinBuild 10240 `
        -States ([ordered]@{
            'aliyun'  = @{ Name = @{ zh = '阿里云(推荐国内)'; en = 'Aliyun NTP (China)' }; Rec = $true; Apply = { & w32tm.exe /config /manualpeerlist:"ntp.aliyun.com,0x9" /syncfromflags:manual /update | Out-Null; Restart-Service w32time -ErrorAction SilentlyContinue; & w32tm.exe /resync | Out-Null } }
            'tencent' = @{ Name = @{ zh = '腾讯云'; en = 'Tencent NTP' }; Rec = $false; Apply = { & w32tm.exe /config /manualpeerlist:"ntp.tencent.com,0x9" /syncfromflags:manual /update | Out-Null; Restart-Service w32time -ErrorAction SilentlyContinue; & w32tm.exe /resync | Out-Null } }
            'ms'      = @{ Name = @{ zh = '微软官方(默认)'; en = 'Microsoft (default)' }; Rec = $false; Apply = { & w32tm.exe /config /manualpeerlist:"time.windows.com,0x9" /syncfromflags:manual /update | Out-Null; Restart-Service w32time -ErrorAction SilentlyContinue; & w32tm.exe /resync | Out-Null } }
        }) `
        -GetCurrent {
            $v = Get-WTRegVal 'HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters' 'NtpServer'
            if (-not $v.Exists) { 'ms' }
            elseif ("$($v.Value)" -match 'aliyun') { 'aliyun' }
            elseif ("$($v.Value)" -match 'tencent') { 'tencent' }
            else { 'ms' }
        }),
    (New-WTOption -Id 'smb1' -Zh 'SMBv1 协议(重大安全隐患)' -En 'SMBv1 protocol (security risk)' -MinBuild 10240 `
        -States ([ordered]@{
            'disabled' = @{ Name = @{ zh = '禁用(推荐)'; en = 'Disabled (recommended)' }; Rec = $true; Apply = { Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart -ErrorAction Stop | Out-Null } }
            'enabled'  = @{ Name = @{ zh = '启用(兼容古董NAS/打印机)'; en = 'Enabled (legacy devices)' }; Rec = $false; Apply = { Enable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart -ErrorAction Stop | Out-Null } }
        }) `
        -GetCurrent {
            try {
                $f = Get-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -ErrorAction Stop
                if ($f.State -eq 'Enabled') { 'enabled' } else { 'disabled' }
            } catch { return $null }
        })
)
