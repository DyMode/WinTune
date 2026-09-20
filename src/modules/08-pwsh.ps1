#requires -Version 5.1
# Module 08 - install PowerShell 7 (per-user ZIP, mirror-aware; MSI intentionally avoided)

Register-WTModule '08-pwsh' 'PowerShell 7' 'PowerShell 7' @(
    (New-WTOption -Id 'install-pwsh' -Zh '安装/更新 PowerShell 7' -En 'Install/update PowerShell 7' -MinBuild 10240 -Admin $false `
        -Available { return [string]::IsNullOrEmpty($script:WT.Env.PwshPath) } `
        -Action {
            $rel = Invoke-RestMethod -Uri 'https://api.github.com/repos/PowerShell/PowerShell/releases/latest' -Headers @{ 'User-Agent' = 'WinTune' }
            $asset = $rel.assets | Where-Object { $_.name -match '^PowerShell-[\d.]+-win-x64\.zip$' } | Select-Object -First 1
            if (-not $asset) { throw 'no win-x64 zip asset found' }
            Write-WTLog (T "最新版: $($rel.tag_name),开始下载..." "Latest: $($rel.tag_name); downloading...") 'Yellow'
            $tmp = Join-Path $env:TEMP $asset.name
            $urls = @(
                $asset.browser_download_url,
                "https://gh-proxy.com/$($asset.browser_download_url)",
                "https://ghfast.top/$($asset.browser_download_url)"
            )
            $ok = $false
            foreach ($u in $urls) {
                try { Invoke-WebRequest -Uri $u -OutFile $tmp -UseBasicParsing -TimeoutSec 300; $ok = $true; break }
                catch { Write-WTLog (T "镜像失败: $u" "Mirror failed: $u") 'DarkGray' }
            }
            if (-not $ok) { throw (T '所有镜像下载失败' 'All mirrors failed') }
            $dest = Join-Path $env:LOCALAPPDATA 'Programs\PowerShell\7'
            Expand-Archive -Path $tmp -DestinationPath $dest -Force
            Remove-Item $tmp -Force -ErrorAction SilentlyContinue
            $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
            if ($userPath -notlike "*$dest*") { [Environment]::SetEnvironmentVariable('Path', "$userPath;$dest", 'User') }
            Write-WTLog (T "已安装到 $dest (需新开终端生效)" "Installed to $dest (open a new terminal)") 'Green'
        } `
        -GetCurrent { if ($script:WT.Env.PwshPath) { 'ok' } else { 'none' } } `
        -NoteZh '当前检测到未安装 PowerShell 7,建议安装以获得更好体验; ZIP解压方式无需管理员' `
        -NoteEn 'PowerShell 7 not found - recommended; per-user ZIP install, no admin needed.')
)
