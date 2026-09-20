#requires -Version 5.1
# WinTune - mirror-aware downloader (GitHub raw with China-friendly fallbacks)

$script:WTMirrors = @(
    'https://raw.githubusercontent.com/{0}/{1}/{2}',                                   # 0 repo, 1 branch, 2 path
    'https://gh-proxy.com/https://raw.githubusercontent.com/{0}/{1}/{2}',
    'https://ghfast.top/https://raw.githubusercontent.com/{0}/{1}/{2}',
    'https://cdn.jsdelivr.net/gh/{0}/{1}@{3}/{2}'                                       # {3} = branch
)

function Get-WTRawUrl([string]$repo, [string]$branch, [string]$path, [int]$mirrorIndex) {
    if ($mirrorIndex -eq 3) { return ($script:WTMirrors[3] -f $repo, $branch, $path, $branch) }
    return ($script:WTMirrors[$mirrorIndex] -f $repo, $branch, $path)
}

function Save-WTRemoteFile([string]$repo, [string]$branch, [string]$path, [string]$outFile) {
    $lastErr = $null
    for ($i = 0; $i -lt $script:WTMirrors.Count; $i++) {
        $url = Get-WTRawUrl $repo $branch $path $i
        try {
            Invoke-WebRequest -Uri $url -OutFile $outFile -UseBasicParsing -TimeoutSec 60
            if ((Get-Item $outFile).Length -gt 0) {
                Write-WTLog (T "下载成功(镜像$i): $path" "Downloaded via mirror $i : $path") 'DarkGray'
                return $true
            }
        } catch {
            $lastErr = $_.Exception.Message
            Write-WTLog (T "镜像$i 失败: $path" "Mirror $i failed: $path") 'DarkGray'
        }
    }
    throw (T "所有镜像均下载失败: $path ($lastErr)" "All mirrors failed for $path ($lastErr)")
}
