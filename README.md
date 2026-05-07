# NRadio 插件助手

NRadio 官方 NROS2.0 路由器使用的 SSH 菜单脚本。

- 当前版本：`V2.0.40`
- 公网页：[https://nradio.mayebano.shop/](https://nradio.mayebano.shop/)
- 最近已确认 Release：[v2.0.35](https://github.com/561410590/ssh-nradio-plugin-installer/releases/tag/v2.0.35)

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
| 常用插件安装 | Web SSH、OpenList、AdGuardHome、哈基米 |
| VPN / 组网 / 路由向导 | EasyTier、ZeroTier、OpenVPN |
| 游戏加速器 | 奇游、雷神、状态读取和卸载链 |
| 应用商店与页面美化 | 卡片视觉、状态徽标、原厂还原 |
| 设备维护与检测 | swap、自检、通用卸载链、风扇控制 |

## V2.0.40 更新

- 保留 `V2.0.35` 的 **MosDNS** 插件能力，并继续修复 MosDNS 同步器日志路径和 SHA256 校验兜底。
- 修复 EasyTier 应用商店卸载后路由规则残留，清理链覆盖 `priority 60 / 70 / 196`。
- AdGuardHome 应用商店内页重新美化，首页打开即可直接看到 DNS 查询和拦截统计数，并补齐监听、运行态和 `3000` 仪表盘认证链路。
- C2000MAX 实机补录 AdGuardHome `dashboard_user / dashboard_password` 后，应用商店内页已恢复显示真统计。
- 修复 AdGuardHome `base.lua` heredoc 中残留的 Linux 空设备重定向问题：`2>nul` 改为 `2>/dev/null`。
- 当前脚本 SHA256：`0eeb26c254d8c97fa1ed4bc3addc44e2674eb9d07cdae07361c06b52f47b8188`（大小 1037112 字节）。

## 版本记录

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
| `00-current/ssh-nradio-plugin-installer.sh` | V2.0.40 当前主线脚本 |
| `40-server-web/mayebano-support/index.html` | 公网支持页 |
| `40-server-web/mayebano-support/wechat-donate.png` | 微信支持图片 |
| `CHECKSUMS.txt` | 当前公开文件校验 |
| `CHANGELOG.md` | 版本记录 |
| `CONTRIBUTING.md` | 反馈和贡献说明 |
| `SECURITY.md` | 安全反馈 |

## 脚本校验

当前脚本：

```text
SHA256  0eeb26c254d8c97fa1ed4bc3addc44e2674eb9d07cdae07361c06b52f47b8188
Bytes   1037112
Path    00-current/ssh-nradio-plugin-installer.sh
```

更多校验值见 [CHECKSUMS.txt](CHECKSUMS.txt)。

## 反馈

- 反馈问题前请阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。
- 安全相关反馈请阅读 [SECURITY.md](SECURITY.md)。
- 提交 issue 时不要公开 root 密码、Cookie、SSH 地址、私有密钥或完整现场备份。

## 开源许可证

本项目使用 [MIT License](LICENSE) 开源。
