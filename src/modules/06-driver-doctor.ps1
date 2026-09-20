#requires -Version 5.1
# Module 06 - driver doctor: detect basic display adapter and fix via Windows Update

function Get-WTBasicAdapterPresent {
    try {
        $devs = Get-PnpDevice -Class Display -ErrorAction Stop
        foreach ($d in $devs) { if ($d.FriendlyName -match 'Basic Display|基本显示') { return $true } }
    } catch {}
    return $false
}

Register-WTModule '06-driver-doctor' '显卡驱动医生' 'Driver Doctor' @(
    (New-WTOption -Id 'fix-display-driver' -Zh '检测并修复基本显示适配器' -En 'Detect & fix Microsoft Basic Display Adapter' -MinBuild 10240 `
        -Available { return $true } `
        -Action {
            if (-not (Get-WTBasicAdapterPresent)) {
                Write-WTLog (T '未发现基本显示适配器,显卡驱动状态正常。' 'No basic display adapter found - GPU drivers look fine.') 'Green'
                return
            }
            Write-WTLog (T '检测到基本显示适配器(显卡缺驱动),开始通过 Windows Update 安装...' 'Basic display adapter detected; installing driver via Windows Update...') 'Yellow'
            $session = New-Object -ComObject Microsoft.Update.Session
            $searcher = $session.CreateUpdateSearcher()
            $result = $searcher.Search("IsInstalled=0 AND Type='Driver'")
            $targets = @()
            foreach ($u in $result.Updates) {
                if ($u.Title -match 'Intel|NVIDIA|AMD|Display|Graphics') { $targets += $u }
            }
            if ($targets.Count -eq 0) { throw (T 'Windows Update 未找到可用显示驱动' 'No display driver found on Windows Update') }
            $coll = New-Object -ComObject Microsoft.Update.UpdateColl
            foreach ($u in $targets) { $coll.Add($u) | Out-Null; Write-WTLog "  -> $($u.Title)" 'DarkGray' }
            $dl = $session.CreateUpdateDownloader(); $dl.Updates = $coll
            $dres = $dl.Download()
            if ($dres.ResultCode -ne 2) { throw (T "下载失败: $($dres.HResult)" "Download failed: $($dres.HResult)") }
            $inst = $session.CreateUpdateInstaller(); $inst.Updates = $coll
            $ires = $inst.Install()
            if ($ires.ResultCode -ne 2 -and $ires.ResultCode -ne 3) { throw (T "安装失败: $($ires.HResult)" "Install failed: $($ires.HResult)") }
            Write-WTLog (T '驱动安装完成,请重启系统。' 'Driver installed; please reboot.') 'Green'
        } `
        -GetCurrent { if (Get-WTBasicAdapterPresent) { 'action' } else { 'ok' } } `
        -NoteZh '典型症状: 亮度滑块消失/无法调节、分辨率异常、无硬件加速' `
        -NoteEn 'Typical symptoms: brightness slider missing, wrong resolution, no hardware acceleration.')
)
