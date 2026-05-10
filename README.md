# NRadio 插件助手

NRadio 官方 NROS2.0 路由器使用的 SSH 菜单脚本。

- 当前版本：`V2.0.50`
- 公网页：[https://nradio.mayebano.shop/](https://nradio.mayebano.shop/)
- GitHub Releases：[发布页](https://github.com/561410590/ssh-nradio-plugin-installer/releases)

## 适用设备

支持以下官方 NROS2.0 设备：

| 设备 |
| --- |
| `NRadio_C8-688` |
| `NRadio_C8-668` |
| `NRadio_C5800-688` |
| `NRadio_NBCPE` |
| `NRadio_C2000MAX` |

标准 OpenWrt 不适用。脚本不是应用商店安装包，也不是固件升级包。

## 安装

先在 NRadio 后台系统安全页开启 SSH，保存并应用。

SSH 登录路由器后，在终端执行：

```sh
cd /root
wget -O ssh-nradio-plugin-installer.sh https://nradio.mayebano.shop/ssh-nradio-plugin-installer.sh
sh ssh-nradio-plugin-installer.sh
```

出现 NRadio 脚本菜单后，再按菜单编号继续。

不要把脚本上传到应用商店，也不要当固件升级包使用。

## 功能清单

当前 5 个功能分类：

| 功能分类 | 内容 |
| --- | --- |
| 常用插件安装 | swap、哈基米、Web SSH、AdGuardHome、OpenList、MosDNS、DDNS-GO |
| VPN / 组网 / 路由向导 | EasyTier、ZeroTier、OpenVPN |
| 游戏加速器 | 奇游、雷神、状态读取和卸载链 |
| 应用商店与页面美化 | 卡片视觉、状态徽标、原厂还原 |
| 设备维护与检测 | swap、自检、通用卸载链、风扇控制 |

## V2.0.50 更新

- 新增 **DDNS-GO** 插件（常用插件菜单第 7 项），包含三件套安装、OEM 包装页、图标、应用商店注册、异步卸载链和虚拟内存接入。
- DDNS-GO 首次安装会在启动服务前设置 Web 登录账号密码，并初始化 `/etc/ddns-go/ddns-go-config.yaml`。
- 修复 `opkg print-architecture` 中 `noarch` 排在前面时导致 DDNS-GO 架构误判的问题。
- 补强应用商店 `package_list` 路由校验、旧路由清理、异步卸载日志、同插件并发锁和 opkg 锁等待。
- C2000MAX 安装 OpenList 时自动改用 lite 包，并把下载包与解压目录放到存储卡，降低 `/tmp` 内存占用和文件过大导致的安装失败风险。
- 公网页同步 V2.0.50 已发布口径，补入 DDNS-GO、应用商店卡片布局和 AdGuardHome 内页二次重新美化说明。
- 当前脚本 SHA256：`e32fc09076793822635c65e174e32caf55ab9ecf8e6f9039cccbf5ab635e188a`（大小 1163194 字节）。

## 版本记录

- `V2.0.50`：DDNS-GO 集成，OpenList C2000MAX 安装链降内存，应用商店和 AdGuardHome 页面重新美化，卸载链和校验链补强。
- `V2.0.40`：EasyTier / MosDNS 修复，AdGuardHome 内页重新美化并补齐监听和统计链路。
- `V2.0.35`：新增 MosDNS 插件。
- `V2.0.30`：雷神卸载残留清理。
- `V2.0.25`：应用商店原厂还原入口与版本头更新。
- `V2.0.20`：OpenVPN 控制台界面升级。
- `V2.0.15`：奇游 / 雷神源切换。
- `V2.0.10`：风扇定时策略。
- `V2.0.7`：新增 `NRadio_C8-668`。
- `V2.0.6`：奇游状态与应用商店标记收口。
- `V2.0.3`：风扇控制增强。
- `V2.0.2`：FanControl 路由、奇游 / 雷神阶段提示和 SHA256 日志补齐。
- `V2.0.1`：风扇控制支持 `NRadio_C8-688` / `NRadio_C2000MAX`。
- `V2.0.0`：默认下载脚本切到正式版。

## 文件

| 文件 | 用途 |
| --- | --- |
| `00-current/ssh-nradio-plugin-installer.sh` | V2.0.50 当前主线脚本 |
| `40-server-web/mayebano-support/index.html` | 公网支持页 |
| `40-server-web/mayebano-support/wechat-donate.png` | 微信支持图片 |
| `CHECKSUMS.txt` | 当前公开文件校验 |
| `CHANGELOG.md` | 版本记录 |
| `CONTRIBUTING.md` | 反馈和贡献说明 |
| `SECURITY.md` | 安全反馈 |

## 脚本校验

当前脚本：

```text
SHA256  e32fc09076793822635c65e174e32caf55ab9ecf8e6f9039cccbf5ab635e188a
Bytes   1163194
Path    00-current/ssh-nradio-plugin-installer.sh
```

更多校验值见 [CHECKSUMS.txt](CHECKSUMS.txt)。

## 反馈

- 反馈问题前请阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。
- 安全相关反馈请阅读 [SECURITY.md](SECURITY.md)。
- 提交 issue 时不要公开 root 密码、Cookie、SSH 地址、私有密钥或完整现场备份。

## 开源许可证

本项目使用 [MIT License](LICENSE) 开源。
