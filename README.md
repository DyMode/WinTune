# WinTune

[![platform](https://img.shields.io/badge/platform-Windows%2010%2F11-0078D6)](https://www.microsoft.com/windows)
[![powershell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE)](https://github.com/PowerShell/PowerShell)
[![license](https://img.shields.io/badge/license-MIT-green)](LICENSE)

**[English](README.en.md)** | 中文

一键体检并优化 Windows 的 PowerShell 工具。自动检测系统版本与设备类型，只展示当前机器可用的功能；每个配置项都是可回滚的多选值，不是开完就回不去的单向开关；可选生成 HTML + Markdown 报告到桌面。

## ✨ 特性

- **自动环境检测**：按 Build（19045 / 22631 / 26100 / 26200 / 26300+）与笔记本 / 台式机自动隐藏不适用项，并说明原因
- **多选值 + 可回滚**：改动前自动快照，菜单内可逐项或全部撤销
- **按需提权**：浏览状态、生成报告不需要管理员；只有执行改动时才弹 UAC
- **Windows Terminal 感知**：在 WT 中运行自动开新标签页，提权会话同样走 WT 窗口
- **双语界面**：默认跟随系统语言，菜单内一键切换中 / English
- **无人值守模式**：`-Auto` 一键应用全部推荐值并自动出报告

## 🚀 使用方法

### 远程一行

```powershell
iex ((irm https://ghfast.top/https://raw.githubusercontent.com/DyMode/WinTune/main/invoke.ps1) -replace '^\uFEFF')
```

GitHub 直连（海外）把 URL 换成 `https://raw.githubusercontent.com/DyMode/WinTune/main/invoke.ps1` 即可。

<details>
<summary>镜像故障时的多源备用命令</summary>

```powershell
foreach($u in 'https://ghfast.top/https://raw.githubusercontent.com/DyMode/WinTune/main/invoke.ps1','https://cdn.jsdelivr.net/gh/DyMode/WinTune@main/invoke.ps1','https://raw.githubusercontent.com/DyMode/WinTune/main/invoke.ps1'){ try { $t=(irm $u -TimeoutSec 15) -replace '^\uFEFF'; if($t -match 'WinTune'){ iex $t; break } } catch {} }
```
</details>

### 本地运行

```powershell
powershell -ExecutionPolicy Bypass -File invoke.ps1
```

### 无人值守

加上 `-Auto`：应用全部推荐值，自动导出报告到桌面，适合新装机。

```powershell
powershell -ExecutionPolicy Bypass -File invoke.ps1 -Auto
```

## 📦 功能模块

| # | 模块 | 内容 |
|---|---|---|
| 01 | 亮度控制（笔记本） | 根治忽明忽暗：关自适应亮度 + 禁用传感器服务 |
| 02 | RDP 客户端 | 启用 UDP + 生成最佳体验 .rdp 模板 |
| 03 | RDP 服务端 | 60fps、GPU 渲染、AVC / HEVC 硬件编码、AVC444、NLA、防火墙、安全提醒 |
| 04 | 电源压榨 | 卓越性能、CPU 100%、ASPM、USB 暂停、显示器超时 |
| 05 | 系统响应 | 电源节流、HAGS、游戏模式、GameDVR |
| 06 | 驱动医生 | 检测"基本显示适配器"并经 Windows Update 自动修复 |
| 07 | 字体渲染 | ClearType 修复（REG_SZ 类型校验，防锯齿 bug） |
| 08 | PowerShell 7 | ZIP 免管理员安装 + 国内镜像 |
| 09 | 隐私与去广告 | 遥测、广告 ID、搜索亮点、锁屏广告、小部件、活动历史 |
| 10 | 网络基础 | BBR2、国内 NTP、禁用 SMBv1 |
| 11 | 资源管理器 | 扩展名、隐藏文件、右键 PowerShell |
| 12 | 磁盘维护 | 存储感知、休眠、SysMain、TRIM 检测 |

## 🖥 兼容性

Windows 10 22H2（兼容模式，已 EOL）~ Windows 11 26H2 预览版（Build 26300）。未来版本按"≥ 最新已知 Build 全部可用"策略前向兼容。台式机自动隐藏亮度等无意义项。

## ⚠️ 免责声明

本工具修改系统设置与组策略，请在使用前阅读各选项说明；作者不对任何数据丢失或系统问题负责。请遵守当地法律法规。

## 📄 License

[MIT](LICENSE)
