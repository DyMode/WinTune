# WinTune

[![platform](https://img.shields.io/badge/platform-Windows%2010%2F11-0078D6)](https://www.microsoft.com/windows)
[![powershell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE)](https://github.com/PowerShell/PowerShell)
[![license](https://img.shields.io/badge/license-MIT-green)](LICENSE)

English | **[中文](README.md)**

A MAS-style PowerShell tuner for Windows. It auto-detects your OS build and device type and only shows features that actually apply; every setting is a reversible multi-state option, not a one-way switch; and it can generate an HTML + Markdown report on your Desktop.

## ✨ Features

- **Environment-aware**: gates every option by build (19045 / 22631 / 26100 / 26200 / 26300+) and form factor (laptop/desktop), with the reason shown inline
- **Reversible**: snapshots before each change; undo a single item or everything from the menu
- **Deferred elevation**: browsing status and exporting reports need no admin rights; UAC only prompts when you actually apply changes
- **Windows Terminal aware**: opens in a new tab when launched from WT; elevated sessions reuse WT windows too
- **Bilingual UI**: follows the system language by default, switchable between 中文 / English in the menu
- **Unattended mode**: `-Auto` applies all recommended states and exports a report automatically

## 🚀 Usage

### One-liner

```powershell
iex ((irm https://raw.githubusercontent.com/DyMode/WinTune/main/invoke.ps1) -replace '^\uFEFF')
```

Users in China, swap the URL for the mirror prefix `https://ghfast.top/https://raw.githubusercontent.com/DyMode/WinTune/main/invoke.ps1`.

<details>
<summary>Multi-mirror fallback</summary>

```powershell
foreach($u in 'https://ghfast.top/https://raw.githubusercontent.com/DyMode/WinTune/main/invoke.ps1','https://cdn.jsdelivr.net/gh/DyMode/WinTune@main/invoke.ps1','https://raw.githubusercontent.com/DyMode/WinTune/main/invoke.ps1'){ try { $t=(irm $u -TimeoutSec 15) -replace '^\uFEFF'; if($t -match 'WinTune'){ iex $t; break } } catch {} }
```
</details>

### Run locally

```powershell
powershell -ExecutionPolicy Bypass -File invoke.ps1
```

### Unattended

Add `-Auto` to apply every recommended state and export a report to the Desktop — handy for fresh installs.

```powershell
powershell -ExecutionPolicy Bypass -File invoke.ps1 -Auto
```

## 📦 Modules

| # | Module | Covers |
|---|---|---|
| 01 | Brightness (laptops) | Stops auto-dimming: adaptive brightness off + sensor service disabled |
| 02 | RDP client | Enables UDP + generates a best-experience .rdp template |
| 03 | RDP server | 60fps, GPU rendering, AVC / HEVC hardware encoding, AVC444, NLA, firewall, security notes |
| 04 | Power squeeze | Ultimate performance, 100% CPU min state, ASPM, USB suspend, display timeout |
| 05 | Responsiveness | Power throttling, HAGS, Game Mode, GameDVR |
| 06 | Driver doctor | Detects "Basic Display Adapter" and fixes it via Windows Update |
| 07 | Font rendering | ClearType repair (REG_SZ type check, fixes jagged-font bug) |
| 08 | PowerShell 7 | ZIP install without admin + CN mirrors |
| 09 | Privacy & ads | Telemetry, advertising ID, search highlights, lock-screen ads, widgets, activity history |
| 10 | Network basics | BBR2, CN NTP sources, SMBv1 disabled |
| 11 | Explorer | File extensions, hidden files, PowerShell here |
| 12 | Storage | Storage Sense, hibernation, SysMain, TRIM check |

## 🖥 Compatibility

Windows 10 22H2 (compatibility mode, EOL) through Windows 11 26H2 Preview (Build 26300). Future builds are handled by a forward-compatible "≥ latest known build = all features" policy. Options that make no sense on a desktop (e.g. brightness) are hidden automatically.

## ⚠️ Disclaimer

This tool modifies system settings and group policies. Read each option's description before applying. The author is not responsible for any data loss or system issues. Comply with local laws and regulations.

## 📄 License

[MIT](LICENSE)
