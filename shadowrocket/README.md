# ShadowTLS 管理脚本

一键部署 SS2022 + ShadowTLS V3 的自动化管理脚本，支持交互式菜单操作，自动下载、配置、升级和卸载。

## 快速使用

```bash
# 一键安装
bash <(curl -fsSL https://raw.githubusercontent.com/oopsunix/script/main/shadowrocket/stls.sh)
```

## 功能菜单

| 选项 | 说明 |
|------|------|
| 1 | Shadowsocks 管理（安装/升级/修改配置/卸载） |
| 2 | ShadowTLS 管理（安装/升级/修改配置/卸载） |
| 3 | 一键安装 SS2022 + ShadowTLS |
| 4 | 生成客户端配置（Shadowrocket/Surge/Loon/Mihomo/Sing-box） |
| 5 | 系统工具（系统信息/网络状态/日志/防火墙/优化） |
| 9 | 完全卸载所有服务 |

## 支持的客户端配置

安装完成后自动生成以下客户端的连接配置：

- **Shadowrocket** — ss:// 链接 + 二维码
- **Surge** — SS+sTLS 代理行
- **Loon** — SS+sTLS 代理行
- **Mihomo (Clash Meta)** — YAML 代理节点
- **Sing-box** — JSON 出站配置

## 特性

- 交互式菜单，支持分步安装或一键部署
- 自动检测系统架构（x86_64 / aarch64）并下载对应二进制
- 自动创建 systemd 服务并设置开机自启
- 支持 SS 配置修改后自动同步 ShadowTLS 后端端口
- 系统网络优化（BBR、TCP Fast Open 等）
- 多源获取服务器公网 IP（支持 IPv4/IPv6）

## 依赖

- Linux 系统（支持 apt/yum/dnf/pacman）
- root 权限
- 自动安装：`wget` `curl` `jq` `qrencode`

## 来源

- Shadowsocks Rust: [shadowsocks/shadowsocks-rust](https://github.com/shadowsocks/shadowsocks-rust)
- ShadowTLS: [ihciah/shadow-tls](https://github.com/ihciah/shadow-tls)
