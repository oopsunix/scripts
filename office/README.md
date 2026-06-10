# Office Deployment Script

基于 Office Deployment Tool (ODT) 的 Microsoft Office 自动化部署与卸载脚本，支持批量安装、KMS 激活和深度清理。

## 快速使用

```powershell
# 一键安装（默认 Microsoft 365 + Word/Excel/PowerPoint/Outlook）
irm https://kms.akams.cn/install.ps1 | iex

# 指定产品安装
.\install.ps1 -ProductIds "ProPlus2024Volume"

# 安装多个产品
.\install.ps1 -ProductIds "ProPlus2024Volume,VisioPro2024Volume,ProjectPro2024Volume"

# 仅安装指定应用
.\install.ps1 -ProductIds "ProPlus2024Volume" -AppIds "Word,Excel"

# 卸载并深度清理
.\install.ps1 -Action Uninstall
```

## 参数

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `-Action` | `Install` 或 `Uninstall` | `Install` |
| `-ProductIds` | 产品 ID，逗号分隔多个 | `O365ProPlusRetail` |
| `-AppIds` | 要安装的应用，逗号分隔 | `Word,Excel,PowerPoint,Outlook` |

也可通过环境变量 `env:Action`、`env:ProductIds`、`env:AppIds` 传参，命令行参数优先。

## 支持的产品 ID

**Office 2024** — `ProPlus2024Volume` `Standard2024Volume`
**Office 2021** — `ProPlus2021Volume` `Standard2021Volume`
**Office 2019** — `ProPlus2019Volume` `Standard2019Volume`
**Office 2016** — `ProPlusVolume` `StandardVolume`
**Visio** — `VisioPro[Year]Volume` / `VisioStd[Year]Volume`
**Project** — `ProjectPro[Year]Volume` / `ProjectStd[Year]Volume`
**Microsoft 365** — `O365ProPlusRetail`

## 功能特性

- **自动提权** — 非管理员运行时自动以管理员权限重启
- **增量下载** — 通过 Content-Length 校验避免重复下载 ODT
- **KMS 激活** — Volume 版本自动配置 GVLK 密钥与 AUTOACTIVATE
- **Mondo 证书** — O365ProPlusRetail 自动安装 Mondo 2016 许可证证书
- **桌面快捷方式** — 自动从开始菜单复制 Office 应用快捷方式到桌面
- **深度卸载** — 7 步清理：产品密钥 → 进程 → 服务 → 文件 → 注册表 → 快捷方式 → 计划任务
- **日志记录** — 全程输出至 `%TEMP%\KMS_AKAMS_CN\ODT-log.txt`

## 要求

- Windows PowerShell 5.1+
- 管理员权限

## 安全检测

- [腾讯云安全](https://tix.qq.com/search/single?keyword=c9f00cb9f11759b21ff55f08543384eb)
- [VirusTotal](https://www.virustotal.com/gui/file/0bcc43c7dfc4e7ad39f66eadaed45145cc642f9e4d9cf466717df691b0b20e10)

安全检测结果由第三方机构出具，仅作参考，网络安全具有动态性，请您自行做好安全防护和风险管控。
