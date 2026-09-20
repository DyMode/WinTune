#requires -Version 5.1
# Module 04 - power plan & CPU

$planGuids = @{
    'ultimate' = 'e9a42b02-d5df-448d-aa00-03f14749eb61'
    'high'     = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
    'balanced' = '381b4222-f694-41f0-9685-ff5bb260df2e'
    'saver'    = 'a1841308-3541-4fab-bc81-f71556f20b4a'
}
# SUB_USB / USBSELECTIVE aliases are not valid on all builds (found on 25H2) - use explicit GUIDs.
$usbSubGuid = '2a737441-1930-4402-8d77-b2bebba308a3'
$usbSelGuid = '48e6b7a6-50f5-4782-a5d4-53bb8f07e226'
function Get-WTPowerPlanCurrent {
    # duplicated schemes get fresh GUIDs, so match by localized name, not GUID
    $out = & powercfg.exe /GETACTIVESCHEME 2>$null | Out-String
    if ($out -match '卓越性能|Ultimate Performance') { return 'ultimate' }
    if ($out -match '高性能|High performance') { return 'high' }
    if ($out -match '节能|Power saver') { return 'saver' }
    if ($out -match '平衡|Balanced') { return 'balanced' }
    return 'custom'
}
$applyPlan = {
    param($key)
    $guid = $planGuids[$key]
    $list = & powercfg.exe /LIST 2>$null | Out-String
    if ($list -notmatch $guid) { & powercfg.exe /DUPLICATESCHEME $guid | Out-Null }
    & powercfg.exe /SETACTIVE $guid | Out-Null
}

Register-WTModule '04-power' '电源压榨' 'Power' @(
    (New-WTOption -Id 'power-plan' -Zh '电源计划' -En 'Power plan' -MinBuild 10240 `
        -States ([ordered]@{
            'ultimate' = @{ Name = @{ zh = '卓越性能(推荐)'; en = 'Ultimate Performance (recommended)' }; Rec = $true; Apply = { & $applyPlan 'ultimate' } }
            'high'     = @{ Name = @{ zh = '高性能'; en = 'High performance' }; Rec = $false; Apply = { & $applyPlan 'high' } }
            'balanced' = @{ Name = @{ zh = '平衡(系统默认)'; en = 'Balanced (default)' }; Rec = $false; Apply = { & $applyPlan 'balanced' } }
            'saver'    = @{ Name = @{ zh = '节能'; en = 'Power saver' }; Rec = $false; Apply = { & $applyPlan 'saver' } }
        }) `
        -GetCurrent { Get-WTPowerPlanCurrent }),
    (New-WTOption -Id 'cpu-min' -Zh 'CPU 最低性能状态(AC+DC)' -En 'CPU minimum performance state' -MinBuild 10240 `
        -States ([ordered]@{
            '100' = @{ Name = @{ zh = '100%(推荐,拒绝降频)'; en = '100% (recommended)' }; Rec = $true; Apply = { & powercfg.exe /SETACVALUEINDEX SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMIN 100 | Out-Null; & powercfg.exe /SETDCVALUEINDEX SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMIN 100 | Out-Null; & powercfg.exe /SETACTIVE SCHEME_CURRENT | Out-Null } }
            '5'   = @{ Name = @{ zh = '5%(系统默认,省电)'; en = '5% (default)' }; Rec = $false; Apply = { & powercfg.exe /SETACVALUEINDEX SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMIN 5 | Out-Null; & powercfg.exe /SETDCVALUEINDEX SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMIN 5 | Out-Null; & powercfg.exe /SETACTIVE SCHEME_CURRENT | Out-Null } }
        }) `
        -GetCurrent {
            $out = & powercfg.exe /QUERY SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMIN 2>$null | Out-String
            if ($out -match '0x00000064') { '100' } elseif ($out -match '0x00000005') { '5' } else { 'custom' }
        }),
    (New-WTOption -Id 'aspm' -Zh 'PCI Express 链路节能 ASPM' -En 'PCIe ASPM' -MinBuild 10240 `
        -States ([ordered]@{
            'off' = @{ Name = @{ zh = '关闭(推荐)'; en = 'Off (recommended)' }; Rec = $true; Apply = { & powercfg.exe /SETACVALUEINDEX SCHEME_CURRENT SUB_PCIEXPRESS ASPM 0 | Out-Null; & powercfg.exe /SETACTIVE SCHEME_CURRENT | Out-Null } }
            'on'  = @{ Name = @{ zh = '开启(默认,省电)'; en = 'On (default)' }; Rec = $false; Apply = { & powercfg.exe /SETACVALUEINDEX SCHEME_CURRENT SUB_PCIEXPRESS ASPM 1 | Out-Null; & powercfg.exe /SETACTIVE SCHEME_CURRENT | Out-Null } }
        }) `
        -GetCurrent {
            $out = & powercfg.exe /QUERY SCHEME_CURRENT SUB_PCIEXPRESS ASPM 2>$null | Out-String
            if ($out -match '0x00000000') { 'off' } elseif ($out -match '0x00000001') { 'on' } else { $null }
        }),
    (New-WTOption -Id 'usb-suspend' -Zh 'USB 选择性暂停(AC)' -En 'USB selective suspend (AC)' -MinBuild 10240 `
        -States ([ordered]@{
            'off' = @{ Name = @{ zh = '关闭(推荐,防设备掉线)'; en = 'Off (recommended)' }; Rec = $true; Apply = { & powercfg.exe /SETACVALUEINDEX SCHEME_CURRENT $usbSubGuid $usbSelGuid 0 | Out-Null; & powercfg.exe /SETACTIVE SCHEME_CURRENT | Out-Null } }
            'on'  = @{ Name = @{ zh = '开启(默认,省电)'; en = 'On (default)' }; Rec = $false; Apply = { & powercfg.exe /SETACVALUEINDEX SCHEME_CURRENT $usbSubGuid $usbSelGuid 1 | Out-Null; & powercfg.exe /SETACTIVE SCHEME_CURRENT | Out-Null } }
        }) `
        -GetCurrent {
            $out = & powercfg.exe /QUERY SCHEME_CURRENT $usbSubGuid $usbSelGuid 2>$null | Out-String
            if ($out -match '0x00000000') { 'off' } elseif ($out -match '0x00000001') { 'on' } else { $null }
        }),
    (New-WTOption -Id 'monitor-timeout' -Zh '自动关闭显示器(AC)' -En 'Turn off display (AC)' -MinBuild 10240 `
        -States ([ordered]@{
            'never' = @{ Name = @{ zh = '永不(推荐,挂机/远程时)'; en = 'Never (recommended)' }; Rec = $true; Apply = { & powercfg.exe /SETACVALUEINDEX SCHEME_CURRENT SUB_VIDEO VIDEOIDLE 0 | Out-Null; & powercfg.exe /SETACTIVE SCHEME_CURRENT | Out-Null } }
            '10'    = @{ Name = @{ zh = '10 分钟'; en = '10 minutes' }; Rec = $false; Apply = { & powercfg.exe /SETACVALUEINDEX SCHEME_CURRENT SUB_VIDEO VIDEOIDLE 600 | Out-Null; & powercfg.exe /SETACTIVE SCHEME_CURRENT | Out-Null } }
            '30'    = @{ Name = @{ zh = '30 分钟'; en = '30 minutes' }; Rec = $false; Apply = { & powercfg.exe /SETACVALUEINDEX SCHEME_CURRENT SUB_VIDEO VIDEOIDLE 1800 | Out-Null; & powercfg.exe /SETACTIVE SCHEME_CURRENT | Out-Null } }
        }) `
        -GetCurrent {
            $out = & powercfg.exe /QUERY SCHEME_CURRENT SUB_VIDEO VIDEOIDLE 2>$null | Out-String
            if ($out -match '0x00000000') { 'never' } elseif ($out -match '0x00000258') { '10' } elseif ($out -match '0x00000708') { '30' } else { 'custom' }
        })
)
