# WinTune bootstrap - paste one line in PowerShell to fetch and run from GitHub.
# Local usage:  powershell -ExecutionPolicy Bypass -File invoke.ps1
# Remote usage: iex (irm https://raw.githubusercontent.com/DyMode/WinTune/main/invoke.ps1)
#
# NOTE: no param() block on purpose. Mirrors may prepend a BOM character; with a
# param block that breaks parsing under iex. Manual $args parsing is immune.

$Repo   = 'DyMode/WinTune'
$Branch = 'main'
$Auto   = $false
for ($i = 0; $i -lt $args.Count; $i++) {
    switch -Regex ($args[$i]) {
        '^-Repo$'           { $Repo = [string]$args[++$i] }
        '^-Repo=(.+)$'      { $Repo = $Matches[1] }
        '^-Branch$'         { $Branch = [string]$args[++$i] }
        '^-Branch=(.+)$'    { $Branch = $Matches[1] }
        '^-Auto$'           { $Auto = $true }
    }
}

$ErrorActionPreference = 'Stop'
$files = @(
    'src/lib/core.ps1','src/lib/detect.ps1','src/lib/net.ps1','src/lib/report.ps1',
    'src/modules/01-brightness.ps1','src/modules/02-rdp-client.ps1','src/modules/03-rdp-server.ps1',
    'src/modules/04-power.ps1','src/modules/05-responsiveness.ps1','src/modules/06-driver-doctor.ps1',
    'src/modules/07-fonts.ps1','src/modules/08-pwsh.ps1','src/modules/09-privacy.ps1',
    'src/modules/10-network.ps1','src/modules/11-explorer.ps1','src/modules/12-storage.ps1',
    'src/menu.ps1'
)

$isLocal = -not [string]::IsNullOrEmpty($PSScriptRoot) -and (Test-Path (Join-Path $PSScriptRoot 'src\menu.ps1'))
if ($isLocal) {
    $root = $PSScriptRoot
} else {
    $root = Join-Path $env:TEMP ("WinTune-" + [guid]::NewGuid().ToString('N').Substring(0,8))
    New-Item -Path $root -ItemType Directory -Force | Out-Null

    $mirrors = @(
        @{ Base = "https://raw.githubusercontent.com/$Repo/$Branch/";                 Ref = $Branch },
        @{ Base = "https://gh-proxy.com/https://raw.githubusercontent.com/$Repo/$Branch/"; Ref = $Branch },
        @{ Base = "https://ghfast.top/https://raw.githubusercontent.com/$Repo/$Branch/";   Ref = $Branch },
        @{ Base = "https://cdn.jsdelivr.net/gh/$Repo@$Branch/";                        Ref = $Branch }
    )
    $mirrorIdx = 0
    :outer for ($f = 0; $f -lt $files.Count; $f++) {
        $rel = $files[$f]
        $out = Join-Path $root ($rel -replace '/', '\')
        New-Item -Path (Split-Path $out -Parent) -ItemType Directory -Force | Out-Null
        $done = $false
        for ($m = $mirrorIdx; $m -lt $mirrors.Count; $m++) {
            try {
                Invoke-WebRequest -Uri ($mirrors[$m].Base + $rel) -OutFile $out -UseBasicParsing -TimeoutSec 60
                # reject block pages / empty bodies: a poisoned mirror returns HTML, not script
                $txt = [System.IO.File]::ReadAllText($out)
                $head = $txt.Substring(0, [Math]::Min(200, $txt.Length))
                if ($txt.Length -gt 50 -and $head -notmatch '<!doctype|<html') { $mirrorIdx = $m; $done = $true; break }
                Write-Host "mirror $m returned bad content for $rel" -ForegroundColor DarkGray
            } catch {
                Write-Host "mirror $m failed for $rel" -ForegroundColor DarkGray
            }
        }
        if (-not $done) { throw "failed to download $rel from all mirrors" }
    }
    Write-Host "downloaded to $root" -ForegroundColor DarkGray
}

$menuArgs = @('-NoProfile','-ExecutionPolicy','Bypass','-File', (Join-Path $root 'src\menu.ps1'))
if ($Repo -ne 'DyMode/WinTune') { $menuArgs += "-Repo `"$Repo`"" }
$menuArgs += "-Branch `"$Branch`""
if ($Auto) { $menuArgs += '-Auto' }

# resolve the CURRENT shell executable: under pwsh 7 $PSHOME contains pwsh.exe only
$shellExe = (Get-Process -Id $PID).Path
if (-not $shellExe -or $shellExe -notmatch '\.(exe|com)$') { $shellExe = Join-Path $PSHOME 'powershell.exe' }

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
# Windows Terminal detection: open a new tab instead of a separate conhost window
$wtExe = Get-Command wt.exe -ErrorAction SilentlyContinue
$inWindowsTerminal = -not [string]::IsNullOrEmpty($env:WT_SESSION)

if ($inWindowsTerminal -and $wtExe) {
    # run inside a new WT tab; menu.ps1 elevates on demand
    # wt needs the shell executable spelled out after '--', and PS 5.1 Start-Process
    # joins ArgumentList without quoting, so build one pre-quoted command line.
    $wtCmd = @(
        'new-tab','--title','WinTune','--',
        ('"{0}"' -f $shellExe),
        '-NoProfile','-ExecutionPolicy','Bypass','-File',
        ('"{0}"' -f (Join-Path $root 'src\menu.ps1'))
    )
    if ($Repo -ne 'DyMode/WinTune') { $wtCmd += ('-Repo "{0}"' -f $Repo) }
    $wtCmd += ('-Branch "{0}"' -f $Branch)
    if ($Auto) { $wtCmd += '-Auto' }
    Start-Process -FilePath $wtExe.Source -ArgumentList ($wtCmd -join ' ')
} elseif (-not $isAdmin) {
    Start-Process -FilePath $shellExe -Verb RunAs -ArgumentList $menuArgs -Wait
} else {
    & $shellExe @menuArgs
}
