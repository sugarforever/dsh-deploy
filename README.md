# DeepSeek Harness 云端部署

这个仓库用于把 `@deepseek-ai/dsh` 部署到 Ubuntu 或 Debian 云服务器，并交给 `systemd` 持续运行。服务会随系统启动；进程退出后，`systemd` 会等待 5 秒再重新启动。

安装器默认使用固定版本 `@deepseek-ai/dsh@0.1.0-rc.7`，不会在每次服务启动时临时下载 npm 包。运行数据保存在 `/var/lib/dsh`，重新安装或默认卸载都不会删除这部分数据。

## 一键安装

服务器需要满足以下条件：

- Ubuntu 或 Debian，并使用 `systemd`
- Node.js `22.19.0` 及以上的 22.x 版本，或者 Node.js `24.0.0` 及以上版本
- 已在系统目录安装 Node.js 与 `npm`，不使用仅对某个登录用户可见的 nvm 版本
- 已安装 `curl`
- 当前用户可以使用 `sudo`

直接运行：

```bash
curl -fsSL https://raw.githubusercontent.com/sugarforever/dsh-deploy/main/install.sh | sudo bash
```

远程脚本会以 root 权限运行。如果希望先检查脚本内容，可以先下载，再执行：

```bash
curl -fsSLO https://raw.githubusercontent.com/sugarforever/dsh-deploy/main/install.sh
less install.sh
sudo bash install.sh
```

安装过程会完成这些操作：

- 创建无登录权限的 `dsh` 系统用户
- 在 `/opt/dsh` 安装固定版本的 `@deepseek-ai/dsh`
- 创建持久化目录 `/var/lib/dsh`
- 创建环境变量文件 `/etc/dsh/dsh.env`
- 注册并启动 `dsh.service`
- 设置开机启动、退出自动重启和重启频率限制

脚本可以重复执行。已有的 `/etc/dsh/dsh.env` 和 `/var/lib/dsh` 会保留。

## 配置

需要传给 DSH 的环境变量放在：

```text
/etc/dsh/dsh.env
```

编辑这个文件：

```bash
sudoedit /etc/dsh/dsh.env
```

每行使用 `KEY=value`，不要添加 `export`：

```bash
YOUR_API_KEY=replace-me
```

修改后重新启动服务：

```bash
sudo systemctl restart dsh.service
```

环境文件的默认权限是 `0640`，仅 root 和 `dsh` 用户组可以读取。

## 服务管理

查看状态：

```bash
sudo systemctl status dsh.service
```

查看实时日志：

```bash
sudo journalctl -u dsh.service -f
```

启动、停止或重新启动：

```bash
sudo systemctl start dsh.service
sudo systemctl stop dsh.service
sudo systemctl restart dsh.service
```

服务使用以下恢复策略：

```ini
Restart=always
RestartSec=5
StartLimitIntervalSec=300
StartLimitBurst=10
```

这套配置可以处理进程崩溃、进程被外部信号终止和服务器重启。通过 `systemctl stop` 主动停止服务时，systemd 不会重新启动它。当前机制也不能判断“进程仍在运行，但 Web 服务已经卡死”的情况。DSH 提供稳定的健康检查地址后，可以再增加 `systemd timer` 做 HTTP 检查；当前实现不猜测端口或健康检查路径。

## 指定 DSH 版本

默认版本写在安装脚本中。需要安装其他版本时，可以显式传入：

```bash
curl -fsSL https://raw.githubusercontent.com/sugarforever/dsh-deploy/main/install.sh \
  | sudo DSH_VERSION=0.1.0-rc.7 bash
```

安装器使用 `npm install --save-exact`，因此 `package.json` 和 `package-lock.json` 会记录确切版本。

## 更新

克隆仓库后，可以把 DSH 更新到指定版本：

```bash
git clone https://github.com/sugarforever/dsh-deploy.git
cd dsh-deploy
sudo ./update.sh 0.1.0-rc.7
```

不传版本时，脚本使用仓库当前默认版本：

```bash
sudo ./update.sh
```

更新不会修改 `/etc/dsh/dsh.env` 或 `/var/lib/dsh`，完成后会重新启动服务并显示状态。

## 卸载

默认卸载会删除服务和 `/opt/dsh`，保留配置与运行数据：

```bash
sudo ./uninstall.sh
```

确认不再需要配置、数据和 `dsh` 系统用户时，使用：

```bash
sudo ./uninstall.sh --purge
```

`--purge` 会永久删除 `/etc/dsh` 和 `/var/lib/dsh`。执行前请先备份需要保留的内容。

## 文件位置

| 路径 | 用途 |
| --- | --- |
| `/opt/dsh` | npm 包、锁文件和本地 `dsh` 命令 |
| `/var/lib/dsh` | `DSH_HOME`，保存 DSH 的持久化数据 |
| `/etc/dsh/dsh.env` | 环境变量和密钥 |
| `/etc/systemd/system/dsh.service` | systemd 服务单元 |

## 网络安全

不要在没有身份验证和访问控制的情况下，把 DSH Web 界面直接暴露到公网。优先让它只监听本机，并通过 SSH Tunnel 访问；如果需要长期对外提供服务，应在前面配置带 TLS 和身份验证的反向代理，同时使用云防火墙限制来源地址。

安装后如果服务没有正常启动，先查看完整状态和最近日志：

```bash
sudo systemctl status dsh.service --no-pager --full
sudo journalctl -u dsh.service -n 200 --no-pager
```

常见原因包括 Node.js 版本不符合要求、环境变量缺失，以及 DSH 使用的端口已经被其他进程占用。

## 开发验证

仓库里的测试不会修改宿主机的 systemd 配置：

```bash
bash tests/test-common.sh
bash tests/test-install.sh
bash tests/test-lifecycle.sh
bash -n install.sh update.sh uninstall.sh lib/common.sh tests/*.sh
```
