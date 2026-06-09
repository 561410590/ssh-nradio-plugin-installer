# NRadio 插件助手

NRadio 官方 NROS 路由器使用的 SSH 菜单脚本。

- 当前版本：`V2.2.5`
- 公网页：[https://nradio.mayebano.shop/](https://nradio.mayebano.shop/)
- GitHub Releases：[发布页](https://github.com/561410590/ssh-nradio-plugin-installer/releases)

## 适用设备

支持以下官方 NROS 设备：

| 设备 | 机型代号 | NROS 范围 |
| --- | --- | --- |
| `NRadio_C8-688` | `HC-WT9104` | NROS 2.x |
| `NRadio_C8-668` | `HC-WT9108` | NROS 2.x |
| `NRadio_C5800-650` | `HC-WT9120` | NROS 2.x |
| `NRadio_C5800-688` | `HC-WT9126` | NROS 2.x |
| `NRadio_NBCPE` | `HC-WT9111` / `NRADIO-WT9111` | NROS 2.x |
| `NRadio_C2000MAX` | `HC-WT9303` | NROS 2.x |

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
| 常用插件安装 | swap（仅 C2000MAX）、哈基米、Web SSH、AdGuardHome、OpenList、MosDNS、DDNS-GO、Docker（仅 C8/C5800 扩展盘） |
| VPN / 组网 / 路由向导 | EasyTier、ZeroTier、OpenVPN |
| 游戏加速器 | 奇游、雷神、状态读取和卸载链 |
| 应用商店与页面美化 | 卡片视觉、状态徽标、原厂还原 |
| 设备维护与检测 | 统一体检、哈基米傻瓜分流助手、C8/C5800 eMMC 存储扩展、通用卸载链、风扇控制 |

## V2.2.5 更新

- `SCRIPT_VERSION` 更新为 `V2.2.5`，发布日期 `2026-06-09`。
- OpenClash 应用商店 iframe 弹窗保留原逻辑，补入黑屏兜底、重载按钮和原版页面顶层跳转。
- OpenClash 保留六个官方标签页：运行状态、插件设置、覆写设置、配置订阅、配置管理、运行日志。
- OpenClash 原版页面隐藏 OEM 顶栏、footer、首页、蜂窝、上网、Wi-Fi、终端和更多，并修复半屏显示。
- 公网页同步 V2.2.5 版本口径，补入 V2.2.0 C2000MAX swap 状态卡日志和 V2.2.5 OpenClash 兼容日志。
- 当前脚本 SHA256：`2666c42c23cddc22ade3911eff0571c967d69821d0cadd3691bb7719a26c6c93`（大小 1899977 字节）。

## V2.2.0 更新

- 应用商店系统状态卡新增 C2000MAX 虚拟内存指标，读取 swap 总量、用量和百分比。
- 非 C2000MAX 自动隐藏 swap 指标，C2000MAX 未启用 swap 时显示“未启用”。

## V2.1.5 更新

- 新增 `NRadio_C5800-650` / `HC-WT9120` 识别，按 NROS 2.x 口径放行。
- Docker / `rootfs_2nd` 扩展盘链补入 C5800-650。
- 缺 NRadio 应用商店环境时，启动层直接退出并提示缺失路径。

## V2.1.0 更新

- Docker 加入常用插件安装菜单第 8 项，仅支持 `NRadio_C5800-688` / `NRadio_C8-688`。
- Docker 安装前要求已启用 `rootfs_2nd` eMMC 扩展盘，下载缓存、feed index、工作目录、IPK 缓存、手动解包目录、备份和 `data-root` 均固定在 `/mnt/rootfs_2nd_data/nradio-apps/docker`。
- Docker LuCI 页面写入 `nradioadv/system/docker`，应用商店入口、图标、状态接口和异步卸载链同步接入。
- Docker 安装链修复 overlay 打满和系统路径污染风险：大体积 Docker 二进制保留扩展盘软链，小依赖库复制到系统路径。
- 公网页同步 V2.1.0 版本口径，当前里程碑改为 Docker 扩展盘安装链接入，历史更新卡只保留 V2.0.70。
- 当前脚本 SHA256：`ec15ab95aca25528f85ed57b1bf2fbc7d243222b2fa1d2262e480892f4da50bd`（大小 1872225 字节）。

## V2.0.70 更新

- 5G 负载均衡支持副 5G / 蜂窝权重设置，保存后自动提交并重启 `mwan3`，避免 UCI 已变但运行态仍停留在旧比例。
- 新增 **C8/C5800 eMMC 存储扩展**，支持将 `rootfs_2nd` 接入为扩展盘，并提供应用迁移、还原和第二系统烧录保护。
- OpenClash / AdGuardHome 还原支持 hybrid 保留策略，overlay 空间不足时保留大项子链接，避免误删扩展盘真实内容。
- OpenClash 扩展盘迁移和哈基米分流助手重载前新增 `ASN.mmdb` 有效性校验，缺失或异常时先停止并提示补齐。
- 修复 OpenList 在 C8/C5800 存储扩展后 `/mnt/app_data/openlist` 断链目标缺失导致安装失败的问题；安装链会识别符号链接并先修复扩展盘目标目录。
- 修复 DDNS-GO 迁移到扩展盘后以 `ddns-go` 用户启动失败的问题，迁移/还原菜单会修正 `nradio-apps` 路径可穿透权限。
- OpenVPN 页面升级到 Mk5 深色玻璃界面，pass 7 至 pass 10 精修已回写总脚本，补强标题、摘要卡、按钮、日志、诊断区、弹窗和小屏防溢出细节。
- AdGuardHome 与应用商店页面美化继续回写总脚本，AdGuardHome 状态页精修、应用商店 pass 3 至 pass 6、系统卡片内存显示、OpenVPN 版本号短显示和 C2000MAX 1 号卡白条修复已进入安装输出。
- 公网页同步 V2.0.70 版本口径，并保留粉色主题视觉精修。
- 本地全量 bug 扫描收口：安装链移除 `base64` / `gzip` 依赖路径，OpenList / DDNS-GO 归档校验改为 tar 自检，MosDNS 解压前补齐 `unzip` 依赖兜底，应用商店 iframe 关闭与外层布局清洗链同步修复。
- 常用插件菜单中的 **扩容 swap 虚拟内存** 仅支持 `NRadio_C2000MAX`，菜单文案同步标明限制。
- 当前脚本 SHA256：`b4aad4ddabde87ce3f4eff2890a4193eb474cf757e9788307fab75ee441b155f`（大小 1702232 字节）。

## V2.0.50 更新

- 新增 **DDNS-GO** 插件（常用插件菜单第 7 项），包含三件套安装、OEM 包装页、图标、应用商店注册、异步卸载链和虚拟内存接入。
- DDNS-GO 首次安装会在启动服务前设置 Web 登录账号密码，并初始化 `/etc/ddns-go/ddns-go-config.yaml`。
- 修复 `opkg print-architecture` 中 `noarch` 排在前面时导致 DDNS-GO 架构误判的问题。
- 补强应用商店 `package_list` 路由校验、旧路由清理、异步卸载日志、同插件并发锁和 opkg 锁等待。
- C2000MAX 安装 OpenList 时自动改用 lite 包，并把下载包与解压目录放到存储卡，降低 `/tmp` 内存占用和文件过大导致的安装失败风险。
- 公网页同步 V2.0.50 已发布口径，补入 DDNS-GO、应用商店卡片布局和 AdGuardHome 内页二次重新美化说明。
- 当前脚本 SHA256：`e32fc09076793822635c65e174e32caf55ab9ecf8e6f9039cccbf5ab635e188a`（大小 1163194 字节）。

## 版本记录

- `V2.2.5`：OpenClash iframe 黑屏兜底、原版页面顶层跳转、六标签保留、OEM 顶栏隐藏和半屏修复。
- `V2.2.0`：C2000MAX 应用商店系统状态卡补入 swap 虚拟内存显示。
- `V2.1.5`：C5800-650 / HC-WT9120 支持、NROS 2.x 口径放行、应用商店缺失启动阻断。
- `V2.1.0`：Docker 扩展盘安装链接入、C8/C5800 rootfs_2nd 落盘、Docker LuCI 页面、应用商店入口和卸载链接入。
- `V2.0.70`：5G 负载均衡权重设置、mwan3 运行态生效修复、OpenVPN Mk5 pass10、AdGuardHome 状态页精修、应用商店显示修复、C2000MAX 1 号卡白条修复和公网页粉色视觉精修。
- `V2.0.60`：C8/C5800 eMMC 存储扩展、OpenList 存储扩展断链修复、hybrid 应用还原、DDNS-GO 迁移权限修复、OpenClash ASN.mmdb 防丢失校验、C2000MAX swap 菜单限制。
- `V2.0.55`：统一体检增强、哈基米傻瓜分流助手、OpenList C2000MAX 风险提示和哈基米规则生效修复。
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
| `00-current/ssh-nradio-plugin-installer.sh` | V2.2.5 当前主线脚本 |
| `40-server-web/mayebano-support/index.html` | 公网支持页入口，当前与 `ai_studio_code.html` 保持一致 |
| `40-server-web/mayebano-support/ai_studio_code.html` | 新版支持页源稿 |
| `40-server-web/mayebano-support/wechat-donate.png` | 微信支持图片 |
| `CHECKSUMS.txt` | 当前公开文件校验 |
| `CHANGELOG.md` | 版本记录 |
| `CONTRIBUTING.md` | 反馈和贡献说明 |
| `SECURITY.md` | 安全反馈 |

## 脚本校验

当前脚本：

```text
SHA256  2666c42c23cddc22ade3911eff0571c967d69821d0cadd3691bb7719a26c6c93
Bytes   1899977
Path    00-current/ssh-nradio-plugin-installer.sh
```

更多校验值见 [CHECKSUMS.txt](CHECKSUMS.txt)。

## 反馈

- 反馈问题前请阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。
- 安全相关反馈请阅读 [SECURITY.md](SECURITY.md)。
- 提交 issue 时不要公开 root 密码、Cookie、SSH 地址、私有密钥或完整现场备份。

## 开源许可证

本项目使用 [MIT License](LICENSE) 开源。
