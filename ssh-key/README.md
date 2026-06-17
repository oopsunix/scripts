# SSH Key Installer

通过 GitHub 账户、URL 或本地文件快速安装 SSH 公钥，并支持修改 SSH 端口和禁用密码登录。

## 快速使用

```bash
# 从 GitHub 获取公钥并安装
bash <(curl -fsSL https://github.com/oopsunix/scripts/raw/main/ssh-key/key.sh) -g GitHub用户名

# 从 URL 获取公钥并安装
bash <(curl -fsSL https://github.com/oopsunix/scripts/raw/main/ssh-key/key.sh) -u https://example.com/key.pub

# 从本地文件安装
bash <(curl -fsSL https://github.com/oopsunix/scripts/raw/main/ssh-key/key.sh) -f /path/to/id_rsa.pub

# 从直接传递的公钥内容字符串安装
bash <(curl -fsSL https://github.com/oopsunix/scripts/raw/main/ssh-key/key.sh) -r "ssh-rsa AAAAB3Nza..."

# 覆盖模式（替换已有密钥）
bash <(curl -fsSL https://github.com/oopsunix/scripts/raw/main/ssh-key/key.sh) -o -g GitHub用户名

# 修改 SSH 端口
bash <(curl -fsSL https://github.com/oopsunix/scripts/raw/main/ssh-key/key.sh) -p 2222

# 禁用密码登录
bash <(curl -fsSL https://github.com/oopsunix/scripts/raw/main/ssh-key/key.sh) -d
```

## 参数

| 参数 | 说明 |
|------|------|
| `-o` | 覆盖模式，替换而非追加已有密钥 |
| `-g <id>` | 从 GitHub 获取公钥，参数为 GitHub 用户名 |
| `-u <url>` | 从 URL 获取公钥 |
| `-f <path>` | 从本地文件获取公钥 |
| `-r <string>` | 从直接传递的公钥内容字符串获取公钥 |
| `-p <port>` | 修改 SSH 端口 |
| `-d` | 禁用密码登录（PasswordAuthentication no） |

选项可组合使用，如 `-o -g user -p 2222 -d`。

## 特性

- 支持 Linux 和 Android (Termux) 环境
- 自动创建 `~/.ssh/authorized_keys` 及设置权限
- 端口修改或禁用密码登录后自动重启 sshd

## 来源

基于 [P3TERX/SSH_Key_Installer](https://github.com/P3TERX/SSH_Key_Installer) v2.7
