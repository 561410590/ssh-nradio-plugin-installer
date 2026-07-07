# Changelog

## V2.6.0 - 2026-06-15

- `SCRIPT_VERSION` 更新为 `V2.6.0`。
- `SCRIPT_RELEASE_DATE` 更新为 `2026-06-15`。
- 新增 `NRadio_C2000Pro` 识别，覆盖 C2000-518 / UDX710 / RG200U-CN 口径。
- 新增 C2000Pro 兼容应用商店层，写入应用前生成 controller/template，还原时只移除脚本生成文件。
- C2000Pro 启动免责声明新增专属资源和风险提示。
- 新增哈基米依赖检查修复，覆盖 OpenClash 本体、配置、核心、`ASN.mmdb` 和 `Model.bin`。
- 新增封版工具箱、脱敏诊断报告、备份清单摘要和动作日志摘要。
- 公网页支持矩阵补入 `NRadio_C2000Pro`，设备介绍按官方蜂窝组网页面的产品定位更新，版本演进档案同步补入 V2.6.0 和 V2.5.0。

## V2.5.0 - 2026-06-14

- `SCRIPT_VERSION` 更新为 `V2.5.0`。
- `SCRIPT_RELEASE_DATE` 更新为 `2026-06-14`。
- 新增哈基米依赖检查修复，覆盖 OpenClash 本体、配置、服务、smart/meta 核心、`ASN.mmdb` 和 `Model.bin`。
- `Model.bin` 支持从多个候选路径识别并复制修复，缺失时使用 OpenClash 官方 LightGBM 模型源和镜像源。
- `5 > 1` 统一体检增强版补入封版摘要、备份清单摘要和动作日志摘要。
- `5 > 7` 新增封版工具箱，可导出脱敏诊断报告、查看备份清单和动作日志。

## V2.3.0 - 2026-06-13

- `SCRIPT_VERSION` 更新为 `V2.3.0`。
- `SCRIPT_RELEASE_DATE` 更新为 `2026-06-13`。
- PicoClaw / 鲲鹏小龙虾接入 C8/C5800 `rootfs_2nd` 应用迁移与还原链。
- `5 > 4 > 5` 迁移和 `5 > 4 > 6` 还原新增 `/usr/bin/picoclaw`、`/usr/bin/picoclaw-launcher`、`/.picoclaw`。
- 迁移复用现有 `nradio-apps` 软链记录、服务停启、运行文件校验和还原流程。
- 公网页同步 V2.3.0 当前版本口径。

## V2.2.5 - 2026-06-09

- `SCRIPT_VERSION` 更新为 `V2.2.5`。
- `SCRIPT_RELEASE_DATE` 更新为 `2026-06-09`。
- OpenClash 应用商店 iframe 弹窗保留原有弹窗逻辑和六个官方标签页。
- OpenClash iframe 增加黑屏/空白兜底，可重载弹窗或顶层打开原版页面。
- “原版页面”按钮顶层跳转到 `/cgi-bin/luci/admin/services/openclash/client`。
- OpenClash 原版页面隐藏 OEM 顶栏、footer、首页、蜂窝、上网、Wi-Fi、终端和更多。
- OpenClash 原版页面修复固定高度导致的半屏显示问题。
- 公网页同步 V2.2.5 当前版本口径，并保留 V2.2.0、V2.1.5、V2.1.0 历史日志。

## V2.2.0 - 2026-06-04

- 应用商店系统状态卡新增 C2000MAX 识别。
- C2000MAX 显示 swap 虚拟内存总量、用量和百分比。
- 非 C2000MAX 隐藏 swap 指标；C2000MAX 未启用 swap 时显示“未启用”。

## V2.1.5 - 2026-05-29

- 新增 `NRadio_C5800-650` / `HC-WT9120` 识别。
- NROS `1.9.4.n0.c3` 按 C5800-650 机型放行。
- Docker / `rootfs_2nd` 扩展盘支持链补入 C5800-650。
- 缺 NRadio 应用商店环境时，启动层直接退出并提示缺失路径。

## V2.1.0 - 2026-05-28

- `SCRIPT_VERSION` 更新为 `V2.1.0`。
- `SCRIPT_RELEASE_DATE` 更新为 `2026-05-28`。
- Docker 加入常用插件安装菜单第 8 项，仅支持 `NRadio_C5800-688` / `NRadio_C8-688`。
- Docker 安装前要求已启用 `rootfs_2nd` eMMC 扩展盘，下载缓存、feed index、工作目录、IPK 缓存、手动解包目录、备份和 `data-root` 均固定在 `/mnt/rootfs_2nd_data/nradio-apps/docker`。
- Docker LuCI 页面写入 `nradioadv/system/docker`，应用商店入口、图标、状态接口和异步卸载链同步接入。
- Docker 安装链修复 overlay 打满和系统路径污染风险：大体积 Docker 二进制保留扩展盘软链，小依赖库复制到系统路径。
- 公网页同步 V2.1.0 版本口径，当前里程碑改为 Docker 扩展盘安装链接入，更新卡不重复展示 V2.1.0。

## V2.0.70 - 2026-05-19

- `SCRIPT_VERSION` 更新为 `V2.0.70`。
- `SCRIPT_RELEASE_DATE` 更新为 `2026-05-19`。
- 5G 负载均衡支持副 5G / 蜂窝权重设置，保存后自动提交并重启 `mwan3`，避免 UCI 已变但运行态仍停留在旧比例。
- 新增 C8/C5800 eMMC 存储扩展，支持 `rootfs_2nd` 扩展盘接入、应用迁移、应用还原和第二系统烧录保护。
- 补强应用还原：OpenClash / AdGuardHome 在 overlay 空间不足时可进入 hybrid 状态，保留扩展盘大项子链接并继续记录迁移状态，避免误删扩展盘真实内容。
- 修复 OpenList 在 C8/C5800 存储扩展后 `/mnt/app_data/openlist` 断链目标缺失导致安装失败的问题；安装链会识别符号链接并先创建扩展盘目标目录及 `bin/data/tmp`。
- 修复 DDNS-GO 迁移到扩展盘后以 `ddns-go` 用户启动失败的问题：存储扩展入口、迁移和还原流程会修正 `nradio-apps` 及目标父目录的可穿透权限。
- OpenClash 扩展盘迁移、还原和哈基米分流助手重载前新增 `ASN.mmdb` 有效性校验，避免缺失数据库时继续迁移或重载。
- OpenVPN 页面升级到 Mk5 深色玻璃界面，pass 7 / pass 8 / pass 9 / pass 10 精修已回写总脚本，并修复摘要卡、标题压缩、表单、日志、诊断区、弹窗层级和小屏溢出细节。
- AdGuardHome 状态页精修、应用商店 pass 3 至 pass 6 精修和 C5800 热更新结果已回写总脚本。
- 应用商店系统卡片内存显示改为短文本，OpenVPN 应用卡版本号显示短版本并保留完整 title。
- 修复 C2000MAX 应用商店 1 号应用卡 `::after` 背景选择器缺口，补齐 `3n+1 / 3n+2 / 3n+3` 同级覆盖。
- 公网页同步 V2.0.70 版本口径，并保留粉色主题视觉精修。
- 本地全量 bug 扫描收口：安装链移除 `base64` / `gzip` 依赖路径，OpenList / DDNS-GO 归档校验改为 tar 自检，MosDNS 解压前补齐 `unzip` 依赖兜底，应用商店 iframe 关闭与外层布局清洗链同步修复。
- 常用插件菜单中的扩容 swap 虚拟内存入口改为仅支持 `NRadio_C2000MAX`，菜单文案同步为“扩容 swap 虚拟内存（仅支持NRadio_C2000MAX）”。

## V2.0.55 - 2026-05-11

- `SCRIPT_VERSION` 更新为 `V2.0.55`。
- `SCRIPT_RELEASE_DATE` 更新为 `2026-05-11`。
- 设备维护与检测新增统一体检增强版，覆盖系统资源、安装前预检、插件健康矩阵、应用商店一致性、端口冲突、哈基米规则检查和脱敏摘要。
- 设备维护与检测新增哈基米傻瓜分流助手，读取当前 YAML 分流目标后，可按数字菜单把域名、IP 或网段写入哈基米自定义规则文件。
- 哈基米自定义规则固定写入 `/etc/openclash/custom/openclash_custom_rules.list`，避免订阅 YAML 更新覆盖用户规则。
- 修复相同哈基米规则已存在时未启用自定义规则开关的问题，确保已有规则也能生效。
- 修复 C2000MAX 工厂提取内容中 `etc/gcom/ncm.json` 的非法尾逗号。

## V2.0.50 - 2026-05-10

- `SCRIPT_VERSION` 更新为 `V2.0.50`。
- `SCRIPT_RELEASE_DATE` 更新为 `2026-05-10`。
- 新增 **DDNS-GO** 插件（常用插件菜单第 7 项），安装链覆盖下载校验、三件套安装、OEM 包装页、图标、应用商店注册、异步卸载链和虚拟内存接入。
- DDNS-GO 首次安装流程新增 Web 登录账号密码设置，启动服务前初始化并写入 `/etc/ddns-go/ddns-go-config.yaml`。
- 修复 `opkg print-architecture` 中 `noarch` 排在前面时导致 DDNS-GO 架构校验误判的问题。
- 补强 DDNS-GO 应用商店 `package_list` 路由校验，避免命中 package 主条目后误报 route mismatch。
- 补强应用商店异步卸载链：任务日志写入当前插件日志、同插件并发锁、opkg 锁等待和失败反馈。
- 修复 appcenter cfg 口径下旧路由清理、section 类型识别、DDNS-GO YAML user/password 补齐和权限一致性问题。
- 修复 C2000MAX 安装 OpenList 时下载包和解压目录占用 `/tmp` 的 OOM 风险：C2000MAX 自动改用 OpenList lite 包，并把下载包与解压目录放到存储卡临时目录。
- OpenList C2000MAX 下载失败兜底改为清理损坏续传临时文件后切换源或完整重下，避免坏 `.tmp` 反复参与续传。
- 公网页同步 V2.0.50 已发布口径，补入 DDNS-GO、应用商店卡片布局和 AdGuardHome 内页二次重新美化说明。

## V2.0.40 - 2026-05-08

- `SCRIPT_VERSION` 更新为 `V2.0.40`。
- `SCRIPT_RELEASE_DATE` 更新为 `2026-05-08`。
- 修复 EasyTier 应用商店卸载后路由规则残留，清理链覆盖 `priority 60 / 70 / 196`。
- 修复 MosDNS 同步器日志路径写死问题，改为读取 `mosdns.main.log_file`。
- 修复 MosDNS 下载后 SHA256 为空时仍可能放行的问题。
- AdGuardHome 应用商店内页重新美化，首页打开即可直接看到 DNS 查询和拦截统计数。
- AdGuardHome 内页新增本地运行态/监听回退，未填 `Dashboard API password` 时也能显示运行中、监听地址和端口。
- 安装链补入 AdGuardHome `dashboard_user / dashboard_password` 录入逻辑，便于直接读取 `3000` 原版仪表盘统计。
- 修复 AdGuardHome `base.lua` heredoc 中残留的 Linux 空设备重定向问题：`2>nul` 改为 `2>/dev/null`。
- 公网页同步到 V2.0.40 当前主线口径，并加入 AdGuardHome 内页重新美化说明。

## V2.0.35 - 2026-05-06

- `SCRIPT_VERSION` 更新为 `V2.0.35`。
- `SCRIPT_RELEASE_DATE` 更新为 `2026-05-06`。
- 新增 **MosDNS** 插件（常用插件菜单第 6 项）：轻量 DNS 分流，支持国内外上游 DNS 分流/缓存，UCI 配置页 + 保存自动同步 YAML + 日志页。
- 脚本内新增 MosDNS 完整安装链、卸载链、CDN 下载优化、自写进度条。
- 公网页同步 V2.0.35 版本口径，新增 MosDNS 说明。

## V2.0.30 - 2026-05-04

- `SCRIPT_VERSION` 更新为 `V2.0.30`。
- `SCRIPT_RELEASE_DATE` 更新为 `2026-05-04`。
- 雷神主卸载链在官方卸载脚本执行后继续无条件兜底清理。
- 雷神内置 `/usr/libexec/nradio-leigod-uninstall` 同步无条件兜底清理。
- 雷神卸载链补删 `/etc/config/acc_version.ini` 和 `/tmp/leigod-plugin-install.sh`。
- 实机验证确认应用商店卸载后无雷神二进制、init、配置、进程、监听端口、controller、view、icon 和 AppCenter 残留。
- 公网页同步 V2.0.30 雷神卸载残留清理说明，并保留 V2.0.25 / V2.0.20 历史更新卡。

## V2.0.25 - 2026-05-03

- `SCRIPT_VERSION` 更新为 `V2.0.25`。
- `SCRIPT_RELEASE_DATE` 更新为 `2026-05-03`。
- 应用商店与页面美化菜单保留“还原应用商店”入口。
- 还原功能直接写回脚本内置 C2000MAX 2.1.7 原厂 `appcenter.htm` / `appcenter.lua`。
- 该功能不读取旧备份目录，不覆盖 `/etc/config/appcenter`。
- 应用商店美化内部 CSS 与校验标记同步为 V2.0.25。
- 公网页同步 V2.0.25 应用商店恢复默认说明，并保留 V2.0.20 历史更新卡。

## V2.0.20 - 2026-05-02

- `SCRIPT_VERSION` 更新为 `V2.0.20`。
- `SCRIPT_RELEASE_DATE` 更新为 `2026-05-02`。
- OpenVPN 控制台界面升级，主页面删除“配置 / 认证 / 隧道 / 路由”四个冗余状态项。
- “实时校验”统一改为“目标检查”，“推荐动作”统一改为“可用操作”，“诊断工作区”统一改为“诊断”。
- 基础配置、高级配置、文件编辑和导入页面同步统一为暗色控制台风格。
- 二级页返回按钮统一为“返回控制台”，导入页“推荐”标签改为“模板”。
- 补齐 OpenVPN Mk3 CSS 精确覆盖块，确保安装输出使用当前本地 Mk3 美化版样式。
- 公网页同步 V2.0.20 OpenVPN 控制台界面升级说明，并继续保持粉色主题。

## V2.0.15 - 2026-05-01

- `SCRIPT_VERSION` 更新为 `V2.0.15`。
- `SCRIPT_RELEASE_DATE` 更新为 `2026-05-01`。
- 奇游联机宝安装前改为调用 `ensure_opkg_update`，复用哈基米的软件源检查和切换流程。
- 雷神加速器安装前改为调用 `ensure_opkg_update`，复用哈基米的软件源检查和切换流程。
- 如果软件源不是 OpenWrt 21.02.7 清华源，会先备份原配置并切换，再继续安装依赖。
- `opkg update` 失败提示统一指向 `/tmp/nradio-plugin-opkg.update.log`。
- 公网页同步 V2.0.15 奇游 / 雷神源切换说明。

## V2.0.10 - 2026-04-30

- `SCRIPT_VERSION` 更新为 `V2.0.10`。
- `SCRIPT_RELEASE_DATE` 保持 `2026-04-30`。
- 风扇控制页面新增定时策略开关，默认关闭，不影响现有用户配置。
- 定时策略支持开始时间、结束时间和定时期间模式，可选 `Close` / `Low` / `Medium` / `High` / `Smart`。
- 支持跨天时段，例如 `23:00` 到 `07:00`。
- 过热保护仍为最高优先级，定时模式不能覆盖保护逻辑。
- C8-688 / C2000MAX 继续保留各自的温度来源、检测间隔、Smart 最低风速和过热保护默认策略。
- 公网页同步 V2.0.10 风扇定时策略说明。

## V2.0.7 - 2026-04-30

- `SCRIPT_VERSION` 更新为 `V2.0.7`。
- `SCRIPT_RELEASE_DATE` 更新为 `2026-04-30`。
- 新增 `HC-WT9108` 机型识别，并映射为 `NRadio_C8-668`。
- 脚本首页支持机型文案加入 `NRadio_C8-668`。
- 风扇控制门禁保持不变，仍只开放 `NRadio_C8-688` / `NRadio_C2000MAX`。
- 公网页同步 V2.0.7 版本口径，支持机型扩展为 5 款。

## V2.0.6 - 2026-04-29

- `SCRIPT_VERSION` 更新为 `V2.0.6`。
- `SCRIPT_RELEASE_DATE` 更新为 `2026-04-29`。
- 应用商店美化用户可见口径统一为“哈基米”，底层 OpenClash 路由保持原插件路径。
- 奇游联机宝状态查看在未安装场景下不再因缺少 `PKG_INFO` 触发 `set -e` 异常退出。
- 公网页同步 V2.0.6 版本口径、安装教程闭环和主要功能区布局。

## V2.0.5 - 2026-05-01

- `SCRIPT_VERSION` 更新为 `V2.0.5`。
- `SCRIPT_RELEASE_DATE` 更新为 `2026-05-01`。
- 基于 V2.0.3 风扇控制增强继续发布，保留温度来源、Smart 最低风速、多段阈值、过热保护和检测间隔。
- OpenVPN 连接中枢 Mk2 美化热更新回写总脚本。
- OpenVPN 状态接口新增 `fast=1` 快速模式，首次打开跳过逐条远端探测，完整诊断随后自动补齐。
- OpenVPN 标准页、二级分类页和上传提示区补齐无障碍状态与视觉层。
- 公网页和定时发布 workflow 更新为 2026-05-01 发布口径。

## V2.0.2 - 2026-04-29

- `SCRIPT_VERSION` 更新为 `V2.0.2`。
- 应用商店 FanControl 打开路由统一为 `nradioadv/system/fanctrl`，并保留旧 `fanctrl_plus` 路由迁移逻辑。
- 奇游联机宝安装阶段号统一为 3 阶段，并记录入口脚本 SHA256。
- 雷神加速器安装阶段号统一为 3 阶段，记录官方脚本 SHA256，并对依赖安装失败给出明确提示。
- 应用商店美化修复层标记同步到 V2.0.2。

## V2.0.1 - 2026-04-28

- `SCRIPT_VERSION` 更新为 `V2.0.1`。
- 设备维护与检测中的风扇控制从仅支持 `NRadio_C8-688` 扩展为支持 `NRadio_C8-688` / `NRadio_C2000MAX`。
- 风扇控制菜单、安装提示和完成说明同步为 C8-688 / C2000MAX 口径。
- 独立风扇控制脚本标题同步为 `NRadio-C8-688/C2000MAX风扇控制插件脚本`。
- 应用商店美化修复层标记同步到 V2.0.1，避免正式脚本内部版本标记混淆。
- `SCRIPT_RELEASE_DATE` 更新为 `2026-04-29`。

## V2.0.0 - 2026-04-27

- 正式脚本切换为默认公开下载文件：`00-current/ssh-nradio-plugin-installer.sh`。
- `SCRIPT_VERSION` 固定为 `V2.0.0`。
- 主菜单改为 5 个功能分类。
- 奇游联机宝和雷神加速器并入正式菜单，取消“测试中”显示。
- 旧 beta 独立短下载入口从 `vercel.json` 移除。
- 公网页更新为单一 V2.0.0 下载入口。
- 支持页继续美化，首屏、下载面板和底部说明改为正式发布页口径。

验证记录：

- 公网支持页：`https://nradio.mayebano.shop/` 返回 `200`。
- 公网脚本：`https://nradio.mayebano.shop/ssh-nradio-plugin-installer.sh` 返回 `200`。
- 公网脚本版本行：`SCRIPT_VERSION="V2.0.0"`。
- 公网脚本中“测试中”出现次数：`0`。
- 旧 beta 短下载路由返回 `404`。

## V2.0.0-beta - 2026-04-27

- 交互式入口改为功能分类菜单。
- 新增“游戏加速器”分类。
- 奇游联机宝和雷神加速器并入总脚本，提供应用商店卡片、NRadio 包装页、状态读取和卸载链。
- 用户在 `NRadio_C2000MAX NROS2.1.8.n0.c1` 新设备上完成安装链路现场验证：
  - 奇游联机宝安装、状态读取和应用商店接入完成。
  - 雷神加速器安装、监听端口、服务启用和应用商店接入完成。
  - 应用商店美化 5 阶段执行完成。

## V1.60.5 - 2026-04-26

- 修复应用商店美化旧 CSS 残留。
- 补齐只读系统状态面板。
- 修复进度条占比、破图图标兜底和空描述隐藏。
- 继续保持应用商店外层布局、下载链、安装链和卸载链不变。

## V1.60.0 - 2026-04-26

- 新增“美化应用商店”独立功能。
- 应用卡片、状态徽标、后台标记、按钮和系统状态面板统一优化。
- 该功能独立执行，不自动跟随 2~8 插件安装链。

## V1.50.x - 2026-04

- V1.50.1：脚本插件卸载体验对齐原厂应用商店。
- V1.50.2：应用商店图标缓存刷新修复。
- V1.50.3：2~8 虚拟内存接入链修正。
- V1.50.4：ttyd / Web SSH 页面美化，并补上 14 号 C8-688 机型门禁。
- V1.50.5：OpenVPN Mk2 页面美化回写总脚本。

## Early V1.x

- V1.0.0 起形成 1~8 菜单基础闭环。
- 后续逐步加入 OEM 环境识别、OpenVPN 控制台、swap 管理、EasyTier、风扇控制和应用商店接入链路。
